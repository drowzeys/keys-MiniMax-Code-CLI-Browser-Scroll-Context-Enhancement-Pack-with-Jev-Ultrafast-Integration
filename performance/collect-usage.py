#!/usr/bin/env python3
"""Collect real LLM usage from the MCode local runtime's own sqlite ledger.

Read-only. Reports per-session and total request counts, input/output/cache-read
tokens, wall-clock windows, and measured throughput. The ledger is the runtime's
own accounting (local_runtime_token_usage table); note that `ts` is stored in
MILLISECONDS, so naive 'unixepoch' date filters silently return nothing.

Usage:
  python3 collect-usage.py                # all days, per-session + totals
  python3 collect-usage.py --day 2026-09-19
  python3 collect-usage.py --totals-only
"""
from __future__ import annotations

import argparse
import sqlite3
import sys

DB_DEFAULT = "~/.minimax/v2/sqlite/runtime-state.sqlite"

PER_SESSION = """
SELECT substr(session_id,1,18) AS session,
       COUNT(*) AS calls,
       SUM(input_tokens) AS input_toks,
       SUM(output_tokens) AS out_toks,
       SUM(cache_read_tokens) AS cache_read,
       datetime(MIN(ts)/1000,'unixepoch','localtime') AS first,
       datetime(MAX(ts)/1000,'unixepoch','localtime') AS last,
       ROUND((MAX(ts)-MIN(ts))/3600000.0,2) AS hours
FROM local_runtime_token_usage
{where}
GROUP BY session_id ORDER BY first;
"""

TOTALS = """
SELECT COUNT(*), SUM(input_tokens), SUM(output_tokens), SUM(reasoning_tokens),
       SUM(cache_read_tokens), SUM(cost_usd)
FROM local_runtime_token_usage {where};
"""


def main() -> int:
    import os
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=DB_DEFAULT)
    ap.add_argument("--day", help="local date filter, YYYY-MM-DD")
    ap.add_argument("--totals-only", action="store_true")
    args = ap.parse_args()

    path = os.path.expanduser(args.db)
    uri = f"file:{path}?mode=ro"
    con = sqlite3.connect(uri, uri=True)

    where = ""
    if args.day:
        where = "WHERE date(ts/1000,'unixepoch','localtime')=:day"
    params = {"day": args.day}

    if not args.totals_only:
        print("=== per-session ledger ===")
        cur = con.execute(PER_SESSION.format(where=where), params)
        print(f"{'session':18} {'calls':>5} {'input_toks':>12} {'out_toks':>9} "
              f"{'cache_read':>11} {'first':19} {'last':19} {'hours':>6}")
        for row in cur:
            print(f"{row[0]:18} {row[1]:>5} {row[2]:>12,} {row[3]:>9,} "
                  f"{row[4]:>11,} {row[5]:19} {row[6]:19} {row[7]:>6}")

    print("\n=== totals ===")
    row = con.execute(TOTALS.format(where=where), params).fetchone()
    calls, inp, outp, reason, cache, cost = row
    print(f"calls={calls}  input_tokens={inp:,}  output_tokens={outp:,}  "
          f"reasoning_tokens={reason or 0:,}  cache_read_tokens={cache or 0:,}  cost_usd={cost or 0}")
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
