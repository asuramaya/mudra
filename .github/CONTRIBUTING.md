# Contributing to mudra

mudra drives the family's release-signing ceremony. Contributions that keep its trust
boundary small — it never holds key material, every signature is the operator's own physical
touch — are very welcome.

Before changing much, read [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md). mudra is a single
stdlib-only Python file with no daemon and no stored state beyond two small convenience
files; most of what looks like it should be "config" is actually derived fresh from git and
the GitHub API on every call, on purpose.

## Setup

```bash
git clone https://github.com/asuramaya/mudra
cd mudra
make check      # check-repo + smoke — no root, no gh, no real keys, no network
make serve      # http://127.0.0.1:7770
```

## The checks

Same ones CI runs:

```bash
make check-repo    # REPO-STANDARD.md's structural gate
make smoke          # tests/smoke.sh — offline, fixture-only, throwaway keys
```

`make check` runs both. Neither touches your real `~/.ssh/asuramaya-master` key home, a real
repo in `~/code/REPOS`, or the network — `tests/smoke.sh` builds its own throwaway fixtures
and keys under a temp directory.

## Style

stdlib only, deliberately — no third-party dependency, ever. Python stays readable over clever;
this file has no test framework of its own to hide behind, so a broken invariant here should
be loud, not swallowed.

Every code path that could write into a tracked repo (`sync_signers`, `Ceremony.seal`) stages
and commits *exactly* the files that ceremony owns — never `git add -A`. See
[SECURITY.md](SECURITY.md) for why that's non-negotiable rather than a style preference.

## Pull requests

Open one against `main`. CI has to pass. If you change behaviour, update
[docs/USAGE.md](../docs/USAGE.md) and add a `docs/CHANGELOG.md` entry. Small, focused PRs get
looked at fastest.

Each document has an owner: `README.md` answers what a stranger needs before installing,
`docs/USAGE.md` covers everything after, `docs/ARCHITECTURE.md` explains how it's built. A
fact that lands in two of them will drift.

## Releasing

Not covered here. See [docs/RELEASING.md](../docs/RELEASING.md) — a release involves a
hardware key and a person, and getting the order wrong can affect every installed pill that
trusts mudra's ceremony.
