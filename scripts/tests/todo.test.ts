// Run with PI_AGENT_TEST_SDK pointing at the pinned pi package (no API calls).
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const sdkDir = process.env.PI_AGENT_TEST_SDK;
if (!sdkDir) throw new Error("Set PI_AGENT_TEST_SDK to the pinned pi SDK directory");
const sdk = await import(pathToFileURL(join(sdkDir, "dist/index.js")).href);
const { theme } = await import(
  pathToFileURL(join(sdkDir, "dist/modes/interactive/theme/theme.js")).href
);
const { loadExtensions } = await import(
  pathToFileURL(join(sdkDir, "dist/core/extensions/loader.js")).href
);
const { ToolExecutionComponent } = await import(
  pathToFileURL(join(sdkDir, "dist/modes/interactive/components/tool-execution.js")).href
);
const { visibleWidth } = await import(
  pathToFileURL(join(sdkDir, "node_modules/@earendil-works/pi-tui/dist/index.js")).href
);
sdk.initTheme("dark", false);

async function setup(t: any) {
  const dir = mkdtempSync(join(tmpdir(), "todo-test-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const loaded = await loadExtensions([resolve("files/pi/agent/extensions/todo.ts")], dir);
  assert.deepEqual(loaded.errors, []);
  const extension = loaded.extensions[0];
  const tool = extension.tools.get("todo").definition;
  const sm = sdk.SessionManager.inMemory(dir);
  const widgets: any[] = [];
  const warnings: string[] = [];
  const ctx: any = {
    mode: "tui",
    hasUI: true,
    sessionManager: sm,
    ui: {
      setWidget(_key: string, value: any) {
        widgets.push(value);
      },
      notify(text: string) {
        warnings.push(text);
      },
    },
  };
  const run = (params: any, signal?: AbortSignal) =>
    tool.execute("test", params, signal, undefined, ctx);
  const replay = (event = "session_start") => extension.handlers.get(event)[0]({}, ctx);
  const append = (details: any, isError = false) =>
    sm.appendMessage({
      role: "toolResult",
      toolName: "todo",
      toolCallId: "test",
      content: [],
      details,
      isError,
      timestamp: 0,
    });
  const render = (result: any, expanded = false, isError = false) =>
    tool.renderResult(result, { expanded, isPartial: false }, theme, { isError, isPartial: false });
  return { tool, ctx, sm, widgets, warnings, run, replay, append, render, extension };
}
const task = { id: 1, text: "legacy", status: "pending" };
const legacy = { action: "list", tasks: [task], nextId: 2 };
const content = [
  { type: "text", text: "Validation failed" },
  { type: "text", text: "action is required" },
];

test("malformed results render and invalidate through the actual pi tool row", async (t) => {
  const { tool, render } = await setup(t);
  const malformed = [
    undefined,
    null,
    {},
    [],
    "bad",
    { action: "future", tasks: [], nextId: 1 },
    { ...legacy, tasks: {} },
    { ...legacy, tasks: [null] },
    { ...legacy, tasks: [{ ...task, text: 42 }] },
    { ...legacy, tasks: [{ ...task, status: "future" }] },
    { ...legacy, nextId: 1 },
    { ...legacy, nextId: null },
    { ...legacy, version: 99 },
    { ...legacy, tasks: [task, task] },
    { ...legacy, offset: -1 },
    { ...legacy, limit: 0 },
    { ...legacy, action: "add", affectedIds: [999] },
  ];
  for (const details of malformed) {
    for (const expanded of [false, true]) {
      const view = render({ content, details }, expanded);
      assert.equal(typeof view.render, "function");
      assert.equal(typeof view.invalidate, "function");
      assert.match(view.render(80).join("\n"), /Validation failed/);
      assert.match(view.render(80).join("\n"), /action is required/);
      view.invalidate();
      const row = new ToolExecutionComponent(
        "todo",
        "test",
        { add: '["bad args"]' },
        {},
        tool,
        { requestRender() {} },
        process.cwd(),
      );
      row.updateResult({ content, details, isError: true });
      row.setExpanded(expanded);
      row.invalidate();
      assert.match(row.render(80).join("\n"), /Validation failed/);
      // Also cover unexpected details on a non-error result.
      row.updateResult({ content, details, isError: false });
      row.invalidate();
      row.render(80);
    }
  }
  for (const args of [
    null,
    undefined,
    {},
    { action: {} },
    { action: "add", text: {}, items: "bad" },
  ]) {
    const view = tool.renderCall(args, theme, {});
    view.invalidate();
    assert.doesNotThrow(() => view.render(40));
  }
  for (const contents of [[], undefined, [null], [{ type: "image" }]]) {
    const view = render({ content: contents, details: {} }, false, true);
    assert.match(view.render(80).join("\n"), /Todo failed/);
  }
});

test("mutations are atomic, errors throw, snapshots are independent, IDs remain valid", async (t) => {
  const { run } = await setup(t);
  const first = await run({ action: "add", items: ["one", "two\nlines"] });
  assert.deepEqual(first.details.affectedIds, [1, 2]);
  assert.equal(first.details.tasks[1].text, "two lines");
  for (const params of [
    { action: "add", items: ["valid", "  "] },
    { action: "add", items: "wrong" },
    { action: "add", items: [4] },
    { action: "add", text: "x".repeat(1001) },
    { action: "update", id: 1, status: "done", text: "  " },
    { action: "update", id: 1, text: "" },
    { action: "update", id: 1, status: "invalid" },
    { action: "update", id: 1 },
    { action: "remove", id: 0.5 },
    { action: "remove", id: 99 },
    { action: "list", offset: -1 },
    { action: "list", limit: 101 },
    { action: "unknown" },
    null,
  ]) {
    await assert.rejects(run(params));
    assert.deepEqual((await run({ action: "list" })).details.tasks, first.details.tasks);
    assert.equal((await run({ action: "list" })).details.nextId, 3);
  }
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(run({ action: "clear" }, controller.signal));
  const changed = await run({ action: "update", id: 1, status: "done" });
  assert.equal(first.details.tasks[0].status, "pending");
  assert.equal(changed.details.tasks[0].status, "done");
  await run({ action: "remove", id: 2 });
  assert.equal((await run({ action: "add", text: "three" })).details.tasks.at(-1).id, 3);
  await run({ action: "clear" });
  assert.equal((await run({ action: "add", text: "reset" })).details.tasks[0].id, 1);
});

test("replay preserves the last valid snapshot and follows only the selected branch", async (t) => {
  const { run, sm, append, replay, warnings, widgets } = await setup(t);
  append(legacy);
  const root = sm.getLeafId();
  append({ ...legacy, tasks: "invalid" });
  append({});
  append({ ...legacy, tasks: [{ ...task, text: "must not restore error result" }] }, true);
  await replay();
  assert.deepEqual((await run({ action: "list" })).details.tasks, [task]);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /Skipped 2/);
  append((await run({ action: "add", text: "branch A" })).details);
  sm.branch(root);
  await replay("session_tree");
  assert.equal((await run({ action: "list" })).details.tasks.length, 1);
  const branchB = await run({ action: "add", text: "branch B" });
  assert.equal(branchB.details.tasks[1].id, 2);
  append(branchB.details);
  sm.appendCompaction("summary", root, 100);
  await replay();
  assert.deepEqual((await run({ action: "list" })).details.tasks, branchB.details.tasks);
  // Reload uses the same session_start reconstruction; an empty/new branch resets state.
  sm.resetLeaf();
  await replay();
  assert.deepEqual((await run({ action: "list" })).details.tasks, []);
  assert.equal(widgets.at(-1), undefined);
});

test("structured rendering never derives affected tasks from prose", async (t) => {
  const { run, render } = await setup(t);
  await run({ action: "add", text: "unrelated" });
  const added = await run({ action: "add", text: "new task" });
  added.content[0].text = "arbitrary\nmultiline\nprose #999";
  const output = render(added).render(100).join("\n");
  assert.match(output, /new task/);
  assert.doesNotMatch(output, /unrelated|arbitrary/);
  const updated = await run({ action: "update", id: 2, status: "done" });
  updated.content[0].text = "Changed #1";
  assert.match(render(updated).render(100).join("\n"), /new task/);
  assert.match(
    render({ details: { ...legacy, action: "add" }, content })
      .render(80)
      .join("\n"),
    /Validation failed/,
  );
  assert.match(
    render({ details: { error: "old error" }, content })
      .render(80)
      .join("\n"),
    /old error/,
  );
});

test("limits, paging, sibling calls, terminal safety, and widget failure isolation", async (t) => {
  const { run, widgets, ctx, render } = await setup(t);
  await assert.rejects(run({ action: "add", items: Array(101).fill("task") }));
  await Promise.all(
    Array.from({ length: 5 }, (_, batch) =>
      run({
        action: "add",
        items: Array.from({ length: 100 }, (_, i) => `task ${batch * 100 + i}`),
      }),
    ),
  );
  const listed = await run({ action: "list", offset: 20, limit: 10 });
  assert.equal(listed.details.tasks.length, 500);
  assert.equal(listed.details.nextId, 501);
  assert.match(listed.content[0].text, /#21 task 20/);
  assert.match(listed.content[0].text, /Next offset: 30/);
  assert.doesNotMatch(listed.content[0].text, /#1 task 0/);
  await assert.rejects(run({ action: "add", text: "overflow" }));
  const widget = widgets.at(-1)({}, theme);
  for (const width of [0, 1, 2, 10, 80]) {
    widget.invalidate();
    for (const line of widget.render(width)) assert.ok(visibleWidth(line) <= width);
  }
  await run({ action: "clear" });
  const controls = await run({ action: "add", text: "\x1b[31mred\x1b[0m\n\twide 界 👋" });
  assert.doesNotMatch(controls.details.tasks[0].text, /[\x1b\n\t]/);
  const view = render(controls);
  for (const line of view.render(12)) assert.ok(visibleWidth(line) <= 12);
  ctx.ui.setWidget = () => {
    throw new Error("broken UI");
  };
  ctx.ui.notify = () => {
    throw new Error("also broken");
  };
  const retained = await run({ action: "add", text: "retained" });
  assert.equal(retained.details.tasks.length, 2);
  for (const mode of ["rpc", "json", "print"]) {
    ctx.mode = mode;
    ctx.ui.setWidget = () => assert.fail("TUI factory called outside TUI");
    await run({ action: "update", id: 1, status: "done" });
  }
});

test("/todos pages safely, invalidates, and closes; partial results keep their text", async (t) => {
  const { run, ctx, extension, tool } = await setup(t);
  await run({ action: "add", items: Array.from({ length: 25 }, (_, i) => `item-${i + 1}`) });
  let closed = false;
  let renders = 0;
  ctx.ui.custom = async (factory: any) => {
    const view = factory(
      {
        requestRender() {
          renders++;
        },
      },
      theme,
      {},
      () => {
        closed = true;
      },
    );
    assert.match(view.render(80).join("\n"), /#1\b/);
    assert.doesNotMatch(view.render(80).join("\n"), /#11\b/);
    view.handleInput("\x1b[6~"); // Page Down
    assert.match(view.render(80).join("\n"), /#11\b/);
    view.handleInput("\x1b[B"); // Down
    assert.match(view.render(80).join("\n"), /#25\b/);
    view.handleInput("\x1b[5~"); // Page Up
    assert.doesNotMatch(view.render(80).join("\n"), /#25\b/);
    view.invalidate();
    for (const width of [0, 1, 2, 10, 80])
      for (const line of view.render(width)) assert.ok(visibleWidth(line) <= width);
    view.handleInput("\x1b");
  };
  await extension.commands.get("todos").handler("", ctx);
  assert.equal(closed, true);
  assert.equal(renders, 4);
  const partial = tool.renderResult(
    { details: {}, content },
    { expanded: false, isPartial: true },
    theme,
    { isPartial: true, isError: false },
  );
  partial.invalidate();
  assert.match(partial.render(80).join("\n"), /action is required/);
});

test("large legacy snapshots remain usable, output is bounded, and ID overflow is rejected", async (t) => {
  const { append, replay, run, render } = await setup(t);
  append({ ...legacy, tasks: [{ ...task, text: "界".repeat(20000) }] });
  await replay();
  const listed = await run({ action: "list" });
  assert.equal(listed.details.tasks[0].text.length, 20000);
  assert.ok(Buffer.byteLength(listed.content[0].text) <= 50 * 1024);
  assert.match(listed.content[0].text, /truncated/);
  assert.doesNotThrow(() => render(listed).render(80));
  append({ ...legacy, nextId: Number.MAX_SAFE_INTEGER });
  await replay();
  await assert.rejects(run({ action: "add", text: "overflow" }), /ID space exhausted/);
  await run({ action: "clear" });
  assert.equal((await run({ action: "add", text: "recovered" })).details.tasks[0].id, 1);
});
