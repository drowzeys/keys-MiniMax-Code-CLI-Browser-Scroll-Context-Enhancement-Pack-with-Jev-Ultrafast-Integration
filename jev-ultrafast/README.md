# Jev Ultrafast Integration (arm64 DGX Spark) — VERIFIED

Wiring [browser-use/jev-ultrafast](https://github.com/browser-use/jev-ultrafast)
— the fast browser agent (TypeSafe policy layer + small text LLM driving a real
browser over CDP) — into the MCode agent stack on arm64 Linux.

**Status: deployed and verified end-to-end on this machine, 2026-09-20.**
The project's own verifiable smoke test (`scripts/smoke.py`, local travel
fixture with hard outcome asserts) passed through the full stack:
**5 actions / 6 TypeSafe decisions / 9.79 seconds / `"verified": true`** —
goal reached, URL and page-content assertions green.

## The verified three-leg stack

| leg | what it runs on | status |
|---|---|---|
| **Policy** (operation + target picker) | TypeSafe cloud (`api.typesafe.ai/v1/systemone`), `TYPESAFE_API_KEY` in `~/jev-ultrafast/.env` (chmod 600, gitignored) | Live — answered every decision in the verified run |
| **Text** (`TYPE_TEXT` only) | **Local** vLLM `GLM-5.3-EXL3` on the cluster lane (`10.100.10.1:8888/v1`), `TEXT_MODEL_REASONING=none` | Live — $0/token, no cloud API |
| **Browser** | The pack's verified CDP lane ([`../browser-cdp/`](../browser-cdp/README.md)): Playwright arm64 Chromium 153, headless, `--no-sandbox`, attached via `BU_CDP_URL=http://127.0.0.1:9222` | Live — same lane the smoke test drove |

Only the policy leg touches a paid/cloud service, and only it: the text leg
and the browser never leave the box (browser binds 127.0.0.1 only).

## How it was run (exact commands, reproducible)

```bash
cd ~/jev-ultrafast

# 1. .env  (bring YOUR OWN keys — never share, never commit)
#    TYPESAFE_API_KEY=<your own key>   # get one at docs.typesafe.ai
#    TEXT_MODEL_API_KEY=local          # placeholder; local vLLM ignores it
#    TEXT_MODEL_BASE_URL=http://10.100.10.1:8888/v1
#    TEXT_MODEL=GLM-5.3-EXL3
#    TEXT_MODEL_REASONING=none

# 2. browser lane up (see ../browser-cdp/) — 127.0.0.1:9222
./../keys-...pack/browser-cdp/launch-chromium-cdp.sh   # or your path to it

# 3. demo/fixture server (serves 127.0.0.1:8766, loads .env itself)
nohup uv run jev >/tmp/jev-demo.log 2>&1 &

# 4. the verifiable smoke test, through the lane
BU_CDP_URL=http://127.0.0.1:9222 uv run python scripts/smoke.py --max-actions 15
```

The smoke test does not trust a `DONE` choice: it independently asserts the
final URL (`#casa-flora`) and the rendered filter text before declaring
`verified: true`. Run artifacts (state.json per step) land under
`artifacts/dynamic/fixture/` in the clone.

## Browser pathway — the dead one is gone

Earlier revisions of this file documented a **snap Chromium** pathway. It is
removed: snap confinement **prevents CDP binding entirely** (measured,
`browser-harness --doctor` names it), so it can never serve as Jev's browser
on this box. The full measurement — including why native Google Chrome is
impossible on arm64 Linux and why `--no-sandbox` is mandatory under Ubuntu
24.04+ AppArmor — lives in [`../browser-cdp/README.md`](../browser-cdp/README.md),
which is the only browser pathway this pack documents.

## Notes and caveats

- The verified run is against the project's **local synthetic fixture** —
  fast, deterministic, and assertable. The open-web demo (Google Flights)
  will behave differently: real pages, real latencies, more steps.
- `TEXT_MODEL_API_KEY=local` is a placeholder: the local vLLM lane does not
  check bearer tokens. It exists only because the helper refuses to run
  without a key value.
- **Bring your own API key.** Every user must use their **own** TypeSafe key
  (sign up at [docs.typesafe.ai](https://docs.typesafe.ai) — the flow
  referenced by the `typesafe-ai` skill). Keys are personal secrets: never
  share them, never paste them into issues or docs, never commit them. This
  machine's key lives only in the local `~/jev-ultrafast/.env` (chmod 600,
  gitignored) and is deliberately absent from this repository.
- The `browser-harness` skill (CDP control: click/type/navigate, logged-in
  sessions) is the MCode-side counterpart for interactive work; Jev is the
  policy/fast-path layer on top.
- Related: `../playwright-mcp/` wires Microsoft's Playwright MCP server into
  MCode so the agent itself gets browser tools without Jev.
- Stop order when done: kill the smoke/demo processes, then the lane
  (`pkill -f remote-debugging-port`); see `../browser-cdp/`.
