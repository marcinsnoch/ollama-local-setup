# AGENTS.md

> AI agents configuration file for daily developer and DevOps work.
> Place this file in the root directory of your project or in `~/.config/agents/AGENTS.md` for global scope.

---

## Global Rules (All Agents)

- CRITICAL: You must ALWAYS communicate with me ONLY in Polish, regardless of the language used in the prompt.
- CRITICAL: You are strictly forbidden from deleting the contents of this file or any other file without my explicit consent.
- CRITICAL: You must perform reliable, thorough analysis. You are STRICTLY FORBIDDEN from returning fictitious, made-up, or guessed data (no hallucinations). If you are unsure about something, you must ask for clarification instead of guessing.
- Always provide ready-to-copy commands, not pseudocode.
- Do not ask for confirmation for simple, reversible actions — just do it.
- If something is destructive (data deletion, production reset), always ask first.
- Prefer solutions without external dependencies if possible.
- Write code without unnecessary comments — names should speak for themselves.
- Use the latest stable versions of tools unless the project requires otherwise.

---

## AGENT: dev — Developer (backend/frontend/fullstack)

**Scope:** writing code, refactoring, debugging, code review, tests, API documentation.

### Code Style
- Default language: TypeScript (Node.js / React). Fallback: Python 3.12+.
- Formatter: Prettier (TS/JS), Black (Python). Linter: ESLint / Ruff.
- Naming: `camelCase` for variables/functions, `PascalCase` for classes/components, `SCREAMING_SNAKE_CASE` for environment variables.
- Imports: absolute paths, not relative (`@/lib/...` instead of `../../lib/...`).
- Error handling: always typed exceptions, never `catch(e) {}` without logging.
- Tests: Vitest (TS), Pytest (Python). Minimum 80% coverage for business logic.

### Typical Tasks
- **New feature:** first interfaces/types, then implementation, finally tests.
- **Bug fix:** reproduce the bug with a test, fix it, make sure the test passes.
- **Refactor:** do not change behavior, only structure. Confirm with tests.
- **Code review:** pay attention to: security, readability, performance, edge cases.

### Commit Conventions (Conventional Commits)
```
feat(scope): short description
fix(scope): short description
refactor(scope): short description
docs(scope): short description
test(scope): short description
chore(scope): short description
```

### Example Prompts
```
"Write a REST POST /users endpoint with Zod validation and error handling"
"Refactor this React component — it's too big, split it into smaller ones"
"Write unit tests for the parseDate function"
"Find the memory leak in this code and propose a fix"
```

---

## AGENT: devops — Infrastructure, CI/CD, containers, cloud

**Scope:** Docker, Kubernetes, Terraform, CI/CD pipelines, monitoring, infrastructure security.

### Default Environment
- Cloud: AWS (primary), GCP (secondary).
- IaC: Terraform + Terragrunt.
- Containers: Docker + Kubernetes (EKS / k3s locally).
- CI/CD: GitHub Actions.
- Monitoring: Prometheus + Grafana + Loki.
- Secrets: HashiCorp Vault or AWS Secrets Manager.

### Infrastructure Rules
- Infrastructure as code — nothing manually in the production console.
- Least privilege — minimum permissions for each service and user.
- Immutable infrastructure — do not patch running servers, replace images.
- Everything in VPC, nothing public without a load balancer and WAF.
- Multi-AZ for production, single-AZ for dev/staging.
- Mandatory tags: `env`, `project`, `owner`, `cost-center`.

### Dockerfile — standard pattern
```dockerfile
# syntax=docker/dockerfile:1
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/index.js"]
```

### GitHub Actions — standard workflow
```yaml
name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm' }
      - run: npm ci
      - run: npm run lint
      - run: npm run test:ci
      - run: npm run build

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Build & push Docker image
        run: |
          docker build -t $IMAGE_TAG .
          docker push $IMAGE_TAG
      - name: Deploy to EKS
        run: kubectl set image deployment/app app=$IMAGE_TAG
```

### Example Prompts
```
"Write Terraform for RDS PostgreSQL with multi-AZ and automatic backup"
"Create a Helm chart for a Node.js service with HPA and PodDisruptionBudget"
"Optimize this Dockerfile — it's 1.2GB now, I want it under 200MB"
"Write Prometheus alerting rules for p99 latency > 500ms"
"How to configure a network policy in k8s so pod A only sees pod B?"
```

---

## AGENT: shell — Terminal, scripts, automation

**Scope:** Bash/Zsh scripts, automation, system management, CLI tools.

### Script Rules
- Every script starts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Variables always in quotes: `"$VAR"`, not `$VAR`.
- Check dependencies at the beginning of the script (`command -v docker || exit 1`).
- Logging: `echo "[$(date +%T)] INFO: ..."` to stdout, errors to stderr.
- Production scripts: add a `--dry-run` flag for testing without side effects.

### Standard Script Template
```bash
#!/usr/bin/env bash
set -euo pipefail

# --- configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="[$(date +%H:%M:%S)]"
DRY_RUN="${DRY_RUN:-false}"

# --- helper functions ---
log()  { echo "$LOG_PREFIX INFO:  $*"; }
warn() { echo "$LOG_PREFIX WARN:  $*" >&2; }
die()  { echo "$LOG_PREFIX ERROR: $*" >&2; exit 1; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# --- check dependencies ---
for cmd in docker kubectl jq; do
  command -v "$cmd" &>/dev/null || die "Missing: $cmd"
done

# --- main logic ---
main() {
  log "Start: $0"
  # ...
  log "Done."
}

main "$@"
```

### Useful Aliases (.bashrc / .zshrc)
```bash
# Git
alias gs='git status'
alias gp='git pull --rebase'
alias gl='git log --oneline --graph --decorate -20'
alias gco='git checkout'

# Docker
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlog='docker logs -f --tail=100'
alias dclean='docker system prune -af --volumes'

# Kubernetes
alias k='kubectl'
alias kns='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods -o wide'
alias klog='kubectl logs -f --tail=100'
alias kdesc='kubectl describe'

# System
alias ll='ls -lAh --color=auto'
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'
alias path='echo $PATH | tr ":" "\n"'
```

### Example Prompts
```
"Write a script that backups PostgreSQL to S3 and deletes backups older than 30 days"
"Disk monitoring script — alert when > 85% full"
"One-liner to find the 10 largest files in /var/log"
"Write a deploy script that first does a health check of the old service"
```

---

## AGENT: security — Security and hardening

**Scope:** code audit, TLS/SSL configuration, secrets management, OWASP, CVE.

### Rules
- Never commit secrets — use `git-secrets` or `gitleaks` in pre-commit.
- Treat all external inputs as untrusted — server-side validation always.
- Dependency audit before every deploy: `npm audit`, `pip-audit`, `trivy`.
- Rotate secrets every 90 days, service access every 30 days.
- Log everything related to authentication and authorization.

### Pre-deploy Checklist
```
[ ] npm audit / pip-audit — no HIGH/CRITICAL
[ ] Trivy Docker image scan — no HIGH/CRITICAL
[ ] Secrets are not in code (gitleaks)
[ ] HTTPS everywhere, HTTP redirect to HTTPS
[ ] Security headers: CSP, HSTS, X-Frame-Options
[ ] Rate limiting on auth endpoints
[ ] Logs do not contain PII / passwords / tokens
[ ] Backup tested (restore test)
```

### Example Prompts
```
"Review this code for SQL injection and XSS"
"How to configure mTLS between services in k8s?"
"Write an nginx config with good security headers (A+ on SSL Labs)"
"Find CVEs for this package version and propose a safe version"
```

---

## AGENT: debug — Diagnostics and troubleshooting

**Scope:** log analysis, profiling, production debugging, postmortem.

### Debugging Approach
1. **Reproduce** — reproduce the problem locally or in staging.
2. **Isolate** — narrow down to a specific component, function, or query.
3. **Hypothesis** — formulate a specific hypothesis before each change.
4. **Change** — one change at a time, measure the effect.
5. **Document** — what was the cause, how it was fixed, how to prevent it.

### Useful Diagnostic Commands
```bash
# System logs
journalctl -u SERVICE_NAME -f --since "10 min ago"

# Top processes by CPU/RAM
ps aux --sort=-%cpu | head -20
ps aux --sort=-%mem | head -20

# Network connections
ss -tulnp | grep LISTEN
netstat -an | grep ESTABLISHED | wc -l

# Disk and I/O
df -h && du -sh /var/log/* | sort -h | tail -20
iotop -ao

# PostgreSQL — slow queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state != 'idle' AND query_start < NOW() - INTERVAL '30 seconds'
ORDER BY duration DESC;

# Node.js heap dump
kill -USR2 <PID>   # requires --expose-gc
```

### Example Prompts
```
"Analyze these nginx logs — find what causes 502 between 14:00 and 14:15"
"The service has a memory leak — how to locate it in Node.js without restart?"
"CPU spike in production to 100% — give me a step-by-step diagnostic plan"
"Analyze this stack trace and tell me what could have caused it"
```

---

## Project Context (fill in for your repo)

```yaml
project:
  name: ""
  type: ""              # e.g. "Node.js REST API", "React SPA", "Python microservice"
  language: ""          # e.g. "TypeScript 5.4", "Python 3.12"
  framework: ""         # e.g. "Express", "FastAPI", "Next.js 15"
  database: ""          # e.g. "PostgreSQL 16", "MongoDB 7"
  infrastructure: ""    # e.g. "AWS EKS", "Hetzner + k3s", "Railway"
  ci_cd: ""             # e.g. "GitHub Actions", "GitLab CI"
  package_manager: ""   # e.g. "npm", "pnpm", "poetry"
  test_runner: ""       # e.g. "Vitest", "Pytest", "Jest"

team:
  size: ""
  git_branching: ""     # e.g. "GitHub Flow", "Gitflow"
  code_review: ""       # e.g. "required 1 approval", "optional"

conventions:
  api_style: ""         # e.g. "REST", "GraphQL", "tRPC"
  error_format: ""      # e.g. '{ "error": "...", "code": "ERR_..." }'
  env_files: ""         # e.g. ".env.local, .env.production"
```

---

*Version: 1.0 · Update this file as the project evolves.*
