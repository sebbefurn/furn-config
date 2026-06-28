# ~/.zshrc — managed by furn-config (stow zsh)

# ---- Auto-attach tmux: interactive, not already nested, opt out with NO_TMUX=1 ----
if [[ $- == *i* ]] && [[ -z ${TMUX:-} ]] && [[ -z ${NO_TMUX:-} ]] && command -v tmux >/dev/null; then
  exec tmux new-session -A -s main
fi

# ---- Environment ----
export EDITOR=vim
export VISUAL=vim
export PATH="$HOME/.local/bin:$PATH"

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_VERIFY INC_APPEND_HISTORY

# ---- Shell options ----
setopt AUTO_CD INTERACTIVE_COMMENTS NO_BEEP PROMPT_SUBST

# ---- Completion ----
[[ -d ~/.cache/zsh ]] || mkdir -p ~/.cache/zsh
autoload -Uz compinit && compinit -d ~/.cache/zsh/zcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive

# ---- vi-mode ----
bindkey -v
export KEYTIMEOUT=1                 # snappy mode switching
bindkey '^A' beginning-of-line      # keep a few emacs keys
bindkey '^E' end-of-line
bindkey '^R' history-incremental-search-backward
bindkey '^K' kill-line
bindkey '^?' backward-delete-char
autoload -Uz edit-command-line      # 'v' in normal mode edits the line in $EDITOR
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# ---- vi-mode indicator + git-aware prompt ----
function zle-keymap-select { case $KEYMAP in vicmd) VIMODE='[N]';; *) VIMODE='[I]';; esac; zle reset-prompt }
function zle-line-init { VIMODE='[I]'; zle reset-prompt }
zle -N zle-keymap-select
zle -N zle-line-init
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' %F{yellow}(%b)%f'
precmd() { vcs_info }
# Show user@host only when connected over SSH; locally just the user.
if [[ -n ${SSH_CONNECTION:-} ]]; then PROMPT_HOST='%n@%m'; else PROMPT_HOST='%n'; fi
PROMPT='%F{green}${PROMPT_HOST}%f %F{blue}%~%f${vcs_info_msg_0_} %F{cyan}%#%f '
RPROMPT='%F{245}${VIMODE}%f'

# ---- Aliases ----
alias ls='ls --color=auto'
alias ll='ls -alhF'
alias la='ls -A'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias v=vim
alias c=claude
alias t=tmux
alias ta='tmux attach'
alias tls='tmux ls'
# git
alias g=git
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glg='git lg'

# ---- Plugins (installed pinned by bootstrap.sh) ----
ZSH_PLUGIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
if [[ -f $ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source $ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'
fi
# syntax-highlighting must be sourced LAST
if [[ -f $ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source $ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
