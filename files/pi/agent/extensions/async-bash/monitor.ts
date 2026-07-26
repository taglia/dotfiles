/**
 * Background monitor for async-bash.
 *
 * Polls every task periodically and wakes the agent (via an injected message)
 * when something interesting happens: the task finished, stalled (no log
 * growth for a while), or exceeded its soft deadline. The monitor never kills
 * anything — it only reports; the LLM makes the judgement call.
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

  const tick = () => {
    if (stopped) return;
    const registry = getRegistry();
    if (!registry) return;

    const now = Date.now();
    const tasks = registry.list();
    const activeIds = new Set(tasks.map((task) => task.id));
    for (const id of lastCheckedAt.keys()) {
      if (!activeIds.has(id)) lastCheckedAt.delete(id);
    }

    for (const task of tasks) {
      const f = flags.get(task.id) ?? {
        completionFired: false,
        stalled: false,
        deadlineFired: false,
      };
      // Completion is checked on every scheduler tick, but running-task log
      // refreshes are throttled using the adaptive interval below.
      if (task.status !== "running" && f.completionFired) continue;
      const lastChecked = lastCheckedAt.get(task.id);
      if (
        task.status === "running" &&
        lastChecked !== undefined &&
        now - lastChecked < monitorIntervalMs(task, now)
      ) {
        continue;
      }
      lastCheckedAt.set(task.id, now);
      registry.refresh(task);

      // Reset stall flag when output resumes.
      if (f.stalled && now - task.lastOutputAt < STALL_THRESHOLD_MS) {
        f.stalled = false;
      }

      if (task.status !== "running" && !f.completionFired) {
        f.completionFired = true;
        wake(task, "completion", "followUp");
      } else if (
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
        Date.now() - task.startedAt > task.softDeadlineMs
      ) {
        f.deadlineFired = true;
        wake(task, "deadline", "steer");
      }

      flags.set(task.id, f);
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

  // Wake periodically to notice newly launched tasks, but each task's output
  // is refreshed only when its own adaptive interval has elapsed.
  const handle = setInterval(tick, MONITOR_INITIAL_INTERVAL_MS);
  // Don't keep pi alive for the monitor alone.
  if (typeof (handle as any).unref === "function") (handle as any).unref();

  return () => {
    stopped = true;
    clearInterval(handle);
    if (ui) {
      try {
        ui.setStatus("async-bash", "");
      } catch {
        /* ignore */
      }
    }
  };
}
