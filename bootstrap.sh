#!/usr/bin/env bash
# bootstrap.sh — set up an Ubuntu machine from furn-config. Idempotent: safe to re-run.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# ---- Pinned versions (bump deliberately) ----
KEYD_TAG="v2.5.0"
TPM_TAG="v3.1.0"
NERD_FONT_VER="v3.2.1"
ZSH_AUTOSUGGEST_TAG="v0.7.1"
ZSH_SYNTAX_TAG="0.8.0"
VIM_NAVIGATOR_REF="master"          # no stable tags upstream

ZDATA="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

log()  { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m!! \033[0m %s\n' "$*" >&2; }

clone_pinned() {  # url  ref  dest
  if [ ! -d "$3/.git" ]; then
    git clone --depth 1 --branch "$2" "$1" "$3"
  fi
}

# ---------------------------------------------------------------------------
log "Installing apt packages"
sudo apt-get update -qq
sudo apt-get install -y \
  zsh tmux vim git stow curl unzip fontconfig build-essential ncurses-term

# ---------------------------------------------------------------------------
log "Installing keyd (built from pinned source ${KEYD_TAG}) — not in noble repos"
if ! command -v keyd >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  git clone --depth 1 --branch "$KEYD_TAG" https://github.com/rvaiya/keyd "$tmp/keyd"
  make -C "$tmp/keyd"
  sudo make -C "$tmp/keyd" install
  rm -rf "$tmp"
fi
sudo install -Dm644 "$REPO_DIR/system/keyd/default.conf" /etc/keyd/default.conf
sudo systemctl enable --now keyd
sudo keyd reload || true
log "Caps Lock -> Esc active (keyd)"

# ---------------------------------------------------------------------------
log "Installing JetBrainsMono Nerd Font (${NERD_FONT_VER})"
if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
  fontdir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  mkdir -p "$fontdir"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/JBM.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VER}/JetBrainsMono.zip"
  unzip -oq "$tmp/JBM.zip" -d "$fontdir"
  rm -rf "$tmp"
  fc-cache -f >/dev/null
fi

# ---------------------------------------------------------------------------
log "Installing zsh plugins (pinned)"
mkdir -p "$ZDATA"
clone_pinned https://github.com/zsh-users/zsh-autosuggestions    "$ZSH_AUTOSUGGEST_TAG" "$ZDATA/zsh-autosuggestions"
clone_pinned https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_SYNTAX_TAG"     "$ZDATA/zsh-syntax-highlighting"

# ---------------------------------------------------------------------------
log "Installing TPM + vim-tmux-navigator"
clone_pinned https://github.com/tmux-plugins/tpm "$TPM_TAG" "$HOME/.tmux/plugins/tpm"
clone_pinned https://github.com/christoomey/vim-tmux-navigator "$VIM_NAVIGATOR_REF" \
  "$HOME/.vim/pack/plugins/start/vim-tmux-navigator"

# ---------------------------------------------------------------------------
log "Ensuring ~/.claude is a real dir (Stow tree-fold guard — keeps secrets out of the repo)"
mkdir -p "$HOME/.claude"

# ---------------------------------------------------------------------------
log "Backing up conflicting pre-existing files"
backup_if_real() {
  local f="$HOME/$1"
  if [ -e "$f" ] && [ ! -L "$f" ]; then
    mv "$f" "$f.pre-furn-config.bak"
    warn "backed up $f -> $f.pre-furn-config.bak"
  fi
}
backup_if_real .zshrc
backup_if_real .tmux.conf
backup_if_real .vimrc
backup_if_real .gitconfig
backup_if_real .config/kitty/kitty.conf
backup_if_real .claude/settings.json
backup_if_real .claude/CLAUDE.md

# ---------------------------------------------------------------------------
log "Stowing packages"
for pkg in zsh tmux vim kitty git claude; do
  stow --dir="$REPO_DIR/stow" --target="$HOME" --restow "$pkg"
done

# ---------------------------------------------------------------------------
log "Installing tmux plugins via TPM (non-interactive)"
"$HOME/.tmux/plugins/tpm/bin/install_plugins" \
  || warn "TPM install failed — run prefix+I inside tmux to retry"

# ---------------------------------------------------------------------------
log "Setting zsh as the login shell"
if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)" || warn "chsh failed — run: chsh -s $(command -v zsh)"
fi

# ---------------------------------------------------------------------------
log "Configuring git/gh SSH identity"
SSH_KEY="$HOME/.ssh/id_ed25519"
AS_REPO="$REPO_DIR/stow/git/.config/git/allowed_signers"   # edit repo file, not the symlink
if [ -f "$SSH_KEY.pub" ]; then
  pub="$(cut -d' ' -f1,2 < "$SSH_KEY.pub")"
  if ! grep -qF "$pub" "$AS_REPO" 2>/dev/null; then
    sed -i '/REPLACE_WITH_YOUR_PUBLIC_KEY/d' "$AS_REPO"
    printf '%s %s\n' "sebastian.furn@gmail.com" "$pub" >> "$AS_REPO"
    log "Added this machine's public key to allowed_signers (commit it when ready)"
  fi
  command -v gh >/dev/null 2>&1 && gh config set git_protocol ssh || true
else
  warn "No SSH key at $SSH_KEY — finish git auth + signing manually:"
  cat <<EOF
    1) ssh-keygen -t ed25519 -C "sebastian.furn@gmail.com"
    2) gh auth login                # choose GitHub.com -> SSH
    3) gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication
    4) gh ssh-key add ~/.ssh/id_ed25519.pub --type signing
    5) re-run ./bootstrap.sh        # populates allowed_signers
EOF
fi

log "Done. Start a new terminal (or 'exec zsh') for zsh + tmux."
log "Caps Lock = Esc · theme = gruvbox dark · editor = vim"
