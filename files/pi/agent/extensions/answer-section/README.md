# Answer section

A dependency-free, display-only extension for stock Pi. After `agent_settled`
(no queued retry, compaction or follow-up remains), it repeats the latest user
request's public assistant replies together in an **Answer** section at the bottom.
Original messages, tool blocks and async completion notices remain above as reference.

- Includes public progress text and final replies, in order; this is a collection,
  not a newly generated summary. Thinking, tool arguments/results, images and
  custom notification payloads are excluded.
- A later async follow-up produces a new, updated collection containing the earlier
  replies too. Previous collections remain in the historical transcript. Repeated
  settled events without new public text do not append duplicate collections.
- A new user message starts a new collection. Reads only the active branch, even
  after compaction; replies on abandoned branches are never mixed in.
- Interrupted, errored, output-limited and provider-deferred replies are labeled.
  Each reply is rendered separately so an unfinished code fence cannot consume the
  next reply. Answer text stays expanded when Ctrl+O collapses technical details.
- `/answer` repeats the collection at the bottom while idle, without calling a model.
- Uses `appendEntry` / `registerEntryRenderer`, **not** `sendMessage`. Copies are
  persisted in the session for resume/reload but never enter model context. This
  increases session storage, not token usage. No Pi patch, new dependency or change
  to async notification delivery/scheduling is required.
- Interactive TUI only; JSON/RPC/headless sessions are unchanged. Reload does not
  retroactively append an Answer: use `/answer` or wait for the next settled run.

Run tests and strict TypeScript checks with the shared extension check:

```sh
nix shell --inputs-from . nixpkgs-unstable#nodejs nixpkgs#typescript \
  --command bash scripts/check-agent-async.sh
```

After applying the Home Manager/darwin configuration, run `/reload` in Pi.
Use `/answer` to check the layout immediately. No configuration is switched by
this extension, and no additional model call is needed for that check.
