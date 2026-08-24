/**
 * Task registry for async-bash.
 *
 * Each task is a detached child process whose stdout/stderr are redirected
 * directly to a per-task log file (via an inherited fd), so the child keeps
 * appending even if pi exits and restarts. We keep the ChildProcess handle
 * for the live session (to receive `exit` events promptly); on restart we
 * rediscover tasks from a `tasks.json` manifest and detect exit by pid
 * liveness.
 *
 * The registry only ever kills PIDs it spawned itself.
 */
import { spawn, spawnSync, type ChildProcess } from "node:child_process";
import {
  closeSync,
  existsSync,
  fstatSync,
  mkdirSync,
  openSync,
  readFileSync,
  readSync,
  writeFileSync,
  statSync,
} from "node:fs";
import { join } from "node:path";
import { randomUUID } from "node:crypto";

export type TaskStatus = "running" | "exited" | "killed";

export interface Task {
  id: string;
  command: string;
  cwd: string;
  pid: number;
  startedAt: number;
  endedAt?: number;
  logPath: string;
  status: TaskStatus;
  exitCode: number | null; // null = unknown (lost across restart)
  softDeadlineMs?: number;
  /** Process identity captured at spawn (via `ps`), used after a restart to
   *  make sure a restored pid still refers to our process and not a reused
   *  one. Missing when `ps` failed or the process died before we could ask. */
  procStartTime?: string;
  procCommand?: string;
  /** True once the monitor has announced this task's completion to the agent
   *  (persisted so /resume doesn't re-announce already-reported tasks). */
  reported?: boolean;
  // polled fields
  lastLogSize: number;
  lastOutputAt: number;
}

export interface SpawnOptions {
  command: string;
  cwd: string;
  softDeadlineMs?: number;
}

export interface SpawnResult {
  task: Task;
  exitPromise: Promise<number | null>;
}

/** Called synchronously when a task's process exits or errors out. */
export type FinishedListener = (task: Task) => void;

export const MAX_LOG_BYTES = 50 * 1024;
const MANIFEST = "tasks.json";

function nowMs() {
  return Date.now();
}

/**
 * Read a process's start time and command line via `ps` (the `lstart=` and
 * `command=` formats work on both macOS and Linux). Returns null when the
 * process is gone or `ps` fails.
 */
function readProcInfo(pid: number): { startTime: string; command: string } | null {
  if (!pid || pid < 0) return null;
  try {
    const start = spawnSync("ps", ["-o", "lstart=", "-p", String(pid)], { encoding: "utf-8" });
    const startTime = start.status === 0 ? start.stdout.trim() : "";
    if (!startTime) return null;
    const cmd = spawnSync("ps", ["-o", "command=", "-p", String(pid)], { encoding: "utf-8" });
    const command = cmd.status === 0 ? cmd.stdout.trim() : "";
    return { startTime, command };
  } catch {
    return null;
  }
}

/** Read at most the trailing maxBytes of a file without slurping the rest. */
function readFileTailBytes(path: string, maxBytes: number): { text: string; truncated: boolean } {
  const fd = openSync(path, "r");
  try {
    const size = fstatSync(fd).size;
    const start = Math.max(0, size - maxBytes);
    const length = size - start;
    const buf = Buffer.alloc(length);
    let read = 0;
    while (read < length) {
      const n = readSync(fd, buf, read, length - read, start + read);
      if (n <= 0) break;
      read += n;
    }
    return { text: buf.subarray(0, read).toString("utf-8"), truncated: start > 0 };
  } finally {
    closeSync(fd);
  }
}

export class Registry {
  private tasks = new Map<string, Task>();
  private children = new Map<string, ChildProcess>();
  private finishedListeners = new Set<FinishedListener>();
  private dir: string;

  constructor(dir: string) {
    this.dir = dir;
  }

  private ensureDir() {
    if (!existsSync(this.dir)) mkdirSync(this.dir, { recursive: true });
  }

  /**
   * Subscribe to task-finished events. Fired from the child's `exit`/`error`
   * handlers, i.e. immediately when a same-session process ends — no polling
   * involved. Returns an unsubscribe function.
   */
  onFinished(cb: FinishedListener): () => void {
    this.finishedListeners.add(cb);
    return () => {
      this.finishedListeners.delete(cb);
    };
  }

  private emitFinished(task: Task): void {
    for (const cb of this.finishedListeners) {
      try {
        cb(task);
      } catch {
        /* listener errors must not break the exit handler */
      }
    }
  }

  spawn(opts: SpawnOptions): SpawnResult {
    this.ensureDir();
    const id = randomUUID().slice(0, 8);
    const logPath = join(this.dir, `${id}.log`);

    // Open the log fd; the child inherits it and writes directly, so output
    // survives a pi restart even though we don't reattach a pipe.
    let fd: number;
    try {
      fd = openSync(logPath, "a");
    } catch {
      fd = openSync(logPath, "w");
    }

    let child: ChildProcess;
    try {
      child = spawn("bash", ["-c", opts.command], {
        cwd: opts.cwd,
        stdio: ["ignore", fd, fd],
        detached: true,
      });
    } catch (err) {
      closeSync(fd);
      const task: Task = {
        id,
        command: opts.command,
        cwd: opts.cwd,
        pid: -1,
        startedAt: nowMs(),
        endedAt: nowMs(),
        logPath,
        status: "exited",
        exitCode: -1,
        lastLogSize: 0,
        lastOutputAt: nowMs(),
      };
      this.tasks.set(id, task);
      void this.persist();
      return { task, exitPromise: Promise.resolve(-1) };
    }
    // Parent doesn't need its fd copy; the child keeps writing.
    try {
      closeSync(fd);
    } catch {
      /* ignore */
    }

    if (typeof child.pid !== "number") {
      const task: Task = {
        id,
        command: opts.command,
        cwd: opts.cwd,
        pid: -1,
        startedAt: nowMs(),
        endedAt: nowMs(),
        logPath,
        status: "exited",
        exitCode: -1,
        lastLogSize: 0,
        lastOutputAt: nowMs(),
      };
      this.tasks.set(id, task);
      void this.persist();
      return { task, exitPromise: Promise.resolve(-1) };
    }

    // Don't keep pi alive just for this child; it's background work.
    child.unref();

    // Capture the process identity so a restored session can tell this pid
    // apart from an unrelated process that reused it.
    const procInfo = readProcInfo(child.pid);

    const task: Task = {
      id,
      command: opts.command,
      cwd: opts.cwd,
      pid: child.pid,
      startedAt: nowMs(),
      logPath,
      status: "running",
      exitCode: null,
      softDeadlineMs: opts.softDeadlineMs,
      procStartTime: procInfo?.startTime,
      procCommand: procInfo?.command,
      lastLogSize: 0,
      lastOutputAt: nowMs(),
    };
    this.tasks.set(id, task);
    this.children.set(id, child);
    void this.persist();

    const exitPromise = new Promise<number | null>((resolve) => {
      child.once("exit", (code, signal) => {
        const t = this.tasks.get(id);
        if (t) {
          t.status = signal ? "killed" : "exited";
          t.exitCode = code;
          t.endedAt = nowMs();
          this.refresh(t);
          this.emitFinished(t);
          void this.persist();
        }
        this.children.delete(id);
        resolve(code);
      });
    });
    child.on("error", () => {
      const t = this.tasks.get(id);
      if (t) {
        t.status = "exited";
        t.exitCode = -1;
        t.endedAt = nowMs();
        this.emitFinished(t);
        void this.persist();
      }
      this.children.delete(id);
    });

    return { task, exitPromise };
  }

  /** True while we still hold the ChildProcess handle for this task. */
  hasHandle(id: string): boolean {
    return this.children.has(id);
  }

  /**
   * Polling fallback for tasks whose ChildProcess handle is gone (restored
   * after a pi restart): if the pid is dead, mark the task exited and notify
   * listeners. Same-session tasks never need this — their `exit` event fires
   * on its own. Returns true when the task transitioned out of "running".
   */
  detectExit(task: Task): boolean {
    if (task.status !== "running" || this.children.has(task.id)) return false;
    if (this.pidAlive(task.pid) && this.isOurProcess(task)) return false;
    task.status = "exited";
    task.exitCode = null;
    task.endedAt = nowMs();
    this.refresh(task);
    this.emitFinished(task);
    void this.persist();
    return true;
  }

  /** Stat the log file to update size + last-output time. */
  refresh(task: Task): void {
    try {
      const st = statSync(task.logPath);
      const size = st.size;
      if (size !== task.lastLogSize) {
        task.lastLogSize = size;
        task.lastOutputAt = st.mtimeMs || nowMs();
      }
    } catch {
      /* log may not exist yet */
    }
  }

  get(id: string): Task | undefined {
    return this.tasks.get(id);
  }

  list(): Task[] {
    return Array.from(this.tasks.values());
  }

  running(): Task[] {
    return this.list().filter((t) => t.status === "running");
  }

  /** Returns true if a pid is alive and ours to signal. EPERM means the pid
   *  now belongs to a process we can't signal — for our purposes that task is
   *  gone (we only ever spawn children we own). */
  private pidAlive(pid: number): boolean {
    if (!pid || pid < 0) return false;
    try {
      process.kill(pid, 0);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * True when a task's pid still refers to the process we spawned. For live
   * children the handle is proof enough; for restored tasks compare the
   * `ps` start time (and command) captured at spawn — a reused pid would
   * differ. Restored tasks with no recorded identity are never trusted.
   */
  private isOurProcess(task: Task): boolean {
    if (this.children.has(task.id)) return true;
    if (!task.procStartTime) return false;
    const info = readProcInfo(task.pid);
    if (!info || info.startTime !== task.procStartTime) return false;
    if (task.procCommand && info.command !== task.procCommand) return false;
    return true;
  }

  /**
   * Kill a task we spawned. SIGTERM the whole process group, escalate to
   * SIGKILL after 5s. Refuses unknown tasks.
   */
  async kill(id: string, _reason?: string): Promise<{ ok: boolean; message: string }> {
    const task = this.tasks.get(id);
    if (!task) return { ok: false, message: `Unknown task id: ${id}` };
    if (task.status !== "running") {
      return { ok: false, message: `Task ${id} is not running (status: ${task.status})` };
    }

    const child = this.children.get(id);
    const pid = task.pid;
    const trySignal = (sig: NodeJS.Signals) => {
      // Signal the whole process group first (spawned detached, so the child
      // leads its own group); fall back to the child alone.
      try {
        process.kill(-pid, sig);
        return true;
      } catch {
        try {
          process.kill(pid, sig);
          return true;
        } catch {
          return false;
        }
      }
    };

    // For restored tasks (no ChildProcess handle) make sure the pid still
    // refers to the process we spawned before signaling anything — the pid
    // may have been reused by an unrelated process.
    if (!this.pidAlive(pid) || !this.isOurProcess(task)) {
      task.status = "exited";
      task.endedAt = nowMs();
      void this.persist();
      return { ok: false, message: `Task ${id} already exited.` };
    }

    trySignal("SIGTERM");
    // Wait up to 5s for graceful exit.
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 200));
      if (!this.pidAlive(pid)) {
        task.status = "killed";
        task.exitCode = null;
        task.endedAt = nowMs();
        this.children.delete(id);
        // Restored tasks have no ChildProcess handle, so no `exit` event
        // will fire — notify listeners directly.
        if (!child) this.emitFinished(task);
        void this.persist();
        return { ok: true, message: `Task ${id} terminated (SIGTERM).` };
      }
    }
    // Re-verify identity before the forceful kill, in case the pid was
    // recycled while we waited.
    if (child || this.isOurProcess(task)) trySignal("SIGKILL");
    task.status = "killed";
    task.exitCode = null;
    task.endedAt = nowMs();
    this.children.delete(id);
    if (!child) this.emitFinished(task);
    void this.persist();
    return { ok: true, message: `Task ${id} killed (SIGKILL after timeout).` };
  }

  /** Read a task's log: tail N lines or full (truncated to MAX_LOG_BYTES).
   *  Only the trailing MAX_LOG_BYTES are ever read into memory, so an
   *  unbounded log can't blow up the process. */
  readLog(id: string, opts: { tail?: number; full?: boolean }): string {
    const task = this.tasks.get(id);
    if (!task) throw new Error(`Unknown task id: ${id}`);
    if (!existsSync(task.logPath)) return "";
    const { text, truncated } = readFileTailBytes(task.logPath, MAX_LOG_BYTES);
    if (opts.full) {
      return truncated ? `[Output truncated to the last ${MAX_LOG_BYTES} bytes]\n\n${text}` : text;
    }
    const lines = text.split("\n");
    const n = opts.tail ?? 50;
    return lines.slice(-n).join("\n");
  }

  /** Persist a manifest so tasks survive restarts. */
  async persist(): Promise<void> {
    this.ensureDir();
    const snapshot = this.list().map((t) => ({
      id: t.id,
      command: t.command,
      cwd: t.cwd,
      pid: t.pid,
      startedAt: t.startedAt,
      endedAt: t.endedAt,
      logPath: t.logPath,
      status: t.status,
      exitCode: t.exitCode,
      softDeadlineMs: t.softDeadlineMs,
      procStartTime: t.procStartTime,
      procCommand: t.procCommand,
      reported: t.reported,
    }));
    try {
      writeFileSync(join(this.dir, MANIFEST), JSON.stringify(snapshot, null, 2));
    } catch {
      /* best effort */
    }
  }

  /** Rebuild task state from the manifest; mark dead pids as exited. */
  async restore(): Promise<void> {
    const path = join(this.dir, MANIFEST);
    if (!existsSync(path)) return;
    let arr: any[];
    try {
      arr = JSON.parse(readFileSync(path, "utf-8"));
    } catch {
      return;
    }
    if (!Array.isArray(arr)) return;
    for (const e of arr) {
      if (!e || typeof e.id !== "string") continue;
      const task: Task = {
        id: e.id,
        command: e.command,
        cwd: e.cwd,
        pid: e.pid,
        startedAt: e.startedAt,
        endedAt: e.endedAt,
        logPath: e.logPath,
        status: e.status,
        exitCode: e.exitCode,
        softDeadlineMs: e.softDeadlineMs,
        procStartTime: e.procStartTime,
        procCommand: e.procCommand,
        reported: e.reported,
        lastLogSize: 0,
        lastOutputAt: e.startedAt || nowMs(),
      };
      // Dead pid, or a pid recycled by an unrelated process, both mean the
      // task itself is gone.
      if (task.status === "running" && !(this.pidAlive(task.pid) && this.isOurProcess(task))) {
        task.status = "exited";
        task.exitCode = null;
        task.endedAt = nowMs();
      }
      this.refresh(task);
      this.tasks.set(task.id, task);
    }
    void this.persist();
  }

  formatSummary(): string {
    const tasks = this.list();
    if (tasks.length === 0) return "No background tasks.";
    return tasks
      .map((t) => {
        const elapsed = Math.round(((t.endedAt ?? nowMs()) - t.startedAt) / 1000);
        const code =
          t.status === "running"
            ? "running"
            : t.exitCode === null
              ? "done(?)"
              : `exit ${t.exitCode}`;
        return `• ${t.id} [${code}] ${elapsed}s — ${truncateCmd(t.command)}`;
      })
      .join("\n");
  }
}

function truncateCmd(cmd: string, n = 60): string {
  const one = cmd.replace(/\s+/g, " ").trim();
  return one.length > n ? one.slice(0, n) + "…" : one;
}
