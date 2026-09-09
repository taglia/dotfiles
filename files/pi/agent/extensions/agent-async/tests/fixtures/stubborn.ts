import { spawn } from "node:child_process";
process.on("SIGTERM", () => {});
process.on("message", () => {
  const child = spawn(
    process.execPath,
    ["-e", "process.on('SIGTERM',()=>{});setInterval(()=>{},1000)"],
    { stdio: "ignore" },
  );
  process.stdout.write(
    JSON.stringify({ type: "pids", worker: process.pid, descendant: child.pid }) + "\n",
  );
});
setInterval(() => {}, 1000);
