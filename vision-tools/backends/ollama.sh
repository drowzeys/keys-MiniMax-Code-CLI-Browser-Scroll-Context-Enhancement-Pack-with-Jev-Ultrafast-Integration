#!/usr/bin/env bash
# backends/ollama.sh — bring up a local "eyes" VLM via Ollama, the easiest
# path if you want a one-liner.
#
# Adapted from tonyd2wild/DeepSeek-Harness-Vision-Tools (MIT), same caveats:
# Ollama cannot load the standalone mmproj vision projector some models need;
# this lane therefore uses Moondream or Qwen2.5-VL, not Qwen3.5.
#
# Ollama serves an OpenAI-compatible endpoint on :11434/v1. After this runs,
# point the tool/proxy at it:
#   VISION_FAST_URL=http://127.0.0.1:11434/v1/chat/completions
#   VISION_FAST_MODEL=moondream            # or qwen2.5vl:3b for "detailed"
#   EYES_URL=http://127.0.0.1:11434/v1/chat/completions
#   EYES_MODEL=moondream
set -euo pipefail
MODEL="${OLLAMA_MODEL:-moondream}"   # moondream (~1.9B) or qwen2.5vl:3b

if ! command -v ollama >/dev/null 2>&1; then
  echo "[ollama] ERROR: ollama not found on PATH."
  echo "[ollama]   Install: https://ollama.com/download"
  exit 1
fi

echo "[ollama] pulling vision model: $MODEL"
ollama pull "$MODEL"

echo "[ollama] ensuring the server is running (OpenAI-compatible on :11434/v1) ..."
if ! curl -s -m 3 http://127.0.0.1:11434/v1/models >/dev/null 2>&1; then
  nohup ollama serve >/tmp/ollama.log 2>&1 &
  disown
  sleep 2
fi

echo "[ollama] ready. Set these, then restart the proxy / call the tool:"
echo "[ollama]   VISION_FAST_URL=http://127.0.0.1:11434/v1/chat/completions"
echo "[ollama]   VISION_FAST_MODEL=$MODEL"
echo "[ollama]   EYES_URL=http://127.0.0.1:11434/v1/chat/completions"
echo "[ollama]   EYES_MODEL=$MODEL"
