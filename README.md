# toolbox

Small, practical scripts and runbooks for the servers I look after.

Everything here is plain shell or a single-file script with no framework
attached. The goal is that when something breaks at 2am I can find the
command I need without guessing.

## Layout

    scripts/   one-off operational scripts (bash, mostly)
    configs/   config snippets meant to be copied and adapted
    docs/      runbooks and notes
    src/       small TypeScript helpers that need a runtime

## Conventions

- Scripts are POSIX-ish bash, `set -euo pipefail`, and take flags rather
  than positional arguments.
- Anything that touches a database or a deploy takes `--dry-run` first.
- Runbooks are written as numbered steps. If a step needs a command that
  only makes sense on one box, the runbook says which box.

## Contents

| Script | What it does |
| --- | --- |
| `scripts/health-check.sh` | One-shot check of the services that should always be up |
| `scripts/nginx-test.sh` | Validate every nginx vhost and show which one is broken |
| `scripts/cert-expiry.sh` | List certificates with days remaining |
| `scripts/pm2-restart-graceful.sh` | Restart pm2 apps one at a time, waiting for each to settle |
| `scripts/pg-backup.sh` | Logical Postgres backup with retention and compression |

Runbooks live in `docs/` and are indexed in `docs/index.md`.
