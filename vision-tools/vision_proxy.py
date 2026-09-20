#!/usr/bin/env python3
"""vision-proxy — eyes for a text-only MCode lane, door 1: CHAT image attachments.

Adapted for the Mcode stack from shim/vision_shim.py in
tonyd2wild/DeepSeek-Harness-Vision-Tools (MIT, Copyright (c) 2026 tonyd2wild).

Sits between MCode and the local text-model endpoint and speaks the ordinary
OpenAI /v1/chat/completions contract both ways. When a request contains
image_url blocks, it describes each image with a LOCAL vision model and
rewrites the block into plain text, so the text brain receives only words and
never 400s on an image. Requests without images forward untouched.

    MCode --image--> vision-proxy --image--> local vision model
                        |                        |
                        |<------ description ----|
                        +--"[Image: ...]" as TEXT--> local vLLM brain

Door 2 (image FILES on disk the agent chooses to look at) is the companion
analyze_image.py in this directory. Ship both: a tool cannot serve a chat
attachment (the model must receive the message first to decide to call it),
and a proxy cannot pick up a file the agent never mentioned. Different doors.

ZERO DEPENDENCIES. Python 3.8+ stdlib only, on purpose (upstream's rule):
a recipe nobody can "pip install" wrong works on someone else's box.

Config (env; all defaults are localhost-only):
  SHIM_HOST        127.0.0.1            bind address — keep it localhost
  SHIM_PORT        8900
  VISION_TARGET    http://127.0.0.1:8000   upstream text brain (local vLLM)
  EYES_URL         http://127.0.0.1:11434/v1/chat/completions
  EYES_MODEL       moondream
  EYES_DETAIL      1 = detailed prompt + more tokens (default 0)
  EYES_MAX_TOKENS  360 detailed / 120 fast
  EYES_TIMEOUT     90
  SHIM_LOG         1

Mcode wiring: point the provider lane's endpoint at this proxy instead of the
vLLM port directly (mcode provider manages endpoints; the local OpenAI-
compatible lane is the pattern this cluster already runs). The proxy is
transparent for everything that is not an image.

Failure policy (upstream's rule, kept): a failed description DEGRADES to a
"[Image: could not be analyzed: ...]" note instead of throwing, so the turn
completes instead of wasting the user's whole message.
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("SHIM_HOST", "127.0.0.1")
PORT = int(os.environ.get("SHIM_PORT", "8900"))
UPSTREAM = os.environ.get("VISION_TARGET", "http://127.0.0.1:8000").rstrip("/")
EYES_URL = os.environ.get("EYES_URL", "http://127.0.0.1:11434/v1/chat/completions")
EYES_MODEL = os.environ.get("EYES_MODEL", "moondream")
DETAIL = os.environ.get("EYES_DETAIL", "0") == "1"
MAXTOK = int(os.environ.get("EYES_MAX_TOKENS", "360" if DETAIL else "120"))
TIMEOUT = float(os.environ.get("EYES_TIMEOUT", "90"))
LOG = os.environ.get("SHIM_LOG", "1") == "1"

MAX_BODY = 64 * 1024 * 1024  # images are base64-inlined; allow up to 64 MB

DEFAULT_PROMPT = (
    "Describe this image in detail. Transcribe any visible text exactly as it "
    "appears, including numbers, labels and UI elements. Note layout and colours."
) if DETAIL else (
    "Describe what you see in one clear sentence."
)
EYES_PROMPT = os.environ.get("EYES_PROMPT", DEFAULT_PROMPT)


def log(*a):
    if LOG:
        print("[vision-proxy]", *a, file=sys.stderr, flush=True)


# ------------------------------------------------------------ vision leg
def _fetch_image_b64(url):
    """Return (b64, mime) for a data: URI or an http(s) URL."""
    if url.startswith("data:"):
        head, _, payload = url.partition(",")
        mime = head[5:].split(";")[0] or "image/jpeg"
        if ";base64" in head:
            return payload, mime
        raw = urllib.parse.unquote(payload).encode()
        return base64.b64encode(raw).decode(), mime
    req = urllib.request.Request(url, headers={"User-Agent": "vision-proxy"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        raw = r.read()
        mime = r.headers.get("Content-Type", "image/jpeg").split(";")[0]
    return base64.b64encode(raw).decode(), mime


def describe(url):
    """Describe one image via the local vision model. Never raises.

    Returns (ok, text). On failure ok is False and text is the error, so the
    caller can DEGRADE (emit a note) rather than throw.
    """
    try:
        b64, mime = _fetch_image_b64(url)
    except Exception as e:
        log("image fetch failed:", e)
        return False, f"could not load image: {e}"
    body = json.dumps({
        "model": EYES_MODEL,
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": EYES_PROMPT},
            {"type": "image_url",
             "image_url": {"url": f"data:{mime};base64,{b64}"}},
        ]}],
        "max_tokens": MAXTOK,
        "temperature": 0.2,
    })
    try:
        req = urllib.request.Request(
            EYES_URL, data=body.encode(),
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            data = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:200]
        log("vision model HTTP", e.code, detail)
        return False, f"vision model returned HTTP {e.code}"
    except Exception as e:
        log("vision model unreachable:", e)
        return False, f"cannot reach vision model at {EYES_URL}: {e}"
    text = (data.get("choices") or [{}])[0].get("message", {}).get("content")
    text = (text or "").strip()
    if not text:
        return False, "vision model returned no text"
    return True, text


def rewrite_images(messages):
    """Rewrite every image_url block in every message to a text note.

    Returns (new_messages, n_images). Only touches content blocks that are
    image_url; text parts pass through untouched.
    """
    n = 0
    out = []
    for m in messages:
        content = m.get("content")
        if not isinstance(content, list):
            out.append(m)
            continue
        new_parts = []
        for part in content:
            if isinstance(part, dict) and part.get("type") == "image_url":
                url = (part.get("image_url") or {}).get("url", "")
                n += 1
                ok, text = describe(url)
                if ok:
                    new_parts.append({"type": "text",
                                      "text": f"[Image {n}: {text}]"})
                else:
                    # DEGRADE, never throw: the turn must complete.
                    new_parts.append({"type": "text",
                                      "text": f"[Image {n}: could not be "
                                              f"analyzed: {text}]"})
            else:
                new_parts.append(part)
        out.append({**m, "content": new_parts})
    return out, n


# ------------------------------------------------------------- forwarding
def forward(method, path, headers, body):
    """Send to the upstream brain and return (status, headers, body bytes)."""
    req = urllib.request.Request(
        UPSTREAM + path, data=body if body else None,
        headers={k: v for k, v in headers.items()
                 if k.lower() not in ("host", "content-length", "connection")},
        method=method)
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            return r.status, dict(r.headers), r.read()
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read()
    except Exception as e:
        return 502, {}, json.dumps({"error": {
            "message": f"vision-proxy cannot reach upstream {UPSTREAM}: {e}",
            "type": "upstream_unreachable"}}).encode()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *a):
        log(fmt % a)

    def _proxy(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""

        if self.path.endswith("/v1/chat/completions") and body:
            try:
                payload = json.loads(body)
                messages, n = rewrite_images(payload.get("messages") or [])
                if n:
                    log(f"rewrote {n} image block(s) to text")
                    payload["messages"] = messages
                    body = json.dumps(payload).encode()
            except json.JSONDecodeError:
                log("body was not JSON; forwarding untouched")

        status, _, resp = forward(self.command, self.path,
                                 dict(self.headers), body)
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = _proxy


def main():
    log(f"listening on {HOST}:{PORT}, upstream {UPSTREAM}, "
        f"eyes {EYES_URL} ({EYES_MODEL}, detail={DETAIL})")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
