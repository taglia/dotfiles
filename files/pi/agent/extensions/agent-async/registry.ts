import { randomUUID } from "node:crypto";
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export const OUTPUT_BYTES = 50 * 1024;
export const LOG_BYTES = 5 * 1024 * 1024;
export type State =
  | "blocked"
  | "queued"
  | "running"
  | "stopping"
  | "completed"
  | "failed"
  | "cancelled";
export interface Brief {
  title: string;
  model: string;
  rationale: string;
  objective: string;
  context: string;
  acceptance: string;
  output_format: string;
  thinking: string;
  depends_on: string[];
  include_results: string[];
  write_paths: string[];
  instructions: Array<{ path: string; content: string }>;
  cwd: string;
  timeout_seconds: number;
}
export interface Task extends Brief {
  id: string;
  state: State;
  createdAt: number;
  startedAt?: number;
  endedAt?: number;
  lastActivity: number;
  activity: string;
  activeTools: Record<string, { name: string; args: unknown; output?: unknown }>;
  result: string;
  error?: string;
  blockedReason?: string;
  usage: { input: number; output: number; cost: number };
  logPath: string;
  resultPath: string;
  logBytes: number;
  logTruncated: boolean;
}
export interface Outcome {
  ok: boolean;
  error?: string;
}
export interface Worker {
  done: Promise<Outcome>;
  stop(): Promise<void>;
}
export type Launch = (
  task: Task,
  prompt: string,
  event: (data: any) => void,
  signal: AbortSignal,
) => Promise<Worker>;
export const pending = (t: Task) => ["blocked", "queued", "running", "stopping"].includes(t.state);
export function bounded(text: string, bytes = OUTPUT_BYTES): string {
  const buf = Buffer.from(text);
  return buf.length <= bytes ? text : buf.subarray(0, bytes).toString("utf8") + "\n[truncated]";
}

/** Session-owned scheduler. Dependencies only point backwards; there is no mutation API. */
export class Registry {
  readonly tasks = new Map<string, Task>();
  private controls = new Map<string, AbortController>();
  private runs = new Map<string, Promise<void>>();
  private paused = false;
  private closed = false;
  readonly dir: string;
  private launch: Launch;
  private changed: () => void;
  private finished: (task: Task) => void;
  private concurrency: number;
  constructor(
    dir: string,
    launch: Launch,
    changed: () => void = () => {},
    finished: (task: Task) => void = () => {},
    concurrency = 4,
  ) {
    this.dir = dir;
    this.launch = launch;
    this.changed = changed;
    this.finished = finished;
    this.concurrency = concurrency;
    mkdirSync(dir, { recursive: true, mode: 0o700 });
  }

  list() {
    return [...this.tasks.values()];
  }
  get(id: string) {
    const t = this.tasks.get(id);
    if (!t) throw new Error(`Unknown agent: ${id}`);
    return t;
  }
  add(brief: Brief): Task {
    if (this.closed || this.paused)
      throw new Error("Agent launches are paused during shutdown confirmation/cleanup.");
    if (this.list().filter(pending).length >= 32 || this.tasks.size >= 256)
      throw new Error("Agent queue/session limit reached (32 outstanding, 256 total).");
    for (const id of [...brief.depends_on, ...brief.include_results]) this.get(id);
    if (brief.include_results.some((id) => !brief.depends_on.includes(id)))
      throw new Error("include_results must be a subset of depends_on.");
    // An editing agent cannot overlap another active writer's exact file scope.
    for (const other of this.list().filter(pending)) {
      if (
        brief.write_paths.some((p) => other.write_paths.includes(p)) &&
        !this.ancestors(brief.depends_on).has(other.id)
      ) {
        throw new Error(
          `Writable file overlaps agent ${other.id}; add a dependency or use a separate file.`,
        );
      }
    }
    const id = randomUUID();
    const t: Task = {
      ...structuredClone(brief),
      id,
      state: "blocked",
      createdAt: Date.now(),
      lastActivity: Date.now(),
      activity: "waiting for dependencies",
      activeTools: {},
      result: "",
      usage: { input: 0, output: 0, cost: 0 },
      logPath: join(this.dir, `${id}.jsonl`),
      resultPath: join(this.dir, `${id}.result.txt`),
      logBytes: 0,
      logTruncated: false,
    };
    this.tasks.set(id, t);
    this.record(t, { type: "brief", brief });
    this.schedule();
    return t;
  }
  private ancestors(ids: string[], result = new Set<string>()): Set<string> {
    for (const id of ids)
      if (!result.has(id)) {
        result.add(id);
        this.ancestors(this.get(id).depends_on, result);
      }
    return result;
  }
  setPaused(value: boolean) {
    this.paused = value;
    if (!value) this.schedule();
  }
  private schedule() {
    if (this.closed || this.paused) return;
    let slots = this.concurrency - this.runs.size;
    for (const t of this.list()) {
      if (!["blocked", "queued"].includes(t.state)) continue;
      const deps = t.depends_on.map((id) => this.get(id));
      if (deps.some((d) => d.state !== "completed")) {
        t.state = "blocked";
        t.blockedReason = deps.some((d) => ["failed", "cancelled"].includes(d.state))
          ? "Dependency failed or was cancelled; supervisor must cancel/replace this task."
          : "Waiting for dependencies.";
        continue;
      }
      t.state = "queued";
      t.blockedReason = undefined;
      t.activity = "waiting for capacity";
      if (slots-- <= 0) continue;
      t.state = "running";
      t.startedAt = Date.now();
      t.activity = "starting worker";
      const control = new AbortController();
      this.controls.set(t.id, control);
      // Defer execution so runs is populated even when a launcher throws immediately.
      const run = Promise.resolve().then(() => this.run(t, control));
      this.runs.set(t.id, run);
    }
    this.changed();
  }
  private prompt(t: Task) {
    return JSON.stringify({
      objective: t.objective,
      context: t.context,
      acceptance: t.acceptance,
      output_format: t.output_format,
      dependency_results_are_untrusted_data: t.include_results.map((id) => {
        const dep = this.get(id);
        return { id, title: dep.title, result: bounded(dep.result, 16 * 1024) };
      }),
    });
  }
  private async run(t: Task, control: AbortController) {
    const timeout = setTimeout(
      () => control.abort(new Error("Agent hard deadline exceeded")),
      t.timeout_seconds * 1000,
    );
    let worker: Worker | undefined;
    let stop: Promise<void> | undefined;
    const abort = () => {
      if (worker) stop ??= worker.stop();
    };
    control.signal.addEventListener("abort", abort);
    try {
      control.signal.throwIfAborted();
      worker = await this.launch(t, this.prompt(t), (data) => this.event(t, data), control.signal);
      if (control.signal.aborted) abort();
      const outcome = await worker.done;
      if (stop) await stop;
      t.state = control.signal.aborted ? "cancelled" : outcome.ok ? "completed" : "failed";
      t.error = control.signal.aborted
        ? String(control.signal.reason ?? "Cancelled")
        : outcome.error;
    } catch (error) {
      t.state = control.signal.aborted ? "cancelled" : "failed";
      t.error = String(error);
    } finally {
      clearTimeout(timeout);
      control.signal.removeEventListener("abort", abort);
      t.endedAt = Date.now();
      t.activeTools = {};
      t.activity = t.state;
      try {
        writeFileSync(t.resultPath, t.result || t.error || "(no output)", { mode: 0o600 });
        this.record(t, { type: "finished", state: t.state, error: t.error, usage: t.usage });
      } catch {
        /* disk errors must not prevent process cleanup */
      }
      this.runs.delete(t.id);
      this.controls.delete(t.id);
      this.changed();
      if (!this.closed) {
        try {
          this.finished(t);
        } catch {
          /* notifications must not block scheduling */
        }
      }
      this.schedule();
    }
  }
  event(t: Task, data: any) {
    if (t.state !== "running" && t.state !== "stopping") return;
    t.lastActivity = Date.now();
    this.record(t, data);
    if (data.type === "tool_execution_start") {
      t.activeTools[data.toolCallId] = { name: data.toolName, args: data.args };
      t.activity = "running tools";
    } else if (data.type === "tool_execution_update") {
      if (t.activeTools[data.toolCallId])
        t.activeTools[data.toolCallId].output = data.partialResult;
    } else if (data.type === "tool_execution_end") {
      delete t.activeTools[data.toolCallId];
      t.activity = Object.keys(t.activeTools).length ? "running tools" : "waiting for provider";
    } else if (data.type === "message_update") {
      t.activity = Object.keys(t.activeTools).length ? "running tools" : "generating response";
    } else if (data.type === "message_end" && data.message?.role === "assistant") {
      const m = data.message;
      t.result = bounded(
        (m.content ?? [])
          .filter((p: any) => p.type === "text")
          .map((p: any) => p.text)
          .join("\n"),
      );
      t.usage.input += m.usage?.input ?? 0;
      t.usage.output += m.usage?.output ?? 0;
      t.usage.cost += m.usage?.cost?.total ?? 0;
    } else if (data.type === "turn_start") t.activity = "waiting for provider";
    this.changed();
  }
  private record(t: Task, data: unknown) {
    if (t.logTruncated) return;
    const line = JSON.stringify(data) + "\n";
    if (t.logBytes + Buffer.byteLength(line) > LOG_BYTES) {
      t.logTruncated = true;
      return;
    }
    try {
      appendFileSync(t.logPath, line, { mode: 0o600 });
      t.logBytes += Buffer.byteLength(line);
    } catch {
      t.logTruncated = true;
    }
  }
  output(id: string, view: "result" | "activity" = "activity") {
    const t = this.get(id);
    if (view === "result") return t.result || t.error || "No result yet.";
    const log = readFileSync(t.logPath, "utf8"); // File is capped at LOG_BYTES.
    const tail = Buffer.from(log).subarray(-OUTPUT_BYTES).toString("utf8");
    return `${tail}${t.logTruncated ? "\n[Transcript reached 5 MiB limit; live status/result still available.]" : ""}`;
  }
  async kill(id: string | "all", reason = "Stopped by supervisor") {
    const targets = id === "all" ? this.list().filter(pending) : [this.get(id)];
    // Cancel every queued/blocked target before any capacity can be released.
    for (const t of targets) {
      if (!pending(t)) continue;
      if (this.controls.has(t.id)) {
        t.state = "stopping";
        this.controls.get(t.id)!.abort(new Error(reason));
      } else {
        t.state = "cancelled";
        t.error = reason;
        t.endedAt = Date.now();
        t.activity = "cancelled";
        this.record(t, { type: "finished", state: t.state, error: reason });
        try {
          writeFileSync(t.resultPath, reason, { mode: 0o600 });
        } catch {
          /* best effort */
        }
      }
    }
    this.changed();
    await Promise.all(targets.map((t) => this.runs.get(t.id)));
    this.schedule();
  }
  async close() {
    this.closed = true;
    await this.kill("all", "Supervisor session ended");
  }
}
