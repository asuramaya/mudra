# Architecture

mudra is a single stdlib-only Python file (`src/bin/mudra`) that is both the CLI and the GUI
server. There is no daemon, no database, no build step. Its whole job is to derive a queue
from reality and hand the operator one desk to clear it.

## Repo map

```
src/bin/          mudra — the entire CLI + GUI server, one file
src/desktop/      mudra.desktop — the app-grid launcher (make install-launcher, no root)
src/polkit/       com.asuramaya.mudra.policy — the desk's polkit action (make install-polkit,
                   needs root once) — and its own README
packaging/        VERSION (the one version constant), sync-signers.sh (local, run only at the
                   operator's first-seal ceremony), release-signing/allowed_signers (ships
                   empty — see Signing itself, below)
tests/            smoke.sh — offline, fixture-only, no gh/network/real keys
docs/             this file, USAGE.md, RELEASING.md, CHANGELOG.md
.github/          ci.yml, release.yml, signing-sync.yml, SECURITY.md, CONTRIBUTING.md,
                   CODE_OF_CONDUCT.md
```

## No stored state, by design

Every other pill keeps a `status.json` seam between a daemon and its clients. mudra has
nothing to keep in sync because it never stores what it can re-derive:

- **The queue is derived from reality.** A published release with no `.sig` asset IS the
  "AWAITING SEAL" entry. An empty `allowed_signers` IS the unarmed state. A `VERSION` whose
  tag doesn't exist yet IS "seat's move, on GO." `mudra status` reads git, the filesystem, and
  (unless `--no-remote`) the GitHub API fresh on every call — there is nothing to invalidate,
  because nothing is cached across runs.
- **The only two files mudra writes for itself** are `~/.config/mudra/session.json` (the
  running serve's port + one-boot token, so `mudra open` needs no journalctl) and
  `~/.config/mudra/keymap.json` (which physical FIDO2 key handle N pairs with, learned on
  first successful seal). Both are pure conveniences; deleting either just means the next
  `mudra open`/seal re-derives or re-learns what it needs.

## The two roles that never overlap

`repo_state()` / `scan()` / `audit()` only ever **read**. `sync_signers()` and the `Ceremony`
class are the only two places mudra **writes** into a tracked repo, and each does exactly one
thing: `sync_signers` rebuilds an anchor from the canonical key home (rebuild-from-all, never
append, refuses on anything but exactly 4 keys); `Ceremony.seal` downloads the *published*
manifest, shells to `ssh-keygen -Y sign` against the operator's hardware key, uploads the
`.sig`, then re-downloads everything and verifies it back exactly as an end user's own install
would. mudra never has a code path that can sign without the operator's own physical touch —
see [SECURITY.md](../.github/SECURITY.md) for why that boundary is load-bearing.

## Signing itself

mudra tracks itself in its own roster (`_self_path`, above) and is not exempt from the
doctrine it enforces on the other eight repos — including this one. `packaging/release-signing/
allowed_signers` ships **empty** (the inert, pre-arming state every repo starts in) and
`packaging/sync-signers.sh` + `make sync-signers` exist to rebuild it, exactly like any pill,
but **arming is a decision, not a default**: nothing in this repo runs that script for you, and
it stays empty until the operator chooses to run mudra's own first sealing ceremony.
`.github/workflows/release.yml` builds a tarball + `SHA256SUMS` from a `vX.Y.Z` tag and
publishes both **unsigned** — CI never signs, for mudra exactly as for everything mudra itself
seals (see [SECURITY.md](../.github/SECURITY.md)). `.github/workflows/signing-sync.yml` checks
the anchor is well-formed (empty, or exactly 4 lines matching mudra's own principal/namespace) —
internal consistency only, since the canonical key home never reaches CI. No `.deb`: mudra is
not a pill (RELEASE.md's artifact ruling is scoped to the six pills that ship to end users) and
has nothing an installer would package differently from the tarball. See
[RELEASING.md](RELEASING.md) for the running order.

## Reading two tree layouts during the family's own rollout

REPO-STANDARD.md (2026-07-27) moved every pill's `VERSION` and `release-signing/` under
`packaging/`. mudra has to read whichever layout a given repo is currently on, since the
rollout lands one repo at a time: `version_path()` / `anchor_file()` / `anchor_rel()` check
root first, then `packaging/`, so an unmigrated repo never pays a stat for the newer path, and
`_uses_packaging_layout()` decides where a **first-ever** anchor gets created for a repo that
migrated `VERSION` but never armed before — without it, that anchor would silently reappear at
the old root, undoing the migration on the one file mudra itself writes.

**Delete condition, exact, not vague.** As of 2026-08-01 five of the six pills (kast,
coldspot, ByeByte, RAMstein, phanspeed) have converged to `packaging/VERSION` +
`packaging/release-signing/`; gestalt is the only repo left on the old root layout, with no
anchors at all yet. The straddle exists **solely for gestalt** now. Delete
`_uses_packaging_layout()` / `_first_existing()` and simplify `version_path()` /
`anchor_file()` / `anchor_rel()` back to a single fixed `packaging/` path the day gestalt
either converges or leaves the roster — not one day before, since that is the one repo that
would break. Check `mudra status` for gestalt's row before removing this.

## Standard exemptions

| Item | Why |
|---|---|
| `install.sh` / `uninstall.sh` | mudra installs through two independent, already-idempotent make targets — `make install-launcher` (desktop entry, no root) and `make install-polkit` (system polkit action, needs root once) — not a shell installer. There is nothing a wrapper script would install differently; adding one would just be a second thing to keep in sync with the Makefile. |
