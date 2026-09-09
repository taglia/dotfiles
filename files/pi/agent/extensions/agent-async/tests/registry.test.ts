import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Registry, type Brief, type Outcome } from "../registry.ts";

export const brief = (extra: Partial<Brief> = {}): Brief => ({
  title: "test",
  model: "fake/cheap",
  rationale: "simple task",
  objective: "inspect",
  context: "scope",
  acceptance: "facts",
  output_format: "text",
  thinking: "off",
  depends_on: [],
  include_results: [],
  write_paths: [],
  instructions: [],
  cwd: process.cwd(),
  timeout_seconds: 60,
  ...extra,
});
const tick = () => new Promise((r) => setImmediate(r));
function fixture(t: any, concurrency = 2) {
  const dir = mkdtempSync(join(tmpdir(), "agent-registry-"));
  const jobs = new Map<
    string,
    { finish: (o: Outcome) => void; prompt: string; stopped: boolean }
  >();
  const finished: string[] = [];
  const r = new Registry(
    dir,
    async (task, prompt) => {
      let finish!: (o: Outcome) => void;
      const done = new Promise<Outcome>((resolve) => {
        finish = resolve;
      });
      const job = { finish, prompt, stopped: false };
      jobs.set(task.id, job);
      return {
        done,
        async stop() {
          job.stopped = true;
          finish({ ok: false });
        },
      };
    },
    undefined,
    (task) => finished.push(task.id),
    concurrency,
  );
  t.after(async () => {
    await r.close();
    rmSync(dir, { recursive: true, force: true });
  });
  return { r, jobs, finished };
}
test("concurrency limit, FIFO queue, event-driven release", async (t) => {
  const { r, jobs } = fixture(t);
  const a = r.add(brief());
  const b = r.add(brief());
  const c = r.add(brief());
  await tick();
  assert.equal(jobs.size, 2);
  assert.equal(c.state, "queued");
  jobs.get(b.id)!.finish({ ok: true });
  await tick();
  assert.equal(a.state, "running");
  assert.equal(c.state, "running");
});
test("diamond DAG includes only explicitly selected results", async (t) => {
  const { r, jobs } = fixture(t);
  const a = r.add(brief());
  const b = r.add(brief({ depends_on: [a.id], include_results: [a.id] }));
  const c = r.add(brief({ depends_on: [a.id] }));
  const d = r.add(brief({ depends_on: [b.id, c.id], include_results: [b.id] }));
  await tick();
  assert.equal(b.state, "blocked");
  a.result = "A output";
  jobs.get(a.id)!.finish({ ok: true });
  await tick();
  assert.match(jobs.get(b.id)!.prompt, /A output/);
  assert.doesNotMatch(jobs.get(c.id)!.prompt, /A output/);
  b.result = "B output";
  jobs.get(b.id)!.finish({ ok: true });
  await tick();
  assert.equal(d.state, "blocked");
  c.result = "C output";
  jobs.get(c.id)!.finish({ ok: true });
  await tick();
  assert.match(jobs.get(d.id)!.prompt, /B output/);
  assert.doesNotMatch(jobs.get(d.id)!.prompt, /C output/);
});
test("failed dependencies stay blocked; kill all includes blocked and queued work", async (t) => {
  const { r, jobs } = fixture(t, 1);
  const a = r.add(brief());
  const b = r.add(brief({ depends_on: [a.id] }));
  await tick();
  jobs.get(a.id)!.finish({ ok: false, error: "failure" });
  await tick();
  assert.equal(b.state, "blocked");
  assert.match(b.blockedReason!, /failed/);
  const c = r.add(brief());
  const d = r.add(brief());
  await tick();
  await r.kill("all");
  assert.equal(b.state, "cancelled");
  assert.equal(c.state, "cancelled");
  assert.equal(d.state, "cancelled");
  assert.equal(jobs.has(d.id), false);
});
test("only backward references; task briefs are copied and writers cannot overlap", async (t) => {
  const { r } = fixture(t);
  assert.throws(() => r.add(brief({ depends_on: ["future"] })), /Unknown/);
  const b = brief({ write_paths: ["file"] });
  const a = r.add(b);
  b.write_paths.push("another");
  assert.deepEqual(a.write_paths, ["file"]);
  assert.throws(() => r.add(brief({ write_paths: ["file"] })), /overlaps/);
  assert.throws(() => r.add(brief({ include_results: [a.id] })), /subset/);
  assert.equal(r.add(brief({ write_paths: ["file"], depends_on: [a.id] })).state, "blocked");
});
test("cancel during startup and close never launch new queued work", async (t) => {
  const { r, jobs, finished } = fixture(t, 1);
  const a = r.add(brief());
  const b = r.add(brief());
  await r.close();
  assert.equal(a.state, "cancelled");
  assert.equal(b.state, "cancelled");
  assert.equal(jobs.size, 0);
  assert.equal(finished.length, 0);
  assert.throws(() => r.add(brief()), /paused/);
});
test("pause confirmation suspends starts; cancellation resumes scheduling", async (t) => {
  const { r, jobs } = fixture(t, 1);
  const a = r.add(brief());
  const b = r.add(brief());
  await tick();
  r.setPaused(true);
  jobs.get(a.id)!.finish({ ok: true });
  await tick();
  assert.equal(b.state, "queued");
  assert.throws(() => r.add(brief()), /paused/);
  r.setPaused(false);
  await tick();
  assert.equal(b.state, "running");
});
test("tracks interleaved tool calls independently and records result usage", async (t) => {
  const { r } = fixture(t);
  const a = r.add(brief());
  await tick();
  r.event(a, {
    type: "tool_execution_start",
    toolCallId: "x",
    toolName: "read",
    args: { path: "a" },
  });
  r.event(a, {
    type: "tool_execution_start",
    toolCallId: "y",
    toolName: "grep",
    args: { text: "b" },
  });
  r.event(a, { type: "tool_execution_end", toolCallId: "x" });
  assert.deepEqual(Object.keys(a.activeTools), ["y"]);
  r.event(a, {
    type: "message_end",
    message: {
      role: "assistant",
      content: [{ type: "text", text: "done" }],
      usage: { input: 3, output: 2, cost: { total: 0.1 } },
    },
  });
  assert.equal(r.output(a.id, "result"), "done");
  assert.equal(a.usage.cost, 0.1);
});

test("hard deadline cancels a worker and releases capacity", async (t) => {
  const { r, jobs } = fixture(t, 1);
  const a = r.add(brief({ timeout_seconds: 0.01 }));
  const b = r.add(brief());
  await tick();
  await new Promise((resolve) => setTimeout(resolve, 40));
  assert.equal(a.state, "cancelled");
  assert.match(a.error!, /deadline/);
  assert.equal(jobs.get(a.id)!.stopped, true);
  assert.equal(b.state, "running");
});

test("outstanding queue and transcript sizes are bounded", async (t) => {
  const { r } = fixture(t);
  const a = r.add(brief());
  for (let i = 1; i < 32; i++) r.add(brief());
  assert.throws(() => r.add(brief()), /limit/);
  await tick();
  r.event(a, { type: "fixture", data: "x".repeat(6 * 1024 * 1024) });
  assert.equal(a.logTruncated, true);
  assert.match(r.output(a.id), /limit/);
  r.event(a, {
    type: "message_end",
    message: {
      role: "assistant",
      content: [{ type: "text", text: "Final result remains accessible" }],
    },
  });
  assert.match(r.output(a.id, "result"), /remains accessible/);
});
