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

**Is mudra sealing itself circular?** Asked and answered before the first ceremony rather than
discovered during it. No, cryptographically: `ssh-keygen -Y verify` is an external tool
unrelated to mudra's own code correctness, and the actual root of trust is the operator's
physical FIDO2 touch on the published bytes — identical whether mudra is checking its own
release or anyone else's. There is one narrow, real asymmetry worth naming, though: for every
other repo, the anchor lives in a *separate* git repository from mudra's own source, so a
compromise of mudra's code alone cannot also reach another repo's anchor. For mudra sealing
itself, the verifying code and the verified anchor sit in the *same* repo — mudra's own
git-history integrity is the one thing both halves of that particular self-check share. This
changes nothing about what the ceremony attests to (the operator's touch, not mudra's own
say-so) and isn't a reason to do anything differently — it's just the honest answer to whether
a wrinkle exists, not a reassurance that one doesn't.

## mudra's roster is wider than any one coordinator's charter

`DEFAULT_REPOS` tracks **nine** repos. REPO-STANDARD.md's `packaging/` convergence effort
covers **eight** of them (the five pills + gestalt + sutra + mudra) — that was the full set
alfred's own coordination charter spans (ByeByte, RAMstein, coldspot, gestalt, kast, mudra,
phanspeed, sutra), and every measurement of "is the family converged" naturally inherited that
boundary without anyone writing down that it existed. **rotten-apple is the ninth, and it was
never in that set.** It's Ra's house, not alfred's: a Rust workspace with no `VERSION` file at
all (its version lives in `Cargo.toml`'s `[workspace.package]`), and its anchor sits at the
pre-convergence root `release-signing/allowed_signers` — genuinely armed, real keys — **by
design, not by lag**. Unlike gestalt, there is nothing here that "converges" later; rotten-apple
simply isn't shaped like a `packaging/`-layout repo and was never going to be.

This mattered because a straddle that read "root, then packaging/" for every repo made the two
sets look like one set with a rollout in progress — which was true for eight repos and false
for the ninth, and nothing distinguished them. Ruling 23d9e8e4 (2026-08-01): a NAMED exception,
not a generic probe. `_ROOT_LAYOUT_REPOS = {"rotten-apple"}` in `src/bin/mudra` is the one
place this fact lives in code; `version_path()` / `anchor_file()` / `anchor_rel()` take a
single fixed `packaging/` path for everyone not in that set. A repo matching **neither**
shape — not the named exception, no `packaging/VERSION` either — reads `anchor:
"unrecognized-layout"`, a value `audit()` treats as a hard finding, never a silent `anchor:
"none"`. Silent invisibility on a real armed anchor is exactly the failure this replaced: the
straddle's own delete condition fired cleanly for the eight (gestalt converged last, `fa2297a`,
2026-08-01), and only got caught before shipping because the roster was diffed against the
FULL nine rows rather than the eight in the convergence report.

**If rotten-apple ever adopts `packaging/`**, remove it from `_ROOT_LAYOUT_REPOS` in the SAME
pass that its own layout flips — leaving it in the set after that would point mudra's read at a
directory that no longer holds the real anchor, blinding it in the opposite direction. That
decision belongs to Ra and the operator, not to mudra.

**A live constraint on testing mudra out-of-tree, found building this fix's negative control:**
`src/bin/mudra` resolves its own version from `packaging/VERSION` at import time, via
`_self_path` (three directories up from `__file__` — see "No stored state, by design", above).
That means a copy of the script only works sitting inside a real, repo-shaped checkout; drop it
somewhere else — an unrelated scratch directory, a `mktemp -d` — and it crashes before reaching
whatever you meant to test. Any future harness that patches or forks the script has to drop the
copy BESIDE the real file (never as it), not off in a temp dir.

## Standard exemptions

| Item | Why |
|---|---|
| `install.sh` / `uninstall.sh` | mudra installs through two independent, already-idempotent make targets — `make install-launcher` (desktop entry, no root) and `make install-polkit` (system polkit action, needs root once) — not a shell installer. There is nothing a wrapper script would install differently; adding one would just be a second thing to keep in sync with the Makefile. |
| rotten-apple's root-layout anchor | See "mudra's roster is wider than any one coordinator's charter", above — a permanent, named exception (`_ROOT_LAYOUT_REPOS`), not a temporary straddle. |
