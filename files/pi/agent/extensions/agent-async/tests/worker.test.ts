import { test } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { startWorker } from "../runner.ts";

const sdk = process.env.PI_AGENT_TEST_SDK;
const directory = dirname(dirname(fileURLToPath(import.meta.url)));
test(
  "real SDK worker: explicit model, no discovery, guarded tools, events and result",
  { skip: !sdk, timeout: 30000 },
  async (t) => {
    const root = realpathSync(mkdtempSync(join(tmpdir(), "agent-worker-")));
    const stateDir = join(root, "state");
    mkdirSync(stateDir);
    const cwd = join(root, "project");
    mkdirSync(cwd);
    mkdirSync(join(cwd, ".pi/extensions"), { recursive: true });
    writeFileSync(
      join(cwd, ".pi/extensions/hostile.ts"),
      `throw new Error("PROJECT EXTENSION LOADED");`,
    );
    writeFileSync(join(cwd, "source.txt"), "workspace content");
    const requests: any[] = [];
    const server = createServer(async (req, res) => {
      let body = "";
      for await (const chunk of req) body += chunk;
      const request = JSON.parse(body);
      requests.push(request);
      const n = requests.length;
      const tool =
        n === 1
          ? { name: "read", arguments: JSON.stringify({ path: "../outside" }) }
          : n === 2
            ? { name: "read", arguments: JSON.stringify({ path: "source.txt" }) }
            : n === 3
              ? {
                  name: "write",
                  arguments: JSON.stringify({ path: "not-approved.txt", content: "bad" }),
                }
              : n === 4
                ? {
                    name: "write",
                    arguments: JSON.stringify({ path: "approved.txt", content: "good" }),
                  }
                : undefined;
      res.writeHead(200, { "Content-Type": "text/event-stream" });
      const data = (delta: any, finish_reason: string | null) =>
        res.write(
          `data: ${JSON.stringify({ id: "test", object: "chat.completion.chunk", created: 1, model: "cheap", choices: [{ index: 0, delta, finish_reason }] })}\n\n`,
        );
      if (tool) {
        data(
          {
            role: "assistant",
            tool_calls: [{ index: 0, id: `tool${n}`, type: "function", function: tool }],
          },
          null,
        );
        data({}, "tool_calls");
      } else {
        data({ role: "assistant", content: "Finished local fixture." }, null);
        data({}, "stop");
      }
      res.end("data: [DONE]\n\n");
    });
    await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
    const port = (server.address() as any).port;
    const events: any[] = [];
    const worker = startWorker({
      directory,
      sdk: sdk!,
      cwd,
      stateDir,
      secrets: ["fixture-secret"],
      event: (e) => events.push(e),
      payload: {
        task: {
          cwd,
          thinking: "off",
          instructions: [{ path: "mandatory", content: "MANDATORY_CONTEXT_MARKER" }],
          write_paths: [join(cwd, "approved.txt")],
        },
        prompt: "DEDICATED_BRIEF_MARKER",
        auth: { ok: true, apiKey: "fixture-secret" },
        model: {
          id: "cheap",
          name: "Cheap",
          provider: "fixture",
          api: "openai-completions",
          baseUrl: `http://127.0.0.1:${port}/v1`,
          reasoning: false,
          input: ["text"],
          contextWindow: 16000,
          maxTokens: 1000,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        },
      },
    });
    t.after(async () => {
      await worker.stop();
      server.closeAllConnections();
      server.close();
      rmSync(root, { recursive: true, force: true });
    });
    const outcome = await worker.done;
    assert.equal(outcome.ok, true, outcome.error);
    assert.equal(requests.length, 5);
    assert.ok(requests.every((r) => r.model === "cheap"));
    const names = requests[0].tools.map((t: any) => t.function.name).sort();
    assert.deepEqual(names, ["edit", "grep", "ls", "read", "write"]);
    assert.match(JSON.stringify(requests[0]), /MANDATORY_CONTEXT_MARKER/);
    assert.match(JSON.stringify(requests[0]), /DEDICATED_BRIEF_MARKER/);
    assert.match(JSON.stringify(requests[1]), /outside the assigned workspace/);
    assert.match(JSON.stringify(requests[2]), /workspace content/);
    assert.match(JSON.stringify(requests[3]), /not in the approved writable scope/);
    assert.equal(existsSync(join(cwd, "not-approved.txt")), false);
    assert.equal(existsSync(join(cwd, "approved.txt")), true);
    assert.ok(events.some((e) => e.type === "tool_execution_start"));
    assert.ok(
      events.some((e) =>
        e.message?.content?.some((p: any) => p.text === "Finished local fixture."),
      ),
    );
  },
);
