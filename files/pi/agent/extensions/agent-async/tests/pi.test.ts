import { test } from "node:test";
import assert from "node:assert/strict";
import { pathToFileURL, fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { mkdtempSync, readFileSync, realpathSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";

const sdkDir = process.env.PI_AGENT_TEST_SDK;
async function load(dir: string) {
  const { loadExtensions } = await import(
    pathToFileURL(join(sdkDir!, "dist/core/extensions/loader.js")).href
  );
  const path = join(dirname(dirname(fileURLToPath(import.meta.url))), "index.ts");
  const loaded = await loadExtensions([path], dir);
  assert.deepEqual(loaded.errors, []);
  return loaded.extensions[0];
}

test(
  "extension uses standard shutdown cleanup, not a custom quit guard",
  { skip: !sdkDir },
  async (t) => {
    const dir = mkdtempSync(join(tmpdir(), "agent-loader-"));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    const extension = await load(dir);
    assert.deepEqual([...extension.tools.keys()].sort(), [
      "agent_async",
      "agent_kill",
      "agent_models",
      "agent_output",
      "agent_status",
    ]);
    assert.equal(extension.handlers.has("session_before_shutdown"), false);
    assert.equal(extension.handlers.has("session_shutdown"), true);
  },
);

test(
  "read-only and write-scoped launches need no per-agent approval; shutdown does not prompt",
  { skip: !sdkDir, timeout: 10000 },
  async (t) => {
    const dir = mkdtempSync(join(tmpdir(), "agent-shutdown-"));
    const previous = process.env.PI_CODING_AGENT_DIR;
    process.env.PI_CODING_AGENT_DIR = dir;
    const extension = await load(dir);
    const shutdown = extension.handlers.get("session_shutdown")[0];
    t.after(async () => {
      await shutdown();
      if (previous === undefined) delete process.env.PI_CODING_AGENT_DIR;
      else process.env.PI_CODING_AGENT_DIR = previous;
      rmSync(dir, { recursive: true, force: true });
    });
    const ctx = {
      cwd: dir,
      mode: "tui",
      hasUI: false,
      sessionManager: { getSessionId: () => "shutdown-test" },
      modelRegistry: {
        getAvailable: () => [{ provider: "fixture", id: "cheap" }],
        getRegisteredProviderConfig: () => undefined,
        getRegisteredNativeProvider: () => undefined,
        // Keep the first task in startup. Cancellation must release it without waiting for auth.
        getApiKeyAndHeaders: () => new Promise(() => {}),
      },
      ui: {
        select() {
          assert.fail("Agent launch and shutdown must not prompt");
        },
        setWidget() {},
      },
    };
    await extension.handlers.get("session_start")[0]({}, ctx);
    const launch = extension.tools.get("agent_async").definition.execute;
    const args = {
      title: "test",
      model: "fixture/cheap",
      rationale: "simple inspection",
      objective: "inspect",
      context: "workspace",
      acceptance: "facts",
      output_format: "text",
    };
    const first = JSON.parse(
      (await launch("one", args, undefined, undefined, ctx)).content[0].text,
    );
    const second = JSON.parse(
      (
        await launch(
          "two",
          { ...args, depends_on: [first.id], write_paths: ["output.txt", "./output.txt"] },
          undefined,
          undefined,
          ctx,
        )
      ).content[0].text,
    );
    assert.deepEqual(first.write_paths, []);
    assert.deepEqual(second.write_paths, [join(realpathSync(ctx.cwd), "output.txt")]);
    assert.equal(first.state, "running");
    assert.equal(second.state, "blocked");
    await shutdown();
    for (const task of [first, second])
      assert.match(readFileSync(task.result, "utf8"), /Supervisor session ended/);
    await assert.rejects(
      extension.tools.get("agent_status").definition.execute("status", {}),
      /No active agent registry/,
    );
  },
);
