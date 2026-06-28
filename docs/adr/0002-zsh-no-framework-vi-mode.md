# zsh as login shell, no framework, vi-mode

We use zsh as the login shell, configured by a hand-rolled `.zshrc` with exactly
two plugins — zsh-autosuggestions and zsh-syntax-highlighting — vendored by
pinned `git clone` in `bootstrap.sh` rather than via a framework. The line editor
runs in vi-mode (`bindkey -v`) to match the user's vim preference, with a handful
of emacs keybindings (Ctrl-A/E/R) kept for muscle memory and a prompt mode indicator.

We rejected oh-my-zsh and other frameworks: they add a version to track, slow
startup, and obscure what's actually configured. Two pinned plugins give us the
high-value features (history ghost-text, syntax highlighting) with no framework.

## Consequences
- `bootstrap.sh` must `apt install zsh`, `git clone` the two plugins to a known
  path, and `chsh -s $(which zsh)`.
- Plugin updates are deliberate (re-pin), not automatic.
- vi-mode pairs with the Caps Lock → Esc remap (see later ADR).
