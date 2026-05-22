#!/usr/bin/env bash
# Kopiuje AGENTS.md z bieżącego katalogu do ~/.config/agents/AGENTS.md
#
# Uruchomienie:
#   ./04_copy_agents_md.sh
#   # albo z innego katalogu:
#   ./04_copy_agents_md.sh /ścieżka/do/projektu
#
# Argument (opcjonalny): katalog z AGENTS.md, domyślnie bieżący.

set -euo pipefail

SRC_DIR="${1:-.}"
SRC_FILE="$SRC_DIR/AGENTS.md"
DST_DIR="$HOME/.config/agents"
DST_FILE="$DST_DIR/AGENTS.md"

if [ ! -f "$SRC_FILE" ]; then
  echo "Błąd: nie znaleziono $SRC_FILE" >&2
  exit 1
fi

mkdir -p "$DST_DIR"
cp "$SRC_FILE" "$DST_FILE"
echo "OK: skopiowano $(realpath "$SRC_FILE") -> $DST_FILE"
