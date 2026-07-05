# Machine profiles (workstation vs headless) via an explicit --headless flag

`bootstrap.sh` supports two **profiles**: **workstation** (the default — a
GUI desktop/laptop with a local display, like the primary machine) and
**headless** (a server reached only over SSH, like the production box). The same
repo and same `bootstrap.sh` run both; headless runs a strict **subset**.

The profile is chosen by an **explicit flag** — `./bootstrap.sh` for workstation,
`./bootstrap.sh --headless` for the server — not auto-detected from the
environment. We rejected sniffing `$XDG_CURRENT_DESKTOP` / Wayland sockets / an
X display for the same reason ADR-0003 rejected `setxkbmap`: a silent heuristic
that guesses wrong (a server with X libs installed, an X-forwarded SSH session)
is worse than a deliberate, versioned input. The machine's role is config-as-code,
declared at the one moment we run bootstrap.

## What headless skips, and why each is *meaningless* there (not merely "smaller")

The GUI/CLI line isn't about disk footprint — every skipped piece operates on a
display or physical device the headless box **does not have**, because you reach
it over SSH:

- **kitty** (config, stow package, and the default-terminal dance —
  `update-alternatives` + the GNOME gsettings keybinding of ADR-0007): terminal
  emulation is the SSH **client's** job; the server renders nothing.
- **Nerd Font** (JetBrainsMono): glyphs are drawn by the **client** terminal. A
  font installed on the server is invisible over SSH.
- **keyd (Caps→Esc, ADR-0003)**: keyd remaps the **physical keyboard of the host
  it runs on**. Over SSH the remap already happened on the workstation; the server
  has no keyboard you type on. Meaningless, not just optional.
- **wl-clipboard + the tmux-yank→`wl-copy` wiring (ADR-0004)**: Wayland, so a no-op
  headless — and system-clipboard-over-SSH would need OSC52 regardless. Accepted
  tradeoff: **no system-clipboard integration on the server** for now.
- **git commit signing + `allowed_signers` enrollment (ADR-0005)**: the server
  doesn't commit, and we deliberately do **not** enroll the production server's SSH
  key as a commit-signing identity in this repo. Plain git config (aliases,
  rebase-pull) still applies; only the signing/enrollment half is skipped.

Consequently the **apt list splits**: headless installs
`zsh tmux vim git stow curl ncurses-term`; workstation additionally installs
`fontconfig unzip build-essential wl-clipboard` (present only for font, the keyd
source build, and clipboard).

## Universal (both profiles)
zsh + the two pinned plugins, tmux + TPM (minus the clipboard wiring), vim +
vim-tmux-navigator, git config, Claude Code, `chsh` to zsh, and the `.zshrc`
tmux auto-attach — which is *more* valuable headless, since tmux sessions then
survive an SSH disconnect.

## Consequences
- `bootstrap.sh` gains a `PROFILE` notion (default `workstation`, set to `headless`
  by `--headless`); GUI steps and the workstation-only apt packages are guarded by
  it, and the stow loop drops `kitty` on headless.
- This **amends** ADR-0003 (keyd), ADR-0005 (SSH signing), and ADR-0007 (kitty
  default terminal): each now runs on workstation only. Their reasoning is
  unchanged where they *do* run.
- The split is by profile, not by host — adding a second workstation or a second
  server needs no new code, just the right flag. Per-host divergence beyond these
  two roles is still unhandled (see ADR-0001) and would want a heavier mechanism.
- Docs that still say "Ubuntu-only" (README) should read "Debian/Ubuntu,
  workstation or headless."
