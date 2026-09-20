import json, urllib.request, time, sys

URL = "http://10.100.10.1:8888/v1/chat/completions"
SYS = ("You are a context-compaction checkpoint generator. Summarize the conversation "
       "state as a structured checkpoint covering: active goals, completed work with "
       "file paths, key decisions, credentials status, and next steps.")

def run(label, filler_reps, max_tokens):
    body = {
        "model": "GLM-5.3-EXL3",
        "max_tokens": max_tokens,
        "temperature": 0,
        "stream": False,
        "messages": [
            {"role": "system", "content": SYS},
            {"role": "user", "content": "Session log filler. " * filler_reps},
        ],
    }
    t0 = time.time()
    req = urllib.request.Request(URL, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": "Bearer local"})
    try:
        r = json.load(urllib.request.urlopen(req, timeout=280))
        dt = time.time() - t0
        msg = r["choices"][0]
        content = msg.get("message", {}).get("content") or ""
        usage = r.get("usage", {})
        print(f"{label}: OK in {dt:.1f}s | finish={msg.get('finish_reason')} | "
              f"out_chars={len(content)} | prompt_toks={usage.get('prompt_tokens')} | "
              f"preview={content[:100]!r}", flush=True)
    except Exception as e:
        print(f"{label}: FAILED in {time.time()-t0:.1f}s: {type(e).__name__}: {str(e)[:300]}", flush=True)

# Test A: small (~5K input) — is the checkpoint prompt itself OK?
run("A-small(5K)", 1000, 4096)
# Test B: large (~170K input), alone — does size alone break it?
run("B-large(170K)", 34000, 8192)
