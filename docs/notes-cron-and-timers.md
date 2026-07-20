# Notes: cron, timers, and the jobs that quietly stop

The recurring jobs are the part of a box that fails quietly. Nothing
alerts when a cron job stops running, and the symptom appears days
later as missing data.

## What runs where

| Job | Schedule | What it does |
| --- | --- | --- |
| store sync | every 10 min | pushes store data to the API |
| certbot renew | daily 03:00 | renews certificates |
| log rotation | hourly | trims pm2 and nginx logs |
| backup | daily 02:30 | Postgres dump, see the backup runbook |
| uptime | every 5 min | external check, writes to a status file |

## Reading the schedule

    crontab -l
    ls /etc/cron.d/
    systemctl list-timers --all

The third one is the one people forget. systemd timers are not crontab
entries and do not show up in `crontab -l`.

    systemctl list-timers --all | grep <job>
    systemctl status <job>.timer
    journalctl -u <job>.service --since "24 hours ago"

`journalctl` on the unit is the only reliable way to know a timer job
ran. Cron mail is usually not delivered anywhere.

## The difference between cron and a timer

A systemd timer runs a service unit. The service has its own logs in
the journal, its own exit status, and can be restarted without
affecting the schedule. A cron job is a shell line whose output goes
to a mail spool nobody reads.

For anything that has to be reliable, a timer is the better shape.

## Timezones

    timedatectl

If the box is on UTC and the schedule was written assuming local time,
a job intended for 03:00 runs at 03:00 UTC, which is 09:00 in Dhaka.
Cron inherits the system timezone. A timer has an explicit
`OnCalendar=` which is also system timezone unless it says otherwise.

DST does not apply in Bangladesh, so the boxes do not shift. Worth
noting anyway for anything that might move.

## Making a job loud

A job that fails silently is the failure mode to design against. Each
one should do one of:

- Write a status file that something else checks.
- Exit non-zero and have the unit marked failed.
- Send to a channel someone actually reads.

## Idempotency

Every one of these jobs runs again five minutes later if something
restarts. They must be safe to run twice.

- The store sync upserts. It does not append.
- The backup writes a dated file and prunes by age. Running twice
  leaves one file.
- The log rotation truncates. Running twice is fine.

## Failure drills

Turn a job off and see whether anything notices.

    systemctl stop <job>.timer

If nothing complains, that job is decorative. That is worth knowing
before it silently stops for a different reason later.
