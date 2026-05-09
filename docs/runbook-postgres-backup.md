# Runbook: Postgres backup and restore

## Why logical dumps and not a volume copy

A `pg_dump` gives a portable, restorable file that can be read on
another machine. A raw copy of the data directory only works if the
destination has the exact same major version and the copy was taken
while Postgres was shut down. Dumps it is.

## Taking a dump

    pg_dump --format=custom --compress=9 --file=app_$(date +%F).dump "$DATABASE_URL"

`--format=custom` is compressed and supports selective restore, which
plain SQL text does not. `--compress=9` matters: the uncompressed dump
of the main database is several times larger.

Note the difference between two dates here. `date +%F` is the date on
the machine, so the file name says when the dump was taken. Good.

## Restoring

    createdb -T template0 restored
    pg_restore --dbname=restored --no-owner --exit-on-error app_2026-05-09.dump

`--no-owner` because the dump records the role that made it, and that
role does not exist on the target box. `--exit-on-error` so a partial
restore fails loudly instead of leaving a half-populated database that
looks fine until the first query.

## Verify before trusting it

A dump that restores cleanly but is missing rows is worse than no dump,
because it is trusted. Check the row count of the tables that matter:

    psql -d restored -c 'select count(*) from users;'

Compare against the source. If the counts differ, do not switch the
application over.

## Retention

Keep daily dumps for two weeks, weekly for two months, monthly for a
year. The script in `scripts/pg-backup.sh` handles this.

## What is not covered

Logical dumps do not capture roles, tablespaces, or settings. Those live
in the cluster configuration and are restored separately. For a single
database on a single box this does not matter much, but keep a copy of
`postgresql.conf` and the list of roles somewhere outside the box:

    pg_dumpall --globals-only > globals.sql

## Offsite copies

A backup on the same disk as the database is not a backup. Copy the
dumps off the machine - and check that the copy job is actually
running, not just configured.
