# Changelog

## 0.8.0 — the key setup wizard (2026-08-02)

The desk's rarest, highest-stakes act finally has a facilitator: `keysetup`, a wizard for
the 4 canonical handles themselves, one notch above sealing. Two acts, per slot:
**this is the plugged-in key** just registers whichever device is connected right now as
handle N — no generation, no touch, the manual version of the mapping a successful seal
already learns on its own — and **GENERATE**/**REGENERATE** mints a brand-new
hardware-backed key straight onto a slot via `ssh-keygen -t ed25519-sk -O resident` (PIN
dialog, then TOUCH). mudra's own rule holds even here: `-O resident` keeps the private
half on the token, non-extractable; only the public half and a local handle stub (useless
without the physical key present) ever touch disk. Regenerating an OCCUPIED slot asks a
distinctly scarier question than an empty one — it permanently retires whatever device was
registered there, and every anchor already armed with its old public half needs re-arming,
family-wide, so it refuses outright without an explicit `force` (CLI) or extra confirmation
(GUI). Reachable from the CLI (`keysetup`, `keysetup --slot N [--force]`,
`keysetup --map N`) and from the desk's header (**manage keys**, next to the key picker).
Ceremony.keysetup shares the same single-flight lock as arm and seal — it's the third act
writing into shared state (the key home this time, not a repo), not a fourth exception to
the rule.

Also in this release: `MUDRA_KEYMAP_PATH` joins the rest of mudra's env overrides
(`MUDRA_KEY_HOME`, `MUDRA_REPO_ROOT`, ...) — found necessary while writing this feature's
own smoke coverage, since `keysetup`/`seal` are the only code paths that ever call
`learn_key()`, and until now nothing sandboxed where that write landed. A smoke run on any
machine with a real hardware key plugged in (this one, as it turned out, mid-development)
would otherwise have silently mapped that real device to a test fixture's throwaway slot
in the operator's actual `~/.config/mudra/keymap.json`.

Fixed before this ever ran for real: `keysetup`'s generation used a single shared
`application=ssh:mudra` for every slot. The real 4 keys already in `~/.ssh/asuramaya-master/`
each carry their own per-slot RP ID (`ssh:asuramaya-master-N`, visible in a hardware key's
own credential manager, not just mudra's view of it) — caught by comparing the two before
`keysetup` was ever used to mint anything. Now matches: `application=ssh:asuramaya-master-{slot}`.

## 0.1.0 — the seal desk opens (2026-07-19)

- Derived-from-reality release queue: published-release-without-.sig IS the
  queue entry; empty anchor IS the unarmed state; VERSION-without-tag IS the
  seat's pending move. No stored state, nothing to drift.
- `status` / `audit` (family invariants: same 4 canonical keys in every armed
  anchor, embedded install.sh twins byte-identical, principals/namespaces
  sane; audit fails only on broken invariants, never on dev-cycle dirt).
- Canonical `sync-signers`: rebuild-from-all from ~/.ssh/asuramaya-master,
  refuses != 4 keys, refreshes anchor + single-quoted embedded twin in one act.
- `seal` ceremony (CLI and GUI): optional arming (explicit consent — pins the
  master identity fail-closed forever), download the PUBLISHED manifest, sign
  via ssh-keygen against the hardware key (the touch stays human), upload the
  .sig, then verify-back the full end-user path (hash chain + signature).
- Local GUI (`serve`, 127.0.0.1 only): family cards, AWAITING SEAL queue,
  live ceremony log, the TOUCH YOUR KEY banner. Family palette.
- Offline smoke: fixtures + throwaway keys; no gh, no network, no hardware.

## 0.1.1 — the seal goes GUI-native (2026-07-19)

- FIDO2 PIN collection moves to a zenity askpass dialog (SSH_ASKPASS_REQUIRE=force):
  ceremony #1 failed fighting for a TTY inside the HTTP thread; the browser is
  now the only place the operator looks — click, PIN dialog, touch.
- Subprocesses get stdin=/dev/null when no input is piped — no more accidental
  terminal interaction from the serve window.

## 0.1.2 — the key picker (2026-07-19)

- Seal cards grow a 🔑 1-4 selector (remembered): handle N pairs with physical
  key N, and signing with a handle whose key is not the one plugged in fails as
  "invalid format" AFTER the touch — the desk now says so in the log hint and
  lets the operator pick the inserted key. CLI: seal --key N.
- Header subtitle removed.

## 0.2.0 — the desk knows your keys (2026-07-19)

- Physical-key auto-detection ladder: serial fingerprint (the 5Cs) or model
  fingerprint (the one serial-less Security Key), LEARNED on first successful
  seal with a picked key — ~/.config/mudra/keymap.json, no setup. GUI shows
  "🔑 N detected" and preselects it. Floor stays manual pick + safe retry:
  the authenticator enforces handle↔credential, a wrong pick only fails clean.
- Desk token: serve prints a one-boot tokened URL; loopback is any-local-user
  reachable, the token keeps the desk single-operator (cookie after first visit).

## 0.2.1 — the scoped arm (2026-07-19)

- SECURITY: the arming commit adds ONLY release-signing/allowed_signers (+
  install.sh when an embedded twin exists) — never `git add -A`. 0.1.x swept a
  seat's untracked session files (.claude/, .mcp.json) into the public
  coldspot repo during ceremony #1; no credentials exposed (local paths and
  a localhost URL only), history rewritten out by the operator's hand.

## 0.3.0 — the whole estate on one desk (2026-07-19)

- Roster grows sutra and rotten-apple (operator order): entries with a "/" are
  paths (rotten-apple lives outside REPO_ROOT), display name = basename.
- VERSION fallback to Cargo.toml for Rust-workspace repos.

## 0.3.1 — manifest dialects (2026-07-19)

- Manifest detection accepts SHA256SUMS (Debian convention, preferred for
  multi-artifact releases — phanspeed ships deb+tarball under one manifest)
  alongside <artifact>.sha256; sig = <manifest>.sig either way. The desk had
  mislabeled phanspeed v0.30.1 "NO MANIFEST (broken)" for speaking the better
  dialect.

## 0.3.2 — byte-identical twins (2026-07-19)

- sync-signers writes the embedded install.sh copy BYTE-IDENTICAL to the
  anchor file, trailing newline included (tjmax's find: the omitted newline
  false-drifted every byte-for-byte CI compare — coldspot's signing-sync was
  red on both post-arming pushes because of it).

## 0.3.3 — one key control (2026-07-19)

- The 🔑 dropdown IS the indicator now: it turns green when the selection
  matches the detected key; the separate "detected" chip is gone.

## 0.3.4 — polkit gate on top of the token (2026-07-27)

- Opening the desk's token URL for the first time (minting a session cookie)
  now also has to clear a polkit check (`com.asuramaya.mudra.open-desk`,
  `auth_self_keep`) — the operator's real fingerprint/password prompt on the
  operator's own screen, layered on top of the URL token rather than
  replacing it. Already-cookied requests (the GUI's status/log polling) are
  never re-prompted. Fails CLOSED on a real denial; fails OPEN with a loud
  warning only when the action isn't installed yet (`make install-polkit`,
  needs root — see polkit/README.md), so a fresh checkout never locks itself
  out before its first install step.

## 0.3.5 — no command to remember (2026-07-27)

- `mudra open` reads the running serve's session (written atomically,
  0600, to ~/.config/mudra/session.json on every boot) and launches the
  default browser straight into an authenticated desk — no journalctl,
  no copy-pasted token URL. Dead/stale session detected via the recorded
  pid, with a clear one-line fix instead of a silent bad open.
- desktop/mudra.desktop + `make install-launcher` (no root) puts a real
  app-grid icon on it — the point of a desk is dodging bash incantations,
  not adding new ones to memorize.

## 0.3.6 — mudra tracks itself (2026-07-27)

- Roster grows a ninth entry: mudra. It is not exempt from the doctrine it
  enforces on the other eight — its own card now shows real anchor/tag
  state (currently: never tagged, anchor none, same "seat's move" bucket
  as any other pre-first-release repo). Resolved via the running script's
  own path, not an assumed REPO_ROOT/mudra, so a relocated checkout or a
  MUDRA_REPO_ROOT override doesn't point the self-entry at nothing.

## 0.3.7 — quieter footer (2026-07-27)

- Dropped the mission-statement tagline from the page footer (operator:
  "a bit cringe" — fair). Just the version now; the doctrine still lives
  in README.md/FAMILY.md where it belongs, not repeated as page chrome.

## 0.3.8 — the rest of the cringe sweep (2026-07-27)

- Launcher and page <title> both just say "mudra" now, not "mudra — the
  seal desk" (same trim as the footer).
- Dropped decorative emoji throughout: the ⚔ on "armed" chips, 🔑 in the
  key picker and "learned this device" log line (plain "Key N" now), the
  ✓ and shouting on the ceremony's success line ("sealed: ..." not
  "SEALED ✓ ..."), and 👆 on the touch prompts. TOUCH YOUR KEY NOW keeps
  its caps — genuine UX reason (the one moment you can't miss) and the
  page JS keys off the literal substring "TOUCH" to show the banner —
  just lost the finger.
- "scanning the family…" → "scanning releases…": internal team jargon
  cut from a string an external/public user would actually read.

## 0.3.9 — reads both layouts (2026-07-27)

- REPO-STANDARD.md (2026-07-27) moves VERSION and release-signing/ under
  packaging/ as part of a twelve-row root; kast adopted it first and
  vanished from the queue ("v? anchor=none no VERSION") since both paths
  were hardcoded at repo root. version_path()/anchor_file()/anchor_rel()
  now check root then packaging/, root first so an unmigrated repo never
  pays a stat for the newer path (alfred, live-fixed while I was away,
  handed back uncommitted for review — see decision graph).
- Fixed one latent case in the handoff before committing: a repo that has
  migrated VERSION but never armed before (gestalt: anchor=none today)
  would have had its FIRST anchor created back at the old root — silently
  reintroducing root clutter on the one file mudra itself writes. Fresh-
  anchor creation now checks packaging/VERSION's presence to pick the
  layout, not a fixed default.
- New smoke fixture (fakepackaged) covers both: reading VERSION from
  packaging/, and a first-ever arm landing under packaging/ instead of
  root. Neither was exercised by the existing fixture, which is exactly
  why the gap wasn't caught before.

## 0.3.10 — the smoke test finally runs (2026-08-01)

- .github/workflows/ci.yml: `make smoke` on every push/PR. tests/smoke.sh
  already covered the dangerous paths (sync-signers rebuild, the 3-key
  refusal, audit catching divergence, the packaging/ layout's first-ever-
  arm placement) — the gap alfred found (msg 2549) wasn't coverage, it was
  that nothing on the desk that seals nine repos ever invoked it. Deliberately
  just the trigger, nothing else from REPO-STANDARD's twelve-row convergence
  (src/ fold, docs/, community files, check-repo) — that's hygiene queued
  for its own pass, this was the one gap worth landing alone.

## 0.4.0 — REPO-STANDARD convergence (2026-08-01)

- The tree fold alfred specified (msg 2591, operator's direct instruction:
  sutra and mudra converge before either one is sealed again): bin/,
  desktop/, polkit/ -> src/; CHANGELOG.md -> docs/; SECURITY.md -> .github/;
  VERSION -> packaging/VERSION. Ten root rows: src/ docs/ packaging/ tests/
  .github/ README.md LICENSE Makefile .gitignore .gitattributes.
- Every reference to the old bin/mudra path updated in the same commit —
  Makefile, tests/smoke.sh, the desktop launcher's Exec=, the polkit
  README's install command, and mudra's own comments — plus the live,
  already-running systemd unit and the already-installed desktop launcher
  on this machine, both reinstalled/restarted and confirmed serving from
  the new path before this commit landed. Alfred's warning (msg 2591) was
  specific: "this is the desk they drive by hand."
- Fixed a self-referential gap the move would otherwise have introduced
  silently: `_self_path` computed two directories up from `__file__`,
  correct for bin/mudra but wrong by one level for src/bin/mudra — it
  would have resolved to src/ instead of the repo root, silently blinding
  mudra's own roster entry (the exact failure shape kast hit when
  REPO-STANDARD first landed on it). Now three levels up, confirmed via
  direct inspection (`_self_path` resolves to the repo root, `mudra
  status --no-remote` reads v0.4.0 correctly) as well as the smoke suite.
- Also collapsed a second duplication while the file was already open:
  `MUDRA_VERSION` was a hand-maintained literal string, bumped by hand
  alongside VERSION on every release — precisely the shape that left sutra
  red for eleven straight commits (decision afda1ee0, the CI-drift class).
  It's now read from packaging/VERSION at import time; check-repo's
  literal-version-string check would have failed on mudra's own file
  otherwise.
- Added docs/USAGE.md, docs/ARCHITECTURE.md (with a Standard exemptions
  table recording install.sh/uninstall.sh's absence — mudra installs via
  two make targets, not a shell installer), docs/RELEASING.md, the two
  missing community files under .github/, .gitattributes, a README ## Map
  block, and a check-repo target (`git ls-files | cut -d/ -f1 | sort -u`,
  never a hand-maintained skip list) ordered first in ci.yml, ahead of
  `make smoke`.

## 0.4.1 — the straddle's exact death condition (2026-08-01)

- docs/ARCHITECTURE.md: documented precisely when `_uses_packaging_layout()`
  / `_first_existing()` can be deleted (alfred, msg 2609, having measured
  it): all five pills but gestalt have converged to packaging/VERSION +
  packaging/release-signing — the straddle exists solely for gestalt now.
  Delete it the day gestalt converges or leaves the roster, not before;
  removing it now would break the one repo that still needs it. Code
  unchanged — this pass only makes the trigger explicit instead of leaving
  a future reader to guess at the code's purpose.

## 0.5.0 — mudra can now be released (2026-08-01)

- The machinery mudra needed to seal itself, requested by alfred (msg
  2665) as the operator's "no sealing until sutra and mudra converge" gate
  approached lifting: `packaging/release-signing/allowed_signers`, shipping
  EMPTY (0 bytes — the inert, pre-arming state, not "none"); `make
  sync-signers` / packaging/sync-signers.sh (principal `mudra`, namespaces
  `mudra-release,pills-tag`, rebuild-from-all, refuses on anything but
  exactly 4 canonical keys — same shape as coldspot's, minus the embedded-
  twin section mudra has no install.sh to need); .github/workflows/
  release.yml (tag push -> tarball + SHA256SUMS, unsigned, refuses without
  a matching docs/CHANGELOG.md section, no .deb — mudra isn't a pill and
  has nothing an installer would package differently); .github/workflows/
  signing-sync.yml (internal-consistency check: anchor empty or exactly 4
  well-formed lines).
- NOTHING WAS ARMED AND NOTHING WAS TAGGED. The anchor is genuinely empty
  on disk (confirmed: `wc -c` = 0), sync-signers.sh was written but never
  run, no `vX.Y.Z` tag exists. Building the machinery is not using it —
  the physical key touch stays the operator's alone.
- Checked the self-blindness angle explicitly, per alfred's framing (the
  same class of bug as _self_path, one layer up): `mudra status
  --no-remote` on mudra's own roster entry read `anchor=none` before this
  change and `anchor=inert` after, with everything else (version, tag
  state) unchanged — the desk sees its own new state correctly rather than
  half-seeing it.
- docs/RELEASING.md and docs/ARCHITECTURE.md (new "Signing itself"
  section) updated to describe the real process now that one exists,
  replacing the earlier "mudra has no release.yml yet" framing.

## 0.6.0 — the straddle's death, and the ninth repo it nearly hid (2026-08-01)

- `_uses_packaging_layout()` / `_first_existing()` DELETED. gestalt (the
  last holdout) converged to packaging/VERSION at fa2297a; every repo the
  packaging/-layout rollout covers is on it now. `version_path()` /
  `anchor_file()` / `anchor_rel()` take a single fixed `packaging/` path.
- BUT: ordered to confirm the roster myself before deleting rather than
  trust the convergence report (alfred, msgs 2801/2806) — made the edit,
  diffed the FULL nine-row roster, not the eight either report measured,
  and rotten-apple regressed from anchor=armed to anchor=none. It's a Rust
  workspace outside REPO-STANDARD's packaging/ convergence by design (no
  VERSION file ever, Cargo.toml carries its version instead), with a
  genuinely armed anchor at the old root release-signing/allowed_signers —
  and neither alfred's convergence matrix (7ec8dff0) nor his dispatch to
  me had ever counted it, because both silently inherited his coordination
  charter's boundary (nine repos on mudra's desk, eight in his charter).
  REVERTED before committing rather than ship a real armed anchor into
  invisibility.
- Ruling 23d9e8e4 (alfred, split by ownership): mudra's read of
  rotten-apple gets a PERMANENT, explicitly NAMED exception
  (`_ROOT_LAYOUT_REPOS = {"rotten-apple"}`) — not a generic dual-layout
  probe, which is what made the regression silent in the first place, by
  asserting any repo might be on either layout. Whether rotten-apple ever
  adopts packaging/ is Ra's and the operator's call, not mudra's.
- FAIL LOUD, never fall back: a repo matching neither the named exception
  nor the packaging/ layout now reads `anchor: "unrecognized-layout"` — a
  hard `audit()` finding, never a silent `anchor: "none"` that looks
  identical to a normal, expected not-yet-armed repo.
- Proved the carve-out load-bearing in both directions, on the real
  roster, not just fixtures: with `_ROOT_LAYOUT_REPOS` in place,
  rotten-apple reads `anchor=armed`; with it removed (a throwaway patched
  copy of the script, never the real file), the same repo reads
  `anchor=unrecognized-layout` and `audit` fails on it. Both runs against
  the live `~/code/rotten-apple` checkout, not a simulation.
- tests/smoke.sh grows fixtures for all three shapes (packaging/-layout,
  the named root-layout exception, and matching neither) plus the same
  positive/negative proof, offline.
- docs/ARCHITECTURE.md: replaced the delete-condition paragraph with what
  actually happened, and named the two sets (mudra's nine-repo desk vs.
  alfred's eight-repo coordination charter) so a successor doesn't
  rediscover the gap by shipping the regression.

## 0.7.0 — mudra's first release (2026-08-01)

mudra is the pill family's release-seal desk. Every release ships from CI unsigned, plus a
`SHA256SUMS` manifest; mudra derives a queue from that reality — a published release with no
`.sig` IS the "awaiting seal" entry, an empty `allowed_signers` IS the unarmed state, nothing
stored, nothing to drift — and gives the operator one desk (CLI or a loopback-only GUI) to
clear it: arm an anchor, sign a manifest with a physical FIDO2 key, verify the result back
exactly as an end user would. mudra never holds key material. Signing shells to `ssh-keygen -Y`
against hardware the private half never leaves; the one act mudra cannot and will not do on its
own is the touch. That is the operator's hand, by design.

This is mudra's first tagged release, after real development that never stopped to cut one.
The highlights, oldest to newest:

- **The desk itself** (0.1.0–0.3.3): the CLI+GUI ceremony end to end — arm, seal, verify-back —
  physical-key auto-detection, a one-boot session token, and the scoped arming commit (never
  `git add -A`, learned from a real incident that swept unrelated files into a public repo).
- **Its own first CI** (0.3.10): `make smoke` on every push. The test suite had already covered
  the dangerous paths — sync-signers rebuild, the 3-key refusal, audit catching divergence —
  for months; nothing had ever run it on a commit before this.
- **The REPO-STANDARD tree fold** (0.4.0): the same twelve-row convergence every pill adopted,
  applied to mudra itself, plus fixing two self-referential bugs the move would otherwise have
  introduced silently — a path-resolution depth error and a hand-duplicated version constant.
- **Its own release machinery** (0.5.0): the anchor, `sync-signers.sh`, `release.yml`,
  `signing-sync.yml` — built with everything shipped empty and nothing armed, so mudra could
  finally do for itself what it does for every other repo in the family.
- **The straddle's death, and the ninth repo it nearly hid** (0.6.0): once every REPO-STANDARD
  repo had converged, the two-layout compatibility code came out — and doing that safely
  surfaced that mudra's own roster is wider than any one coordinator's charter. One repo,
  outside that convergence entirely, had a genuinely armed anchor at a different, permanent
  location; catching it before shipping (by checking the full roster rather than trusting a
  report) is why that anchor is still visible today instead of silently gone dark. Fixed with a
  named, permanent exception and a rule that anything unrecognized fails loud, never quietly
  reads as "nothing to see here."
- **Arming reaches the UI**: the desk's GUI could only ever arm as a side effect of sealing,
  and sealing refuses without a published release — so for any repo without a tag yet
  (mudra, tonight), the card rendered nothing at all, no control of any kind. Split into two
  separate ceremonies sharing one lock: `arm` (public keys only, works on an untagged repo —
  that is the entire point) and `seal` (the physical touch, published-release-only, and now
  refuses cleanly if the anchor isn't armed rather than silently arming it too). The desk's
  own **ARM** button previews which keys it's about to write before an irreversible
  confirmation; the **SEAL** button only ever appears once a repo is both armed and actually
  awaiting one.

Also in this release: a documentation note on a testing constraint found proving the
rotten-apple exception load-bearing — a copy of `src/bin/mudra` only runs from inside a real,
repo-shaped checkout, since it reads its own version from `packaging/VERSION` at import time —
and a fix to `docs/RELEASING.md`'s own arming order, found before it could ship a first tagged
tarball with a permanently empty anchor (arm must happen before the tag, never bundled into
the seal step afterward). That fix is now enforced in `release.yml` itself, not just
documented: a CI step refuses to build the release tarball if
`packaging/release-signing/allowed_signers` is empty at tag time, ported from gestalt hitting
the identical drafting mistake independently and adding the guard rather than just the prose
fix. Also fixed in the same pass: a pre-existing bug in the seal ceremony's verify-back step,
which resolved a path-based roster entry's (rotten-apple's) anchor from `REPO_ROOT/<name>`
instead of its own real path — silently wrong for any repo outside `REPO_ROOT`, only ever
"working" for mudra itself by coincidence (mudra happens to live inside `REPO_ROOT`). Found
while already in that exact function for the arm/seal split.

Two small desk UX fixes: the `untagged` chip dropped its `(seat's move, on GO)` suffix — jargon
that meant something in a doc, not a live status board a card shows on every load. And the
physical-key picker moved out of each AWAITING SEAL card and into the header, once: only one key
is ever plugged in at a time and it's good for whichever repo gets sealed next, so a picker per
card was implying a choice that doesn't exist. Detection still wins over a stale manual pick on
every refresh, same as before.
