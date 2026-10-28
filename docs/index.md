# Runbooks

Start here.

| Runbook | Read it when |
| --- | --- |
| [deploy.md](deploy.md) | You are about to deploy something |
| [prisma-migrations.md](prisma-migrations.md) | The release changes the schema |
| [nginx-tls.md](nginx-tls.md) | A domain returns 502 or a bad certificate |
| [pm2.md](pm2.md) | An app is flapping or a restart did not take |
| [postgres-backup.md](postgres-backup.md) | Setting up or restoring backups |
| [monitoring.md](monitoring.md) | An alert fired and you need to know what it means |

## Notes

| Notes | About |
| --- | --- |
| [payments.md](payments.md) | EPS and COD state machines, and the re-check rule |

## The order of a deploy

    pull -> install -> build -> migrate -> restart -> verify

Pull first. Build second. Migrate third. Restart fourth. Verify last,
and verify against the health endpoint rather than the exit code of the
restart command.

## When something is broken and you do not know what

1. Is it one app or everything? `scripts/health-check.sh`.
2. Is it the app or the proxy? Check the upstream port directly.
3. Is it the app or the database? The health endpoint checks the
   database. If `/api/health` reports the database as down, nothing
   else matters until that is fixed.
4. Did a deploy just happen? Check the restart counters and the deploy
   log.

## Conventions in these documents

- Commands are run from your project directory (e.g. `/var/www/<app>` or `~/apps/<app>`).
- Anything destructive is marked as such.
- When a runbook says "check the logs", it means:

      pm2 logs <app> --lines 100 --nostream

  and reading from the top, because the first error is the cause.
