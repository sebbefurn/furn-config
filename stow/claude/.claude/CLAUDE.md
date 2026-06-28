# Global instructions (Sebastian)

Personal, cross-project preferences for Claude Code. Project-level `CLAUDE.md`
files always take precedence over this.

## Environment
- Terminal-centric Ubuntu: kitty + tmux + zsh (vi-mode) + vim. Caps Lock is Esc (keyd).
- Editor everywhere is `vim`. Prefer vim/vi idioms when suggesting editor actions.
- Dotfiles live in the `furn-config` repo (GNU Stow + `bootstrap.sh`).

## Working style
- Be concise and direct. Lead with the answer; keep preamble minimal.
- Prefer minimal, reproducible, dependency-light solutions over heavy frameworks.
- When adding tooling, prefer something a single pinned file or apt package can capture.

## Git
- Rebase-based workflow (`pull.rebase=true`); keep history linear.
- Commits are SSH-signed. Default branch is `main`. Use `gh` over SSH.
- Don't commit or push unless asked.

## Don't
- Don't introduce plugin managers or frameworks without flagging the trade-off.
- Don't add secrets to any tracked file.
