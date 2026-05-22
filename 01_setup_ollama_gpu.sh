#!/bin/bash
# Konfiguracja GPU dla Ollama (systemd override)
#
# Uwaga: uruchom jako root (sudo).
#
# Instrukcja:
#   sudo chmod +x ./01_setup_ollama_gpu.sh
#   sudo ./01_setup_ollama_gpu.sh

set -euo pipefail

OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OVERRIDE_CONF="$OVERRIDE_DIR/override.conf"

echo "=== Ollama: ustawienia GPU (systemd override) ==="

sudo mkdir -p "$OVERRIDE_DIR"

sudo tee "$OVERRIDE_CONF" > /dev/null << 'EOF'
[Service]
# Ścieżka modeli
Environment="OLLAMA_MODELS=/mnt/Working/OllamaModels"

# Offload na GPU
Environment="OLLAMA_NUM_GPU=999"
Environment="CUDA_VISIBLE_DEVICES=0"

# Szybsze inference (jeśli wspierane przez Twoją konfigurację)
Environment="OLLAMA_FLASH_ATTENTION=1"

# KV cache mniej pamięciożerny
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"

# Wiele modeli załadowanych jednocześnie (główny + subagenci)
Environment="OLLAMA_MAX_LOADED_MODELS=3"
Environment="OLLAMA_NUM_PARALLEL=3"
EOF

echo "OK: zapisano $OVERRIDE_CONF"

echo "=== Przeładowanie systemd ==="
sudo systemctl daemon-reload

echo "=== Restart Ollama ==="
sudo systemctl restart ollama

echo "=== Weryfikacja (status) ==="
if systemctl is-active --quiet ollama; then
  echo "Ollama: DZIAŁA"
else
  echo "Ollama: NIEAKTYWNA (sprawdź logi: journalctl -u ollama -n 80)"
fi

echo "=== Weryfikacja (GPU w logach) ==="
journalctl -u ollama --no-pager -n 80 | grep -i "offloading\|CUDA\|GPU" | tail -n 30 || true

echo "=== Gotowe ==="
