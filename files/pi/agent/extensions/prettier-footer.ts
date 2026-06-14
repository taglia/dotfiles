import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { isAbsolute, relative, resolve, sep } from "node:path";
import { execSync } from "node:child_process";

function sanitizeStatusText(text: string): string {
  return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

function formatTokens(count: number): string {
  if (count < 1000) return count.toString();
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
  return `${Math.round(count / 1000000)}M`;
}

function checkGitDirty(cwd: string): boolean {
  try {
    const output = execSync("git status --porcelain", {
      cwd,
      encoding: "utf8",
      timeout: 2000,
      stdio: ["ignore", "pipe", "ignore"],
    });
    return output.trim().length > 0;
  } catch {
    return false;
  }
}

function createGitDirtyChecker(): () => boolean {
  let lastCwd = "";
  let lastResult = false;
  let lastCheck = 0;
  const TTL_MS = 3000;

  return () => {
    const cwd = process.cwd();
    const now = Date.now();
    if (cwd === lastCwd && now - lastCheck < TTL_MS) return lastResult;
    lastCwd = cwd;
    lastResult = checkGitDirty(cwd);
    lastCheck = now;
    return lastResult;
  };
}
function formatCwdForFooter(cwd: string, home: string | undefined): string {
  if (!home) return cwd;

  const resolvedCwd = resolve(cwd);
  const resolvedHome = resolve(home);
  const relativeToHome = relative(resolvedHome, resolvedCwd);
  const isInsideHome =
    relativeToHome === "" ||
    (relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));

  if (!isInsideHome) return cwd;
  return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());
      const getDirty = createGitDirtyChecker();
      const separator = () => theme.fg("dim", "  •  ");
      const label = (text: string) => theme.fg("muted", `${text}: `);
      const value = (text: string) => theme.fg("text", text);

      const thinkingColor = (level: string) => {
        switch (level) {
          case "off":
            return "thinkingOff" as const;
          case "minimal":
            return "thinkingMinimal" as const;
          case "low":
            return "thinkingLow" as const;
          case "high":
            return "thinkingHigh" as const;
          case "xhigh":
            return "thinkingXhigh" as const;
          case "medium":
          default:
            return "thinkingMedium" as const;
        }
      };

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          let totalInput = 0;
          let totalOutput = 0;
          let totalCacheRead = 0;
          let totalCacheWrite = 0;
          let totalCost = 0;
          let latestCacheHitRate: number | undefined;

          for (const entry of ctx.sessionManager.getEntries()) {
            if (entry.type === "message" && entry.message.role === "assistant") {
              const message = entry.message as AssistantMessage;
              totalInput += message.usage.input;
              totalOutput += message.usage.output;
              totalCacheRead += message.usage.cacheRead;
              totalCacheWrite += message.usage.cacheWrite;
              totalCost += message.usage.cost.total;

              const latestPromptTokens =
                message.usage.input + message.usage.cacheRead + message.usage.cacheWrite;
              latestCacheHitRate =
                latestPromptTokens > 0 ? (message.usage.cacheRead / latestPromptTokens) * 100 : undefined;
            }
          }

          const contextUsage = ctx.getContextUsage();
          const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
          const contextPercentValue = contextUsage?.percent ?? 0;
          const contextPercent = contextUsage?.percent !== null ? contextPercentValue.toFixed(1) : "?";

          const cwd = formatCwdForFooter(
            ctx.sessionManager.getCwd(),
            process.env.HOME || process.env.USERPROFILE,
          );
          const branch = footerData.getGitBranch();
          const dirty = branch ? getDirty() : false;
          const sessionName = ctx.sessionManager.getSessionName();

          const line1Segments = [label("dir") + value(cwd)];
          if (branch) line1Segments.push(label("git") + theme.fg("accent", branch) + (dirty ? theme.fg("warning", " *") : ""));
          if (sessionName) line1Segments.push(label("session") + value(sessionName));
          const line1 = truncateToWidth(line1Segments.join(separator()), width, theme.fg("dim", "..."));

          const modelText =
            footerData.getAvailableProviderCount() > 1 && ctx.model
              ? `${ctx.model.provider}/${ctx.model.id}`
              : (ctx.model?.id ?? "no-model");

          const activeThinkingLevel = String(pi.getThinkingLevel());

          let contextValue = `${contextPercent}% / ${formatTokens(contextWindow)}`;
          if (contextPercent === "?") contextValue = `? / ${formatTokens(contextWindow)}`;
          const coloredContextValue =
            contextPercentValue > 90
              ? theme.fg("error", contextValue)
              : contextPercentValue > 70
                ? theme.fg("warning", contextValue)
                : value(contextValue);

          const cacheValue = [
            `read ${formatTokens(totalCacheRead)}`,
            `write ${formatTokens(totalCacheWrite)}`,
            latestCacheHitRate !== undefined ? `hit ${latestCacheHitRate.toFixed(1)}%` : undefined,
          ]
            .filter(Boolean)
            .join("  ");

          const line2Segments = [
            label("model") + theme.fg("accent", modelText),
            label("thinking") + theme.fg(thinkingColor(activeThinkingLevel), activeThinkingLevel),
            label("ctx") + coloredContextValue,
            label("tok") + value(`in ${formatTokens(totalInput)}  out ${formatTokens(totalOutput)}`),
            label("cache") + value(cacheValue),
            label("cost") +
              theme.fg(
                "success",
                `$${totalCost.toFixed(3)}${ctx.model && ctx.modelRegistry.isUsingOAuth(ctx.model) ? " (sub)" : ""}`,
              ),
          ];

          const line2 = truncateToWidth(line2Segments.join(separator()), width, theme.fg("dim", "..."));

          const statusTexts = Array.from(footerData.getExtensionStatuses().values()).map(sanitizeStatusText);
          if (statusTexts.length === 0) return [line1, line2];

          const line3 = truncateToWidth(statusTexts.join(theme.fg("dim", "  •  ")), width, theme.fg("dim", "..."));
          return [line1, line2, line3];
        },
      };
    });
  });

  pi.registerCommand("default-footer", {
    description: "Restore pi's built-in footer",
    handler: async (_args, ctx) => {
      ctx.ui.setFooter(undefined);
      ctx.ui.notify("Built-in footer restored", "info");
    },
  });

  pi.registerCommand("pretty-footer", {
    description: "Re-enable the managed prettier footer",
    handler: async (_args, ctx) => {
      await ctx.reload();
      return;
    },
  });
}
