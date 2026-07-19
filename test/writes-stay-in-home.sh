#!/usr/bin/env bash
# writes-stay-in-home.sh — guard that this repo's scripts only create/modify
# files under $HOME. Run it from anywhere in the repo:  ./test/writes-stay-in-home.sh
#
# WHAT IT CHECKS (static, no execution)
#   Every tracked shell script is scanned for filesystem-write operations —
#   redirections (`>`, `>>`, `tee`) and the file-mutating commands
#   cp/mv/ln/install/mkdir/rmdir/rm/touch/unzip/sed -i/truncate/dd/stow — whose
#   target is an ABSOLUTE path outside $HOME. Any such target that is not in the
#   ALLOW list below fails the test.
#
#   Writes under $HOME/~ or to a $VAR/relative path are fine (the common case).
#   Expansions ($VAR, ${..}, $(..), `..`, ~) are blanked before matching, so only
#   hard-coded absolute literals like `/etc/foo` can trip the check.
#
# WHAT IT DOES NOT CHECK
#   System *operations* that aren't file writes — apt-get, chsh, systemctl,
#   update-alternatives, gsettings — are legitimate parts of a machine bootstrap
#   and live behind `sudo`/documented steps in bootstrap.sh. This guard is about
#   files landing outside your home, not about a bootstrap touching system state.
#
# ALLOW — the reviewed set of sanctioned out-of-$HOME write targets. Adding an
# entry is a conscious decision: it means "yes, this script is meant to write
# there." Keep it minimal.
#   /etc/keyd  — sudo-installed keyd config (workstation only; see bootstrap.sh)
#   /dev/*     — null/std streams etc.; never a real file
#   /tmp       — scratch
ALLOW=(/etc/keyd /dev/null /dev/stdout /dev/stderr /dev/stdin /dev/tty /dev/fd /tmp)

set -euo pipefail

# --- blank shell expansions so only literal absolute paths remain ------------
# Replaces single-quoted strings, $(..) `..` ${..} $VAR and ~ with a
# non-boundary marker (X), so that "$REPO_DIR/system" becomes "X/system" (not an
# absolute literal) and a sed regex like '/foo/d' stops looking like a path,
# while a bare or double-quoted /etc/keyd is left intact.
# Blind spot (accepted): an absolute write target wrapped in SINGLE quotes is
# blanked too, so it wouldn't be checked — real writes here are bare or
# double-quoted, which are fully covered.
blank_expansions() {
  sed -E -e 's/'\''[^'\'']*'\''/X/g' -e '
    s/\$\([^)]*\)/X/g
    s/`[^`]*`/X/g
    s/\$\{[^}]*\}/X/g
    s/\$[A-Za-z_][A-Za-z0-9_]*/X/g
    s/~/X/g
  '
}

# Write-capable commands (file-mutating). Read-only tools (grep, cat, git -C,
# command -v, [ -d ]) are deliberately absent.
WRITE_CMDS='cp|mv|ln|install|mkdir|rmdir|rm|touch|tee|unzip|sed|truncate|dd|stow'

is_allowed() {  # $1 = absolute path literal
  local p="$1" a
  for a in "${ALLOW[@]}"; do
    [[ "$p" == "$a" || "$p" == "$a"/* ]] && return 0
  done
  return 1
}

# scan_stream <label> — read a script on stdin, print `label:line: target` for
# each disallowed absolute write target. Returns 1 if any were found.
scan_stream() {
  local label="$1" line n=0 heredoc="" trimmed blanked found=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))

    # Inside a heredoc body: skip until the closing delimiter (ltrimmed).
    if [[ -n "$heredoc" ]]; then
      trimmed="${line#"${line%%[![:space:]]*}"}"
      [[ "$trimmed" == "$heredoc" ]] && heredoc=""
      continue
    fi
    # Opening a heredoc (`<<EOF`, `<<-'EOF'`, …) but not a `<<<` here-string.
    if [[ "$line" != *'<<<'* && "$line" =~ \<\<-?[[:space:]]*[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]? ]]; then
      heredoc="${BASH_REMATCH[1]}"   # still scan this opener line below
    fi
    # Full-line comments carry no writes.
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    blanked="$(printf '%s' "$line" | blank_expansions)"

    # Is this line a write operation?
    #   (a) redirection whose target begins with '/'  (not >&, not 2>&1)
    #   (b) a file-mutating command in command position (optionally via sudo/env)
    local re_redir='(^|[^<>&0-9])>>?[[:space:]]*("|'\'')?/'
    local re_wcmd='(^|[[:space:]])(sudo[[:space:]]+|env[[:space:]]+)?('"$WRITE_CMDS"')([[:space:]]|$)'
    [[ "$blanked" =~ $re_redir || "$blanked" =~ $re_wcmd ]] || continue

    # Pull every absolute-path literal (boundary-anchored) off the line.
    local path
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      path="${path#"${path%%/*}"}"          # drop the leading boundary char
      is_allowed "$path" && continue
      printf '%s:%d: writes to %s (outside $HOME, not in ALLOW)\n' "$label" "$n" "$path"
      printf '        %s\n' "$line"
      found=1
    done < <(printf '%s\n' "$blanked" | grep -oE "(^|[[:space:]\"'=(>])/[A-Za-z0-9._+/-]*" || true)
  done
  return $((found ? 1 : 0))
}

is_shell() {  # $1 = path; true if it's a shell script we should scan
  case "$1" in
    *.sh|*.bash|*.zsh) return 0 ;;
    */.zshrc|.zshrc|*/.bashrc|.bashrc|*/.profile|.profile) return 0 ;;
  esac
  # else sniff the shebang
  IFS= read -r first < "$1" 2>/dev/null || return 1
  [[ "$first" =~ ^#!.*(bash|[[:space:]/]sh|zsh) ]]
}

# --- selftest: prove the checker actually catches violations -----------------
if [[ "${1:-}" == "--selftest" ]]; then
  bad='echo hi > /etc/motd
cp foo /usr/local/bin/bar
sudo tee /etc/hosts <<EOF
ignored body line writing to /etc/should-not-flag
EOF'
  good='echo hi > "$HOME/.foo"
cmd >/dev/null 2>&1
mkdir -p ~/.cache/zsh
sudo install -Dm644 "$REPO_DIR/x" /etc/keyd/default.conf
[ -d "/run/user/$(id -u)" ] && export XDG_RUNTIME_DIR="/run/user/$(id -u)"
git -C /some/repo status'
  nbad=$(scan_stream selftest <<<"$bad" | grep -c 'writes to' || true)
  ngood=$(scan_stream selftest <<<"$good" | grep -c 'writes to' || true)
  fail=0
  # 3 bad writes (/etc/motd, /usr/local/bin/bar, /etc/hosts); the heredoc body
  # line is correctly skipped — so 3, not 4, also proves heredoc skipping works.
  [[ "$nbad" -eq 3 ]] || { echo "SELFTEST FAIL: expected 3 bad hits, got $nbad"; scan_stream selftest <<<"$bad"; fail=1; }
  [[ "$ngood" -eq 0 ]] || { echo "SELFTEST FAIL: expected 0 good hits, got $ngood"; scan_stream selftest <<<"$good"; fail=1; }
  [[ $fail -eq 0 ]] && echo "selftest OK (bad=$nbad good=$ngood)"
  exit $fail
fi

# --- main --------------------------------------------------------------------
# Resolve this script's own path so we can skip it: its selftest fixtures
# deliberately contain writes to /etc/… and it makes no filesystem writes itself.
self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
cd "$(git rev-parse --show-toplevel)"
rc=0 scanned=0
while IFS= read -r f; do
  is_shell "$f" || continue
  [[ "$(pwd)/$f" == "$self" ]] && continue
  scanned=$((scanned + 1))
  scan_stream "$f" < "$f" || rc=1
done < <(git ls-files)

if [[ $rc -eq 0 ]]; then
  echo "OK — $scanned scripts scanned; all filesystem writes stay under \$HOME (allowlist: ${ALLOW[*]})"
else
  echo
  echo "FAIL — a script writes to an absolute path outside \$HOME that isn't in ALLOW."
  echo "Fix the write to target \$HOME, or add a reviewed entry to ALLOW in $0."
fi
exit $rc
