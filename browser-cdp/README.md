# browser-cdp: the verified CDP lane for browser-harness on arm64 DGX Spark

Real-Chromium CDP automation for the MCode `browser-harness` skill on arm64
Linux, where every "just install Chrome" instruction fails. This module is the
**measured, working path**, plus the two dead ends that were ruled out on this
machine — and the tool-surface pattern ported from
[tonyd2wild/DeepSeek-Harness-Browser](https://github.com/tonyd2wild/DeepSeek-Harness-Browser)
(see the mapping table below).

**Status: verified on this machine, 2026-09-20 (early hours, EDT).** Every
claim below was reproduced live in an MCode session; exact strings, not
paraphrases.

## The two dead ends, ruled out by measurement

| path | what actually happens |
|---|---|
| **Google Chrome, native install** (the fix `browser-harness --doctor` and its [snap-linux-headless.md](https://github.com/browser-use/browser-harness/blob/main/docs/snap-linux-headless.md) doc recommend) | Impossible here: Google ships **no arm64 Linux Chrome**. The doc's `.deb` is AMD64-only. |
| **Snap Chromium** (`/snap/bin/chromium`, the only system browser on this box) | `browser-harness --doctor` prints: `Browser: chromium (snap) — WARNING: Snap confinement prevents CDP binding.` Snap's sandbox prevents the DevTools endpoint from binding where the harness daemon can reach it. A desktop-class browser, but a **CDP dead end**. |

## The verified lane

Playwright's own arm64 Chromium build (real Chromium, not headless-shell-only),
launched headless with the one flag Ubuntu's AppArmor makes mandatory, attached
from the harness via its documented `BU_CDP_URL` endpoint mode:

```bash
# 1. Playwright arm64 Chromium (already on this box after `npx playwright install chromium`)
~/.cache/ms-playwright/chromium-1243/chrome-linux-arm64/chrome \
  --headless --no-sandbox \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/bh-cdp-profile \
  --disable-gpu --disable-dev-shm-usage about:blank

# 2. Attach the harness (each invocation; the daemon resolves it to WebSocket)
BU_CDP_URL=http://127.0.0.1:9222 browser-harness <<'PY'
new_tab("https://example.com")
wait_for_load()
print(page_info())
PY
```

### Why `--no-sandbox` is mandatory, not optional

Without it the browser **aborts at zygote init**, core dump and all:

```text
FATAL:content/browser/zygote_host/zygote_host_impl_linux.cc:129] No usable
sandbox! If you are running on Ubuntu 23.10+ or another Linux distro that has
disabled unprivileged user namespaces with AppArmor, see
https://chromium.googlesource.com/chromium/src/+/main/docs/security/apparmor-userns-restrictions.md
```

Ubuntu 24.04+ (this box) restricts unprivileged user namespaces under AppArmor,
so Chromium's sandbox cannot initialize. The browser's own error message names
the workaround. **Tradeoff, stated plainly:** `--no-sandbox` runs renderer
processes without the Chromium sandbox. The exposure is scoped by everything
else in this recipe: dedicated profile, localhost-only bind, headless, no
user session inside it, and the MCode permission gate still reviews every
harness action.

### What was verified, end to end (2026-09-20)

1. `/json/version` answers on `127.0.0.1:9222` only: `Chrome/153.0.8010.12`
   (Playwright `chromium-1243`, arm64 build).
2. `browser-harness` attaches via `BU_CDP_URL` and drives it: the
   `new_tab("https://example.com")` smoke test returned live page info, with
   the harness's own 🐴 tab marker proving the attach (not a snap-Chromium
   mirage).
3. `--doctor` still prints `daemon alive / active browser connections` FAIL
   lines in `BU_CDP_URL` mode — those checks are **cosmetic** there; the live
   smoke test above is the real verification. (`smoke-test.sh` encodes it.)

## Tool surface: the tonyd2wild pattern, mapped to browser-harness

[DeepSeek-Harness-Browser](https://github.com/tonyd2wild/DeepSeek-Harness-Browser)
puts a real Chrome beside the chat — a **real layout column** (conversation
measured 907px → 447px, restored on close), the pane mirroring the browser as
JPEG frames while clicks/scroll/keystrokes forward back as CDP input events.
No iframe, for three measured reasons: sites send `X-Frame-Options: SAMEORIGIN`
(x.com, reddit.com), `SameSite=Lax` cookies render a framable site signed-out,
and a server-side proxy fetches anonymously. Only a real browser over CDP
holds a logged-in session — with a **dedicated profile**, so the user's daily
browser is untouched and a login persists.

The model never sees pixels there either; it gets **three tools**. MCode's
`browser-harness` helpers cover the same ground:

| DeepSeek-Harness-Browser tool | browser-harness equivalent |
|---|---|
| `open_preview(url, label?)` — web page or local file into the pane | `new_tab(url)` / `goto_url(url)`, `wait_for_load()` |
| `read_preview(start?, count?)` — what's on screen, as text; pages through | `js("document.body.innerText")` (live DOM, exactly their mechanism), or the AX tree via `cdp("Accessibility.getFullAXTree")` for element-accurate reads |
| `close_preview(url?)` — one tab or the whole pane | tab lifecycle helpers (`close_tab`/`ensure_real_tab` discipline per the skill) |
| dedicated persistent Chrome profile | `--user-data-dir` on a dedicated dir (never the daily browser's profile) |

What the pane itself (a human-watchable column inside the host UI) does not
port: MCode's TUI has no embedded browser pane, and the harness deliberately
keeps the browser headless here. The **agent-facing capability** is the part
that ports cleanly, and it is now verified working on arm64.

## Files

- `launch-chromium-cdp.sh` — the verified launcher. Auto-detects the newest
  Playwright `chromium-*` build (override with `BH_CHROME_PATH`), refuses to
  double-launch, verifies `/json/version`, prints the attach line. Localhost
  bind only.
- `smoke-test.sh` — the end-to-end verification from tonight: version
  endpoint, localhost-only bind assertion, live `new_tab` navigation through
  the harness. PASS/FAIL, no mercy.

## Security notes

- CDP binds `127.0.0.1` only; `smoke-test.sh` asserts it.
- Dedicated `--user-data-dir`; the daily browser (snap Chromium) is never
  touched, and it cannot open the same profile twice anyway.
- `--no-sandbox` is the one flags-level compromise; see the tradeoff above.
- In the pack's container image, Playwright Chromium is installed at build
  time (see [`Dockerfile`](../Dockerfile)); container Chrome confinement
  differs from bare metal — re-verify inside the image before relying on it.
- Keep the browser down when not in use: `pkill -f 'remote-debugging-port'`
  (the launcher logs to `<profile>/chromium.log`).
