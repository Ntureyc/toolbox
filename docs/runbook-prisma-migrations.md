# Runbook: Prisma migrations

## The rule that matters

A migration must work with the code that is currently running *and*
with the code that is about to run. Between `db:migrate` and the
restart there is a window where the running app talks to the migrated
database. If that migration is not backward compatible, the running app
breaks before the new code ever starts.

## Safe migrations

**Adding a column with a default** - safe. The old code ignores it.

    ALTER TABLE "user" ADD COLUMN "phone" TEXT;

**Adding a nullable column** - safe. The old code ignores it.

**Adding a NOT NULL column with no default** - NOT safe. The old code
inserts without it and fails immediately.

    -- instead:
    ALTER TABLE "user" ADD COLUMN "phone" TEXT;
    -- backfill
    UPDATE "user" SET "phone" = '' WHERE "phone" IS NULL;
    -- then enforce
    ALTER TABLE "user" ALTER COLUMN "phone" SET NOT NULL;

**Renaming a column** - NOT safe, because the old code still refers to
the old name. Do it in three deploys:

1. Add the new column, write to both, read from the old one.
2. Switch reads to the new column.
3. Drop the old column.

**Renaming a table** - same three-step shape.

**Dropping a column** - not safe in one step. Deploy the code that
stops using it first, drop the column in the next deploy.

## Type changes

Changing a column type rewrites the table and takes a lock. On a live
table that is a long pause. The safe pattern is: add the new column,
migrate the data in batches, switch the code, drop the old column.

For `text` to `varchar(n)` or `int` to `bigint`, do the widen-and-migrate
rather than an `ALTER ... TYPE`.

## Running one

    cd backend
    bun run db:migrate

`db:migrate` runs `prisma migrate deploy`, which applies pending
migrations and never prompts. That is what you want in a deploy.
`db:migrate:dev` is for local work and can reset the database. Do not
run the dev variant on a box with real data.

## Inspecting what is applied

    prisma migrate status

    psql "$DATABASE_URL" -c 'select * from "_prisma_migrations" order by finished_at desc limit 10;'

## When a migration fails halfway

Postgres runs each migration in a transaction, so a failed migration
leaves nothing behind. The `_prisma_migrations` table records the
failure. Fix the migration, then:

    prisma migrate resolve --applied <migration-name>   # if it actually succeeded
    prisma migrate resolve --rolled-back <migration-name> # if it did not

Do not edit the `_prisma_migrations` table by hand.

## The schema file

`backend/prisma/schema.prisma` is the source of truth. After changing it:

    bun run db:generate

This regenerates the client. A deploy that skips it runs new code
against an old client and fails in ways that look like a type error in
application code.
