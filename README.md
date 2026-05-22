# Ollama + lokalny model + MCP + Hermes

Ten katalog służy do odtworzenia lokalnego setupu Ollama + Hermes Agent po reinstalacji albo do ponownej konfiguracji obecnego systemu.

Katalog roboczy:

```text
$HOME/ollama-setup/
```

Cel konfiguracji:

- Ollama działa lokalnie na `127.0.0.1:11434`
- Hermes używa lokalnego providera Ollama
- główny model: `qwen3:14b-ctx131072` (bazowy `qwen3:14b` z `num_ctx 131072`)
- model do kodu dostępny w katalogu providera: `deepseek-coder-v2:16b`
- szybki model pomocniczy: `qwen2.5:7b`
- `model.context_length: 64000` — override dla głównego modelu (wymóg Hermesa)
- `auxiliary.compression.context_length: 64000` — override dla modelu kompresji
- MCP: filesystem, fetch, git, sqlite
- sqlite MCP działa w osobnym venv, bez systemowego `pip install`

## Aktualny stan po poprawkach

Sprawdzone na tym systemie:

- Ollama API działa
- Główny model: `qwen3:14b-ctx131072` (num_ctx: 131072)
- Hermes config wskazuje na `ollama-launch`
- `model.context_length: 64000` override dla głównego modelu
- `auxiliary.compression.context_length: 64000` override dla kompresji
- `mcp` jest zainstalowane w venv Hermesa
- `hermes mcp list` widzi: `filesystem`, `fetch`, `git`, `sqlite`
- `hermes mcp test filesystem/fetch/git/sqlite` przechodzi poprawnie

Uwaga: `kimi-k2.6:cloud` może być nadal widoczny w samej Ollamie, ale został usunięty z lokalnego providera Hermesa. Dzięki temu Hermes nie powinien wybierać go jako modelu lokalnego.

## Struktura katalogu

```text
$HOME/ollama-setup/
├── README.md
├── AGENTS.md                        # globalny plik agenta (dev/devops/shell/security/debug)
├── 01_setup_ollama_gpu.sh           # systemd GPU override dla Ollamy
├── 02_install_mcp_servers.sh        # instalacja zależności MCP (npm + venv)
├── 03_add_mcp_to_hermes.sh          # konfiguracja Hermes config.yaml
├── 04_copy_agents_md.sh             # kopiuje AGENTS.md do ~/.config/agents/
├── 05_restore_models.sh             # pull modeli bazowych + create custom
├── modelfiles/
│   ├── qwen3-14b.ctx131072.modelfile      # qwen3:14b-ctx131072 (num_ctx 131072)
│   └── deepseek-coder-v2.ctx65536.modelfile # deepseek-coder-v2:16b-ctx65536 (num_ctx 65536)
└── venvs/
    └── mcp-sqlite/   # tworzony przez 02_install_mcp_servers.sh
```

## Wymagania po świeżej instalacji systemu

```bash
sudo apt update
sudo apt install -y curl git nodejs npm python3 python3-venv python3-pip pipx sqlite3
```

Sprawdzenie podstaw:

```bash
ollama --version
node --version
npm --version
npx --version
python3 --version
hermes --version
```

Jeśli Ollama nie jest zainstalowana, zainstaluj ją zgodnie z oficjalną instrukcją Ollama.

## Szybkie odtworzenie (pełna reinstalacja systemu)

Po świeżej instalacji systemu, sklonuj/copy ten katalog z backupu, a następnie:

```bash
# 1. Zainstaluj podstawowe pakiety
sudo apt update
sudo apt install -y curl git nodejs npm python3 python3-venv python3-pip pipx sqlite3

# 2. Zainstaluj Ollama (oficjalny skrypt)
curl -fsSL https://ollama.com/install.sh | sh

# 3. Przywróć config Hermesa z backupu (najważniejsze!)
#    cp /ścieżka/do/backupu/config.yaml ~/.hermes/config.yaml
#    cp /ścieżka/do/backupu/.env ~/.hermes/.env

# 4. GPU + systemd (opcjonalnie, jeśli używasz usługi systemd)
sudo chmod +x $HOME/ollama-setup/01_setup_ollama_gpu.sh
sudo $HOME/ollama-setup/01_setup_ollama_gpu.sh

# 5. Zainstaluj MCP zależności
chmod +x $HOME/ollama-setup/02_install_mcp_servers.sh
$HOME/ollama-setup/02_install_mcp_servers.sh

# 6. Pull modeli bazowych + utwórz modele z większym kontekstem
chmod +x $HOME/ollama-setup/05_restore_models.sh
$HOME/ollama-setup/05_restore_models.sh

# 7. Skonfiguruj Hermes pod lokalne modele (jeśli nie przywróciłeś config.yaml z backupu)
chmod +x $HOME/ollama-setup/03_add_mcp_to_hermes.sh
$HOME/ollama-setup/03_add_mcp_to_hermes.sh

# 8. Weryfikacja
hermes mcp list
hermes mcp test filesystem
hermes mcp test fetch
hermes mcp test git
hermes mcp test sqlite
```

Po zmianach konfiguracji zamknij aktualną sesję Hermesa i uruchom `hermes` ponownie.

## 01_setup_ollama_gpu.sh

Skrypt zapisuje override systemd dla usługi `ollama`:

- `OLLAMA_MODELS=/mnt/Working/OllamaModels`
- `OLLAMA_NUM_GPU=999`
- `CUDA_VISIBLE_DEVICES=0`
- `OLLAMA_FLASH_ATTENTION=1`
- `OLLAMA_KV_CACHE_TYPE=q8_0`

Uruchamiaj tylko wtedy, gdy Ollama działa jako usługa systemd:

```bash
sudo $HOME/ollama-setup/01_setup_ollama_gpu.sh
```

Jeśli Ollama działa jako zwykły proces użytkownika, ten skrypt może nie być potrzebny.

Sprawdzenie:

```bash
curl -s http://127.0.0.1:11434/api/tags
ollama list
nvidia-smi
journalctl -u ollama --no-pager -n 80 | grep -i "offloading\|CUDA\|GPU" || true
```

## 02_install_mcp_servers.sh

Skrypt:

- sprawdza, czy pakiety npm istnieją, zanim cokolwiek instaluje
- przygotowuje venv: `$HOME/ollama-setup/venvs/mcp-sqlite`
- instaluje/aktualizuje `mcp` i `mcp-server-sqlite` w tym venv
- nie modyfikuje `~/.hermes/config.yaml`

Pakiety Node używane przez Hermes przez `npx -y`:

- `@modelcontextprotocol/server-filesystem`
- `@yawlabs/fetch-mcp`
- `@cyanheads/git-mcp-server`

Celowo nie używamy tych nazw, bo potrafią dawać 404 w npm:

- `@modelcontextprotocol/server-fetch`
- `@modelcontextprotocol/server-git`
- `@modelcontextprotocol/server-memory`

Uruchomienie:

```bash
$HOME/ollama-setup/02_install_mcp_servers.sh
```

## 03_add_mcp_to_hermes.sh

Skrypt jest idempotentny. Robi backup configu i aktualizuje YAML zamiast dopisywać drugą sekcję `mcp_servers`.

Konfiguruje:

- `model.provider = ollama-launch`
- `model.default = qwen3:14b-ctx131072`
- `model.base_url = http://127.0.0.1:11434/v1`
- `model.context_length = 64000`
- `delegation` na lokalne Ollama
- `auxiliary.compression/session_search/mcp/title_generation` na lokalne Ollama
- `auxiliary.compression.context_length = 64000`
- `mcp_servers.fetch`
- `mcp_servers.filesystem`
- `mcp_servers.git`
- `mcp_servers.sqlite`

Uruchomienie:

```bash
$HOME/ollama-setup/03_add_mcp_to_hermes.sh
```

Domyślny zakres filesystem MCP to `$HOME`.

Możesz zawęzić zakres tak:

```bash
FILESYSTEM_SCOPE=$HOME/EasyRobots $HOME/ollama-setup/03_add_mcp_to_hermes.sh
```

## 04_copy_agents_md.sh

Kopiuje `AGENTS.md` z katalogu projektu do `~/.config/agents/AGENTS.md` (centralna lokalizacja dla agentów AI).

```bash
# z bieżącego katalogu
$HOME/ollama-setup/04_copy_agents_md.sh

# z konkretnego projektu
$HOME/ollama-setup/04_copy_agents_md.sh $HOME/WebProjects/mmis2
```

## 05_restore_models.sh

Pulluje bazowe modele z Ollama Registry i tworzy warianty z większym kontekstem z modelfiles. Idempotentny — pomija modele, które już istnieją.

```bash
$HOME/ollama-setup/05_restore_models.sh
```

Pullowane modele: `qwen3:14b`, `deepseek-coder-v2:16b`, `qwen2.5:7b`, `gemma4:latest`
Tworzone modele: `qwen3:14b-ctx131072`, `deepseek-coder-v2:16b-ctx65536`

Możesz też wskazać inne modele:

```bash
MAIN_MODEL=qwen3:14b-ctx131072 \
FAST_MODEL=qwen2.5:7b \
CODING_MODEL=deepseek-coder-v2:16b-ctx65536 \
$HOME/ollama-setup/03_add_mcp_to_hermes.sh
```

## Sprawdzenie konfiguracji Hermesa

```bash
hermes config check
hermes mcp list
hermes mcp test filesystem
hermes mcp test fetch
hermes mcp test git
hermes mcp test sqlite
```

Sprawdzenie modelu po restarcie Hermesa:

```bash
hermes chat -q "Jakiego modelu i providera używasz? Odpowiedz krótko."
```

Test narzędzi po restarcie:

```bash
hermes chat -q "Użyj narzędzi, żeby wypisać pliki w $HOME/EasyRobots i krótko podsumuj strukturę."
```

## Modele i Modelfile

W katalogu `modelfiles/` są przykładowe Modelfile dla większego kontekstu.

### qwen3:14b-ctx131072 (aktualnie używany)

```bash
ollama create qwen3:14b-ctx131072 -f $HOME/ollama-setup/modelfiles/qwen3-14b.ctx131072.modelfile
```

### deepseek-coder-v2:16b-ctx65536

```bash
ollama create deepseek-coder-v2:16b-ctx65536 -f $HOME/ollama-setup/modelfiles/deepseek-coder-v2.ctx65536.modelfile
```

Uwaga: większy kontekst mocno zwiększa zużycie VRAM/RAM. Dla stabilnej pracy agentowej zacznij od standardowych modeli `qwen3:14b` i `deepseek-coder-v2:16b`.

## Typowe problemy

### Hermes nie widzi MCP

1. Sprawdź, czy pakiet `mcp` jest w venv Hermesa:

```bash
$HOME/.hermes/hermes-agent/venv/bin/python -c "import mcp; print('mcp ok')"
```

2. Sprawdź listę MCP:

```bash
hermes mcp list
```

3. Zrestartuj Hermesa. Zmiany MCP nie muszą wejść do już działającej sesji.

### 404 przy npm

Nie zgaduj nazw pakietów. Sprawdź:

```bash
npm view @modelcontextprotocol/server-filesystem version
npm view @yawlabs/fetch-mcp version
npm view @cyanheads/git-mcp-server version
```

### PEP 668 / externally-managed-environment

Nie instaluj `mcp-server-sqlite` systemowym pipem. Użyj venv tworzonego przez:

```bash
$HOME/ollama-setup/02_install_mcp_servers.sh
```

### Web search w Hermes doctor pokazuje ostrzeżenia

To normalne, jeśli nie masz zewnętrznych kluczy EXA/Tavily/Firecrawl. MCP `fetch` pobiera konkretne URL, ale nie jest pełną wyszukiwarką internetową.

## Bezpieczeństwo

Filesystem MCP daje Hermesowi dostęp do katalogu ustawionego w `FILESYSTEM_SCOPE`.

Domyślnie:

```text
$HOME
```

Bezpieczniej można zawęzić do projektu:

```bash
FILESYSTEM_SCOPE=$HOME/EasyRobots $HOME/ollama-setup/03_add_mcp_to_hermes.sh
```

## Co warto backupować

- `$HOME/ollama-setup/`
- `$HOME/.hermes/config.yaml`
- `$HOME/.hermes/.env`
- `/mnt/Working/OllamaModels/` albo lista modeli z `ollama list`

## Finalna checklista

- [ ] Ollama działa: `curl -s http://127.0.0.1:11434/api/tags`
- [ ] `qwen3:14b-ctx131072` jest dostępny: `ollama list | grep qwen3`
- [ ] sqlite MCP venv istnieje: `$HOME/ollama-setup/venvs/mcp-sqlite/bin/mcp-server-sqlite`
- [ ] Hermes ma `mcp`: `$HOME/.hermes/hermes-agent/venv/bin/python -c "import mcp"`
- [ ] `hermes mcp list` pokazuje 4 serwery
- [ ] `hermes mcp test ...` przechodzi dla wszystkich serwerów
- [ ] Hermes został zrestartowany po zmianach
# ollama-local-setup
