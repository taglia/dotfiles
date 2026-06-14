# Global AGENTS.md

Cross-project instructions for pi. Read on every session.

## Behavior

- **When unsure, search the web**: rather than guessing. Cite the source. Prefer `workflow: "none"` for `web_search` calls to skip the interactive curator.
- **Do not modify files until the user has approved the implementation**: Propose the plan first; wait for explicit approval before writing, editing, or running state-changing commands.
- **Prioritize nix packages when you need a missing command**: the system has a nix index database installed; use nix-shell when you need a missing command.
- **Prioritize nix dev-shells to install repo-specific tools**: if specific tools (i.e. for embedded systems, compilers, tooling) is required for a project, always propose to use a dev-shell, and auto-activate it with dir-env.

## Things to check after completing a task

- **Check if there are open todos, and if they should not be closed or dropped**: it is not good to leave dangling todos.
