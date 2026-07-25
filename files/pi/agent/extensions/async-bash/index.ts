/**
 * pi-async-bash extension entry.
 *
 * Adds a parallel `bash_async` tool that runs shell commands in background
 * subprocesses, plus `bash_status` / `bash_output` / `bash_kill` to manage
 * them. A background monitor wakes the agent on completion, stall, or
 * soft-deadline so the LLM can judge whether to keep waiting, investigate,
 * or kill.
 *
 * Load (dev):   pi -e ~/src/pi-async-bash/index.ts
 * Promote:      copy into dotfiles/files/pi/agent/extensions/async-bash/ and
 *               add to modules/home/pi.nix managedPiAgentFiles.
 */
import { type ExtensionAPI, getAgentDir } from "@earendil-works/pi-coding-agent";
import { join } from "node:path";
import { Registry } from "./registry";
import { registerTools } from "./tools";
import { startMonitor } from "./monitor";

export default function (pi: ExtensionAPI) {
  let registry: Registry | null = null;
  let stopMonitor: (() => void) | null = null;

  // Register tools once (factory runs once per load). They resolve the
  // current registry lazily so they work after /new, /resume, /reload.
  registerTools(pi, () => registry);

  const teardown = async () => {
    stopMonitor?.();
    stopMonitor = null;
    await registry?.persist();
    registry = null;
  };

  pi.on("session_start", async (_event, ctx) => {
    // Defensive: if a previous session wasn't torn down, do it now.
    if (registry) await teardown();

    const sessionId = ctx.sessionManager.getSessionId();
    const dir = join(getAgentDir(), "async-bash", sessionId ?? "default");
    registry = new Registry(dir);
    await registry.restore();

    stopMonitor = startMonitor(pi, ctx.hasUI ? ctx.ui : undefined, () => registry);
  });

  pi.on("session_shutdown", async () => {
    await teardown();
  });

  pi.registerCommand("tasks", {
    description: "List async-bash background tasks",
    handler: async (_args, ctx) => {
      if (!registry) {
        ctx.ui.notify("No active session.", "info");
        return;
      }
      const tasks = registry.list();
      if (tasks.length === 0) {
        ctx.ui.notify("No background tasks.", "info");
        return;
      }
      for (const t of tasks) registry.refresh(t);
      ctx.ui.notify(registry.formatSummary(), "info");
    },
  });
}