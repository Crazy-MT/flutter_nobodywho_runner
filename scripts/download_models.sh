#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

download() {
  local url="$1"
  local output="$2"
  local part="${output}.part"

  mkdir -p "$(dirname "$output")"

  if [[ -s "$output" ]]; then
    echo "exists: ${output#$repo_root/}"
    return
  fi

  echo "download: ${output#$repo_root/}"
  curl -fL --retry 3 --continue-at - --output "$part" "$url"
  mv "$part" "$output"
}

download \
  "https://huggingface.co/NobodyWho/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf" \
  "$repo_root/assets/model.gguf"

download \
  "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf" \
  "$repo_root/assets/multimodal/gemma-4-E2B-it-Q4_K_M.gguf"

download \
  "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/mmproj-BF16.gguf" \
  "$repo_root/assets/multimodal/mmproj-BF16.gguf"

echo "done"
