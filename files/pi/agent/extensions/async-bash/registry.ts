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
import { spawn, type ChildProcess } from "node:child_process";
import {
  closeSync,
  existsSync,
  mkdirSync,
  openSync,
  readFileSync,
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

export const MAX_LOG_BYTES = 50 * 1024;
const MANIFEST = "tasks.json";

function nowMs() {
  return Date.now();
}

export class Registry {
  private tasks = new Map<string, Task>();
  private children = new Map<string, ChildProcess>();
  private dir: string;

  constructor(dir: string) {
    this.dir = dir;
  }

  private ensureDir() {
    if (!existsSync(this.dir)) mkdirSync(this.dir, { recursive: true });
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
      return { task, exitPromise: Promise.resolve(-1) };
    }

    // Don't keep pi alive just for this child; it's background work.
    child.unref();

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
      lastLogSize: 0,
      lastOutputAt: nowMs(),
    };
    this.tasks.set(id, task);
    this.children.set(id, child);

    const exitPromise = new Promise<number | null>((resolve) => {
      child.once("exit", (code, signal) => {
        const t = this.tasks.get(id);
        if (t) {
          t.status = signal ? "killed" : "exited";
          t.exitCode = code;
          t.endedAt = nowMs();
          this.refresh(t);
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
      }
      this.children.delete(id);
    });

    return { task, exitPromise };
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

  /** Returns true if a pid is alive. */
  private pidAlive(pid: number): boolean {
    if (!pid || pid < 0) return false;
    try {
      process.kill(pid, 0);
      return true;
    } catch (err: any) {
      return err.code === "EPERM"; // alive but not ours to signal
    }
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
      if (child && typeof child.kill === "function") {
        // child.kill only signals the child itself; for the group use -pid.
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
      } else {
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
      }
    };

    if (!this.pidAlive(pid)) {
      task.status = "exited";
      task.endedAt = nowMs();
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
        return { ok: true, message: `Task ${id} terminated (SIGTERM).` };
      }
    }
    trySignal("SIGKILL");
    task.status = "killed";
    task.exitCode = null;
    task.endedAt = nowMs();
    this.children.delete(id);
    return { ok: true, message: `Task ${id} killed (SIGKILL after timeout).` };
  }

  /** Read a task's log: tail N lines or full (truncated to MAX_LOG_BYTES). */
  readLog(id: string, opts: { tail?: number; full?: boolean }): string {
    const task = this.tasks.get(id);
    if (!task) throw new Error(`Unknown task id: ${id}`);
    if (!existsSync(task.logPath)) return "";
    let content = readFileSync(task.logPath, "utf-8");
    if (opts.full) {
      const bytes = Buffer.byteLength(content, "utf-8");
      if (bytes > MAX_LOG_BYTES) {
        content =
          content.slice(0, MAX_LOG_BYTES) + `\n\n[Output truncated at ${MAX_LOG_BYTES} bytes]`;
      }
      return content;
    }
    const lines = content.split("\n");
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
        lastLogSize: 0,
        lastOutputAt: e.startedAt || nowMs(),
      };
      if (task.status === "running" && !this.pidAlive(task.pid)) {
        task.status = "exited";
        task.exitCode = null;
        task.endedAt = nowMs();
      }
      this.refresh(task);
      this.tasks.set(task.id, task);
    }
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
