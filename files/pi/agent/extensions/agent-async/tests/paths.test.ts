import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { scopedPath, writablePath } from "../paths.ts";
import { workerEnvironment } from "../runner.ts";

test("scope rejects traversal, symlink escapes, and writes to control paths", (t) => {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), "agent-paths-")));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const root = join(dir, "root");
  mkdirSync(root);
  mkdirSync(join(dir, "outside"));
  symlinkSync(join(dir, "outside"), join(root, "escape"));
  writeFileSync(join(root, "a"), "hi");
  assert.equal(scopedPath(root, "a"), join(root, "a"));
  assert.equal(writablePath(root, "new/file"), join(root, "new/file"));
  for (const path of ["../outside", "escape/file", dir])
    assert.throws(() => scopedPath(root, path), /outside/);
  for (const path of [
    ".pi/settings.json",
    ".git/config",
    "AGENTS.md",
    ".env.local",
    ".agents/foo",
    ".",
  ])
    assert.throws(() => writablePath(root, path), /prohibited/);
});
test("worker environment excludes provider secrets, preload hooks and package settings", () => {
  process.env.AGENT_TEST_SECRET = "secret";
  process.env.NODE_OPTIONS = "--require hostile";
  try {
    const env = workerEnvironment("/isolated");
    assert.equal(env.HOME, "/isolated");
    assert.equal(env.PI_OFFLINE, "1");
    assert.equal(env.AGENT_TEST_SECRET, undefined);
    assert.equal(env.NODE_OPTIONS, undefined);
  } finally {
    delete process.env.AGENT_TEST_SECRET;
    delete process.env.NODE_OPTIONS;
  }
});
