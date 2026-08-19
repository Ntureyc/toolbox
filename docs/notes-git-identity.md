# Notes: git identity and where contributions land

A commit's contribution is attributed to the GitHub account that owns
the **author email** of the commit. Not the repo, not the pusher, not
the committer. The email is the whole thing.

This surprised me for a long time, because a repo you own shows commits
you did not write, and it looks like they should count for you. They
do not.

## The rule

Given a commit:

    author email  ->  GitHub account
    author date   ->  which day the square is filled in

Both come from the commit object. The committer fields do not affect
attribution at all.

## The three things that go wrong

**A different email.** Committing with `princekakku220@gmail.com` when
the repo is under `Ntureyc` credits the `princekakku220-lang` account.
The commits exist, the work was done, and the graph stays empty.

**An email that is not linked to any account.** `Ntureuc@gmail.com` -
note the capital U, a typo - resolves to nothing. The commits are
invisible on every profile including the author's own. 82 commits,
invisible.

**A noreply email that does not match the account id.** The noreply
form is `<numeric-id>+<login>@users.noreply.github.com`. If the id
does not match the account, it does not resolve to that account.

## Checking what resolves

    gh api repos/OWNER/REPO/commits?per_page=100 \
      --jq '.[] | "\(.commit.author.email) -> \(.author.login // "NONE")"'

`NONE` means the email is not linked to any account. That is the
signal to act on.

## Fixing it

Two options, and they are not exclusive.

**Change the identity used for new commits.** Set it once, globally:

    git config --global user.name "Ntureyc"
    git config --global user.email "ntureyc@gmail.com"

Check it took effect in a repo that has a local override:

    git -C <repo> config user.email

A local `user.email` in the repo's `.git/config` wins over the global
one, and that is the usual reason a global change appears to do
nothing.

**Add the address as a verified email on the account.** GitHub settings
-> Emails. This retroactively attributes existing commits, because
attribution is resolved from the email at read time, not at write time.
A commit made a year ago starts counting the moment the address is
verified.

## Attribution of already-pushed commits

The history is not rewritten. The author field stays as it was. What
changes is which account the commit belongs to when GitHub resolves it.
So adding the address as a verified email fixes existing commits
without a force push, without changing SHAs, and without touching
anyone's clone.

That is the cheap fix and it is worth doing before rewriting anything.

## Backdating

A commit's author date is what decides the day. Setting it to a past
date puts the square on that past day:

    GIT_AUTHOR_DATE="2026-10-27T12:00:00+06:00" \
    GIT_COMMITTER_DATE="2026-10-27T12:00:00+06:00" \
    git commit --allow-empty -m "message"

Two details:

- The **offset matters**. GitHub buckets by the local date as recorded.
  A commit stored at `2026-10-27T12:00:00+06:00` is Oct 27. The same
  instant stored as `+00:00` is still Oct 27, but a commit at
  `2026-10-28T00:30:00+06:00` is Oct 28 in local time and Oct 27 in
  UTC. Pick a time in the middle of the day so both readings agree.
- Set both dates. Author and committer. There is no reason to leave
  them different, and differing them makes it ambiguous which one
  GitHub used.

## What actually counts

- Commits on the **default branch** count.
- Commits on a feature branch do not, until they are merged.
- Commits in a **private** repo count for the author, but a collaborator's
  commits in your private repo count for them.
- Squash merges count as one commit. The individual commits are gone.
- A **merge commit** counts as a commit in its own right.

## Verifying

    gh api graphql -f query='
    { viewer { contributionsCollection(from:"2026-10-25T00:00:00Z", to:"2026-10-28T00:00:00Z") {
        contributionCalendar { weeks { contributionDays { date contributionCount } } } } } }'

The counts show up immediately for public repos. Private repos can
take a little longer to appear.
