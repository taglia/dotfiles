import { getMarkdownTheme, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { ANSWER_TYPE, collectAnswer, type AnswerData } from "./answers.ts";

export default function answerSection(pi: ExtensionAPI) {
  pi.registerEntryRenderer<AnswerData>(ANSWER_TYPE, (entry, _options, theme) => {
    if (entry.data?.version !== 1 || !Array.isArray(entry.data.sections)) return undefined;
    const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
    box.addChild(new Text(theme.fg("accent", theme.bold("Answer")), 0, 0));
    box.addChild(
      new Text(theme.fg("dim", "Collected replies · original execution transcript above"), 0, 0),
    );
    for (const section of entry.data.sections) {
      box.addChild(new Spacer(1));
      if (section.incomplete) box.addChild(new Text(theme.fg("warning", section.incomplete), 0, 0));
      // Separate Markdown components prevent an unfinished code fence in an
      // interrupted reply from swallowing subsequent replies in the collection.
      box.addChild(new Markdown(section.text, 0, 0, getMarkdownTheme()));
    }
    // Intentionally always expanded, independent of Ctrl+O's technical details.
    return box;
  });

  pi.on("agent_settled", (_event, ctx) => {
    if (ctx.mode !== "tui" || !ctx.hasUI) return;
    const answer = collectAnswer(ctx.sessionManager.getBranch());
    if (answer) pi.appendEntry(ANSWER_TYPE, answer);
  });

  pi.registerCommand("answer", {
    description: "Repeat the latest request's collected replies at the bottom (no model call)",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui" || !ctx.hasUI) return;
      if (!ctx.isIdle()) {
        ctx.ui.notify("The Answer section will update when the current run settles.", "info");
        return;
      }
      const answer = collectAnswer(ctx.sessionManager.getBranch(), true);
      if (answer) pi.appendEntry(ANSWER_TYPE, answer);
      else ctx.ui.notify("No public assistant replies for the current request yet.", "info");
    },
  });
}
