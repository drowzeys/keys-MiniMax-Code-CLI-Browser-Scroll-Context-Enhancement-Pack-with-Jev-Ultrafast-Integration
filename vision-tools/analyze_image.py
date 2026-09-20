#!/usr/bin/env python3
"""analyze_image — eyes for a text-only MCode lane, door 2: image FILES on disk.

Adapted for the Mcode stack from the analyze_image tool in
tonyd2wild/DeepSeek-Harness-Vision-Tools (MIT, Copyright (c) 2026 tonyd2wild).
The upstream original is a dsh plugin (defineTool); this is the same contract
as a plain CLI so any MCode session can call it through the Bash gate, or a
skill wrapper can expose it.

THE BOUNDARY (unchanged from upstream): the brain sees words, never pixels.
This tool forwards the image bytes ONLY to a local OpenAI-compatible vision
model and prints its text description. Nothing image-shaped ever enters the
text model's context, so a text-only lane (e.g. local GLM-5.3-EXL3 via vLLM)
never refuses or 400s on an image again.

Backends: two roles, chosen per call, same as upstream —
  fast     (default) tiny VLM: colours, layout, coarse content
  detailed          larger VLM: small text, fine detail
Configured by env (or defaults below), pointing at YOUR local servers:

  VISION_FAST_URL      http://127.0.0.1:11434/v1/chat/completions
  VISION_FAST_MODEL    moondream
  VISION_DETAILED_URL  http://127.0.0.1:11435/v1/chat/completions
  VISION_DETAILED_MODEL qwen2.5vl:3b
  VISION_MAX_TOKENS    360 (detailed) / 120 (fast)
  VISION_TIMEOUT       90 seconds

Stdlib only, on purpose (upstream's rule, kept): a recipe nobody can
"pip install" wrong is a recipe that works on someone else's box.

Usage:
  analyze_image.py PATH [--backend fast|detailed] [--prompt "..."]

Exit codes: 0 description printed; 2 usage/unknown backend (error names the
valid backends — no silent fallback, a typo'd "detailed" must never quietly
answer from the tiny "fast" model); 1 backend/network failure (error names
the endpoint, so a down lane is obvious instead of vague).
"""
import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request

MIME = {
    "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
    "gif": "image/gif", "webp": "image/webp", "bmp": "image/bmp",
    "tif": "image/tiff", "tiff": "image/tiff",
}

DEFAULT_PROMPT = "Describe this image in detail."

# Roles and their env wiring. Placeholders point at the common local lanes;
# see backends/ in this directory for how to bring one up.
BACKENDS = {
    "fast": {
        "url": os.environ.get("VISION_FAST_URL", "http://127.0.0.1:11434/v1/chat/completions"),
        "model": os.environ.get("VISION_FAST_MODEL", "moondream"),
        "max_tokens": int(os.environ.get("VISION_MAX_TOKENS", "120")),
    },
    "detailed": {
        "url": os.environ.get("VISION_DETAILED_URL", "http://127.0.0.1:11435/v1/chat/completions"),
        "model": os.environ.get("VISION_DETAILED_MODEL", "qwen2.5vl:3b"),
        "max_tokens": int(os.environ.get("VISION_MAX_TOKENS", "360")),
    },
}
TIMEOUT = float(os.environ.get("VISION_TIMEOUT", "90"))


def die(code, *msg):
    print("[analyze_image] ERROR:", *msg, file=sys.stderr)
    sys.exit(code)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("path", help="path to the image file to analyze")
    ap.add_argument("--backend", default="fast", choices=sorted(BACKENDS),
                    help="vision backend role (default: fast)")
    ap.add_argument("--prompt", default=DEFAULT_PROMPT,
                    help="what to ask the vision model about the image")
    args = ap.parse_args()

    be = BACKENDS[args.backend]

    try:
        with open(args.path, "rb") as f:
            raw = f.read()
    except OSError as e:
        die(1, f"cannot read {args.path}: {e}")
    ext = args.path.lower().rsplit(".", 1)[-1]
    mime = MIME.get(ext, "image/png")
    b64 = base64.b64encode(raw).decode()

    body = json.dumps({
        "model": be["model"],
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": args.prompt},
                {"type": "image_url",
                 "image_url": {"url": f"data:{mime};base64,{b64}"}},
            ],
        }],
        "max_tokens": be["max_tokens"],
        "temperature": 0.2,
    })

    # Every failure names the ENDPOINT (upstream's rule, kept): a down lane or
    # a typo'd URL must be obvious here, not a vague "vision failed".
    try:
        req = urllib.request.Request(
            be["url"], data=body.encode(),
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            data = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        die(1, f'backend "{args.backend}" ({be["url"]}) returned '
               f'HTTP {e.code}: {detail}')
    except Exception as e:
        die(1, f'cannot reach backend "{args.backend}" at {be["url"]}: {e}')

    text = (data.get("choices") or [{}])[0].get("message", {}).get("content")
    text = (text or "").strip()
    if not text:
        die(1, f'backend "{args.backend}" ({be["url"]}) returned no text')

    print(text)


if __name__ == "__main__":
    main()
