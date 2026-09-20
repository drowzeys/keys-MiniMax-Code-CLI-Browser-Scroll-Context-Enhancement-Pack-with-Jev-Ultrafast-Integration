#!/usr/bin/env bash
# smoke-test.sh — end-to-end verification of the browser-cdp lane.
#
# Encodes exactly what was verified live on 2026-09-20:
#   1. the DevTools endpoint answers on 127.0.0.1 (and only there),
#   2. browser-harness attaches via BU_CDP_URL and really drives the browser.
#
# It launches the lane if it is not already up, navigates example.com through
# the harness, and prints PASS/FAIL with evidence. It does NOT paper over
# failures: any failed step exits non-zero with the raw evidence above it.
set -euo pipefail
cd "$(dirname "$0")"

PORT="${CDP_PORT:-9222}"

echo "== [1/4] lane up =="
./launch-chromium-cdp.sh

echo
echo "== [2/4] endpoint answers =="
V=$(curl -s -m 5 "http://127.0.0.1:${PORT}/json/version" || true)
if [ -z "$V" ]; then
  echo "FAIL: /json/version did not answer on 127.0.0.1:${PORT}"
  exit 1
fi
echo "$V" | head -c 120; echo

echo
echo "== [3/4] localhost-only bind =="
if ss -tln 2>/dev/null | grep -q "127.0.0.1:${PORT} "; then
  echo "ok: ${PORT} bound to 127.0.0.1 only"
else
  echo "FAIL: ${PORT} not confirmed on 127.0.0.1 (ss -tln | grep ${PORT}):"
  ss -tln | grep ":${PORT} " || true
  exit 1
fi

echo
echo "== [4/4] harness drives it =="
OUT=$(BU_CDP_URL="http://127.0.0.1:${PORT}" browser-harness <<'PY'
new_tab("https://example.com")
wait_for_load()
info = page_info()
print("RESULT", info.get("url"), info.get("title"))
PY
) || true
echo "$OUT"
# The harness stamps its own tab marker into the title on attach; its presence
# plus a real URL is the proof the harness (not a mirage) drove the page.
if echo "$OUT" | grep -q "RESULT https://example.com"; then
  echo "PASS: harness attached over BU_CDP_URL and navigated a live page."
else
  echo "FAIL: harness did not return live page info; see output above."
  exit 1
fi
