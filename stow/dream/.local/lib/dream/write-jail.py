#!/usr/bin/env python3
"""
write-jail.py — the PreToolUse guardrail for dream runs.

A dream runs `claude -p --dangerously-skip-permissions` (headless, no human to
approve prompts) so it can work autonomously. This hook is the thing that keeps
that autonomy safe on prod: it is the ONLY write authority the dream has, and it
permits exactly one writable surface — $DREAM_WRITE_ROOT/** — refusing every
file write and every mutating shell verb outside it.

Layers of protection (this hook is defense-in-depth, not the only line):
  • Hard, precise: Write/Edit/MultiEdit/NotebookEdit are denied unless their
    target path resolves under the write root.
  • Bash: a denylist of clearly-mutating verbs (git writes, systemctl changes,
    rm/mv/cp/dd/truncate, in-place editors, redirection/tee outside the jail,
    sqlite3, mutating `npm run` scripts, tsx/node execution of repo scripts,
    file-writing curl/wget). Read verbs and `npm run db:query` pass.
  • Independent of this hook (halvex campaign): monitor.db is opened read-only
    in agent context (db-query.ts, issue #509), so even a Bash path this
    denylist missed cannot mutate the database.

Fail-closed: unparseable input, a gated tool whose target can't be resolved, or
a missing DREAM_WRITE_ROOT is denied — a dream that can't prove it's writing
inside the jail doesn't write.

Wired via the `dream` CLI's --settings for the matcher
"Write|Edit|MultiEdit|NotebookEdit|Bash". Reads the PreToolUse event JSON on
stdin; emits a deny decision or stays silent (letting skip-permissions allow).
Environment (exported by the CLI): DREAM_WRITE_ROOT (absolute jail root),
DREAM_TARGET (the target repo root, for resolving relative paths — the dream's
cwd).
"""

import json
import os
import re
import sys

TARGET = os.environ.get("DREAM_TARGET", "")
WRITE_ROOT = os.environ.get("DREAM_WRITE_ROOT", "")


def deny(reason):
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": f"[dream write-jail] {reason}",
                }
            }
        )
    )
    sys.exit(0)


def allow():
    # Silent: with --dangerously-skip-permissions in force, no decision == allow.
    sys.exit(0)


def under_write_root(path):
    """True if path (relative paths resolved against the target repo root, the
    dream's cwd) is inside the write root."""
    if not path or not WRITE_ROOT:
        return False
    p = path if os.path.isabs(path) else os.path.join(TARGET or "/", path)
    p = os.path.abspath(p)
    root = os.path.abspath(WRITE_ROOT)
    return p == root or p.startswith(root + os.sep)


# --- Bash denylist ---------------------------------------------------------

# Mutating / destructive verbs that are refused outright.
_BASH_DENY = [
    (r"\bgit\s+(commit|push|add|rm|reset|checkout|switch|merge|rebase|tag|stash|"
     r"clean|apply|restore|cherry-pick|revert|update-ref|pull|fetch|worktree)\b",
     "git write/branch operations are not allowed"),
    (r"\bsystemctl\s+(start|stop|restart|enable|disable|reload|daemon-reload|kill|mask|unmask)\b",
     "systemctl state changes are not allowed"),
    (r"\bloginctl\s+(enable-linger|disable-linger|terminate|kill)\b",
     "loginctl state changes are not allowed"),
    (r"(^|[\s;&|])(rm|rmdir|unlink|shred|srm|truncate|dd|mkfs|shutdown|reboot|poweroff)\b",
     "destructive filesystem/host commands are not allowed"),
    (r"(^|[\s;&|])(mv|cp|install|chmod|chown|chgrp|chattr)\b",
     "file move/copy/permission commands are not allowed (use the Write tool into the scratch jail)"),
    (r"\b(sed|perl|gawk|awk)\s+-i\b", "in-place file editing is not allowed"),
    (r"(^|[\s;&|])sqlite3\b",
     "direct sqlite3 is not allowed; use `npm run db:query` (read-only in agent context)"),
    (r"\bnpm\s+run\s+(db:apply|db:migrate|deploy|deploy:code|deploy:logo|schema:generate|"
     r"metrics:generate|docs:generate|schema:fingerprint|sync-issuers|sync-batch-queue|"
     r"batch|ingest|verify|backfill|record-coverage|record-centrality|renormalize-artifacts|"
     r"enrich-sec-metadata|enrich-identifiers|onboard-registry-pull|restate-splits|"
     r"columnar:backfill|columnar:compact|update-prices|tweet|evidence:backfill-claims|"
     r"evidence:signoff|automation:register|automation:start|automation:stop|automation:restart)\b",
     "mutating npm scripts are not allowed"),
    (r"\b(npx\s+tsx|tsx|node)\s+\S*scripts/(?!ops/db-query|ops/status|ops/issuer-state)",
     "executing repo scripts is not allowed except read-only db-query/status/issuer-state"),
    (r"\bwget\b", "wget is not allowed (use the WebFetch tool for research)"),
    (r"\bcurl\b[^\n]*\s-[oO]\b", "curl writing to a file is not allowed"),
]


def check_bash(command):
    if not command:
        deny("empty Bash command could not be inspected")
    for pattern, reason in _BASH_DENY:
        if re.search(pattern, command, re.IGNORECASE):
            deny(reason)
    # Redirections / tee must target the write root (or /dev/null).
    for m in re.finditer(r"(?:>>?|\btee\b(?:\s+-a)?)\s+(\"?)([^\s\"';|&<>]+)", command):
        target = m.group(2)
        if target == "/dev/null" or target.startswith("/dev/std"):
            continue
        if not under_write_root(target):
            deny(f"redirection/tee target outside the write jail: {target}")
    allow()


def main():
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        deny("could not parse the PreToolUse event")
        return

    if not WRITE_ROOT:
        deny("DREAM_WRITE_ROOT is not set — refusing all writes")
        return

    tool = event.get("tool_name", "")
    ti = event.get("tool_input", {}) or {}

    if tool in ("Write", "Edit"):
        if not under_write_root(ti.get("file_path")):
            deny(f"write outside the jail: {ti.get('file_path')!r}")
        allow()
    elif tool == "MultiEdit":
        if not under_write_root(ti.get("file_path")):
            deny(f"write outside the jail: {ti.get('file_path')!r}")
        allow()
    elif tool == "NotebookEdit":
        if not under_write_root(ti.get("notebook_path") or ti.get("file_path")):
            deny(f"notebook write outside the jail: {ti.get('notebook_path')!r}")
        allow()
    elif tool == "Bash":
        check_bash(ti.get("command", ""))
    else:
        # Not gated by this hook's matcher; let it through.
        allow()


if __name__ == "__main__":
    main()
