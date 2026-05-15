# Runbook: deploying

The shape of a deploy is the same everywhere: build, migrate, restart,
verify. The order is the part that matters.

## The order

1. **Pull first.**

       cd /path/to/app
       git pull --ff-only

   A deploy that builds before pulling deploys the old code. The order
   that breaks things is: build, then pull, then restart. Now you have
   new binaries and old code, or the reverse, and the restart picks up
   whichever happened last.

2. **Install dependencies.**

       bun install --frozen-lockfile

   `--frozen-lockfile` is the point. Without it a lockfile drift gets
   silently resolved to new versions, and the deploy that was tested
   against pinned versions is not what ships.

3. **Build.**

       bun run build

   For the NestJS services this is `nest build`; for the Next.js apps
   it is `next build`. Both write to `dist/`.

4. **Migrate, if the release includes migrations.**

       bun run db:migrate

   See `docs/runbook-prisma-migrations.md`. Migrations run *before* the
   new code starts. A migration that is not backward compatible with the
   running version will take the app down.

5. **Restart.**

       pm2 restart <app>

6. **Verify.** Not "the restart command returned 0". Actually check:

       pm2 logs <app> --lines 50 --nostream
       curl -fsS https://<domain>/api/health

   The health endpoint hits the database on purpose. A process that is up
   but cannot reach Postgres will answer `/` fine and fail every real
   request.

## Zero downtime

The web apps sit behind nginx, so a restart is a blip that clients do
not notice. The API apps answer directly, so a restart is a visible
error for a second or two. Do API deploys when usage is low.

## Rollback

Rollback is a pull, not a re-deploy. Tag the release before deploying
so there is something to go back to:

    git tag -a deploy-$(date +%Y%m%d-%H%M) -m "deploy $(date -Is)"

To roll back:

    git checkout deploy-20260515-1430
    bun install --frozen-lockfile
    bun run build
    pm2 restart <app>

If the release included a migration, rolling back the code alone is not
enough. The schema is now ahead of the code. Either write a forward
migration that undoes it, or accept that the rollback is code-only.

## Deploys that changed the schema

Any release that touches `schema.prisma` needs the migration and the
deploy planned together. See the Prisma runbook.
