#!/usr/bin/env bash
# bootstrap.sh — set up a Debian/Ubuntu machine from furn-config. Idempotent: safe to re-run.
#
# Profiles (see docs/adr/0008):
#   (default)     workstation — GUI desktop/laptop; installs everything.
#   --headless    server reached only over SSH; skips kitty, Nerd Font, keyd,
#                 wl-clipboard, and commit-signing enrollment.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# ---- Profile selection (explicit, not auto-detected — ADR-0008) ----
PROFILE=workstation
for arg in "$@"; do
  case "$arg" in
    --headless)    PROFILE=headless ;;
    --workstation) PROFILE=workstation ;;
    -h|--help)
      cat <<EOF
usage: ./bootstrap.sh [--headless]
  (default)    workstation profile — full GUI setup
  --headless   server profile — no kitty/font/keyd/clipboard/signing
EOF
      exit 0 ;;
    *) printf '!! unknown argument: %s (try --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

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

is_workstation() { [ "$PROFILE" = workstation ]; }

log "Profile: $PROFILE"

# ---------------------------------------------------------------------------
# apt packages: a universal core, plus workstation-only extras that exist only
# for the font (fontconfig/unzip), the keyd source build (build-essential), and
# the Wayland clipboard (wl-clipboard) — all meaningless headless (ADR-0008).
log "Installing apt packages"
sudo apt-get update -qq
sudo apt-get install -y \
  zsh tmux vim git stow curl ncurses-term
if is_workstation; then
  sudo apt-get install -y \
    fontconfig unzip build-essential wl-clipboard
fi

# ---------------------------------------------------------------------------
# keyd remaps the *physical keyboard of the host it runs on*; over SSH your
# Caps->Esc already happened on the workstation, so it's skipped headless.
if is_workstation; then
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
fi

# ---------------------------------------------------------------------------
# Nerd Font glyphs render on the SSH *client's* terminal; a font on the server
# is invisible, so it's skipped headless.
if is_workstation; then
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
fi

# ---------------------------------------------------------------------------
# No local display headless, so no default terminal to set.
if is_workstation; then
  log "Making kitty the default terminal (GNOME-specific, idempotent)"
  KITTY_BIN="$(command -v kitty || true)"
  if [ -n "$KITTY_BIN" ]; then
    # 1) Debian alternative — used by apps that invoke x-terminal-emulator
    sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$KITTY_BIN" 50
    sudo update-alternatives --set x-terminal-emulator "$KITTY_BIN"

    # 2) GNOME Ctrl+Alt+T is hardwired to gnome-terminal and ignores the alternative.
    #    Free the built-in 'terminal' binding, then add a custom shortcut -> kitty.
    if command -v gsettings >/dev/null 2>&1 && [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
      mk=org.gnome.settings-daemon.plugins.media-keys
      path=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kitty/
      base="$mk.custom-keybinding:$path"
      gsettings set "$mk" terminal "@as []" 2>/dev/null || true   # release built-in C-A-t
      current="$(gsettings get "$mk" custom-keybindings 2>/dev/null || echo '@as []')"
      case "$current" in
        *"$path"*)            : ;;                                  # already registered
        "@as []"|"[]")        gsettings set "$mk" custom-keybindings "['$path']" ;;
        *)                    gsettings set "$mk" custom-keybindings "${current%]}, '$path']" ;;
      esac
      gsettings set "$base" name 'kitty'
      gsettings set "$base" command 'kitty --start-as=maximized'
      gsettings set "$base" binding '<Primary><Alt>t'
    fi
  fi
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
is_workstation && backup_if_real .config/kitty/kitty.conf
backup_if_real .claude/settings.json
backup_if_real .claude/CLAUDE.md

# ---------------------------------------------------------------------------
# kitty is stowed on workstation only; everything else is universal.
log "Stowing packages"
packages=(zsh tmux vim git claude)
is_workstation && packages+=(kitty)
for pkg in "${packages[@]}"; do
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
# Commit signing enrolls this machine's SSH key as a signing identity in the repo
# (ADR-0005). The server doesn't commit, and we don't enroll its key — skip headless.
if is_workstation; then
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
fi

log "Done ($PROFILE). Start a new terminal (or 'exec zsh') for zsh + tmux."
if is_workstation; then
  log "Caps Lock = Esc · theme = gruvbox dark (hard) · editor = vim"
else
  log "headless: no kitty/font/keyd/clipboard/signing · theme = gruvbox dark (hard) · editor = vim"
fi
