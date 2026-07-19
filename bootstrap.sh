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

# ---- Profile selection (explicit, not auto-detected) ----
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
# the Wayland clipboard (wl-clipboard) — all meaningless headless.
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
# Ensure ~/.config/claude is a real dir so stow links its files individually
# (tree-folding would otherwise symlink the whole dir into the repo).
mkdir -p "$HOME/.config/claude"

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
backup_if_real .config/claude/settings.json
backup_if_real .config/claude/CLAUDE.md
backup_if_real .config/claude/accounts

# ---------------------------------------------------------------------------
# kitty is stowed on workstation only; everything else is universal.
log "Stowing packages"
packages=(zsh tmux vim git claude bin)
is_workstation && packages+=(kitty)
for pkg in "${packages[@]}"; do
  stow --dir="$REPO_DIR/stow" --target="$HOME" --restow "$pkg"
done

# ---------------------------------------------------------------------------
# Machine-local overrides (generated, NOT stowed). The stowed .zshrc/.tmux.conf
# each source a ~/.<tool>.local file if present; only headless writes them, so
# nothing server-specific reaches the workstation. Removed on workstation to keep
# re-runs idempotent (e.g. after re-purposing a box).
#   tmux : this server's tmux runs nested inside the workstation's C-Space tmux
#          over SSH, so flip the inner prefix back to C-b to avoid the clash.
#   zsh  : shells not started by pam_systemd (a reattached tmux over SSH) inherit
#          no XDG_RUNTIME_DIR, so `systemctl --user` can't find the user bus.
if is_workstation; then
  rm -f "$HOME/.tmux.local.conf" "$HOME/.zshrc.local"
else
  log "Writing headless machine-local overrides (tmux prefix C-b, systemctl --user env)"
  cat > "$HOME/.tmux.local.conf" <<'EOF'
# Generated by furn-config bootstrap.sh (--headless) — do not edit; re-run to regenerate.
# This tmux runs nested inside the workstation's C-Space tmux over SSH; give the
# inner prefix back to C-b to avoid the nested-prefix clash.
unbind C-Space
set -g prefix C-b
bind C-b send-prefix
EOF
  cat > "$HOME/.zshrc.local" <<'EOF'
# Generated by furn-config bootstrap.sh (--headless) — do not edit; re-run to regenerate.
# Shells not started by pam_systemd (e.g. a reattached tmux over SSH) inherit no
# XDG_RUNTIME_DIR, so `systemctl --user` can't reach the user bus. Point both at
# the running per-uid session.
if [[ -z "$XDG_RUNTIME_DIR" && -d "/run/user/$(id -u)" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi
EOF
fi

# ---------------------------------------------------------------------------
# Claude Code accounts — manifest-driven, symmetric: every account is an
# explicit config dir ~/.claude-<account>; no account uses the default
# ~/.claude. ~/.config/claude/accounts (stowed above) maps command names to
# accounts; each command is a claude-account wrapper symlink in
# ~/.local/claude-bin, which .zshrc puts ahead of the updater-owned
# ~/.local/bin/claude on PATH.
log "Setting up Claude accounts"

# One-time migration of the legacy default-dir layout (~/.claude account state
# + its ~/.claude.json sibling) into the explicit sebbe dir. Two same-
# filesystem renames — logins, history, and sessions all survive. Refuses to
# move live state out from under a running claude; must run before anything
# below creates ~/.claude-sebbe, or this guard would never fire again.
if [ -d "$HOME/.claude" ] && [ ! -d "$HOME/.claude-sebbe" ]; then
  if pgrep -x claude >/dev/null 2>&1; then
    warn "claude is running — exit all Claude sessions, then re-run to migrate ~/.claude -> ~/.claude-sebbe"
    exit 1
  fi
  log "Migrating legacy ~/.claude -> ~/.claude-sebbe"
  mv "$HOME/.claude" "$HOME/.claude-sebbe"
  if [ -f "$HOME/.claude.json" ]; then
    mv "$HOME/.claude.json" "$HOME/.claude-sebbe/.claude.json"
  fi
fi

# The pre-manifest hand-written cc wrapper is superseded by ~/.local/claude-bin/cc.
if [ -f "$HOME/.local/bin/cc" ] && [ ! -L "$HOME/.local/bin/cc" ]; then
  mv "$HOME/.local/bin/cc" "$HOME/.local/bin/cc.pre-furn-config.bak"
  warn "backed up legacy ~/.local/bin/cc (superseded by ~/.local/claude-bin/cc)"
fi

# Per-account: config dir with the shared settings/CLAUDE.md linked in, plus
# the command wrapper. All accounts share one settings.json by design — a
# /config change in any account lands in the repo working tree, visibly.
mkdir -p "$HOME/.local/claude-bin"
while read -r cmd account _; do
  case "$cmd" in ''|'#'*) continue ;; esac
  dir="$HOME/.claude-$account"
  mkdir -p "$dir"
  for f in settings.json CLAUDE.md; do
    backup_if_real ".claude-$account/$f"
    ln -sfn "$HOME/.config/claude/$f" "$dir/$f"
  done
  if [ -L "$dir/statusline.sh" ]; then
    rm "$dir/statusline.sh"   # superseded by ~/.local/bin/claude-statusline
  fi
  ln -sfn "$HOME/.local/bin/claude-account" "$HOME/.local/claude-bin/$cmd"
  log "account $account: $cmd -> ~/.claude-$account"
done < "$HOME/.config/claude/accounts"

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
# Commit signing enrolls this machine's SSH key as a signing identity in the
# repo. The server doesn't commit, and we don't enroll its key — skip headless.
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
