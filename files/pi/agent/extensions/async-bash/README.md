# pi-async-bash

A [pi](https://github.com/earendil-works/pi-coding-agent) extension that lets the
LLM run shell commands in **background subprocesses** instead of blocking the single
agent flow.

pi has one flow: while a command runs, the agent is stuck until it completes or the
timeout fires. This extension adds a parallel `bash_async` tool that spawns the
command detached and returns immediately with a `task_id`. A background monitor
watches each task and **wakes the agent** (via an injected message) when something
interesting happens — the task finishes, stalls (no output for a while), or exceeds
a soft deadline. The LLM then makes the judgement call: keep waiting, investigate,
or kill it and try a different strategy.

The built-in `bash` tool is left untouched, so quick commands keep their fast path.
The LLM picks `bash` or `bash_async` per command.

## Tools

| Tool | Purpose |
|------|---------|
| `bash_async` | Spawn a command in the background. Waits a short grace period to capture instant failures, then returns `{ task_id, pid, log_path }`. |
| `bash_status` | Report runtime, log growth, last-output age, and exit code for one or all tasks. |
| `bash_output` | Read a task's log file (tail or full). |
| `bash_kill` | Stop a task (SIGTERM → SIGKILL). Only kills processes this extension started. |

## Monitor behaviour

- The monitor scheduler wakes every 30s to notice newly launched tasks.
- Each task's output is checked no more often than every 30s initially.
- Per-task checks back off exponentially with runtime: 30s for the first 2m,
  60s through 4m, 2m through 8m, 4m through 16m, and 8m through 32m.
  Checks are capped at once every 10m for longer-running tasks.
- Wakes the agent with a factual status message (incl. a log tail) on:
  - **completion** → `deliverAs: "followUp"`,
  - **stall** (no log growth for `STALL_THRESHOLD_MS`, 60s) → `deliverAs: "steer"`,
  - **soft deadline exceeded** (if `bash_async` was given `timeout`) → `deliverAs: "steer"`.
- The monitor never kills anything itself — it only reports; the LLM decides.

## Run / test

Promoted into the dotfiles repo: source lives in
`dotfiles/files/pi/agent/extensions/async-bash/` and is installed to
`~/.pi/agent/extensions/async-bash/` by `modules/home/pi.nix` (auto-discovered,
no `settings.json` change needed).

For dev iteration against the writable source (the installed copy is a nix-store
symlink), load straight from the repo:

```bash
pi -e ~/dotfiles/files/pi/agent/extensions/async-bash/index.ts
```

then `home-manager switch` to take it live.

State lives in `~/.pi/agent/async-bash/<session-id>/` (logs + `tasks.json` manifest).
Tasks survive a pi restart; still-running children keep appending to their log file.

## Tunables

`monitor.ts` top: `MONITOR_INITIAL_INTERVAL_MS`, `MONITOR_MAX_INTERVAL_MS`,
`STALL_THRESHOLD_MS`, `TAIL_LINES`. `tools.ts` top: `GRACE_MS`. `registry.ts` top:
`MAX_LOG_BYTES`.