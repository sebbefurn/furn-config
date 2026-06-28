# furn-config

Personal dotfiles for a terminal-centric Ubuntu dev environment, replicable across
machines with one command. Managed with [GNU Stow](https://www.gnu.org/software/stow/).

```sh
git clone <this-repo> ~/Projects/furn-config
cd ~/Projects/furn-config
./bootstrap.sh
```

Then open a new terminal (or `exec zsh`).

## What you get

| Tool | Highlights |
|------|-----------|
| **zsh** | login shell, vi-mode, autosuggestions + syntax-highlighting (pinned, no framework), git-aware prompt, auto-attaches tmux |
| **tmux** | prefix `C-Space`, vi copy-mode, `\|`/`-` splits, TPM (sensible, yank, vim-tmux-navigator), gruvbox status |
| **vim** | stock vim, zero plugins (except vim-tmux-navigator), gruvbox, sane defaults |
| **kitty** | JetBrainsMono Nerd Font, gruvbox dark, minimal (tmux multiplexes) |
| **keyd** | Caps Lock → Esc, universal (Wayland/X11/TTY) |
| **git/gh** | rebase-pull, SSH auth + SSH commit signing, curated aliases |
| **Claude Code** | tracked `settings.json` + global `CLAUDE.md` (secrets excluded) |

Theme is **gruvbox dark** across kitty, tmux, and vim.

## Layout

```
bootstrap.sh        # apt + keyd-from-source + fonts + stow + chsh + TPM
stow/               # user configs, symlinked into $HOME by stow
system/keyd/        # root-owned config, copied to /etc by bootstrap (sudo)
docs/adr/           # architecture decision records (the "why")
CONTEXT.md          # glossary
```

## Per-machine manual step (can't be automated — secrets)

git commit signing needs your SSH key, which is never committed. On a fresh machine
`bootstrap.sh` prints the steps; in short:

```sh
ssh-keygen -t ed25519 -C "sebastian.furn@gmail.com"
gh auth login                                              # SSH
gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing
./bootstrap.sh                                             # populates allowed_signers
```

## Adding a tool

1. `mkdir -p stow/<tool>/<path-relative-to-$HOME>` and put the config there.
2. `cd stow && stow <tool>`.
3. Add any package install / pinned dependency to `bootstrap.sh`.

See [`docs/adr/`](docs/adr/) for the reasoning behind each choice.
