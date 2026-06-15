# Global AGENTS.md

Cross-project instructions for pi. Read on every session.

## Behavior

- **When unsure, search the web**: rather than guessing. Cite the source.
- **Do not modify files until the user has approved the implementation**: Propose the plan first; wait for explicit approval before writing, editing, or running state-changing commands.
- **Prioritize nix packages when you need a missing command**: the system has a nix index database installed; use nix-shell when you need a missing command.
- **Prioritize nix dev-shells to install repo-specific tools**: if specific tools (i.e. for embedded systems, compilers, tooling) is required for a project, always propose to use a dev-shell, and auto-activate it with direnv.
- **CRITICAL: Do NOT commit or push code without authorization**: never, never commit or push code without asking for approval first.
- **Use small scripts whenever you can rather than push large contexts**: if you need to process large amounts of data, NEVER push that to the LLM, write a script to process the data.
- **Cleanup temporary files**: if you create temporary documents or scripts, clean them up once you have completed the work and do not need them anymore.

## Things to check after completing a task

- **Check if there are open todos, and if they should not be closed or dropped**: it is not good to leave dangling todos.
