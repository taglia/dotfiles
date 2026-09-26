import { test } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import type { Model } from "@earendil-works/pi-ai";
import { configureWorkerModel } from "../worker-auth.ts";

// Exercise the real Codex provider without depending on its changing model catalog.
function codexModel(): Model<"openai-codex-responses"> {
  return {
    id: "fixture-codex",
    name: "Fixture Codex",
    provider: "openai-codex",
    api: "openai-codex-responses",
    baseUrl: "https://chatgpt.com/backend-api",
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 128000,
    maxTokens: 4096,
  };
}

const sdkDir = process.env.PI_AGENT_TEST_SDK;
async function fixture(t: any) {
  const sdk = await import(pathToFileURL(join(sdkDir!, "dist/index.js")).href);
  const ai = await import(
    pathToFileURL(join(sdkDir!, "node_modules/@earendil-works/pi-ai/dist/index.js")).href
  );
  const dir = mkdtempSync(join(tmpdir(), "agent-auth-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const credentials = new ai.InMemoryCredentialStore();
  const runtime = await sdk.ModelRuntime.create({
    credentials,
    modelsPath: null,
    modelsStorePath: join(dir, "models-store.json"),
    refreshOnCreate: false,
    allowModelNetwork: false,
  });
  return { runtime, credentials };
}

test(
  "OAuth-only Codex recognizes the request snapshot without storing credentials",
  { skip: !sdkDir },
  async (t) => {
    const { runtime, credentials } = await fixture(t);
    const model = codexModel();
    // Reproduce the old implementation: the override is NOT recognized as configured OAuth auth.
    runtime.registerProvider(model.provider, {
      api: model.api,
      baseUrl: model.baseUrl,
      models: [model],
    });
    await runtime.setRuntimeApiKey(model.provider, "synthetic-access-token");
    assert.equal(await runtime.checkAuth(model.provider), undefined);
    await runtime.removeRuntimeApiKey(model.provider);

    const snapshot = {
      ok: true as const,
      apiKey: "synthetic-access-token",
      headers: { "X-Literal": "!printf wrong $NOT_ENV" },
    };
    const resolved = await configureWorkerModel(
      runtime,
      { ...model, headers: { "X-Unresolved": "$DO_NOT_RESOLVE" } },
      snapshot,
    );
    assert.ok(await runtime.checkAuth(model.provider));
    assert.equal((await runtime.getAvailable(model.provider)).length, 1);
    assert.equal(resolved.id, model.id);
    assert.equal(resolved.headers, undefined);
    const request = await runtime.getAuth(resolved);
    assert.equal(request.auth.apiKey, snapshot.apiKey);
    assert.equal(request.auth.headers["X-Literal"], snapshot.headers["X-Literal"]);
    assert.equal(await credentials.read(model.provider), undefined);
    assert.equal(runtime.getProvider(model.provider).auth.oauth, undefined);
    await assert.rejects(
      runtime.getProvider(model.provider).auth.apiKey.login({}),
      /Workers cannot log in/,
    );
  },
);

test(
  "snapshot resolver supports header-only auth without environment lookup",
  { skip: !sdkDir },
  async (t) => {
    const { runtime } = await fixture(t);
    const model = {
      ...codexModel(),
      provider: "header-only",
      api: "openai-completions",
    };
    const selected = await configureWorkerModel(runtime, model, {
      ok: true,
      headers: { Authorization: "Bearer synthetic-token" },
    });
    assert.ok(await runtime.checkAuth(selected.provider));
    assert.equal(
      (await runtime.getAuth(selected)).auth.headers.Authorization,
      "Bearer synthetic-token",
    );
    await assert.rejects(
      configureWorkerModel(runtime, model, { ok: true, env: { SECRET: "unapproved" } }),
      /Unsupported/,
    );
  },
);

test(
  "real Codex transport uses the inherited token and account against a local SSE mock",
  { skip: !sdkDir, timeout: 15000 },
  async (t) => {
    const { runtime } = await fixture(t);
    const token = `fixture.${Buffer.from(JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: "fixture-account" } })).toString("base64")}.signature`;
    let requestHeaders: any;
    let requestUrl: string | undefined;
    const server = createServer(async (req, res) => {
      requestHeaders = req.headers;
      requestUrl = req.url;
      // Codex can zstd-compress its body; this fixture only needs to verify auth/route.
      for await (const _chunk of req) {
        /* drain */
      }
      res.writeHead(200, { "Content-Type": "text/event-stream" });
      const item = {
        id: "msg_fixture",
        type: "message",
        role: "assistant",
        status: "completed",
        content: [{ type: "output_text", text: "Authenticated fixture.", annotations: [] }],
      };
      for (const event of [
        { type: "response.created", response: { id: "resp_fixture", status: "in_progress" } },
        {
          type: "response.output_item.added",
          output_index: 0,
          item: { ...item, status: "in_progress", content: [] },
        },
        {
          type: "response.content_part.added",
          output_index: 0,
          content_index: 0,
          item_id: item.id,
          part: { type: "output_text", text: "", annotations: [] },
        },
        {
          type: "response.output_text.delta",
          output_index: 0,
          content_index: 0,
          item_id: item.id,
          delta: "Authenticated fixture.",
        },
        { type: "response.output_item.done", output_index: 0, item },
        {
          type: "response.completed",
          response: {
            id: "resp_fixture",
            status: "completed",
            output: [item],
            usage: { input_tokens: 10, output_tokens: 3, total_tokens: 13 },
          },
        },
      ])
        res.write(`data: ${JSON.stringify(event)}\n\n`);
      res.end();
    });
    t.after(() => {
      server.closeAllConnections();
      server.close();
    });
    await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
    const baseUrl = `http://127.0.0.1:${(server.address() as any).port}`;
    const model = codexModel();
    const selected = await configureWorkerModel(runtime, model, {
      ok: true,
      apiKey: token,
      baseUrl,
      headers: { "X-Literal": "!printf wrong $NOT_ENV" },
    });
    const response = await runtime.completeSimple(
      selected,
      { messages: [{ role: "user", content: "Reply briefly.", timestamp: Date.now() }] },
      { transport: "sse", reasoning: "off", maxRetries: 0, signal: AbortSignal.timeout(10000) },
    );
    assert.equal(response.stopReason, "stop", response.errorMessage);
    assert.ok(response.content.some((p: any) => p.text === "Authenticated fixture."));
    assert.equal(requestHeaders.authorization, `Bearer ${token}`);
    assert.equal(requestHeaders["chatgpt-account-id"], "fixture-account");
    assert.equal(requestHeaders["x-literal"], "!printf wrong $NOT_ENV");
    assert.match(requestUrl!, /\/codex\/responses$/);
  },
);
