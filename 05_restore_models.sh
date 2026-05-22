#!/usr/bin/env bash
# Pull bazowych modeli + tworzy warianty z większym kontekstem.
#
# Uruchom po reinstalacji systemu, przed 03_add_mcp_to_hermes.sh.
# Wymaga: ollama (zainstalowane i działające).
#
#   ./05_restore_models.sh

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELFILES="$BASE_DIR/modelfiles"

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'UWAGA: %s\n' "$*" >&2; }
die()  { printf 'BŁĄD: %s\n' "$*" >&2; exit 1; }

command -v ollama >/dev/null 2>&1 || die "ollama nie jest zainstalowane"
ollama list >/dev/null 2>&1 || die "ollama nie odpowiada (uruchom 'ollama serve'?)"

# --- modele bazowe ---
BASE_MODELS=(
  "qwen3:14b"
  "deepseek-coder-v2:16b"
  "qwen2.5:7b"
  "gemma4:latest"
)

for model in "${BASE_MODELS[@]}"; do
  if ollama list 2>/dev/null | grep -q "$model"; then
    log "Model $model już istnieje, pomijam pull"
  else
    log "Pull: $model"
    ollama pull "$model"
  fi
done

# --- modele z większym kontekstem ---
# Format: model_name|modelfile   (| jako separator, bo model:tag zawiera :)
CUSTOM_MODELS=(
  "qwen3:14b-ctx131072|qwen3-14b.ctx131072.modelfile"
  "deepseek-coder-v2:16b-ctx65536|deepseek-coder-v2.ctx65536.modelfile"
)

for entry in "${CUSTOM_MODELS[@]}"; do
  model_name="${entry%%|*}"
  modelfile="${entry#*|}"
  if ollama list 2>/dev/null | grep -q "$model_name"; then
    log "Model $model_name już istnieje, pomijam create"
  else
    log "Create: $model_name z $modelfile"
    ollama create "$model_name" -f "$MODELFILES/$modelfile"
  fi
done

log "=== Gotowe ==="
ollama list
