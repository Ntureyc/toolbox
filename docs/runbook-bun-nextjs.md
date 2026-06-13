# Notes: Bun and Next.js in production

The apps run under Bun with Next.js on the front end. A few things are
worth writing down because they cost time to rediscover.

## Why Bun

Startup time and install time, mostly. The API services are NestJS and
the build output runs under `bun run dist/main.js` rather than `node`.
The runtime is interchangeable - the output is JavaScript - so the
portability is not a concern.

## Next.js standalone output

The frontend build is configured for standalone output. That produces
`dist/standalone/` with a minimal `node_modules` containing only what
is actually imported. It makes the deploy artefact much smaller.

The catch: standalone output does not copy `.next/static` or `public/`
into the standalone directory. They have to be copied next to it:

    cp -r .next/static dist/standalone/.next/static
    cp -r public dist/standalone/public

Miss that and the app serves HTML with no CSS and no images, which looks
like a broken deployment rather than a missing directory.

## `next start` versus a static export

The frontend runs with `next start -p 3012`. It is a Node server
serving a hybrid app, not a static export, so it needs the port and the
pm2 process. A static export would be simpler but the app has server
actions, so it cannot be one.

## Environment variables

Next.js inlines `NEXT_PUBLIC_*` variables **at build time**. A variable
that is set in the environment but missing at build time is baked into
the bundle as `undefined`, and setting it later does not help.

    NEXT_PUBLIC_API_URL=https://api.example.com bun run build

This is the single most common cause of "the frontend is calling the
wrong API". The value has to be right when the build runs, not when
the process starts.

Server-only variables are read at runtime and behave normally.

## Build memory

`next build` on a machine with a lot of apps running can get OOM-killed.
It is a large build. Options, in order of preference:

1. Build on a machine with more memory and copy the artefact over.
2. Build with a lower concurrency setting.
3. Stop the other apps for the duration.

## `next lint` and the lockfile

The lockfile is authoritative. `bun install --frozen-lockfile` in CI and
`bun install` locally. A lockfile that drifts between environments
means the thing that was tested is not the thing that ships.

## Ports

The web apps each take a port, and the port is in the pm2 ecosystem
file and in the nginx vhost. When they disagree, nginx returns 502 and
the app looks broken when it is fine.

The health check in `scripts/health-check.sh` reads the ports from the
vhost, so a mismatch shows up there.
