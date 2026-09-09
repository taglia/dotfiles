import { startWorker } from "../../runner.ts";
process.on("message", (options: any) => {
  const worker = startWorker({ ...options, event: (e: any) => process.send?.(e) });
  void worker.done.then((result) => process.send?.({ type: "done", result }));
});
