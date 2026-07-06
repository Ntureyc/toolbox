# Notes: psql queries worth keeping

Running these by hand is common enough that writing them down is faster
than reconstructing them. All of them are read-only.

## Connect

    psql "$DATABASE_URL"

`psql` as the postgres user on the box:

    sudo -u postgres psql -d <dbname>

For the application database, the URL is the right way - it is the same
credentials the app uses, so what you see is what the app sees.

## Useful flags

    psql -X            # do not read ~/.psqlrc
    psql -c "..."      # one command, non-interactive
    psql -e            # echo the query before running it
    psql -c "..." -c "..."   # several commands, one connection

`-X` matters in scripts. A `~/.psqlrc` with `SET search_path` or
`	iming` changes the output.

## Who is connected

    select pid,
           usename,
           application_name,
           client_addr,
           state,
           now() - state_change as since
    from pg_stat_activity
    where datname = current_database()
      and pid <> pg_backend_pid();

An idle-in-transaction connection holds locks. Those are the ones to
kill:

    select pg_terminate_backend(<pid>);

## Long-running queries

    select pid,
           now() - query_start as runtime,
           left(query, 120) as query
    from pg_stat_activity
    where state <> 'idle'
      and query_start is not null
    order by query_start;

## Table sizes

    select relname,
           pg_size_pretty(pg_total_relation_size(relid)) as total,
           pg_size_pretty(pg_relation_size(relid)) as table_only,
           n_live_tup
    from pg_stat_user_tables
    order by pg_total_relation_size(relid) desc;

`n_live_tup` is an estimate from the statistics collector. It is
usually close enough to spot the table that grew, and `count(*)` is the
truth when it matters.

## Index usage

    select relname, indexrelname, idx_scan
    from pg_stat_user_indexes
    order by idx_scan asc;

An index with `idx_scan = 0` is pure write overhead. Worth checking
before dropping it - the scan may just not have happened yet.

## Sequences out of sync

After a bulk import the sequence is behind the primary key, and the next
insert fails with a duplicate key:

    select setval(pg_get_serial_sequence('"user"', 'id'),
                  coalesce((select max(id) from "user"), 1) + 1,
                  false);

## Things not to do

- `VACUUM FULL` on a live table. It takes an exclusive lock for the
  duration.
- Editing a table while a migration is running.
- `DELETE FROM` without a `WHERE`. Add `LIMIT 1` first, look at what
  came back, then drop the limit.
