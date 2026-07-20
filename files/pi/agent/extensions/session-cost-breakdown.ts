import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

interface ModelStats {
  messages: number;
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("cost", {
    description: "Show per-model token usage and cost breakdown for the current session",
    handler: async (_args, ctx) => {
      const stats = new Map<string, ModelStats>();
      let grandTotal = 0;

      for (const entry of ctx.sessionManager.getEntries()) {
        if (entry.type === "message" && entry.message.role === "assistant") {
          const msg = entry.message as AssistantMessage;
          const key = `${msg.provider}/${msg.model}`;
          const existing = stats.get(key) ?? {
            messages: 0,
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            cost: 0,
          };

          existing.messages += 1;
          existing.input += msg.usage.input;
          existing.output += msg.usage.output;
          existing.cacheRead += msg.usage.cacheRead;
          existing.cacheWrite += msg.usage.cacheWrite;
          existing.cost += msg.usage.cost.total;
          grandTotal += msg.usage.cost.total;

          stats.set(key, existing);
        }
      }

      if (stats.size === 0) {
        ctx.ui.notify("No assistant messages in this session yet.", "info");
        return;
      }

      const lines: string[] = [];
      const sorted = Array.from(stats.entries()).sort((a, b) => b[1].cost - a[1].cost);

      // Header
      lines.push("model                  msgs     in       out      cache-r  cache-w  cost");
      lines.push("―".repeat(78));

      for (const [key, s] of sorted) {
        const modelPad = key.padEnd(22).slice(0, 22);
        const msgs = String(s.messages).padStart(4);
        const inp = formatTokens(s.input).padStart(8);
        const out = formatTokens(s.output).padStart(8);
        const cr = formatTokens(s.cacheRead).padStart(8);
        const cw = formatTokens(s.cacheWrite).padStart(8);
        const cost = `$${s.cost.toFixed(4)}`.padStart(10);
        lines.push(`${modelPad} ${msgs}  ${inp}  ${out}  ${cr}  ${cw}  ${cost}`);
      }

      lines.push("―".repeat(78));
      lines.push(
        `${"TOTAL".padEnd(22)} ${String(stats.size).padStart(4)} models, ${`$${grandTotal.toFixed(4)}`.padStart(10)}`,
      );

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });
}
