# furn-config

Personal dotfiles for replicating a terminal-centric Ubuntu development
environment (kitty, tmux, vim, git/gh, Claude Code) across machines.

## Language

**Stow package**:
A single folder under `stow/` (one per application) whose internal directory
tree mirrors `$HOME`. Running `stow <name>` symlinks its contents into `$HOME`.
_Avoid_: module, bundle, dotfile group

**bootstrap.sh**:
The single entry point run on a fresh machine. Installs system packages via apt
and symlinks every Stow package into place. Idempotent — safe to re-run.
_Avoid_: install.sh, setup script

**System config**:
Config that targets `/etc` (root-owned) rather than `$HOME`. Lives under
`system/` and is *copied* with sudo by `bootstrap.sh` — not stowed. keyd is the
only such piece so far.
_Avoid_: root config, etc files

**Profile**:
The machine role bootstrap targets, chosen by an explicit flag: **workstation**
(default) or **headless**. Selects which subset of packages and steps run. Passed
as `--headless`; absence means workstation.
_Avoid_: mode, environment, target, machine type

**Workstation**:
The full GUI profile — a desktop/laptop with a display (this machine). Gets
everything: kitty, Nerd Font, keyd, clipboard integration, commit signing. The
default when `bootstrap.sh` runs with no flag.
_Avoid_: desktop, GUI box, full install

**Headless**:
The CLI/server profile — a machine reached only over SSH, with no local display
(the production server). Skips everything GUI- or hardware-bound: kitty, Nerd Font,
keyd, wl-clipboard, and commit-signing enrollment. Runs zsh/tmux/vim/git/Claude.
_Avoid_: server, CLI mode, minimal, remote

**Replication**:
The act of reproducing this environment on another Debian/Ubuntu machine via
`git clone … && ./bootstrap.sh [--headless]`. The repo is the single source of
truth; the profile flag picks workstation vs headless.
_Avoid_: sync, deploy
