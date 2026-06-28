# Use GNU Stow + bootstrap.sh for dotfile replication

We manage dotfiles as per-application **Stow packages** under `stow/`, where each
package mirrors the `$HOME` layout (e.g. `stow/kitty/.config/kitty/kitty.conf`).
A top-level `bootstrap.sh` installs apt packages and runs `stow` to symlink each
package into `$HOME`. Replicating onto a new Ubuntu machine is `git clone … && ./bootstrap.sh`.

We chose this over a bare `$HOME` git repo (clever but a footgun for the unwary),
a hand-rolled `install.sh` symlink loop (we'd re-implement what Stow already does
well), and chezmoi (templating/secret machinery we don't need for an Ubuntu-only,
single-user setup). Stow keeps each tool's config self-contained and transparent —
adding or removing a tool is one folder and one `stow`/`stow -D`.

## Consequences
- `stow` becomes a hard dependency and must be installed early in `bootstrap.sh`.
- Files must live at their real `$HOME`-relative path inside each package folder.
- Machine-specific differences (if they ever arise) aren't handled by templating;
  we'd solve them with conditionals in `bootstrap.sh` or per-host packages.
