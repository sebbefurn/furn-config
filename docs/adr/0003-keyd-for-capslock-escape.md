# keyd for Caps Lock → Esc (universal remap)

We remap Caps Lock to Escape using **keyd**, a system daemon that rewrites keys
at the libinput/evdev layer — below XKB and below the display server. We chose it
over the GNOME-native `gsettings caps:escape` and the `/etc/default/keyboard`
(XKBOPTIONS) approach because only keyd is **universal**: it works on Wayland, X11,
every TTY, the GDM login screen, and any desktop/WM, with no log-out/log-in step.
The remap also becomes versioned config-as-code (`/etc/keyd/default.conf`) rather
than an opaque dconf key, which fits a dotfiles repo.

## Context that forced this
The machine is GNOME **Wayland** on Ubuntu 24.04. The commonly-Googled answers —
`setxkbmap` and `xmodmap` — are X11-only and silently do nothing on Wayland.

## Install path
keyd is **not** packaged in Ubuntu 24.04 (noble) repos, so `bootstrap.sh` builds
it from a **pinned git tag** (`make && sudo make install`; needs `build-essential`),
installs the tracked config to `/etc/keyd/default.conf`, then
`systemctl enable --now keyd`. Live immediately; reloadable with `keyd reload`.

## Consequences
- Requires root for install + a running systemd service (the one privileged piece
  of an otherwise user-level setup).
- keyd config lives **outside** `stow/` (it targets `/etc`, not `$HOME`) — see the
  repo-layout split into `stow/` (user, symlinked) vs `system/` (root, copied).
- Pinned source build means keyd upgrades are deliberate, not automatic.
