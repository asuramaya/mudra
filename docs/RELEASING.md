# Releasing mudra

mudra is pre-1.0 and has never been tagged — this describes the process for when it is, not a
retrospective of one that already happened. Two people are involved and only one of them can
finish it: a maintainer prepares and tags, the operator signs by hand with a physical FIDO2
key. No automation can stand in for that step, and the signing key never goes near CI — the
same rule as every pill mudra itself seals.

## 1. Prepare

Bump `packaging/VERSION` — it's the one version constant; `src/bin/mudra` reads it directly at
import time (see [ARCHITECTURE.md](ARCHITECTURE.md)), so there's nothing else to keep in sync.

Write the `docs/CHANGELOG.md` entry for the release.

Run the checks:

```sh
make check    # check-repo (REPO-STANDARD.md's structure gate), then smoke
```

## 2. Tag and publish

```sh
git tag v0.X.Y && git push origin v0.X.Y
```

`.github/workflows/release.yml` verifies the tag matches `packaging/VERSION`, builds
`mudra.tar.gz` + `SHA256SUMS` via `git archive`, and creates or updates the GitHub release with
those two assets — **unsigned**. It refuses outright if `docs/CHANGELOG.md` has no section for
the version being tagged, rather than falling back to a generated commit dump. No `.deb`: see
[ARCHITECTURE.md](ARCHITECTURE.md#signing-itself) for why mudra's tarball is the whole artifact.
CI publishing unsigned artifacts, never signing them, is the whole point — a workflow that
could sign would make the GitHub account the trust root instead of the operator's hardware key.

## 3. The operator seals it

mudra tracks itself in its own roster (see `src/bin/mudra`'s `_self_path` resolution), so once
a release is published, mudra's own desk shows mudra as AWAITING SEAL exactly like any other
repo, and the ceremony runs the same way:

```sh
src/bin/mudra seal mudra --arm   # first release only — arms mudra's own anchor
```

or through the GUI, same as any card. The operator verifies the published bytes, signs the
checksum manifest offline with the FIDO2 key, and mudra uploads the detached signature and
verifies it back as an end user would.

## Rules that don't bend

* **A sealed release is never re-cut.** If something is wrong with it, the fix is the next
  version.
* **The signing key never enters CI**, in any form, for any reason.
* **Arming commits are scoped** to exactly the anchor file (+ an embedded `install.sh` twin,
  which mudra doesn't have) — never `git add -A`. See [SECURITY.md](../.github/SECURITY.md).
