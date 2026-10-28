# toolbox

Practical operational scripts, diagnostic utilities, and runbooks for servers and production applications.

Everything here is plain shell or single-file scripts with zero unnecessary dependencies. Built so that when something breaks at 2am, you can diagnose and fix it quickly and safely.

## Layout

    scripts/   production operational and diagnostic scripts (bash)
    configs/   reference config snippets (Nginx, PM2, etc.)
    docs/      runbooks and architecture notes
    src/       utility helpers and formatting tests (TypeScript / Bun)

## Conventions

- Scripts are POSIX-ish bash with `set -euo pipefail`.
- Scripts support `-h` / `--help` flags with clear usage instructions.
- Maintenance and database tasks support `--dry-run` modes before making destructive changes.
- Configurable via CLI flags and standard environment variables.

## Tools & Scripts

### System & Health Monitoring

| Script | What it does |
| --- | --- |
| [`scripts/system-info.sh`](scripts/system-info.sh) | Terminal dashboard of OS, Kernel, CPU, RAM, Disk, Network, and services |
| [`scripts/health-check.sh`](scripts/health-check.sh) | One-shot health verification of PM2 apps, HTTP endpoints, and system resources |
| [`scripts/disk-usage.sh`](scripts/disk-usage.sh) | Disk space breakdown, inode usage, top directories, and largest files |
| [`scripts/job-health.sh`](scripts/job-health.sh) | Audit systemd timers, crontabs, backup age, and PM2 log sizes |
| [`scripts/sys-cleanup.sh`](scripts/sys-cleanup.sh) | Safe cleanup of journal logs, package caches, old temp files, and Docker |

### Network & Security

| Script | What it does |
| --- | --- |
| [`scripts/port-audit.sh`](scripts/port-audit.sh) | Scan listening sockets and flag sensitive databases/caches exposed on `0.0.0.0` |
| [`scripts/ssl-inspect.sh`](scripts/ssl-inspect.sh) | Inspect remote TLS certificates, validity days, SANs, cipher, and TLS version |
| [`scripts/cert-expiry.sh`](scripts/cert-expiry.sh) | List Let's Encrypt certificates and highlight upcoming expirations |
| [`scripts/nginx-test.sh`](scripts/nginx-test.sh) | Validate Nginx configuration (`nginx -t`) and isolate broken vhosts |
| [`scripts/bench-http.sh`](scripts/bench-http.sh) | Dependency-free HTTP latency and throughput benchmarker with percentile breakdown |

### Deployment & Application Lifecycle

| Script | What it does |
| --- | --- |
| [`scripts/deploy-check.sh`](scripts/deploy-check.sh) | Pre-flight release checks: build artifacts, lockfile integrity, git branch state |
| [`scripts/pm2-restart-graceful.sh`](scripts/pm2-restart-graceful.sh) | Restart PM2 apps sequentially with health settlement checks |
| [`scripts/log-tail.sh`](scripts/log-tail.sh) | Filter noisy logs to isolate real errors, exceptions, and timeouts |
| [`scripts/next-build-check.sh`](scripts/next-build-check.sh) | Verify Next.js standalone outputs, `.next` bundles, and build environment vars |
| [`scripts/migrate-status.sh`](scripts/migrate-status.sh) | Non-destructive Prisma migration status and schema verification |
| [`scripts/env-audit.sh`](scripts/env-audit.sh) | Compare `.env` against `.env.example` to catch missing keys and weak secrets |
| [`scripts/git-cleanup.sh`](scripts/git-cleanup.sh) | Prune stale remote tracking branches, merged local branches, and run `git gc` |

### Database & Storage

| Script | What it does |
| --- | --- |
| [`scripts/psql-inspect.sh`](scripts/psql-inspect.sh) | Deep PostgreSQL diagnostics: connection states, cache hit %, table sizes, bloat |
| [`scripts/pg-backup.sh`](scripts/pg-backup.sh) | Logical Postgres backups with daily, weekly, and monthly hardlinked tiers |
| [`scripts/psql-daily-report.sh`](scripts/psql-daily-report.sh) | Daily database summary and high-level health report |

Runbooks live in `docs/` and are indexed in [`docs/index.md`](docs/index.md).
