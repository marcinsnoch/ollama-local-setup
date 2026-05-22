#!/usr/bin/env bash
# Konfiguruje Hermes Agent pod lokalne Ollama + MCP.
#
# Skrypt jest idempotentny:
# - robi backup ~/.hermes/config.yaml,
# - aktualizuje/scala istniejące sekcje YAML zamiast dopisywać duplikaty,
# - ustawia model główny, delegation i auxiliary na lokalne Ollama,
# - dodaje/aktualizuje MCP: filesystem, fetch, git, sqlite.
#
# Uruchomienie:
#   chmod +x ./03_add_mcp_to_hermes.sh
#   ./03_add_mcp_to_hermes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${HERMES_CONFIG:-$HOME/.hermes/config.yaml}"
SQLITE_CMD="${SQLITE_CMD:-$(find "$SCRIPT_DIR/venvs" -name mcp-server-sqlite -type f 2>/dev/null | head -1)}"
FILESYSTEM_SCOPE="${FILESYSTEM_SCOPE:-$HOME}"
MAIN_MODEL="${MAIN_MODEL:-qwen3:14b-ctx131072}"
FAST_MODEL="${FAST_MODEL:-qwen2.5:7b}"
CODING_MODEL="${CODING_MODEL:-deepseek-coder-v2:16b-ctx65536}"
GEMMA_MODEL="${GEMMA_MODEL:-gemma4:latest}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://127.0.0.1:11434/v1}"
PROVIDER_NAME="${PROVIDER_NAME:-ollama-launch}"

# Znajdź Python z Hermes venv; fallback do systemowego
HERMES_PYTHON=""
for _py in \
  "$HOME/.hermes/hermes-agent/venv/bin/python" \
  "$HOME/.hermes/hermes-agent/.venv/bin/python" \
  "$(command -v hermes 2>/dev/null && dirname "$(realpath "$(command -v hermes)")")/python" \
  "$(command -v python3)"; do
  if [ -n "$_py" ] && [ -x "$_py" ]; then
    HERMES_PYTHON="$_py"
    break
  fi
done
HERMES_PYTHON="${HERMES_PYTHON:-python3}"

if [ ! -f "$CONFIG" ]; then
  echo "BŁĄD: nie znaleziono configu: $CONFIG" >&2
  exit 1
fi

if [ ! -x "$SQLITE_CMD" ]; then
  echo "BŁĄD: brak sqlite MCP executable: $SQLITE_CMD" >&2
  echo "Najpierw uruchom: $SCRIPT_DIR/02_install_mcp_servers.sh" >&2
  exit 1
fi

BACKUP="$CONFIG.bak.ollama-setup.$(date +%Y%m%d_%H%M%S)"
echo "=== Hermes: konfiguracja Ollama + MCP ==="
echo "Config: $CONFIG"
echo "Backup: $BACKUP"
cp "$CONFIG" "$BACKUP"

"$HERMES_PYTHON" - "$CONFIG" "$SQLITE_CMD" "$FILESYSTEM_SCOPE" "$MAIN_MODEL" "$FAST_MODEL" "$CODING_MODEL" "$GEMMA_MODEL" "$OLLAMA_BASE_URL" "$PROVIDER_NAME" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except Exception as exc:
    raise SystemExit(f"Brak PyYAML w Pythonie ({sys.executable}): {exc}")

(
    config_path,
    sqlite_cmd,
    filesystem_scope,
    main_model,
    fast_model,
    coding_model,
    gemma_model,
    ollama_base_url,
    provider_name,
) = sys.argv[1:]

path = Path(config_path)
cfg = yaml.safe_load(path.read_text(encoding="utf-8")) or {}

# Model główny — context_length override na 64K (minimum Hermesa)
cfg.setdefault("model", {})
cfg["model"].update({
    "provider": provider_name,
    "base_url": ollama_base_url,
    "api_key": "ollama",
    "api_mode": "chat_completions",
    "context_length": 64000,
    "default": main_model,
})

# Provider lokalnego Ollama bez modeli cloud
cfg.setdefault("providers", {})
cfg["providers"][provider_name] = {
    "name": "Ollama",
    "api": ollama_base_url,
    "default_model": main_model,
    "models": [main_model, coding_model, fast_model, gemma_model],
}

# Zostaw custom provider jako lokalny alias, jeśli istnieje
for item in cfg.get("custom_providers") or []:
    if item.get("name") in {"Gemma Local", "Ollama Local"}:
        item.update({
            "name": "Ollama Local",
            "base_url": ollama_base_url,
            "api_mode": "chat_completions",
            "model": main_model,
        })

# Delegation/subagenci lokalnie
cfg.setdefault("delegation", {})
cfg["delegation"].update({
    "provider": provider_name,
    "base_url": ollama_base_url,
    "api_key": "ollama",
    "model": main_model,
})

# Auxiliary lokalnie tam, gdzie nie potrzeba vision/API zewnętrznych
cfg.setdefault("auxiliary", {})
aux_models = {
    "compression": main_model,
    "session_search": main_model,
    "mcp": main_model,
    "title_generation": fast_model,
}
for key, model in aux_models.items():
    cfg["auxiliary"].setdefault(key, {})
    cfg["auxiliary"][key].update({
        "provider": provider_name,
        "base_url": ollama_base_url,
        "api_key": "ollama",
        "model": model,
    })

# Model kompresji wymaga 64K context minimum — override dla modeli z <64K
cfg["auxiliary"].setdefault("compression", {})
cfg["auxiliary"]["compression"]["context_length"] = 64000

# MCP serwery
cfg["mcp_servers"] = {
    "fetch": {
        "command": "npx",
        "args": ["-y", "@yawlabs/fetch-mcp"],
    },
    "filesystem": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", filesystem_scope],
    },
    "git": {
        "command": "npx",
        "args": ["-y", "@cyanheads/git-mcp-server"],
    },
    "sqlite": {
        "command": sqlite_cmd,
        "args": ["--db-path", str(Path.home() / ".hermes/sqlite_mcp_server.db")],
    },
}

path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print("OK: zaktualizowano config YAML")
PY

# Hermes potrzebuje pakietu mcp w swoim venv do natywnego klienta MCP.
if [ -x "$HERMES_PYTHON" ]; then
  echo "=== Sprawdzam pakiet mcp w venv Hermesa ==="
  if ! "$HERMES_PYTHON" -c "import mcp" >/dev/null 2>&1; then
    if ! "$HERMES_PYTHON" -m pip --version >/dev/null 2>&1; then
      "$HERMES_PYTHON" -m ensurepip --upgrade
    fi
    "$HERMES_PYTHON" -m pip install --upgrade mcp
  fi
  "$HERMES_PYTHON" -c "import mcp; print('OK: mcp importuje się w venv Hermesa')"
else
  echo "UWAGA: nie znaleziono interpretera Pythona w venv Hermesa — pomijam instalację mcp"
fi

cat <<EOF

Gotowe.

Sprawdź bez restartu:
  hermes mcp list
  hermes mcp test filesystem
  hermes mcp test fetch
  hermes mcp test git
  hermes mcp test sqlite
  hermes config check

Aby nowe narzędzia i model weszły do aktualnej pracy agenta, zrestartuj Hermesa.
EOF
