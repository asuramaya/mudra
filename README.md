# mudra — the seal desk

*Sutra the thread, mudra the seal.* Operator-side release manager for the
pill family ([FAMILY.md](../FAMILY.md), [RELEASE.md](../RELEASE.md)): the
seats build, commit, and tag on GO; CI publishes UNSIGNED artifacts plus a
sha256 manifest; and mudra gives the operator one desk where everything
awaiting their literal sign-off queues up.

**The queue is derived from reality, never stored.** A published release
missing its `.sig` IS a queue entry. An empty `allowed_signers` IS the
unarmed state. A `VERSION` without its tag IS a candidate still in the
seat's hands. Nothing to sync, nothing to drift.

**mudra never holds key material.** Signing shells to `ssh-keygen -Y sign`
against the hardware keys in `~/.ssh/asuramaya-master/`; the private halves
are FIDO2-resident and non-extractable, and the one act mudra cannot and
will not do is the touch. That is the operator's hand, by design — mudra
just makes it one click plus one touch.

## Map

| | |
|---|---|
| Use it | [docs/USAGE.md](docs/USAGE.md) |
| Change it | [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) |
| Understand how it's built | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Cut a release | [docs/RELEASING.md](docs/RELEASING.md) |
| See what changed | [docs/CHANGELOG.md](docs/CHANGELOG.md) |
| Report a vulnerability | [.github/SECURITY.md](.github/SECURITY.md) |

## The desk (GUI)

```sh
make serve              # → http://127.0.0.1:7770 (localhost only), autostarts
                         #   as a systemd --user unit once installed — see below
src/bin/mudra open       # opens it in your browser, already authenticated —
                         # no token to remember, no journalctl. Or just click
                         # the app-grid icon (make install-launcher).
```

Access is loopback-only, one-boot-token-gated, and — once
`make install-polkit` has run once (needs root, one time) — also asks for
your fingerprint/password on the operator's own screen before minting a
session, on top of the token. See `src/polkit/README.md`.

Every repo renders as a card: version, tag state, anchor state (armed / inert / none),
embedded-copy drift, working-tree dirt, and the derived verdict. Arm and seal are two
separate acts, each its own button, because they need different things: arming needs
only the public keys and works on a repo with no tag at all; sealing needs the operator's
physical touch and a published release. An unarmed repo's card carries an **ARM**
button — click it and the desk previews which keys it's about to write before an extra
confirmation ("arming pins the master identity fail-closed *forever*"). A repo AWAITING
SEAL carries a **SEAL** button. The ceremony streams its steps live; when it's time to
sign, the desk lights up: TOUCH YOUR KEY NOW. After upload, mudra re-downloads
everything and verifies hash chain + signature exactly as an end user would — sealed
means *proven* sealed.

**manage keys**, in the header, is the wizard for the 4 canonical handles themselves —
lower stakes than sealing, higher stakes than everything else on the desk. Each slot
shows empty or a fingerprint, a **plugged in now** chip when it's the one actually
detected (read-only — one physical key is ever connected at a time), and a
**GENERATE**/**REGENERATE** button that mints a brand-new hardware-backed key straight
onto that slot (PIN, then TOUCH). mudra still never holds key material here either:
`-O resident` means the private half exists only on the token, never on disk.
Regenerating an OCCUPIED slot is a distinct, scarier confirmation — it permanently
retires whatever was there, and every anchor already armed with its public half needs
re-arming family-wide. Manual mapping (registering the plugged-in device as handle N
without generating anything) is CLI-only — `keysetup --map N`. The panel polls live
while open (2s) so swapping physical keys shows up without reopening it; a device
that's detected but not yet mapped to any slot shows its raw fingerprint so "is this
even seeing my key" has a direct answer.

## The CLI (same verbs, no browser)

```sh
src/bin/mudra status [--json] [--no-remote]   # the family at a glance
src/bin/mudra audit  [--remote]               # invariants: same 4 keys everywhere,
                                              # embedded twins identical, principals sane
src/bin/mudra sync-signers <repo> [--dry]     # rebuild an anchor from the key home
                                              # (rebuild-from-all, refuses != 4 keys)
src/bin/mudra arm <repo>                      # rebuild + scoped commit + push, one act
src/bin/mudra seal <repo> [--key N]           # the full ceremony, terminal edition
src/bin/mudra keysetup                        # the 4 handles: which are filled, which
                                              # device is plugged in and mapped to what
src/bin/mudra keysetup --slot N [--force]     # mint a new hardware key into slot N
src/bin/mudra keysetup --map N                # register the plugged-in device as slot N
```

## Environment

| var | default | meaning |
|---|---|---|
| `MUDRA_REPO_ROOT` | `~/code/REPOS` | where the family lives |
| `MUDRA_REPOS` | the six pills | comma-separated roster |
| `MUDRA_KEY_HOME` | `~/.ssh/asuramaya-master` | canonical key home (ruling 13ee52ce) |
| `MUDRA_SIGN_KEY` | `…/id_asuramaya_master_1` | which handle to sign with |
| `MUDRA_KEYMAP_PATH` | `~/.config/mudra/keymap.json` | device-fingerprint → handle map |
| `MUDRA_PORT` | `7770` | desk port, 127.0.0.1 only |

## Test

```sh
make smoke     # offline: fixtures + throwaway keys, no gh, no hardware
```

Free software, GPLv3, stdlib-only, no telemetry. Not a pill — mudra ships to
no one; it is the desk the family's releases cross on their way out.
