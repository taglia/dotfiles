import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { once } from "node:events";
import { startWorker } from "../runner.ts";

const tests = dirname(fileURLToPath(import.meta.url));
const directory = dirname(tests);
function fixture(t: any) {
  const dir = mkdtempSync(join(tmpdir(), "agent-lifetime-"));
  symlinkSync(join(directory, "guardian.ts"), join(dir, "guardian.ts"));
  symlinkSync(join(tests, "fixtures/stubborn.ts"), join(dir, "worker.ts"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return { directory: dir, sdk: "unused", cwd: dir, stateDir: dir, payload: {}, secrets: [] };
}
function alive(pid: number) {
  try {
    process.kill(pid, 0);
    // Minimal Linux containers may not reap adopted zombies promptly. They are
    // terminated (cannot execute), even while their PID remains observable.
    const ps = spawnSync("ps", ["-o", "stat=", "-p", String(pid)], { encoding: "utf8" });
    return !ps.stdout.trim().startsWith("Z");
  } catch {
    return false;
  }
}
async function gone(pid: number) {
  const until = Date.now() + 8000;
  while (alive(pid) && Date.now() < until) await new Promise((r) => setTimeout(r, 100));
  assert.equal(alive(pid), false, `Process ${pid} was orphaned`);
}

test(
  "stop escalates and kills stubborn worker plus its descendants",
  { timeout: 15000 },
  async (t) => {
    const options = fixture(t);
    let ready!: (e: any) => void;
    const pids = new Promise<any>((r) => {
      ready = r;
    });
    const worker = startWorker({
      ...options,
      event: (e) => {
        if (e.type === "pids") ready(e);
      },
    });
    t.after(() => worker.stop());
    const p = await pids;
    assert.ok(alive(p.worker));
    await worker.stop();
    await Promise.all([gone(p.worker), gone(p.descendant)]);
  },
);

test(
  "supervisor SIGKILL closes IPC; guardian reaps workers without a shutdown handler",
  { timeout: 15000 },
  async (t) => {
    const options = fixture(t);
    const owner = spawn(process.execPath, [join(tests, "fixtures/owner.ts")], {
      stdio: ["ignore", "ignore", "inherit", "ipc"],
    });
    t.after(() => {
      if (owner.exitCode === null && owner.signalCode === null) owner.kill("SIGKILL");
    });
    const message = once(owner, "message");
    owner.send(options);
    const [p] = await message;
    assert.equal(p.type, "pids");
    assert.ok(alive(p.worker));
    const exited = once(owner, "exit");
    owner.kill("SIGKILL");
    await exited;
    await Promise.all([gone(p.worker), gone(p.descendant)]);
  },
);
