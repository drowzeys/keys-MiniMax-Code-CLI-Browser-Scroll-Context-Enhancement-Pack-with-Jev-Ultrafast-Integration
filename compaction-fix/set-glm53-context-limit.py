#!/usr/bin/env python3
"""Surgically set limit.context for a custom-provider model in ~/.minimax/config.yaml.

Only the one number on the one line inside the target provider/model block is
touched; formatting, comments, and every other value (including API keys) are
preserved byte-for-byte. A timestamped backup is written next to the config
before any edit. Idempotent: re-running with the same limit is a no-op.

Usage:
  python3 set-glm53-context-limit.py --limit 128000
  python3 set-glm53-context-limit.py --provider glm53 --model GLM-5.3-EXL3 --limit 128000
  python3 set-glm53-context-limit.py --limit 128000 --dry-run
"""
from __future__ import annotations

import argparse
import datetime
import re
import shutil
import sys

CONFIG_DEFAULT = "~/.minimax/config.yaml"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=CONFIG_DEFAULT)
    ap.add_argument("--provider", default="glm53")
    ap.add_argument("--model", default="GLM-5.3-EXL3")
    ap.add_argument("--limit", type=int, required=True, help="new limit.context value in tokens")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    import os
    path = os.path.expanduser(args.config)
    with open(path) as f:
        lines = f.readlines()

    # Find the provider block
    prov_re = re.compile(rf"^\s*{re.escape(args.provider)}\s*:")
    prov_start = next((i for i, ln in enumerate(lines) if prov_re.match(ln)), None)
    if prov_start is None:
        print(f"ERROR: provider block '{args.provider}' not found in {path}")
        return 1

    # Inside the provider block, find the model key, then its limit.context
    model_re = re.compile(rf"^\s*{re.escape(args.model)}\s*:")
    limit_re = re.compile(r"^(\s*context\s*:\s*)(\d+)\s*$")
    top_re = re.compile(r"^\S")

    model_start = None
    for i in range(prov_start, len(lines)):
        if i > prov_start and top_re.match(lines[i]):
            break
        if model_re.match(lines[i]):
            model_start = i
            break
    if model_start is None:
        print(f"ERROR: model '{args.model}' not found under provider '{args.provider}'")
        return 1

    target = None
    current = None
    for i in range(model_start, len(lines)):
        ln = lines[i]
        if i > model_start and top_re.match(ln):
            break
        m = limit_re.match(ln)
        if m:
            target, current = i, int(m.group(2))
            break
    if target is None:
        print(f"ERROR: limit.context not found under {args.provider}/{args.model}")
        return 1

    if current == args.limit:
        print(f"Already set: {args.provider}/{args.model} limit.context == {args.limit}. No change.")
        return 0

    print(f"{args.provider}/{args.model} limit.context: {current} -> {args.limit} (line {target + 1})")
    if args.dry_run:
        print("Dry run: no changes written.")
        return 0

    backup = f"{path}.bak-{datetime.datetime.now():%Y%m%d-%H%M%S}"
    shutil.copy2(path, backup)
    print(f"Backup written: {backup}")

    m = limit_re.match(lines[target])
    lines[target] = m.group(1) + str(args.limit) + "\n"
    with open(path, "w") as f:
        f.writelines(lines)

    # Verify the file still parses and the value landed
    import yaml
    with open(path) as f:
        cfg = yaml.safe_load(f)
    got = cfg["custom_provider"][args.provider]["models"][args.model]["limit"]["context"]
    if got != args.limit:
        print(f"ERROR: verification failed, parsed value is {got} (backup: {backup})")
        return 1
    print(f"Verified: {args.provider}/{args.model} limit.context == {got}; config parses cleanly.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
