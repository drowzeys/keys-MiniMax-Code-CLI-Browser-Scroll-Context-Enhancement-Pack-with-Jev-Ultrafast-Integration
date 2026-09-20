# Pre-built container image (GHCR)

A turnkey arm64 image with the pack applied — no local build, no patching by
hand. Built by GitHub Actions on an arm64 runner and published to GHCR.

## Pull

```bash
docker pull ghcr.io/drowzeys/keys-mcode-continuous-context-browser-decision-enhancement-pack:latest
# pinned:
docker pull ghcr.io/drowzeys/keys-mcode-continuous-context-browser-decision-enhancement-pack:0.4.12-keys1
```

If the pull is denied right after the first publish, the package may still be
private — flip it to public once under the package's settings (or via the
GitHub CLI, see below), it is intended to be public.

## What's inside

- **MiniMax Code CLI 0.4.12** (the official
  [@minimax-ai/code](https://www.npmjs.com/package/@minimax-ai/code) release
  from the public npm registry, which ships the correct arm64 native modules)
  **overlaid with the pack's patched bundles** built from source at the exact
  upstream commit the patches sit on — so the fullscreen-transcript scrollbar
  and the context-meter status item are actually active
- **arm64 browser stack**: Playwright's real arm64 Chromium
  (`PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers`) — Google ships no arm64 Linux
  Chrome; this is the supported path for Jev Ultrafast / Playwright MCP
- **Pack tooling**: `compaction-fix/` (config editor, probe, status checker)
  and `performance/` (usage collector) under `/opt/keys-pack/`

## What is NOT inside (by design)

- **No model, no weights** — point MCode at your own local vLLM endpoint via
  the mounted config (this pack's reference stack: GLM-5.3-EXL3 on 4× DGX
  Spark, see `../performance/`)
- **No credentials** — mount your own:
  ```bash
  docker run -it --rm \
    -v "$HOME/.minimax:/root/.minimax" \
    ghcr.io/drowzeys/keys-mcode-continuous-context-browser-decision-enhancement-pack:latest
  ```
- **No TypeSafe key** — bring your own for Jev's policy layer

## How it is built and published

- `../Dockerfile` — two-stage build: patched-source bundles → overlay onto the
  official npm release; provenance labels point at this repository
- `../.github/workflows/ghcr.yml` — runs on `ubuntu-24.04-arm`, builds,
  **smoke-tests** (CLI executes AND the `context-meter` patch marker is present
  in the overlay) and only then pushes. Manual dispatch or `v*` tag
- Rebuild/check status:
  ```bash
  gh run list -R drowzeys/keys-mcode-continuous-context-browser-decision-enhancement-pack --workflow ghcr.yml --limit 3
  gh workflow run ghcr.yml -R drowzeys/keys-mcode-continuous-context-browser-decision-enhancement-pack
  ```
- Make the package public after first publish (one-time):
  ```bash
  gh api --method PATCH /user/packages/container/keys-mcode-continuous-context-browser-decision-enhancement-pack \
    -f visibility=public || echo "flip visibility in the web UI: Package settings -> Danger Zone -> Change visibility"
  ```

## Compaction fix reminder

The image ships the fix **tooling**, but the 128 K limit must be set in the
mounted config and requires a **fresh session start** to take effect — see
`../compaction-fix/README.md` (deployment note).
