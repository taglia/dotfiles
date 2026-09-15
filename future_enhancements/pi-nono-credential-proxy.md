# Pi credential isolation with nono's proxy

## Status

Deferred. This document records a proposed implementation; no proxy configuration
or application changes have been implemented. Creating this document does not
constitute approval to implement the plan.

The proposal was checked against nono 0.74.0, Pi 0.85.1, the repository's current
configuration, and the online documentation linked below. Recheck compatibility
and configuration before implementation.

## Goal and security boundary

Keep API keys supplied by agenix outside sandboxed Pi, its tools, and its workers.
Use nono's session-managed credential reverse proxy:

```text
agenix secret files -> nono proxy -> authenticated HTTPS upstream request
                            ^
                 Pi sends a phantom session token
```

The proxy reads real credentials on the host. Sandboxed clients receive a
localhost endpoint and a session-scoped phantom token, not the real key. Prefer
explicit reverse-proxy URLs over TLS interception for Ollama Cloud and Kagi.

This prevents direct extraction of those keys from sandboxed processes; it does
not prevent authorized API use, data submission, or charges. Phantom-token holders
can use the session's permitted routes. This is not per-worker authorization.
Other credentials, including existing Pi OAuth authentication, require separate
review and are not automatically protected by these two routes.

## User-facing behavior

Preserve the existing command distinction:

```sh
pi-sandbox       # nono sandbox and credential proxy
pi               # ordinary Pi with direct agenix credential access
```

Both commands must continue to accept arguments such as `-c`. Run ordinary `pi`
from a terminal outside nono: launching it through sandboxed Pi's shell tool does
not escape the sandbox, because child processes inherit its restrictions.

Keep direct-mode credential resolution available deliberately. Sandbox mode must
select proxy endpoints and phantom credentials explicitly. Missing or invalid
proxy configuration must fail closed, never fall back to real keys.

## Current configuration

- `modules/home/pi.nix` grants read access to `~/.local/share/agenix`.
- Ollama Cloud's `apiKey` setting executes `!cat "$OLLAMA_API_KEY_FILE"` inside Pi.
- `files/pi/agent/extensions/minimal-web/index.ts` reads the Kagi key from an
  environment variable or agenix file.
- Its Kagi base-URL validator only accepts HTTPS destinations under `kagi.com`;
  it currently rejects nono's localhost reverse-proxy URL.
- The inherited `nolabs-ai/pi` profile grants access to `~/.pi`, so authentication
  files there need review alongside agenix paths.
- `profiles/private.nix` provides host-specific agenix consumer paths without
  putting secret contents into the Nix store.

## Worker behavior

### Ollama Cloud

Workers must remain able to call Ollama Cloud through the parent session's proxy.
The existing `agent-async` implementation passes the selected model's resolved
API key, headers, and base URL through IPC, keeping credentials in memory.

Under proxy mode that snapshot should contain the localhost route and phantom
token. Workers inherit the outer sandbox and can use its proxy while the session
is alive. They do not need agenix access, independent credential discovery, or
separate proxy processes.

Explicit reverse-proxy routing should avoid broadening the worker environment
with general proxy or CA variables just for Ollama Cloud. Verify this with the
actual bundled SDK and a worker integration test.

Relevant files:

- `files/pi/agent/extensions/agent-async/worker-auth.ts`
- `files/pi/agent/extensions/agent-async/runner.ts`
- `files/pi/agent/extensions/agent-async/worker.ts`

### Web searching and Kagi

Workers currently have no web-search tools and no shell. They disable extension
discovery and expose only workspace-scoped `read`, `ls`, and `grep`, plus approved
`edit` and `write` when enabled. The supervisor's `minimal-web` extension is not
loaded into workers.

Research tasks can benefit from web searches, but normal coding and review tasks
do not require independent worker browsing. For this implementation, preserve the
existing restriction: the supervisor searches with Kagi and supplies relevant
findings in worker briefs. Workers report missing information or unavailable
tools as blockers.

Independent research workers are a separate, optional future feature. Add an
explicit opt-in web capability with bounded searches and timeouts rather than
loading all extensions. Such tools could call Kagi through the same credential
proxy without receiving its real key. Enabling the proxy alone does not give
workers web tools or enforce per-worker route permissions.

## Implementation plan

### 1. Add agenix-backed nono credential routes

Configure `network.custom_credentials` in `modules/home/pi.nix` and activate both
routes through `network.credentials`:

| Route | Upstream | Authorization header value |
| --- | --- | --- |
| `ollama_cloud` | `https://ollama.com/v1` | `Bearer {}` |
| `kagi` | `https://kagi.com/api/v1` | `Bot {}` |

- Use `file://` credential references to the correct host-specific agenix paths.
  Generate paths only, never read secret contents during Nix evaluation.
- Set explicit phantom-token environment variable names through `env_var`.
- Use underscore-separated route names: nono derives environment variables such
  as `OLLAMA_CLOUD_BASE_URL` and `KAGI_BASE_URL` from them.
- Verify route path joining so `/v1` and `/api/v1` are neither lost nor duplicated.
- Use the proxy managed by `nono run`, with an ephemeral port and session lifetime.
  Do not introduce a permanent daemon or disable proxy authentication.
- Keep generic agenix wiring and other applications' credential access unchanged.
- Enable only routes supported by the host's deployed credentials, with clear
  errors for unavailable services.

### 2. Implement explicit direct and proxy modes

- Preserve ordinary `pi` and its direct credential configuration.
- Make `pi-sandbox` select a managed proxy mode and forward arguments unchanged.
- Add a small runtime configuration adapter to apply the generated Ollama Cloud
  endpoint and phantom credential without duplicating model definitions or
  changing provider IDs, pricing, or thinking controls.
- Confirm the appropriate adapter mechanism against the installed Pi SDK before
  implementing it; do not assume provider-specific environment variables
  automatically override Pi's explicit `models.json` base URL.
- Never persist session-specific proxy URLs or tokens in shared configuration.
- Missing proxy variables or a stopped proxy must fail closed in sandbox mode.

### 3. Adapt Kagi integration safely

Update `files/pi/agent/extensions/minimal-web/index.ts`:

- Add explicit proxy-mode handling for the expected loopback route and phantom
  credential. Merely setting `KAGI_BASE_URL` will not work with today's validator.
- Preserve direct mode's destination restrictions. Do not broadly permit real
  Kagi credentials to be sent to arbitrary URL overrides.
- Route Kagi search and summarization through the credential proxy.
- Keep ordinary webpage fetching separate from credential-bearing requests.
- Validate redirect handling, timeouts, and errors without logging credentials.

### 4. Close alternate credential access

- Remove the agenix directory read grant from the Pi profile.
- Verify both consumer symlinks and resolved agenix backing files are inaccessible
  on macOS and Linux, including after agenix generation changes.
- Review inherited grants, decryption identities, Pi authentication files, and
  inherited real-key environment variables for alternate access.
- Ensure no real credentials enter sandboxed Pi through environment inheritance.
- Keep proxy configuration and any host-side credential helpers outside
  sandbox-writable paths.
- Do not weaken protections by granting broad home-directory or configuration
  access to resolve denials.

### 5. Preserve worker and general network behavior

- Pass the resolved proxy URL and phantom authentication snapshot to workers via
  their existing in-memory IPC mechanism.
- Test Ollama Cloud calls from an actual `agent-async` worker, not just Pi itself.
- Keep worker web tools unavailable in this change.
- Preserve local Ollama access on port 11434 with suitable sandbox permissions.
- Credential injection activates proxy-based network restrictions. Choose an
  explicit general browsing/domain policy rather than assuming today's open
  networking remains unchanged.
- Test general webpage fetching through the forward proxy with the actual Node
  runtime. Do not assume `HTTP_PROXY`/`HTTPS_PROXY` alone control every fetch client.
- Test npm/Nix downloads and normal development commands. Use explicit proxy
  support where necessary; do not disable TLS verification.

### 6. Restrict API use and validate

Configure method/path allowlists for only the Ollama and Kagi endpoints actually
needed. Consider optional rate limits to contain runaway use.

Start with fake credentials and a local mock upstream, with no paid API calls.
Acceptance tests must establish:

- Only the mock upstream receives the real test credential.
- Pi and workers cannot read deployed secret files through symlinks or backing
  paths, and do not receive real keys in their environments.
- Missing/invalid phantom tokens and disallowed endpoints are rejected.
- Cross-host redirects and malformed requests cannot disclose credentials.
- Direct mode works independently and sandbox mode never falls back to direct
  credential access.
- Streaming, cancellation, concurrent workers/sessions, and shutdown work.
- Proxy URLs and credentials are not persisted into shared configuration, task
  briefs, logs, or worker artifacts.
- General web fetching and local Ollama remain functional.

Run relevant repository checks: Nix formatting, deadnix, statix, TypeScript
formatting, shellcheck for any new shell scripts, and
`scripts/check-agent-async.sh` if worker code changes. Add focused tests for the
Kagi proxy-mode URL and credential handling.

After explicit approval, perform small live smoke tests for sandboxed Pi, an
Ollama Cloud worker, and supervisor Kagi search/summarization. Apply the normal
Home Manager/darwin switch only when authorized, then restart Pi. Existing
sessions do not acquire the new sandbox policy.

## Scope and open decisions

Initial scope is Ollama Cloud and Kagi, covering the current direct credential
readers identified above. Other providers and OAuth flows are separate work.

Resolve before implementation:

1. The precise Pi runtime adapter used for dynamic proxy configuration.
2. General browsing policy: broad public-web access through the proxy versus a
   curated domain allowlist.
3. Treatment of existing real credentials in Pi authentication files while
   preserving intentional unsandboxed usage.
4. Exact endpoint rules and whether rate limits are wanted.

Independent worker web access is explicitly out of scope for this plan.

## Separate maintenance reminder

At documentation review, nixpkgs PR #558782 had merged and its merge commit
`589b05034898403a2beb39985dde6e7df5d21b6d` was an ancestor of the pinned unstable
revision `ef34387ddd751e1ab8857adf4676492d32eb24ec`.

Revisit removing the nono `doCheck = false` override in `profiles/ai.nix` to
restore binary-cache substitution. Validate the relevant builds, especially the
previously noted Linux failures; the upstream Darwin fix alone is not evidence
that every environment-sensitive test now passes. This maintenance task is
separate from credential proxying.

## References

- [nono credential injection](https://nono.sh/docs/cli/features/credential-injection)
- [nono networking](https://nono.sh/docs/cli/features/networking)
- [nixpkgs PR #558782](https://github.com/NixOS/nixpkgs/pull/558782)
- Installed nono references: `nono profile guide`, `nono profile schema`, and
  `nono run --help`.
- Installed Pi documentation: `docs/models.md`; consult relevant provider and
  extension documentation before implementing the runtime adapter.
- Local worker design: `files/pi/agent/extensions/agent-async/README.md`.
