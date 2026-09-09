/** A tiny, independent lifetime owner. IPC EOF means the supervisor died, even by SIGKILL. */
import { spawn } from "node:child_process";

const worker = spawn(process.execPath, [process.argv[2], process.argv[3]], {
  stdio: ["ignore", "inherit", "inherit", "ipc"],
  env: process.env,
});
let stopping = false;
let outcome: unknown;
let timer: NodeJS.Timeout | undefined;
function reap() {
  // The guardian leads this group. Workers cannot create detached jobs (no shell tool).
  try {
    process.kill(-process.pid, "SIGKILL");
  } catch {
    worker.kill("SIGKILL");
    process.exit(1);
  }
}
function stop() {
  if (stopping) return;
  stopping = true;
  timer = setTimeout(reap, 5000);
  try {
    process.kill(-process.pid, "SIGTERM");
  } catch {
    worker.kill("SIGTERM");
  }
}
process.on("SIGTERM", stop);
process.on("SIGHUP", stop);
process.on("disconnect", stop);
process.on("message", (message: any) => {
  if (message?.type === "stop") stop();
  else if (!stopping && worker.connected) worker.send(message, () => {});
});
worker.on("message", (message: any) => {
  if (message?.type === "done") outcome = message;
});
worker.on("error", () => {
  outcome = { type: "done", ok: false, error: "Worker failed to spawn" };
});
worker.on("close", (code) => {
  if (timer) clearTimeout(timer);
  const result = outcome ?? {
    type: "done",
    ok: false,
    error: `Worker exited without a result (${code})`,
  };
  if (process.connected) process.send!(result, () => reap());
  else reap();
});
// A supervisor disappearing during startup must not leave an uninitialised worker.
if (!process.connected) stop();
