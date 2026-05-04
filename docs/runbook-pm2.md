# Runbook: pm2

Everything user-facing on these boxes runs under pm2. This is the note I
open when an app is flapping or a deploy did not take.

## The basics

    pm2 list
    pm2 logs <app> --lines 200
    pm2 describe <app>
    pm2 restart <app>
    pm2 reload <app>          # zero-downtime, if the app supports it
    pm2 restart all --update-env

`pm2 list` shows status, restart count, uptime and CPU/memory. The
restart count is the useful number: a counter that keeps climbing means
the process is crash-looping, not that it is busy.

## Zero-downtime reload

`pm2 reload` starts the new process and only drops requests once it is
listening. It requires the app to bind the same port successfully while
the old one is still up - which most apps cannot do - so for a single
port app `restart` is the honest choice. The window is a second or two.

For the web apps behind nginx, that is invisible. For the API apps it is
a brief blip, so schedule it.

## Environment

Each app has its own env file under its own directory. pm2 is started
with the environment from the shell it was launched in, so an app
started with the wrong shell can be missing variables.

    pm2 env <id> | grep NODE_ENV

If a variable looks wrong, delete the process and start it again from a
shell that has the right environment:

    pm2 delete <app>
    cd /path/to/app && pm2 start ecosystem.config.js --name <app>

## Logs

    pm2 logs <app> --lines 200 --nostream
    pm2 flush                    # empty all logs, frees disk

Logs are per-user under `~/.pm2/logs`. A runaway app can fill the disk
here rather than in `/var/log`, so check it during disk investigations.

## Restart loops

If an app is restarting every few seconds, look at the last error in the
log rather than the crash pattern:

    pm2 logs <app> --lines 50 --err --nostream

Common causes, in order of how often they turn out to be the cause:

1. A migration was applied that the running build does not know about.
2. The app cannot reach the database - check `db-health`, it exists for
   this.
3. Port already in use by the previous process that has not exited yet.

## Deploying

Deploys are a pull plus a restart, in that order. Never restart first:
the new process starts against the old schema and crashes.

    cd /path/to/app
    git pull --ff-only
    npm run build
    pm2 restart <app>

`--ff-only` matters. A merge commit left behind by a local experiment
will make `git pull` stop and leave the working tree in a state nobody
intended.
