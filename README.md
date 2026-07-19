# furn-config

Personal dotfiles for a terminal-centric Debian/Ubuntu dev environment, replicable
across machines with one command. Managed with [GNU Stow](https://www.gnu.org/software/stow/).

```sh
git clone <this-repo> ~/Projects/furn-config
cd ~/Projects/furn-config
./bootstrap.sh              # workstation (GUI) — the default
./bootstrap.sh --headless   # server (SSH-only) — see below
```

Then open a new terminal (or `exec zsh`).

## Profiles

Two machine roles, chosen by an explicit flag:

- **workstation** (default) — a GUI desktop/laptop. Installs everything.
- **headless** (`--headless`) — a server you only reach over SSH. Skips the pieces
  that need a local display or physical keyboard: **kitty**, the **Nerd Font**,
  **keyd**, **wl-clipboard**, and **commit-signing enrollment**. zsh/tmux/vim/git/Claude
  are otherwise identical, bar two generated server-only overrides (`~/.tmux.local.conf`,
  `~/.zshrc.local`): tmux prefix → `C-b` (its tmux nests inside the workstation's
  `C-Space` tmux over SSH), and an `XDG_RUNTIME_DIR` export so `systemctl --user`
  works in reattached-tmux shells.

## What you get

| Tool | Highlights |
|------|-----------|
| **zsh** | login shell, vi-mode, autosuggestions + syntax-highlighting (pinned, no framework), git-aware prompt, auto-attaches tmux |
| **tmux** | prefix `C-Space` (`C-b` headless — nested tmux), vi copy-mode, `\|`/`-` splits, TPM (sensible, yank, vim-tmux-navigator), gruvbox status |
| **vim** | stock vim, zero plugins (except vim-tmux-navigator), gruvbox, sane defaults |
| **kitty** _(workstation)_ | JetBrainsMono Nerd Font, gruvbox dark (hard), minimal (tmux multiplexes) |
| **keyd** _(workstation)_ | Caps Lock → Esc, universal (Wayland/X11/TTY) |
| **git/gh** | merge-pull (`git pr` rebases), curated aliases; SSH auth + SSH commit signing _(workstation)_ |
| **Claude Code** | manifest-driven multi-account (`claude`, `cc`, …) with shared tracked `settings.json` + global `CLAUDE.md` (secrets excluded) |

Theme is **gruvbox dark (hard contrast)** across kitty, tmux, and vim.

## Layout

```
bootstrap.sh        # apt + keyd-from-source + fonts + stow + chsh + TPM
stow/               # user configs, symlinked into $HOME by stow
system/keyd/        # root-owned config, copied to /etc by bootstrap (sudo)
test/               # repo guards (run ./test/<name>.sh)
CONTEXT.md          # glossary
```

## Tests

`./test/writes-stay-in-home.sh` — a static guard that every tracked shell script
only creates/modifies files under `$HOME`. It scans for filesystem writes
(redirections, `cp`/`mv`/`ln`/`install`/`mkdir`/`rm`/`tee`/`sed -i`/…) whose
target is a hard-coded absolute path, and fails on any not in a small reviewed
allowlist. The **one** sanctioned out-of-`$HOME` write is keyd's `/etc/keyd`
config (sudo, workstation only); adding another means editing `ALLOW` in the
script — a deliberate, visible exception. It does *not* police system operations
that aren't file writes (apt, `chsh`, `systemctl`), which are legitimate
bootstrap steps behind `sudo`. Run `--selftest` to check the checker itself.

## Claude accounts

Every Claude Code account is an explicit config dir `~/.claude-<name>` (state
file `.claude.json` inside it) — no account uses the default `~/.claude`, so
no tool ever has to special-case "the default account". The manifest
`~/.config/claude/accounts` (tracked) maps command names to accounts:

```
claude sebbe
cc sebastian
```

Each command is a symlink in `~/.local/claude-bin` to the `claude-account`
dispatcher, which sets `CLAUDE_CONFIG_DIR` from the manifest and execs the
real binary. The wrapper dir sits *ahead* of `~/.local/bin` on PATH because
the Claude updater owns `~/.local/bin/claude` and rewrites it on every update.

All accounts share the tracked `settings.json` and `CLAUDE.md`, symlinked
into each account dir by `bootstrap.sh`; per-account divergence is
unsupported by design. Tools that resolve the account themselves (like
`overnight --account <name>`) bypass the wrappers.

**Adding an account:** add a line to the manifest, re-run `./bootstrap.sh`,
run the new command once and `/login`.

## Parallel work: one worktree per effort

Every parallel effort gets its own manually-created git worktree; every tool —
`claude`, wayfinder sessions, `overnight` — runs plainly inside it with no
tool-level isolation (no `claude --worktree`). The cwd *is* the isolation;
the global CLAUDE.md tells agents never to create or enter worktrees themselves.

```sh
cd ~/Code/<repo>          # any checkout of the repo
wt-new my-effort          # creates the tree AND cds into it (~/Code/worktrees/<repo>/my-effort)
claude                    # or: overnight --account <name> <issues>
...                       # merge the branch when done
wt-done my-effort         # removes worktree + branch
```

- **`wt-new <name>`** creates the worktree (reusing branch `<name>` if it
  exists), copies the main checkout's untracked `.env*` files, runs
  `npm install` when there's a `package.json`, and runs the repo's executable
  `.wt-setup` (passed the main checkout path as `$1`) if present — so
  repo-specific setup lives in each repo and `wt-new` stays repo-agnostic. The
  script prints the worktree path on stdout (all else goes to stderr); a `wt-new`
  shell function in `.zshrc` wraps it to `cd` you into the new tree.
- **`wt-done <name>`** removes the worktree and deletes the branch, refusing
  while the tracked tree is dirty or the branch is unmerged into the default
  branch.

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
