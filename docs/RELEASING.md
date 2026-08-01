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

## 2. The operator arms — BEFORE the tag, not after

One command, the CLI or the desk's own **ARM** button (works on any unarmed repo, tag or no
tag — that is the entire point of it being separate from seal):

```sh
src/bin/mudra arm mudra
```

previews which 4 keys are about to be written, asks for confirmation ("arming pins the master
identity fail-closed *forever*"), then rebuilds the anchor and makes the SCOPED commit + push
in one act. Or, the manual three-step version underneath it, if you want to see each act on
its own:

```sh
make sync-signers                                              # writes the anchor, nothing else
git add -- packaging/release-signing/allowed_signers
git commit -m "arm release verification: pin the master identity"
git push
```

Either way this step is the operator's, at their hand — `KEY_HOME` is
`~/.ssh/asuramaya-master`, outside every repo. `make sync-signers` alone only WRITES
`packaging/release-signing/allowed_signers`; it never commits or pushes on its own, which is
why `arm` exists as the one-shot version — the scoped commit is a separate, deliberate act
either way, exactly as [SECURITY.md](../.github/SECURITY.md) requires.

**Why before the tag, and not folded into the seal ceremony afterward:** `.github/workflows/
release.yml` builds `mudra.tar.gz` via `git archive` from the TAGGED commit, and that archive
carries `packaging/release-signing/allowed_signers` as tracked content — the same file a
downloader would check a signature against. Arm after tagging and the published tarball's own
anchor is still empty; arm before, and the first sealed release is self-verifying from birth.
This is exactly RELEASE.md's "arm before tag" rule, and exactly coldspot's original mistake
(its first sealed tarball shipped a pre-arming installer) — mudra has no `install.sh` twin to
get that wrong, but the tarball's own anchor file is the equivalent exposure.

Once armed, the anchor stays `armed` — nothing later in this runbook re-arms it.

## 3. Tag and publish

```sh
git tag v0.X.Y && git push origin v0.X.Y
```

`.github/workflows/release.yml` verifies the tag matches `packaging/VERSION`, builds
`mudra.tar.gz` + `SHA256SUMS` via `git archive` — now carrying the armed anchor — and creates
or updates the GitHub release with those two assets — **unsigned**. It refuses outright if
`docs/CHANGELOG.md` has no section for the version being tagged, rather than falling back to a
generated commit dump. No `.deb`: see [ARCHITECTURE.md](ARCHITECTURE.md#signing-itself) for why
mudra's tarball is the whole artifact. CI publishing unsigned artifacts, never signing them, is
the whole point — a workflow that could sign would make the GitHub account the trust root
instead of the operator's hardware key.

## 4. The operator seals it

mudra tracks itself in its own roster (see `src/bin/mudra`'s `_self_path` resolution), so once
a release is published, mudra's own desk shows mudra as AWAITING SEAL exactly like any other
repo, and the ceremony runs the same way:

```sh
src/bin/mudra seal mudra   # refuses if the anchor isn't armed yet — step 2 already handled that
```

or the desk's own **SEAL** button, which only appears once a repo is both armed and AWAITING
SEAL. The operator verifies the published bytes, signs the checksum manifest offline with the
FIDO2 key, and mudra uploads the detached signature and verifies it back as an end user would.

## Rules that don't bend

* **A sealed release is never re-cut.** If something is wrong with it, the fix is the next
  version.
* **The signing key never enters CI**, in any form, for any reason.
* **Arming commits are scoped** to exactly the anchor file (+ an embedded `install.sh` twin,
  which mudra doesn't have) — never `git add -A`. See [SECURITY.md](../.github/SECURITY.md).
