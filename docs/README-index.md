# Repository layout and conventions

## Where things go

    scripts/     one script per job. Named after what they do.
    configs/     templates to copy and adapt. Not applied automatically.
    docs/        runbooks and notes. One file per topic.
    src/         small TypeScript helpers. Bun runtime, bun test.

A script that needs arguments has a `--help` that says what they are.

## Commit messages

Conventional commits, one line, lowercase after the type:

    feat(scripts): add router-status.sh
    fix(deploy): use --ff-only so a dirty tree stops the pull
    docs(runbook): explain the EPS re-check rule

The scope is the area, not the file. `feat(scripts)` for anything in
scripts/, `docs(runbook)` for a runbook, `feat(src)` for the TypeScript.

## Script rules

- `set -euo pipefail` at the top.
- Fail loudly. If a check cannot run, exit non-zero rather than
  printing a reassuring message.
- Everything destructive takes `--dry-run` or a `DRY_RUN=1` environment
  variable, and the dry run prints exactly what it would do.
- No network calls without a timeout.
- Prefer `printf` over `echo` - `echo` behaviour varies between shells
  when the argument looks like a flag.

## Documentation rules

- Write the runbook for the person who is on call, not for the person
  who wrote the code. Assume less context than feels natural.
- Every command says where to run it.
- Every step that can fail says what the failure looks like.
- No steps that depend on a specific machine's local state without
  saying so.

## Why the toolbox is separate from the apps

Runbooks that live next to the code they describe get deleted when the
code is rewritten. These survive, and they are useful when the problem
is in a different service than the one you have open.
