# Make kitty the default terminal via two layers (GNOME-specific)

`bootstrap.sh` sets kitty as the default terminal in two independent places, because
no single setting covers both:

1. **Debian alternative** — `update-alternatives --set x-terminal-emulator kitty`.
   Covers apps that launch "a terminal" via `x-terminal-emulator` (file managers,
   launchers, scripts).
2. **GNOME `Ctrl+Alt+T`** — on Ubuntu 24.04 / GNOME 46 this is hardwired to
   gnome-terminal and **ignores** the alternative. So we release the built-in
   `media-keys terminal` binding and add a **custom keybinding** that runs `kitty`.

## Why this is recorded
A future reader will reasonably expect "set the default terminal" to be one command,
and will be surprised that `Ctrl+Alt+T` still opens gnome-terminal until the GNOME
custom-keybinding half is also applied. The two-layer split is GNOME's doing, not ours.

## Consequences
- This is the second privileged/system-touching step (alongside keyd): the
  `update-alternatives` half needs sudo; the gsettings half needs a live GNOME session.
- The gsettings half is GNOME-only — on another desktop it's a no-op (guarded by
  `XDG_CURRENT_DESKTOP`), and only the alternative applies.
- Re-running bootstrap is idempotent: it reuses a fixed custom-keybinding path
  (`…/custom-keybindings/kitty/`) rather than `custom0`, so it won't clobber or
  duplicate other custom shortcuts.
