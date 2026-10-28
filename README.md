# toolbox

Practical operational scripts, diagnostic utilities, and runbooks for servers and production applications.

Everything here is plain shell or single-file scripts with zero unnecessary dependencies. Built so that when something breaks at 2am, you can diagnose and fix it quickly and safely.

## Layout

    scripts/   production operational and diagnostic tools (each in its own directory)
    configs/   reference config snippets (Nginx, PM2, etc.)
    docs/      runbooks and architecture notes
    src/       utility helpers and formatting tests (TypeScript / Bun)

Each tool inside `scripts/<tool>/` includes:
- `<tool>.sh`: Standalone POSIX-ish bash script
- `README.md`: Detailed documentation, requirements, options table, and examples
- `preview.png`: Visual terminal screenshot of the tool in action

## Conventions

- Scripts are POSIX-ish bash with `set -euo pipefail`.
- Every script supports `-h` / `--help` flags with clear usage instructions.
- Maintenance and database tasks support `--dry-run` modes before making destructive changes.
- Configurable via CLI flags and standard environment variables.

---

## Tools & Scripts

### System & Health Monitoring

| Tool | What it does | Docs & Showcase |
| --- | --- | --- |
| [`system-info`](scripts/system-info/system-info.sh) | Terminal dashboard of OS, Kernel, CPU, RAM, Disk, Network, and services | [README](scripts/system-info/README.md) · [Preview](scripts/system-info/preview.png) |
| [`health-check`](scripts/health-check/health-check.sh) | One-shot health verification of PM2 apps, HTTP endpoints, and system resources | [README](scripts/health-check/README.md) · [Preview](scripts/health-check/preview.png) |
| [`disk-usage`](scripts/disk-usage/disk-usage.sh) | Disk space breakdown, inode usage, top directories, and largest files | [README](scripts/disk-usage/README.md) · [Preview](scripts/disk-usage/preview.png) |
| [`job-health`](scripts/job-health/job-health.sh) | Audit systemd timers, crontabs, backup age, and PM2 log sizes | [README](scripts/job-health/README.md) · [Preview](scripts/job-health/preview.png) |
| [`sys-cleanup`](scripts/sys-cleanup/sys-cleanup.sh) | Safe cleanup of journal logs, package caches, old temp files, and Docker | [README](scripts/sys-cleanup/README.md) · [Preview](scripts/sys-cleanup/preview.png) |

### Network & Security

| Tool | What it does | Docs & Showcase |
| --- | --- | --- |
| [`port-audit`](scripts/port-audit/port-audit.sh) | Scan listening sockets and flag sensitive databases/caches exposed on `0.0.0.0` | [README](scripts/port-audit/README.md) · [Preview](scripts/port-audit/preview.png) |
| [`ssl-inspect`](scripts/ssl-inspect/ssl-inspect.sh) | Inspect remote TLS certificates, validity days, SANs, cipher, and TLS version | [README](scripts/ssl-inspect/README.md) · [Preview](scripts/ssl-inspect/preview.png) |
| [`cert-expiry`](scripts/cert-expiry/cert-expiry.sh) | List Let's Encrypt certificates and highlight upcoming expirations | [README](scripts/cert-expiry/README.md) · [Preview](scripts/cert-expiry/preview.png) |
| [`nginx-test`](scripts/nginx-test/nginx-test.sh) | Validate Nginx configuration (`nginx -t`) and isolate broken vhosts | [README](scripts/nginx-test/README.md) · [Preview](scripts/nginx-test/preview.png) |
| [`bench-http`](scripts/bench-http/bench-http.sh) | Dependency-free HTTP latency and throughput benchmarker with percentile breakdown | [README](scripts/bench-http/README.md) · [Preview](scripts/bench-http/preview.png) |

### Deployment & Application Lifecycle

| Tool | What it does | Docs & Showcase |
| --- | --- | --- |
| [`deploy-check`](scripts/deploy-check/deploy-check.sh) | Pre-flight release checks: build artifacts, lockfile integrity, git branch state | [README](scripts/deploy-check/README.md) · [Preview](scripts/deploy-check/preview.png) |
| [`pm2-restart-graceful`](scripts/pm2-restart-graceful/pm2-restart-graceful.sh) | Restart PM2 apps sequentially with health settlement checks | [README](scripts/pm2-restart-graceful/README.md) · [Preview](scripts/pm2-restart-graceful/preview.png) |
| [`log-tail`](scripts/log-tail/log-tail.sh) | Filter noisy logs to isolate real errors, exceptions, and timeouts | [README](scripts/log-tail/README.md) · [Preview](scripts/log-tail/preview.png) |
| [`next-build-check`](scripts/next-build-check/next-build-check.sh) | Verify Next.js standalone outputs, `.next` bundles, and build environment vars | [README](scripts/next-build-check/README.md) · [Preview](scripts/next-build-check/preview.png) |
| [`migrate-status`](scripts/migrate-status/migrate-status.sh) | Non-destructive Prisma migration status and schema verification | [README](scripts/migrate-status/README.md) · [Preview](scripts/migrate-status/preview.png) |
| [`env-audit`](scripts/env-audit/env-audit.sh) | Compare `.env` against `.env.example` to catch missing keys and weak secrets | [README](scripts/env-audit/README.md) · [Preview](scripts/env-audit/preview.png) |
| [`git-cleanup`](scripts/git-cleanup/git-cleanup.sh) | Prune stale remote tracking branches, merged local branches, and run `git gc` | [README](scripts/git-cleanup/README.md) · [Preview](scripts/git-cleanup/preview.png) |

### Database & Storage

| Tool | What it does | Docs & Showcase |
| --- | --- | --- |
| [`psql-inspect`](scripts/psql-inspect/psql-inspect.sh) | Deep PostgreSQL diagnostics: connection states, cache hit %, table sizes, bloat | [README](scripts/psql-inspect/README.md) · [Preview](scripts/psql-inspect/preview.png) |
| [`pg-backup`](scripts/pg-backup/pg-backup.sh) | Logical Postgres backups with daily, weekly, and monthly hardlinked tiers | [README](scripts/pg-backup/README.md) · [Preview](scripts/pg-backup/preview.png) |
| [`psql-daily-report`](scripts/psql-daily-report/psql-daily-report.sh) | Daily database summary and high-level health report | [README](scripts/psql-daily-report/README.md) · [Preview](scripts/psql-daily-report/preview.png) |
| [`eps-reconcile`](scripts/eps-reconcile/eps-reconcile.sh) | Query stuck payment records and surface unhandled callback anomalies | [README](scripts/eps-reconcile/README.md) · [Preview](scripts/eps-reconcile/preview.png) |
| [`router-status`](scripts/router-status/router-status.sh) | Inspect PPPoE subscriber session counts and router accounting | [README](scripts/router-status/README.md) · [Preview](scripts/router-status/preview.png) |

---

Runbooks live in `docs/` and are indexed in [`docs/index.md`](docs/index.md).
