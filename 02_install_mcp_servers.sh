#!/usr/bin/env bash
# Instalacja/weryfikacja MCP serwerów dla Hermes Agent.
#
# Ten skrypt nie modyfikuje konfiguracji Hermesa. Instaluje tylko zależności:
#   - Node/npx MCP: filesystem, fetch, git
#   - Python MCP: sqlite w dedykowanym venv
#
# Uruchomienie:
#   chmod +x ./02_install_mcp_servers.sh
#   ./02_install_mcp_servers.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"
VENV_DIR="$BASE_DIR/venvs/mcp-sqlite"
PYTHON_BIN="${PYTHON_BIN:-python3}"

NPM_PACKAGES=(
  "@modelcontextprotocol/server-filesystem"
  "@yawlabs/fetch-mcp"
  "@cyanheads/git-mcp-server"
)

log() { printf '\n==> %s\n' "$*"; }
warn() { printf 'UWAGA: %s\n' "$*" >&2; }
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'BŁĄD: brak komendy: %s\n' "$1" >&2
    exit 1
  fi
}

log "Sprawdzam wymagane komendy"
need_cmd node
need_cmd npm
need_cmd npx
need_cmd "$PYTHON_BIN"

log "Sprawdzam, czy pakiety MCP istnieją w npm (żeby uniknąć 404)"
for pkg in "${NPM_PACKAGES[@]}"; do
  version="$(npm view "$pkg" version --silent 2>/dev/null || true)"
  if [ -z "$version" ]; then
    printf 'BŁĄD: pakiet npm nie istnieje albo npm nie ma dostępu: %s\n' "$pkg" >&2
    exit 1
  fi
  printf 'OK: %s@%s\n' "$pkg" "$version"
done

log "Przygotowuję venv dla sqlite MCP: $VENV_DIR"
mkdir -p "$(dirname "$VENV_DIR")"
if [ ! -x "$VENV_DIR/bin/python" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
  "$VENV_DIR/bin/python" -m ensurepip --upgrade
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install --upgrade mcp mcp-server-sqlite

log "Weryfikuję sqlite MCP w venv"
"$VENV_DIR/bin/python" - <<'PY'
import importlib.util
missing = [name for name in ("mcp", "mcp_server_sqlite") if importlib.util.find_spec(name) is None]
if missing:
    raise SystemExit("Brak modułów w venv: " + ", ".join(missing))
print("OK: mcp i mcp_server_sqlite są dostępne")
PY

if [ ! -x "$VENV_DIR/bin/mcp-server-sqlite" ]; then
  printf 'BŁĄD: brak executable: %s\n' "$VENV_DIR/bin/mcp-server-sqlite" >&2
  exit 1
fi

log "Opcjonalna informacja o globalnych instalacjach npm"
# Nie instalujemy globalnie na siłę. Hermes używa npx -y, więc globalna instalacja nie jest wymagana.
npm list -g --depth=0 "${NPM_PACKAGES[@]}" 2>/dev/null || true

cat <<EOF

Gotowe.

Następny krok:
  chmod +x "$SCRIPT_DIR/03_add_mcp_to_hermes.sh"
  "$SCRIPT_DIR/03_add_mcp_to_hermes.sh"

Po restarcie Hermesa sprawdź:
  hermes mcp list
  hermes mcp test filesystem
  hermes mcp test fetch
  hermes mcp test git
  hermes mcp test sqlite
EOF
