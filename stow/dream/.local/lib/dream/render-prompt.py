#!/usr/bin/env python3
"""
render-prompt.py — substitute {{PLACEHOLDER}}s in the dream prompt template.

Deliberately not sed: topic titles and family names carry `&`, `/` and `|`
(e.g. "Standing queries, triage & candidate ranking", "Weak supervision /
programmatic labeling"). In a sed replacement `&` means "the whole match", so
sed silently re-inserted the placeholder instead of the value. This does plain
literal string replacement, which has no metacharacter hazard at all.

Usage:
  render-prompt.py <template> KEY=VALUE [KEY=VALUE …]   # renders to stdout
"""

import sys


def main():
    if len(sys.argv) < 2:
        print("usage: render-prompt.py <template> KEY=VALUE …", file=sys.stderr)
        sys.exit(2)
    text = open(sys.argv[1]).read()
    for arg in sys.argv[2:]:
        key, _, value = arg.partition("=")
        text = text.replace("{{" + key + "}}", value)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
