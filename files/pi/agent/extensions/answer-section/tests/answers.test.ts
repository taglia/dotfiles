import { test } from "node:test";
import assert from "node:assert/strict";
import type { SessionEntry } from "@earendil-works/pi-coding-agent";
import { ANSWER_TYPE, collectAnswer } from "../answers.ts";

function message(id: string, role: string, content: any, stopReason = "stop"): SessionEntry {
  return {
    type: "message",
    id,
    parentId: null,
    timestamp: "",
    message: { role, content, stopReason },
  } as SessionEntry;
}
const user = (id = "u") => message(id, "user", "Request");
const reply = (id: string, text: string, stopReason = "stop") =>
  message(id, "assistant", [{ type: "text", text }], stopReason);
const notice: SessionEntry = {
  type: "custom_message",
  id: "notice",
  parentId: null,
  timestamp: "",
  customType: "async-bash",
  content: "SECRET TECHNICAL LOG",
  display: true,
};
const stored = (branch: SessionEntry[]): SessionEntry => ({
  type: "custom",
  id: "copy",
  parentId: null,
  timestamp: "",
  customType: ANSWER_TYPE,
  data: collectAnswer(branch),
});

test("collects only public assistant text, preserving Markdown and message order", () => {
  const branch = [
    user(),
    message(
      "a",
      "assistant",
      [
        { type: "text", text: "First **public** reply." },
        { type: "thinking", thinking: "PRIVATE REASONING" },
        { type: "toolCall", name: "bash_async", arguments: { command: "SECRET COMMAND" } },
      ],
      "toolUse",
    ),
    message("tool", "toolResult", [{ type: "text", text: "SECRET TOOL RESULT" }]),
    notice,
    reply("b", "Final reply.\n\n```sh\necho safe\n```"),
    message("hidden", "assistant", [{ type: "thinking", thinking: "PRIVATE" }]),
  ];
  assert.deepEqual(collectAnswer(branch), {
    version: 1,
    promptId: "u",
    sections: [
      { sourceId: "a", text: "First **public** reply." },
      { sourceId: "b", text: "Final reply.\n\n```sh\necho safe\n```" },
    ],
  });
});

test("async follow-ups extend the same collection; repeated settle events do not duplicate it", () => {
  const branch = [user(), reply("a", "Original answer.")];
  branch.push(stored(branch), notice);
  assert.equal(collectAnswer(branch), undefined);
  assert.equal(collectAnswer(branch, true)?.sections.length, 1);
  branch.push(reply("b", "Late job finished."));
  assert.deepEqual(
    collectAnswer(branch)?.sections.map((s) => s.text),
    ["Original answer.", "Late job finished."],
  );
  branch.push(stored(branch));
  assert.equal(collectAnswer(branch), undefined);
});

test("a new user request resets collection and does not copy earlier answers", () => {
  const branch = [user(), reply("a", "Old answer."), user("new")];
  assert.equal(collectAnswer(branch), undefined);
  branch.push(reply("b", "New answer."));
  assert.equal(collectAnswer(branch)?.promptId, "new");
  assert.deepEqual(
    collectAnswer(branch)?.sections.map((s) => s.text),
    ["New answer."],
  );
  assert.equal(collectAnswer([notice, reply("orphan", "No user request")]), undefined);
});

test("incomplete replies are labeled; pending and empty replies are not copied", () => {
  const branch = [
    user(),
    reply("pending", "Partial stream", "pending"),
    reply("empty", "  "),
    ...["aborted", "error", "length", "deferred"].map((status) =>
      reply(status, "Partial text", status),
    ),
    reply("done", "Complete"),
  ];
  const sections = collectAnswer(branch)!.sections;
  assert.equal(sections.length, 5);
  assert.ok(sections.slice(0, 4).every((s) => s.incomplete));
  assert.equal(sections[4].incomplete, undefined);
});
