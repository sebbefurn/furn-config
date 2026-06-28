# Selectively track ~/.claude (settings + CLAUDE.md), never its secrets/runtime

`~/.claude` mixes a few durable config files with a lot of secret and runtime
state. We track only `settings.json` and a (new) global `CLAUDE.md`, and treat
everything else as untracked: `.credentials.json` (OAuth tokens — secret),
`projects/`, `sessions/`, `plans/`, `history.jsonl`, `shell-snapshots/`, `cache/`,
`backups/`, `file-history/`, `downloads/`, `session-env/`, and the generated
`plugins/` cache. `settings.json` was verified to contain no secrets (just theme,
marketplace, enabled plugins), and it alone restores the plugin setup on a new box.

## Stow tree-folding trap (the surprising part)
Stow symlinks at the shallowest unique level. If `~/.claude` does **not** already
exist, `stow claude` would symlink the *entire* `~/.claude` directory to the repo —
so Claude's runtime writes (including `.credentials.json`) would land inside the
tracked repo. To prevent this, `bootstrap.sh` must ensure `~/.claude` exists as a
**real directory** before stowing, so Stow folds at the file level and symlinks only
`settings.json` and `CLAUDE.md`.

## Consequences
- `.gitignore` must explicitly exclude the secret/runtime entries above as a backstop.
- Adding a new tracked Claude file = add it to the stow package; everything else
  stays out by default.
- The global `CLAUDE.md` becomes versioned cross-project instruction — review it for
  anything sensitive before committing.
