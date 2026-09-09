import { spawn } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { StringDecoder } from "node:string_decoder";
import type { Outcome, Worker } from "./registry.ts";

/** No shell, NODE_OPTIONS, preload hooks, npm settings, or ambient provider secrets. */
export function workerEnvironment(home: string): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = { HOME: home, TMPDIR: home, PI_OFFLINE: "1", PI_TELEMETRY: "0" };
  for (const key of [
    "PATH",
    "LANG",
    "LC_ALL",
    "TZ",
    "SSL_CERT_FILE",
    "SSL_CERT_DIR",
    "NIX_SSL_CERT_FILE",
  ]) {
    if (process.env[key]) env[key] = process.env[key];
  }
  return env;
}
export function startWorker(options: {
  directory: string;
  sdk: string;
  cwd: string;
  stateDir: string;
  payload: unknown;
  secrets: string[];
  event: (event: any) => void;
}): Worker {
  const home = mkdtempSync(join(options.stateDir, ".worker-"));
  const child = spawn(
    process.execPath,
    [join(options.directory, "guardian.ts"), join(options.directory, "worker.ts"), options.sdk],
    {
      cwd: options.cwd,
      detached: true,
      stdio: ["ignore", "pipe", "pipe", "ipc"],
      env: workerEnvironment(home),
    },
  );
  const clean = (text: string) =>
    options.secrets
      .filter((s) => s.length >= 6)
      .reduce((s, secret) => s.split(secret).join("[redacted]"), text);
  let outcome: Outcome | undefined;
  let stderr = "";
  let buffer = "";
  let stopping = false;
  const decoder = new StringDecoder("utf8");
  const stop = () => {
    if (stopping) return;
    stopping = true;
    if (child.connected) child.send({ type: "stop" }, () => {});
  };
  child.stdout!.on("data", (chunk) => {
    buffer += decoder.write(chunk);
    if (Buffer.byteLength(buffer) > 1024 * 1024) {
      outcome = { ok: false, error: "Worker event exceeded 1 MiB protocol limit" };
      buffer = "";
      stop();
      return;
    }
    let end: number;
    while ((end = buffer.indexOf("\n")) >= 0) {
      const line = buffer.slice(0, end);
      buffer = buffer.slice(end + 1);
      try {
        options.event(JSON.parse(clean(line)));
      } catch {
        outcome = { ok: false, error: "Invalid worker event" };
        stop();
      }
    }
  });
  child.stderr!.on("data", (chunk) => {
    stderr = (stderr + clean(chunk.toString())).slice(-8192);
  });
  child.on("message", (message: any) => {
    if (message?.type === "done" && !outcome)
      outcome = {
        ok: message.ok === true,
        error: message.error ? clean(String(message.error)) : undefined,
      };
  });
  const done = new Promise<Outcome>((resolve) => {
    child.once("error", (error) => {
      outcome = { ok: false, error: clean(error.message) };
    });
    child.once("close", () => {
      rmSync(home, { recursive: true, force: true });
      resolve(outcome ?? { ok: false, error: stderr || "Worker guardian exited unexpectedly" });
    });
  });
  if (child.connected)
    child.send({ type: "start", payload: options.payload }, (error) => {
      if (error) {
        outcome = { ok: false, error: "Failed to initialise worker" };
        stop();
      }
    });
  return {
    done,
    async stop() {
      stop();
      await done;
    },
  };
}
