# vision-tools: eyes for a text-only MCode lane

Adapted for MiniMax Code from
[tonyd2wild/DeepSeek-Harness-Vision-Tools](https://github.com/tonyd2wild/DeepSeek-Harness-Vision-Tools)
(MIT, Copyright (c) 2026 tonyd2wild; upstream README + `plugin/vision/index.js`
+ `shim/vision_shim.py` are the origin of the pattern and most of the wording
worth keeping). Upstream targets the DeepSeek Harness (`dsh`); this port keeps
the architecture and the safety rules, swaps the dsh plugin surface for the
MCode one.

**The problem it solves here:** this cluster's local lane is **text-only**
GLM-5.3-EXL3 via vLLM. Hand it an image and the request dies — refused or
`400` mid-turn. The fix is a boundary, not a bigger model:

> **The brain sees words, never pixels.** Image bytes go ONLY to a small local
> vision model; the text brain receives its description as plain text. Nothing
> image-shaped ever enters the text model's context, so nothing gets refused.

## The two doors (upstream's framing, kept)

```
DOOR 1  chat attachment
  MCode --image--> vision-proxy --image--> local vision model
                       |                        |
                       |<------ description ----|
                       +--"[Image: ...]" as TEXT--> local vLLM brain

DOOR 2  file on disk
  agent --calls tool--> analyze_image.py --> local vision model
    ^                                                     |
    +--------------- "[Image: ...]" as TEXT --------------+
```

They are **complementary, not primary-and-alternative**: a tool cannot serve a
chat attachment (the model must receive the message first to decide to call
it — the exact request that gets refused), and a proxy cannot pick up a file
the agent never mentioned. Ship both or neither.

## What ships here

| file | door | what it is |
|---|---|---|
| `analyze_image.py` | 2 (files on disk) | CLI port of the upstream `analyze_image` tool: `analyze_image.py PATH [--backend fast\|detailed] [--prompt ...]` prints a text description. Exit 2 on unknown backend **naming the valid ones** (no silent fallback — a typo'd `detailed` must never quietly answer from the tiny `fast` model); exit 1 on backend failure **naming the endpoint**. |
| `vision_proxy.py` | 1 (chat attachments) | Port of the upstream shim: a stdlib-only OpenAI-compatible proxy on `127.0.0.1:8900`. Requests with `image_url` blocks get each image described by the local VLM and rewritten to `[Image: ...]` text; everything else forwards to the upstream (`VISION_TARGET`, the local vLLM lane) untouched. A failed description **degrades to a note instead of throwing**, so the turn completes. |
| `backends/ollama.sh` | both | Brings up a local eyes model: `moondream` (~1.9B, the `fast` role) or `qwen2.5vl:3b` (`detailed`) on Ollama's OpenAI-compatible `:11434/v1`. |

Backend roles (upstream's table, kept):

| role | when | example model |
|---|---|---|
| `fast` *(default)* | colours, layout, coarse content | a tiny ~0.8B–2B VLM (moondream) |
| `detailed` | small text, fine detail | a larger VLM (qwen2.5vl:3b / ~27B Qwen-VL build) |

## Wiring into MCode

- **Door 2** — the script is directly callable from any session through the
  normal Bash permission gate (`python3 vision-tools/analyze_image.py <path>`),
  or wrap it in a skill directory for first-class exposure. The gate already
  reviews every call; that is the MCode counterpart of upstream's `ctx.fs`
  sandbox read.
- **Door 1** — point the provider lane's endpoint at the proxy instead of the
  vLLM port directly (the local OpenAI-compatible lane is the pattern this
  cluster already runs; `mcode provider` manages endpoints). The proxy is
  transparent for everything that is not an image.

## Status — read before relying on this

- **The pattern is verified upstream** (by its author, against `dsh 0.1.0-rc.6`
  — see the upstream README's own verification section).
- **The port is NOT yet validated on this box** (2026-09-20): no local VLM
  endpoint was answering at time of writing — Ollama is installed but its
  service is down with no vision model pulled, and this node's `:8000` vLLM
  lane was not up. Scripts are syntax-checked and their failure paths behave
  as specified (endpoint-naming errors, graceful degradation), but no real
  image has been described here yet.
- **Validation checklist before first real use:** `backends/ollama.sh` →
  `ollama list` shows the VLM → `curl 127.0.0.1:11434/v1/models` answers →
  `analyze_image.py <local test image>` returns a description → only then
  wire door 1 and restart the session.

## Security notes

- Everything binds `127.0.0.1` by default; image bytes never leave the box
  and never enter the text model's context or its logs.
- The proxy adds zero egress: it talks only to the two configured local
  endpoints (`EYES_URL`, `VISION_TARGET`).
- Degrade-not-throw is deliberate (upstream's rule): a down eyes lane wastes
  one image note, not the user's whole turn.
- `EYES_DETAIL=1` trades speed for transcription fidelity; keep it off unless
  you need UI-text reads.

Provenance and license: see [`ATTRIBUTION.md`](../ATTRIBUTION.md). Upstream is
MIT; this port is a from-scratch adaptation for the MCode stack, same license
spirit, original credited.
