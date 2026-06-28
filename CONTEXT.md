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

**Replication**:
The act of reproducing this environment on another Ubuntu machine via
`git clone … && ./bootstrap.sh`. The repo is the single source of truth.
_Avoid_: sync, deploy
