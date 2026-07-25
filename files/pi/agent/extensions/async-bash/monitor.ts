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

export const MONITOR_INTERVAL_MS = 15_000;
export const STALL_THRESHOLD_MS = 60_000;
const TAIL_LINES = 30;

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
  let stopped = false;

  const tick = () => {
    if (stopped) return;
    const registry = getRegistry();
    if (!registry) return;

    for (const task of registry.list()) {
      registry.refresh(task);
      const f = flags.get(task.id) ?? {
        completionFired: false,
        stalled: false,
        deadlineFired: false,
      };

      // Reset stall flag when output resumes.
      if (f.stalled && Date.now() - task.lastOutputAt < STALL_THRESHOLD_MS) {
        f.stalled = false;
      }

      if (task.status !== "running" && !f.completionFired) {
        f.completionFired = true;
        wake(task, "completion", "followUp");
      } else if (
        task.status === "running" &&
        !f.stalled &&
        Date.now() - task.lastOutputAt > STALL_THRESHOLD_MS &&
        Date.now() - task.startedAt > STALL_THRESHOLD_MS
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

  function wake(task: Task, event: "completion" | "stall" | "deadline", deliverAs: "followUp" | "steer") {
    const tail = safeTail(task);
    const runtime = Math.round(((task.endedAt ?? Date.now()) - task.startedAt) / 1000);
    let headline: string;
    if (event === "completion") {
      const code =
        task.exitCode === null ? "unknown" : task.exitCode;
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

  const handle = setInterval(tick, MONITOR_INTERVAL_MS);
  // Don't keep pi alive for the monitor alone.
  if (typeof (handle as any).unref === "function") (handle as any).unref();
  // Fire once shortly after start so the footer is accurate immediately.
  setTimeout(tick, 1000);

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