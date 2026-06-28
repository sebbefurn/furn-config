# tmux uses TPM; vim gets one deliberate plugin (navigator)

tmux manages plugins with **TPM** and a curated set: `tmux-sensible` (sane
defaults), `tmux-yank` (system-clipboard yank, wired to `wl-copy` on Wayland), and
`vim-tmux-navigator` (seamless `Ctrl-h/j/k/l` movement across vim splits and tmux
panes). `bootstrap.sh` installs TPM and runs its non-interactive installer.

## The exception worth recording
Vim is otherwise **zero-plugin** (see the lean-vim decision), but we make exactly
one exception: the Vim half of `vim-tmux-navigator`. It is required for the
cross-boundary navigation to work in both directions — the tmux plugin alone only
covers the tmux side. We judged seamless "vim and tmux feel like one editor"
navigation worth introducing a single plugin (and a minimal plugin-load mechanism)
into an otherwise pure `.vimrc`.

We rejected session-persistence plugins (resurrect/continuum) — tmux sessions here
are ephemeral around Claude Code runs — and theme plugins (styling is done inline).

## Consequences
- Vim is no longer strictly zero-plugin; it now needs the navigator plugin present,
  fetched at bootstrap. Keep the count at one unless a future need clears the same bar.
- TPM plugins should be pinned (by commit) for reproducibility; TPM doesn't pin by default.
- `Ctrl-h/j/k/l` are consumed by the navigator, so they're unavailable for other maps.
