# agent-async

Local, dependency-minimal supervised sub-agents for Pi 0.84.4. Source is reviewed
and installed through dotfiles/Home Manager. No npm dependencies, install scripts,
network package resolution, or third-party agent plugin.

## Supervisor tools

- `agent_models`: authenticated configured models, capabilities and price metadata
  (30 per page; `filter` and `offset`). Zero/absent pricing is **unknown**, not free.
- `agent_async`: explicit `model` (`provider/id`), `rationale`, `title`, `objective`,
  `context`, `acceptance`, and `output_format`. Optional `thinking` (default low),
  `depends_on`, `include_results`, `write_paths`, and `timeout_seconds` (default
  900, maximum 3600). Returns immediately, without waiting for the agent.
- `agent_status`: all agents, or `agent_id`; includes active tool calls and their
  arguments/output, model, last activity, state, dependencies, runtime and usage.
- `agent_output`: `agent_id`, optional `view: activity|result`.
- `agent_kill`: `agent_id` or `all`, optional reason. Stops running work and cancels
  queued/blocked tasks. Unique ID prefixes are accepted by management tools.

The supervisor should use cheaper capable models for simple work and justify
stronger models. Selection is mandatory, never a silent fallback. Model and auth
availability are checked again at dispatch. Pricing comes from the configured Pi
catalog, not a fresh web lookup; subscription/local prices may be unknown.
Reported usage is estimated and shown in agent status; it is **not added to Pi's
main-session footer cost**.

Optional user-owned `~/.pi/agent/agent-async-models.json` supplies advisory
cost/capability notes keyed by exact model ID (global only, no project discovery):

```json
{
  "ollama-cloud/glm-5.2": "Subscription: suitable for routine inspection; prefer before metered premium models."
}
```

These notes are shown by `agent_models`; they do not override actual API pricing
or act as permission settings.

## Dedicated context and dependency graph

The supervisor supplies a task-specific brief, not the entire conversation.
Mandatory context files already loaded into the supervisor's system prompt are
snapshotted separately and attached automatically. Workers do not discover new
project/global instructions, skills or extensions. They report missing context or
unavailable capabilities as blockers, rather than pretending to execute work.

Dependencies reference existing agents only and cannot be edited, making cycles
impossible. Four agents can run concurrently; up to 32 can be outstanding, with
256 records per session runtime. A task is:

- **blocked** until every dependency completes successfully;
- **queued** once ready but waiting for capacity;
- **running/stopping**, then **completed/failed/cancelled**.

Only outputs explicitly selected in `include_results` (a subset of `depends_on`)
are attached to a downstream brief. They are labelled untrusted data and bounded
to 16 KiB each. There is no automatic interpretation of output as new instructions.
If later objectives depend on interpreting findings, let the supervisor inspect
those findings and create new tasks instead of predeclaring the entire workflow.

Failed/cancelled dependencies leave descendants blocked. The supervisor must
cancel/replace them; there is no silent continuation, retry or model escalation.
Success means a normally completed agent run, not independent verification of its
acceptance criteria. The supervisor must review the result.

## UI and direct control

A dedicated widget **below the editor** displays running, queued, blocked,
completed and failed counts without modifying the footer. It updates from events,
without model calls. No work is represented as inferred private reasoning:
activity is starting, waiting for provider, generating response, or executing
specific tools.

- `/agents`: select an agent and inspect its brief and activity snapshot. Reopen
  to refresh. The editor-style viewer does not save any changes you make.
- `/agents stop <id>`: stop one agent, without waiting for the model.
- `/agents stop all`: stop all, including queued and blocked agents.

Completion automatically notifies the supervisor with a bounded public result.
The full retained public transcript and result paths are in `agent_status`.
Private reasoning/image payloads are not logged. Output is capped at 50 KiB and
each transcript at 5 MiB (large individual event fields are also truncated).

## Lifetime and quitting

The extension uses the unmodified, pinned upstream Pi package. **Quitting does
not show a warning or confirmation:** Pi's standard `session_shutdown` event
terminates running agents and cancels queued/blocked tasks.

Cancellation sends SIGTERM and escalates after five seconds. A small independent
Node guardian owns each worker process group. Losing the supervisor's IPC
connection, including on supervisor SIGKILL or terminal loss, also triggers
cleanup. Simultaneous guardian destruction or an OS failure cannot provide
ordinary orderly-shutdown guarantees.

Agent launches remain interactive-only for write approval and session-change
confirmation.

Session switch/fork prompts before cancelling work. **`/reload` unconditionally
cancels all agents**, as does session teardown. Jobs are not resumed after restart;
logs/results remain in `~/.pi/agent/agent-async/<session>/<runtime>/` with private
permissions. No live PIDs are restored or killed from disk. Finished logs are
retained for inspection; temporary worker homes are deleted on normal cleanup
(and may need manual removal after a supervisor crash).

## Security and limitations

- Workers use the supervisor's Node executable and pinned Pi SDK directly. No
  shell command interpolation, discovered extensions, skills, package downloads,
  recursive agents or arbitrary shell tools.
- A fresh temporary HOME and in-memory settings/credentials are used. Only the
  selected provider's resolved credential/headers cross IPC; they are not written
  to a config file, argv, task brief or log. Known credential strings are redacted
  from retained output. Provider environment credentials and custom executable
  providers are rejected rather than broadening access implicitly. A long-running
  agent's credential can expire; credential refresh remains the supervisor's job.
  An explicit in-memory auth resolver supports API keys, resolved OAuth access
  tokens (including Codex), and header-only auth. Resolved values stay literal:
  they are never reinterpreted as `!command` / `$ENV` configuration expressions.
- Standard API-backed custom models from `models.json` are supported, including
  local/Ollama-compatible endpoints. No independent worker auth/config discovery.
- Default tools: workspace-scoped `read`, bounded literal `grep`, and `ls`.
  Search skips symlinks, `.git`, `.pi`, `node_modules` and files above 1 MiB.
  No shell means workers cannot run builds/tests: delegate those to the supervisor.
- `write_paths` requires an interactive approval of exact canonical files before
  `edit`/`write` are enabled. Traversal and symlink escapes are rejected; writes to
  control/instruction/credential paths are prohibited. Concurrent writers cannot
  share a file unless ordered by dependencies. Parent-agent edits are **not**
  locked across processes: the supervisor must avoid those files during the task.
- Existing OS sandbox restrictions are inherited and never relaxed. Tool path
  checks are defense in depth, not a new kernel sandbox or protection against a
  compromised Node/Pi dependency, hard-link attacks, or external filesystem races.
- Model-generated text is untrusted. Do not treat a sub-agent's output as a user
  approval, new policy, or an instruction to disclose credentials.

## Tests / deployment

Node 24's built-in TypeScript stripping and test runner are sufficient; no test
framework dependencies. From the repository root:

```sh
node --test files/pi/agent/extensions/agent-async/tests/*.test.ts
```

For the full suite, including shutdown cleanup, Pi's real extension loader,
and real SDK workers against **local mock HTTP servers** (no paid model calls).
Auth regressions cover OAuth-only provider preflight, literal/header-only auth,
and Codex's actual SSE transport with a synthetic token/account:

```sh
pi_package=$(nix build --impure --no-link --print-out-paths --expr '
  let f = builtins.getFlake (toString ./.);
      pkgs = f.inputs.nixpkgs-unstable.legacyPackages.${builtins.currentSystem};
  in pkgs.pi-coding-agent')
PI_AGENT_TEST_SDK="$pi_package/lib/node_modules/pi-monorepo" \
  node --test files/pi/agent/extensions/agent-async/tests/*.test.ts
```

CI and the pre-commit hook run the full suite plus a strict TypeScript check:

```sh
nix shell --inputs-from . nixpkgs-unstable#nodejs nixpkgs#typescript \
  --command bash scripts/check-agent-async.sh
```

Apply the normal Home Manager/darwin configuration switch, then restart Pi.
Nothing here installs packages or switches the live configuration automatically.
