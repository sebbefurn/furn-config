#!/usr/bin/env python3
"""
queue.py — the state machine for a dream campaign.

Campaign-agnostic: everything campaign-specific (topics, target repo, accounts,
default interval) lives in ~/.config/dream/campaigns/<name>/ (stowed from
furn-config); everything mutable lives in ~/.local/state/dream/<name>/. One JSON
file, queue.json, is the whole campaign state: the topics in drain order, each
carrying its lifecycle (pending → running → done) plus the account it ran under
and the artifact it produced. All writes are atomic (temp + os.replace) so a
crash mid-write never corrupts the queue.

Subcommands (invoked by the `dream` CLI; first argument is the campaign name):

  seed                 Build queue.json from the campaign's topics.json if it
                       does not exist. Idempotent: an existing queue is left
                       untouched so a re-run never clobbers progress. The drain
                       order is a WEIGHTED round-robin across families: a family
                       with weight N contributes up to N topics per round, so
                       priority families drain proportionally faster while every
                       family still gets sampled early.
  gate                 Decide whether THIS fire should run a dream: fires are
                       gated on wall-clock elapsed since the last dream STARTED
                       being >= the configured interval (minus 5 min of timer
                       jitter slack). The interval is a mutable state setting
                       (`interval` subcommand), default from campaign.json — so
                       changing cadence never touches systemd.
  interval [HOURS]     Print (no arg) or set (arg) the interval in whole hours.
  status               Print campaign progress (counts by status + per account).
  peek [--account A]   Same shape as select, but claims nothing.
  select [--account A] Claim the next pending topic: assign the account (forced
                       via --account, else strict alternation over the campaign's
                       account list, parity recomputed from committed state so it
                       is deterministic and reboot-safe), mark it running, print
                       its JSON. Prints {"drained": true} when nothing is pending.
  finalize IDX EXIT    Close topic IDX: read its <NNN>.result.json (written by
                       the dream into the target's scratch dir), record
                       status/artifact/finds/exit, print a summary (incl.
                       all_done) for the Discord ping.

This file is pure state + clock; it never launches claude and never touches the
target repo beyond reading result.json. The `dream` CLI is the only caller.
"""

import json
import os
import sys
import uuid
from datetime import datetime

GATE_SLACK_S = 300  # timer jitter slack: RandomizedDelaySec + scheduling drift


def _now_iso():
    return datetime.now().astimezone().isoformat(timespec="seconds")


def _atomic_write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w") as f:
        json.dump(obj, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)


class Campaign:
    def __init__(self, name):
        self.name = name
        home = os.path.expanduser("~")
        self.config_dir = os.path.join(home, ".config", "dream", "campaigns", name)
        self.state_dir = os.path.join(home, ".local", "state", "dream", name)
        self.queue_json = os.path.join(self.state_dir, "queue.json")
        self.settings_json = os.path.join(self.state_dir, "settings.json")
        with open(os.path.join(self.config_dir, "campaign.json")) as f:
            self.config = json.load(f)
        self.target = os.path.expanduser(
            os.environ.get("DREAM_TARGET", self.config["target"])
        )
        self.scratch_dreams = os.path.join(self.target, self.config["scratch_dir"])

    def topics_catalog(self):
        with open(os.path.join(self.config_dir, "topics.json")) as f:
            return json.load(f)

    def family_name(self, letter):
        return self.topics_catalog()["families"][letter]["name"]

    def load_queue(self):
        with open(self.queue_json) as f:
            return json.load(f)

    def settings(self):
        try:
            with open(self.settings_json) as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def interval_hours(self):
        return int(
            self.settings().get("interval_hours", self.config["default_interval_hours"])
        )


def _interleave_weighted(topics, families):
    """Weighted round-robin: each round, family F contributes up to weight(F)
    topics, in catalog order. Weight-2 families drain about twice as fast while
    every family is still sampled from the first rounds."""
    buckets = {}
    order = []
    for t in topics:
        fam = t["family"]
        if fam not in buckets:
            buckets[fam] = []
            order.append(fam)
        buckets[fam].append(t)
    out = []
    while any(buckets[f] for f in order):
        for fam in order:
            take = int(families.get(fam, {}).get("weight", 1))
            for _ in range(take):
                if buckets[fam]:
                    out.append(buckets[fam].pop(0))
    return out


def cmd_seed(c):
    if os.path.exists(c.queue_json):
        print(json.dumps({"seeded": False, "reason": "queue already exists"}))
        return
    catalog = c.topics_catalog()
    ordered = _interleave_weighted(catalog["topics"], catalog["families"])
    topics = []
    for i, t in enumerate(ordered, start=1):
        topics.append(
            {
                "index": i,
                "family": t["family"],
                "slug": t["slug"],
                "title": t["title"],
                "hint": t.get("hint", ""),
                "status": "pending",
                "account": None,
                "session_id": None,
                "started_at": None,
                "finished_at": None,
                "exit": None,
                "artifact_url": None,
                "finds": None,
                "error": None,
            }
        )
    _atomic_write(
        c.queue_json,
        {"campaign": c.name, "created_at": _now_iso(), "topics": topics},
    )
    print(json.dumps({"seeded": True, "count": len(topics)}))


def cmd_gate(c):
    q = c.load_queue()
    interval = c.interval_hours()
    started = [t["started_at"] for t in q["topics"] if t["started_at"]]
    if not started:
        print(json.dumps({"fire": True, "reason": "no dream has run yet", "interval_hours": interval}))
        return
    last = max(datetime.fromisoformat(s) for s in started)
    elapsed = (datetime.now().astimezone() - last).total_seconds()
    fire = elapsed >= interval * 3600 - GATE_SLACK_S
    print(
        json.dumps(
            {
                "fire": fire,
                "interval_hours": interval,
                "last_started": last.isoformat(timespec="seconds"),
                "elapsed_s": int(elapsed),
            }
        )
    )


def cmd_interval(c, value):
    if value is None:
        print(json.dumps({"interval_hours": c.interval_hours()}))
        return
    hours = int(value)
    if hours < 1:
        print("interval must be >= 1 hour", file=sys.stderr)
        sys.exit(2)
    s = c.settings()
    s["interval_hours"] = hours
    _atomic_write(c.settings_json, s)
    print(json.dumps({"interval_hours": hours}))


def _next_account(c, q):
    """Strict alternation over campaign.json's account list; parity is the count
    of already-claimed topics, recomputed from committed state each time —
    deterministic and reboot-safe."""
    accounts = c.config["accounts"]
    n_claimed = sum(1 for t in q["topics"] if t["status"] in ("running", "done"))
    return accounts[n_claimed % len(accounts)]


def _selection_json(c, topic, account, session_id, drained=False):
    return json.dumps(
        {
            "drained": drained,
            "index": topic["index"],
            "nnn": f"{topic['index']:03d}",
            "slug": topic["slug"],
            "title": topic["title"],
            "hint": topic.get("hint", ""),
            "family": topic["family"],
            "family_name": c.family_name(topic["family"]),
            "account": account,
            "session_id": session_id,
        }
    )


def cmd_peek(c, forced_account):
    q = c.load_queue()
    topic = next((t for t in q["topics"] if t["status"] == "pending"), None)
    if topic is None:
        print(json.dumps({"drained": True}))
        return
    account = forced_account or _next_account(c, q)
    print(_selection_json(c, topic, account, "(not claimed)"))


def cmd_select(c, forced_account):
    q = c.load_queue()
    topic = next((t for t in q["topics"] if t["status"] == "pending"), None)
    if topic is None:
        print(json.dumps({"drained": True}))
        return
    account = forced_account or _next_account(c, q)
    topic["status"] = "running"
    topic["account"] = account
    topic["session_id"] = str(uuid.uuid4())
    topic["started_at"] = _now_iso()
    _atomic_write(c.queue_json, q)
    print(_selection_json(c, topic, account, topic["session_id"]))


def cmd_status(c):
    q = c.load_queue()
    topics = q["topics"]
    by_status = {}
    by_account = {}
    for t in topics:
        by_status[t["status"]] = by_status.get(t["status"], 0) + 1
        if t["account"]:
            by_account[t["account"]] = by_account.get(t["account"], 0) + 1
    done = [t for t in topics if t["status"] == "done"]
    print(
        json.dumps(
            {
                "campaign": c.name,
                "total": len(topics),
                "by_status": by_status,
                "by_account": by_account,
                "with_artifact": sum(1 for t in done if t["artifact_url"]),
                "finds": sum(len(t["finds"] or []) for t in done),
                "failed": sum(1 for t in done if t["error"]),
                "interval_hours": c.interval_hours(),
            },
            indent=2,
        )
    )


def cmd_finalize(c, index, exit_code):
    q = c.load_queue()
    topic = next((t for t in q["topics"] if t["index"] == index), None)
    if topic is None:
        print(json.dumps({"error": f"no topic with index {index}"}))
        sys.exit(1)

    result_path = os.path.join(c.scratch_dreams, f"{index:03d}.result.json")
    result = {}
    if os.path.exists(result_path):
        try:
            with open(result_path) as f:
                result = json.load(f)
        except (json.JSONDecodeError, OSError):
            result = {}

    topic["status"] = "done"
    topic["finished_at"] = _now_iso()
    topic["exit"] = exit_code
    topic["artifact_url"] = result.get("artifact_url")
    topic["finds"] = result.get("finds")
    if exit_code != 0 and not result:
        topic["error"] = f"dream exited {exit_code} with no result.json"
    elif not result:
        topic["error"] = "no result.json written by the dream"
    _atomic_write(c.queue_json, q)

    remaining = sum(1 for t in q["topics"] if t["status"] == "pending")
    print(
        json.dumps(
            {
                "index": index,
                "slug": topic["slug"],
                "title": result.get("title", topic["title"]),
                "idea": result.get("idea", ""),
                "better": result.get("better", []),
                "worse": result.get("worse", []),
                "finds": result.get("finds", []),
                "artifact_url": topic["artifact_url"],
                "error": topic["error"],
                "remaining": remaining,
                "all_done": remaining == 0,
            }
        )
    )


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        print(
            "usage: queue.py CAMPAIGN {seed|gate|status|interval [H]|peek|select [--account A]|finalize IDX EXIT}",
            file=sys.stderr,
        )
        sys.exit(2)
    c = Campaign(args[0])
    cmd, rest = args[1], args[2:]

    def forced_account():
        if rest and rest[0] == "--account":
            if len(rest) < 2:
                print("--account needs a value", file=sys.stderr)
                sys.exit(2)
            return rest[1]
        return None

    if cmd == "seed":
        cmd_seed(c)
    elif cmd == "gate":
        cmd_gate(c)
    elif cmd == "interval":
        cmd_interval(c, rest[0] if rest else None)
    elif cmd == "status":
        cmd_status(c)
    elif cmd == "peek":
        cmd_peek(c, forced_account())
    elif cmd == "select":
        cmd_select(c, forced_account())
    elif cmd == "finalize":
        if len(rest) != 2:
            print("usage: queue.py CAMPAIGN finalize IDX EXIT", file=sys.stderr)
            sys.exit(2)
        cmd_finalize(c, int(rest[0]), int(rest[1]))
    else:
        print(f"unknown subcommand: {cmd}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
