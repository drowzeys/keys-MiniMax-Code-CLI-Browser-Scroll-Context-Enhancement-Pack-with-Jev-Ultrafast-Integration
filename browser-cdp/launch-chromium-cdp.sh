#!/usr/bin/env bash
# launch-chromium-cdp.sh — the verified arm64 Spark CDP lane for browser-harness.
#
# Playwright's arm64 Chromium build, headless, --no-sandbox (mandatory under
# Ubuntu 24.04+ AppArmor userns restriction), localhost-only DevTools port,
# dedicated profile. See README.md in this directory for the full measured
# background and the two dead ends this replaces.
#
# Verified on this machine 2026-09-20. Stdlib only; no dependencies.
set -euo pipefail

PORT="${CDP_PORT:-9222}"
PROFILE="${CDP_PROFILE:-/tmp/bh-cdp-profile}"

# Resolve the NEWEST Playwright chromium build; never a stale pinned one.
if [ -z "${BH_CHROME_PATH:-}" ]; then
  BH_CHROME_PATH=$(ls -d "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux-arm64/chrome 2>/dev/null | sort -V | tail -1 || true)
fi
if [ -z "${BH_CHROME_PATH:-}" ] || [ ! -x "$BH_CHROME_PATH" ]; then
  echo "[browser-cdp] ERROR: no Playwright arm64 chromium found."
  echo "[browser-cdp]   Install it with:  npx playwright install chromium"
  echo "[browser-cdp]   (or set BH_CHROME_PATH to a real arm64 chromium binary)"
  exit 1
fi

# Refuse to double-launch: if the endpoint already answers, keep that instance.
if curl -s -m 3 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "[browser-cdp] endpoint already alive on 127.0.0.1:${PORT}; not relaunching."
else
  mkdir -p "$PROFILE"
  # --no-sandbox: MANDATORY here. Without it the zygote aborts:
  #   FATAL ... No usable sandbox! (Ubuntu 23.10+ AppArmor userns restriction)
  # The browser's own error message names this workaround.
  nohup "$BH_CHROME_PATH" \
    --headless \
    --no-sandbox \
    --remote-debugging-port="$PORT" \
    --user-data-dir="$PROFILE" \
    --disable-gpu \
    --disable-dev-shm-usage \
    about:blank \
    >"$PROFILE/chromium.log" 2>&1 &
  echo "[browser-cdp] launched pid $! (log: $PROFILE/chromium.log)"
  sleep 4
fi

# Verify the endpoint answers, and only on localhost.
echo "[browser-cdp] /json/version says:"
curl -s -m 5 "http://127.0.0.1:${PORT}/json/version" | head -c 200; echo
if ! ss -tln 2>/dev/null | grep -q "127.0.0.1:${PORT} "; then
  echo "[browser-cdp] WARNING: endpoint is not confirmed localhost-only; check: ss -tln | grep ${PORT}"
fi

echo "[browser-cdp] attach the harness with:"
echo "[browser-cdp]   BU_CDP_URL=http://127.0.0.1:${PORT} browser-harness <<'PY'"
echo "[browser-cdp]     new_tab(\"https://example.com\")"
echo "[browser-cdp]     wait_for_load()"
echo "[browser-cdp]     print(page_info())"
echo "[browser-cdp]   PY"
echo "[browser-cdp] stop later with:  pkill -f 'remote-debugging-port'"
