/**
 * LLM-facing tools for async-bash.
 *
 * Adds a parallel `bash_async` tool (the built-in `bash` is left untouched) plus
 * `bash_status`, `bash_output`, and `bash_kill` for managing background tasks.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { Registry, type Task } from "./registry";

/** Short grace window so instant failures (e.g. "command not found") come back
 *  synchronously in the same tool call instead of becoming a background task. */
export const GRACE_MS = 2000;

export function registerTools(pi: ExtensionAPI, getRegistry: () => Registry | null) {
  // ---- bash_async ----------------------------------------------------------
  pi.registerTool({
    name: "bash_async",
    label: "Bash (async)",
    description:
      "Run a shell command in a background subprocess and return immediately with a task_id. " +
      "Use for long-running commands (builds, test suites, installs, dev servers). " +
      "The agent is woken automatically when the task finishes, stalls, or exceeds its soft deadline. " +
      "Does NOT block the agent flow. Use the built-in `bash` for quick commands.",
    promptSnippet: "Run a long-running shell command in the background and return a task_id",
    promptGuidelines: [
      "Use bash_async for commands that may run longer than ~30s (builds, test suites, package installs, dev servers, long scripts). Use bash for quick commands so you don't add round-trips.",
      "After calling bash_async you get a task_id; use bash_status and bash_output to inspect progress, and bash_kill to stop it. You will also be notified automatically on completion, stall, or soft-deadline.",
    ],
    parameters: Type.Object({
      command: Type.String({ description: "The shell command to run" }),
      timeout: Type.Optional(
        Type.Number({
          description:
            "Soft deadline in seconds. If the task is still running past this, the monitor wakes you so you can decide whether to keep waiting or kill it. Not a hard kill.",
        }),
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const registry = getRegistry();
      if (!registry) {
        return textResult("No active session registry.");
      }
      const { command, timeout } = params as { command: string; timeout?: number };
      const softDeadlineMs = timeout ? timeout * 1000 : undefined;

      const { task, exitPromise } = registry.spawn({
        command,
        cwd: ctx.cwd,
        softDeadlineMs,
      });

      // Grace window: capture instant failures synchronously.
      const settled = await Promise.race([
        exitPromise.then((code) => ({ exited: true as const, code })),
        new Promise<{ exited: false }>((r) => setTimeout(() => r({ exited: false }), GRACE_MS)),
      ]);

      if (settled.exited) {
        const output = registry.readLog(task.id, { tail: 200 });
        const trimmed = output.trim();
        const body = trimmed ? `\n\nOutput:\n${trimmed}` : "\n\n(no output)";
        return textResult(`Command finished (exit ${task.exitCode}) in ${elapsed(task)}s.${body}`, {
          task_id: task.id,
          status: task.status,
          exit_code: task.exitCode,
          log_path: task.logPath,
        });
      }

      return textResult(
        [
          `Started in background.`,
          `- task_id: ${task.id}`,
          `- pid: ${task.pid}`,
          `- log: ${task.logPath}`,
          softDeadlineMs ? `- soft deadline: ${timeout}s` : null,
          ``,
          `You'll be notified when it finishes or stalls. Use bash_status / bash_output to check progress, bash_kill to stop it.`,
        ]
          .filter(Boolean)
          .join("\n"),
        {
          task_id: task.id,
          status: "running",
          pid: task.pid,
          log_path: task.logPath,
          soft_deadline_ms: softDeadlineMs,
        },
      );
    },
  });

  // ---- bash_status ---------------------------------------------------------
  pi.registerTool({
    name: "bash_status",
    label: "Bash status",
    description:
      "Report the health of background tasks started with bash_async: runtime, log size/growth, time since last output, and exit code. Pass a task_id for one task, or omit for all.",
    promptSnippet: "Check health/runtime of background bash_async tasks",
    promptGuidelines: [
      "Use bash_status to check the health and runtime of background tasks started with bash_async before deciding whether to keep waiting, investigate, or kill.",
    ],
    parameters: Type.Object({
      task_id: Type.Optional(Type.String({ description: "Specific task id; omit for all tasks" })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const registry = getRegistry();
      if (!registry) return textResult("No active session registry.");
      const { task_id } = params as { task_id?: string };
      const tasks = task_id ? ([registry.get(task_id)].filter(Boolean) as Task[]) : registry.list();
      if (tasks.length === 0) return textResult("No matching background tasks.");
      for (const t of tasks) registry.refresh(t);
      const lines = tasks.map(formatStatusLine);
      return textResult(lines.join("\n"));
    },
  });

  // ---- bash_output ---------------------------------------------------------
  pi.registerTool({
    name: "bash_output",
    label: "Bash output",
    description:
      "Read the log file of a background task started with bash_async. Defaults to the last 50 lines; pass full:true for the whole log (truncated to 50KB).",
    promptSnippet: "Read the log of a background bash_async task",
    promptGuidelines: [
      "Use bash_output to read the captured stdout/stderr of a background task started with bash_async when deciding why it is blocked or whether it succeeded.",
    ],
    parameters: Type.Object({
      task_id: Type.String({ description: "The task id to read" }),
      tail: Type.Optional(
        Type.Number({ description: "Number of trailing lines to return (default 50)" }),
      ),
      full: Type.Optional(Type.Boolean({ description: "Return the full log (truncated to 50KB)" })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const registry = getRegistry();
      if (!registry) return textResult("No active session registry.");
      const { task_id, tail, full } = params as { task_id: string; tail?: number; full?: boolean };
      try {
        const out = registry.readLog(task_id, { tail, full });
        return textResult(out || "(empty log so far)", { task_id });
      } catch (e: any) {
        return textResult(`Error: ${e.message}`);
      }
    },
  });

  // ---- bash_kill -----------------------------------------------------------
  pi.registerTool({
    name: "bash_kill",
    label: "Bash kill",
    description:
      "Stop a background task started with bash_async (SIGTERM, escalating to SIGKILL after 5s). Only kills processes this extension started.",
    promptSnippet: "Stop a background bash_async task",
    promptGuidelines: [
      "Use bash_kill to stop a background task you started with bash_async if it is stalled, taking too long, or you have chosen a different strategy. Only tasks started by bash_async can be killed.",
    ],
    parameters: Type.Object({
      task_id: Type.String({ description: "The task id to kill" }),
      reason: Type.Optional(
        Type.String({ description: "Why the task is being killed (for the log)" }),
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const registry = getRegistry();
      if (!registry) return textResult("No active session registry.");
      const { task_id, reason } = params as { task_id: string; reason?: string };
      const res = await registry.kill(task_id, reason);
      return textResult(res.message, { task_id, ok: res.ok });
    },
  });
}

// ---- helpers ---------------------------------------------------------------

function textResult(text: string, details?: Record<string, unknown>) {
  return {
    content: [{ type: "text" as const, text }],
    details: details ?? {},
  };
}

function elapsed(t: Task): number {
  const end = t.endedAt ?? Date.now();
  return Math.max(0, Math.round((end - t.startedAt) / 1000));
}

function formatStatusLine(t: Task): string {
  const runtime = elapsed(t);
  const sinceOutput = Math.max(0, Math.round((Date.now() - t.lastOutputAt) / 1000));
  const state =
    t.status === "running" ? "running" : t.exitCode === null ? "done(?)" : `exit ${t.exitCode}`;
  const cmd = t.command.replace(/\s+/g, " ").trim().slice(0, 60);
  return [
    `• ${t.id} [${state}] ${runtime}s`,
    `  cmd: ${cmd}`,
    `  log: ${t.lastLogSize}B, last output ${sinceOutput}s ago, pid ${t.pid}`,
  ].join("\n");
}
