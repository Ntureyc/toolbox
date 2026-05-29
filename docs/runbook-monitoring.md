# Runbook: monitoring and alerting

What is watched, and what to do when it fires.

## What is watched

| Signal | Where | Meaning |
| --- | --- | --- |
| App status | pm2 | process not online, or restart counter climbing |
| HTTP health | `/api/health` | app up but cannot reach the database |
| Disk usage | node exporter | logs filling the disk |
| Certificate expiry | certbot timer | TLS about to expire |
| Payment stuck | eps reconcile | EPS payment not reaching a final state |
| Container memory | docker stats | a build container eating the box |

## The health endpoint

`/api/health` does more than return 200. It checks the database
connection and returns the check result. That is deliberate: a process
that is up but cannot reach Postgres answers `/` perfectly and fails
every real request, and the only cheap way to catch that is a health
endpoint that touches the dependency.

The response is shaped like:

    { "status": "ok", "database": "ok", "uptime": 12345 }

so a monitor can check `database` rather than just the status code.

## Reading a pm2 alert

A restart count that grows by one every few seconds is a crash loop.
Get the actual error:

    pm2 logs <app> --lines 50 --nostream --err

The first error in the log is usually the cause. Later lines are the
same error repeated.

## Disk

The usual cause is a log file nobody rotates. pm2 keeps its logs under
`~/.pm2/logs`, and those are not covered by the system logrotate
config.

    du -sh ~/.pm2/logs
    pm2 flush

Disk at 100% causes Postgres to refuse writes and the apps to fail in
ways that look like application bugs.

## Alerting

Alerts that cannot be acted on get muted, and then they get ignored
entirely. Each alert needs a runbook link and a named owner.

The order of preference for a check:

1. Something a human looks at.
2. Something that pages.
3. A dashboard nobody reads.

Most things should be the first one.

## Adding a check

Put it in `scripts/` with a non-zero exit on failure, then point
whatever is running the checks at it. Exit codes are the interface -
the script should be usable from cron without any parsing.
