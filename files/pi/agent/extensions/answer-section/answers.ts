import type { SessionEntry } from "@earendil-works/pi-coding-agent";

export const ANSWER_TYPE = "consolidated-answer";
const INCOMPLETE: Partial<Record<string, string>> = {
  aborted: "Interrupted response",
  error: "Response ended with an error",
  length: "Response reached its output limit",
  deferred: "Response deferred by provider",
};
export interface AnswerData {
  version: 1;
  promptId: string;
  sections: { sourceId: string; text: string; incomplete?: string }[];
}

/** Read the active branch, not the compacted model context or other branches.
 * Custom async notices deliberately do not start a new user request.
 * Copies are TUI-only custom entries; never feed them back to the model.
 */
export function collectAnswer(
  branch: readonly SessionEntry[],
  force = false,
): AnswerData | undefined {
  const start = branch.findLastIndex((e) => e.type === "message" && e.message.role === "user");
  if (start < 0) return;
  const answer: AnswerData = { version: 1, promptId: branch[start].id, sections: [] };
  let previous: AnswerData | undefined;
  for (const entry of branch.slice(start + 1)) {
    if (entry.type === "custom" && entry.customType === ANSWER_TYPE) {
      const data = entry.data as AnswerData | undefined;
      if (data?.version === 1 && data.promptId === answer.promptId) previous = data;
    }
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;
    const message = entry.message;
    if (message.stopReason === "pending") continue;
    const text = message.content
      .filter((p) => p.type === "text")
      .map((p) => p.text)
      .join("\n\n");
    if (!text.trim()) continue;
    const incomplete = INCOMPLETE[message.stopReason];
    answer.sections.push({ sourceId: entry.id, text, ...(incomplete ? { incomplete } : {}) });
  }
  if (!answer.sections.length) return;
  // Message entries are immutable. Repeated settled events / notification-only
  // runs must not append identical copies. A manual /answer explicitly can.
  if (!force && previous && JSON.stringify(previous.sections) === JSON.stringify(answer.sections))
    return;
  return answer;
}
