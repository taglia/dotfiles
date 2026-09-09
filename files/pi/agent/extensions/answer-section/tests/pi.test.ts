import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { ANSWER_TYPE, collectAnswer } from "../answers.ts";

const sdkDir = process.env.PI_AGENT_TEST_SDK;
async function setup(t: any) {
  const dir = mkdtempSync(join(tmpdir(), "answer-test-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const sdk = await import(pathToFileURL(join(sdkDir!, "dist/index.js")).href);
  const { theme } = await import(
    pathToFileURL(join(sdkDir!, "dist/modes/interactive/theme/theme.js")).href
  );
  sdk.initTheme("dark", false);
  const { loadExtensions } = await import(
    pathToFileURL(join(sdkDir!, "dist/core/extensions/loader.js")).href
  );
  const loaded = await loadExtensions(
    [join(dirname(dirname(fileURLToPath(import.meta.url))), "index.ts")],
    dir,
  );
  assert.deepEqual(loaded.errors, []);
  const sm = sdk.SessionManager.inMemory(dir);
  loaded.runtime.appendEntry = (type: string, data: unknown) => sm.appendCustomEntry(type, data);
  const extension = loaded.extensions[0];
  const ctx = {
    mode: "tui",
    hasUI: true,
    sessionManager: sm,
    isIdle: () => true,
    ui: { notify() {} },
  };
  return { theme, sm, extension, ctx };
}
const assistant = (text: string) => ({
  role: "assistant",
  content: [{ type: "text", text }],
  api: "openai-completions",
  provider: "fixture",
  model: "fixture",
  timestamp: 1,
  stopReason: "stop",
  usage: {
    input: 1,
    output: 1,
    cacheRead: 0,
    cacheWrite: 0,
    totalTokens: 2,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
  },
});

test(
  "stock Pi entry rendering: settled collection, late follow-up, no LLM context duplication",
  { skip: !sdkDir },
  async (t) => {
    const { theme, sm, extension, ctx } = await setup(t);
    sm.appendMessage({ role: "user", content: "Question", timestamp: 0 });
    sm.appendMessage(assistant("First public reply."));
    sm.appendCustomMessageEntry("async-bash", "PRIVATE TECHNICAL LOG", true);
    sm.appendMessage(assistant("Final public reply."));
    const before = sm.buildSessionContext().messages;
    const settled = extension.handlers.get("agent_settled")[0];
    assert.equal(extension.handlers.has("agent_end"), false);
    assert.equal(extension.handlers.has("message_end"), false);
    await settled({}, ctx);
    const entry = sm.getLeafEntry();
    assert.equal(entry.customType, ANSWER_TYPE);
    assert.deepEqual(sm.buildSessionContext().messages, before);
    await settled({}, ctx);
    assert.equal(sm.getLeafId(), entry.id);

    // Rendering works from persisted data without live in-memory extension state.
    const render = extension.entryRenderers.get(ANSWER_TYPE);
    for (const expanded of [false, true]) {
      const view = render(JSON.parse(JSON.stringify(entry)), { expanded }, theme);
      const text = view.render(100).join("\n");
      assert.match(text, /Answer/);
      assert.match(text, /First public reply/);
      assert.match(text, /Final public reply/);
      assert.doesNotMatch(text, /PRIVATE TECHNICAL LOG/);
    }
    sm.appendCustomMessageEntry("agent-async", "Worker finished", true);
    sm.appendMessage(assistant("Late follow-up."));
    await settled({}, ctx);
    assert.deepEqual(
      sm.getLeafEntry().data.sections.map((s: any) => s.text),
      ["First public reply.", "Final public reply.", "Late follow-up."],
    );

    const leaf = sm.getLeafId();
    await extension.commands.get("answer").handler("", { ...ctx, isIdle: () => false });
    assert.equal(sm.getLeafId(), leaf);
    await extension.commands.get("answer").handler("", ctx);
    assert.notEqual(sm.getLeafId(), leaf);
  },
);

test(
  "active-branch collection survives compaction and does not mix forked replies",
  { skip: !sdkDir },
  async (t) => {
    const { sm } = await setup(t);
    const question = sm.appendMessage({ role: "user", content: "Question", timestamp: 0 });
    sm.appendMessage(assistant("Abandoned branch."));
    sm.branch(question);
    sm.appendMessage(assistant("Current branch, before compaction."));
    const kept = sm.appendMessage(assistant("Current branch, retained."));
    sm.appendCompaction("Summary", kept, 1000);
    sm.appendMessage(assistant("Current branch, after compaction."));
    assert.deepEqual(
      collectAnswer(sm.getBranch())?.sections.map((s) => s.text),
      [
        "Current branch, before compaction.",
        "Current branch, retained.",
        "Current branch, after compaction.",
      ],
    );
  },
);

test(
  "non-TUI sessions and requests without public replies get no display entries",
  { skip: !sdkDir },
  async (t) => {
    const { sm, extension, ctx } = await setup(t);
    sm.appendMessage({ role: "user", content: "Question", timestamp: 0 });
    const settled = extension.handlers.get("agent_settled")[0];
    const userLeaf = sm.getLeafId();
    await settled({}, ctx);
    assert.equal(sm.getLeafId(), userLeaf);
    sm.appendMessage(assistant("Reply"));
    const leaf = sm.getLeafId();
    for (const overrides of [{ mode: "rpc" }, { mode: "json" }, { hasUI: false }]) {
      await settled({}, { ...ctx, ...overrides });
      assert.equal(sm.getLeafId(), leaf);
    }
  },
);
