/**
 * Background monitor for async-bash.
 *
 * Completion of a same-session task is event-driven: the registry fires a
 * `onFinished` callback from the child's `exit` handler, and the monitor
 * wakes the agent immediately (small debounce for the final log flush).
 *
 * The periodic tick only handles things that genuinely require polling:
 * stall detection (no log growth for a while), soft-deadline overruns, and
 * tasks restored after a pi restart (no ChildProcess handle -> pid liveness
 * polling with exponential backoff). The monitor never kills anything — it
 * only reports; the LLM makes the judgement call.
 *
 * Tunables live at the top.
 */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Registry, type Task } from "./registry";

/** Minimum time between output checks for any task. */
export const MONITOR_INITIAL_INTERVAL_MS = 30_000;
/** Long-running tasks are never checked less often than this. */
export const MONITOR_MAX_INTERVAL_MS = 10 * 60_000;
/** Double the task-specific interval every two minutes of runtime. */
const MONITOR_BACKOFF_WINDOW_MS = 2 * 60_000;
export const STALL_THRESHOLD_MS = 60_000;
const TAIL_LINES = 30;
/** Delay between a task's `exit` event and the completion wake-up, so the
 *  final log bytes land in the file before we tail it. */
const COMPLETION_FLUSH_MS = 250;

/**
 * Return the minimum interval between checks for a task at a given time.
 *
 * The scheduler itself may wake more often to notice newly started tasks, but
 * callers must not refresh a task's log more often than this interval.
 */
export function monitorIntervalMs(task: Pick<Task, "startedAt">, now = Date.now()): number {
  const age = Math.max(0, now - task.startedAt);
  const doublings = Math.floor(age / MONITOR_BACKOFF_WINDOW_MS);
  return Math.min(MONITOR_MAX_INTERVAL_MS, MONITOR_INITIAL_INTERVAL_MS * 2 ** doublings);
}

interface Flags {
  completionFired: boolean;
  stalled: boolean;
  deadlineFired: boolean;
}

export function startMonitor(
  pi: ExtensionAPI,
  ui: ExtensionContext["ui"] | undefined,
  getRegistry: () => Registry | null,
): () => void {
  const flags = new Map<string, Flags>();
  const lastCheckedAt = new Map<string, number>();
  let stopped = false;
  let unsubscribe: (() => void) | null = null;

  const getFlags = (id: string): Flags => {
    let f = flags.get(id);
    if (!f) {
      f = { completionFired: false, stalled: false, deadlineFired: false };
      flags.set(id, f);
    }
    return f;
  };

  /**
   * Event-driven completion path: the registry fires this synchronously from
   * the child's `exit` handler. Wake the agent after a short flush delay.
   */
  const onFinished = (task: Task) => {
    if (stopped) return;
    const f = getFlags(task.id);
    if (f.completionFired) return;
    f.completionFired = true;
    const timer = setTimeout(() => {
      if (stopped) return;
      const registry = getRegistry();
      registry?.refresh(task); // pick up the flushed log tail
      wake(task, "completion", "followUp");
      // Persist the reported flag so a later /resume doesn't re-announce.
      task.reported = true;
      void registry?.persist();
    }, COMPLETION_FLUSH_MS);
    if (typeof (timer as any).unref === "function") (timer as any).unref();
  };

  /**
   * The registry is only available once a session is active; subscribe the
   * first time we see it (and re-subscribe if the instance changes).
   */
  const ensureSubscription = () => {
    if (unsubscribe) return;
    const registry = getRegistry();
    if (registry) unsubscribe = registry.onFinished(onFinished);
  };

  const tick = () => {
    if (stopped) return;
    ensureSubscription();
    const registry = getRegistry();
    if (!registry) return;

    const now = Date.now();
    const tasks = registry.list();
    const activeIds = new Set(tasks.map((task) => task.id));
    for (const id of lastCheckedAt.keys()) {
      if (!activeIds.has(id)) lastCheckedAt.delete(id);
    }
    for (const id of flags.keys()) {
      if (!activeIds.has(id)) flags.delete(id);
    }

    for (const task of tasks) {
      const f = getFlags(task.id);
      if (task.status !== "running") {
        // Completion is normally delivered immediately via onFinished; this
        // is just the backstop (e.g. task already dead when the monitor
        // started and no exit event ever fired). Tasks whose completion was
        // already reported (persisted flag) are skipped so a /resume doesn't
        // re-announce them.
        if (!f.completionFired && !task.reported) {
          f.completionFired = true;
          registry.refresh(task);
          wake(task, "completion", "followUp");
          task.reported = true;
          void registry.persist();
        }
        continue;
      }

      // Still running. Log-stat refreshes (for stall/deadline detection) and
      // pid-liveness probes (for handle-less restored tasks) are throttled
      // by the adaptive interval — completion itself is event-driven and
      // never waits on this loop.
      const lastChecked = lastCheckedAt.get(task.id);
      if (lastChecked !== undefined && now - lastChecked < monitorIntervalMs(task, now)) {
        continue;
      }
      lastCheckedAt.set(task.id, now);
      registry.refresh(task);
      if (!registry.hasHandle(task.id)) registry.detectExit(task);

      // Reset stall flag when output resumes.
      if (f.stalled && now - task.lastOutputAt < STALL_THRESHOLD_MS) {
        f.stalled = false;
      }

      if (
        task.status === "running" &&
        !f.stalled &&
        now - task.lastOutputAt > STALL_THRESHOLD_MS &&
        now - task.startedAt > STALL_THRESHOLD_MS
      ) {
        f.stalled = true;
        wake(task, "stall", "steer");
      } else if (
        task.status === "running" &&
        task.softDeadlineMs &&
        !f.deadlineFired &&
        now - task.startedAt > task.softDeadlineMs
      ) {
        f.deadlineFired = true;
        wake(task, "deadline", "steer");
      }
    }

    // Footer status (best effort, both TUI + RPC).
    if (ui) {
      const n = registry.running().length;
      try {
        if (n > 0) {
          ui.setStatus("async-bash", `⚙ ${n} async task${n > 1 ? "s" : ""}`);
        } else {
          ui.setStatus("async-bash", "");
        }
      } catch {
        /* ignore */
      }
    }
  };

  function wake(
    task: Task,
    event: "completion" | "stall" | "deadline",
    deliverAs: "followUp" | "steer",
  ) {
    const tail = safeTail(task);
    const runtime = Math.round(((task.endedAt ?? Date.now()) - task.startedAt) / 1000);
    let headline: string;
    if (event === "completion") {
      const code = task.exitCode === null ? "unknown" : task.exitCode;
      headline = `async-bash task ${task.id} finished (exit ${code}) after ${runtime}s.`;
    } else if (event === "stall") {
      const since = Math.round((Date.now() - task.lastOutputAt) / 1000);
      headline = `async-bash task ${task.id} appears stalled: no output for ${since}s (still running, pid ${task.pid}).`;
    } else {
      const dl = Math.round((task.softDeadlineMs ?? 0) / 1000);
      headline = `async-bash task ${task.id} exceeded its soft deadline of ${dl}s (still running, pid ${task.pid}).`;
    }
    const body = tail ? `\n\nLast output:\n${tail}` : "\n\n(no output captured yet)";
    const cmd = task.command.replace(/\s+/g, " ").trim().slice(0, 200);

    try {
      pi.sendMessage(
        {
          customType: "async-bash",
          content: `${headline}\ncommand: ${cmd}${body}\n\nDecide whether to keep waiting, investigate with bash_output, or kill it with bash_kill.`,
          display: true,
          details: { taskId: task.id, event, pid: task.pid, exitCode: task.exitCode ?? null },
        },
        { triggerTurn: true, deliverAs },
      );
    } catch {
      /* ignore */
    }
  }

  function safeTail(task: Task): string {
    try {
      return (getRegistry()?.readLog(task.id, { tail: TAIL_LINES }) ?? "").trim();
    } catch {
      return "";
    }
  }

  // Wake periodically to notice newly launched tasks, subscribe to the
  // registry's finished events, and run the health checks above. Completion
  // of same-session tasks is NOT gated on this interval — it is delivered
  // immediately via onFinished.
  ensureSubscription();
  const handle = setInterval(tick, MONITOR_INITIAL_INTERVAL_MS);
  // Don't keep pi alive for the monitor alone.
  if (typeof (handle as any).unref === "function") (handle as any).unref();

  return () => {
    stopped = true;
    clearInterval(handle);
    unsubscribe?.();
    unsubscribe = null;
    if (ui) {
      try {
        ui.setStatus("async-bash", "");
      } catch {
        /* ignore */
      }
    }
  };
}
