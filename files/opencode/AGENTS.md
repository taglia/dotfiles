# Global AGENTS.md

Cross-project instructions for OpenCode. Read on every session.

## Behavior

- When unsure, search rather than guess and cite the source.
- Propose an implementation and get approval before modifying files or running state-changing commands.
- Prefer Nix packages for missing commands and Nix dev shells for repository-specific tooling.
- Never commit or push without explicit authorization.
- Never search all of `/` or the home directory. Narrow searches to a known project or subdirectory.
- Prefer small scripts for processing large inputs rather than placing large data in model context.
- Remove temporary files when the work is complete.
- Check for unfinished todos before ending a task.

## Interactive Commands

`tmux-cli` controls interactive CLI applications in separate tmux panes. Use
`tmux-cli --help` for usage. It starts Fish by default, so launch Bash or Zsh
explicitly when one of those shells is required.
