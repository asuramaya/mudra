# mudra — a release-seal desk

Release manager for your own projects: you build, commit, and tag; CI publishes UNSIGNED
artifacts plus a sha256 manifest; mudra gives you one desk where everything awaiting your
literal sign-off queues up.

**The queue is derived from reality, never stored.** A published release
missing its `.sig` IS a queue entry. An empty `allowed_signers` IS the
unarmed state. A `VERSION` without its tag IS a candidate still in your
hands. Nothing to sync, nothing to drift.

**mudra never holds key material.** Signing shells to `ssh-keygen -Y sign`
against your own hardware keys; the private halves are FIDO2-resident and
non-extractable, and the one act mudra cannot and will not do is the touch.
That is your hand, by design — mudra just makes it one click plus one touch.

## Map

| | |
|---|---|
| Set it up | `mudra init` — see below |
| Use it | [docs/USAGE.md](docs/USAGE.md) |
| Change it | [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) |
| Understand how it's built | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Cut a release | [docs/RELEASING.md](docs/RELEASING.md) |
| See what changed | [docs/CHANGELOG.md](docs/CHANGELOG.md) |
| Report a vulnerability | [.github/SECURITY.md](.github/SECURITY.md) |

## Setup

```sh
src/bin/mudra init
```

Walks you through configuring your own roster (which repos to track), where your key home
lives, and how many signing keys you use — writes `~/.config/mudra/config.json`. Re-runnable
any time to edit; env vars (see Environment, below) always override it for a one-off run.
Nothing is hardcoded to anyone else's setup — a fresh checkout tracks nothing until you tell
it to.

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
your fingerprint/password on your own screen before minting a
session, on top of the token. See `src/polkit/README.md`.

Three tabs, one visible at a time — **sign**, **keys**, **setup** — instead of stacking
panels that used to fight the always-visible queue for space.

**sign** (the default) is the queue itself: every repo renders as a card — version, tag
state, anchor state (armed / inert / none), embedded-copy drift, working-tree dirt, and
the derived verdict. Arm and seal are two separate acts, each its own button, because
they need different things: arming needs only the public keys and works on a repo with
no tag at all; sealing needs your physical touch and a published release. An unarmed
repo's card carries an **ARM** button — click it and the desk previews which keys it's
about to write before an extra confirmation ("arming pins the master identity
fail-closed *forever*"). A repo AWAITING SEAL carries a **SEAL** button. The ceremony
streams its steps live; when it's time to sign, the desk lights up: TOUCH YOUR KEY NOW.
After upload, mudra re-downloads everything and verifies hash chain + signature exactly
as an end user would — sealed means *proven* sealed.

**setup** opens the same configuration `mudra init` writes — roster, key home, key
prefix, expected key count, namespace tag — editable from the browser, no terminal
needed after the first run. **keys** is the wizard for your canonical handles
themselves — lower stakes than sealing, higher stakes than everything else on the desk.
Each slot shows empty or a fingerprint, a **plugged in now** chip when it's the one
actually detected (read-only — one physical key is ever connected at a
time), and a **GENERATE**/**REGENERATE** button that mints a brand-new hardware-backed
key straight onto that slot (PIN, then TOUCH). mudra still never holds key material here
either: `-O resident` means the private half exists only on the token, never on disk.
Regenerating an OCCUPIED slot is a distinct, scarier confirmation — it permanently
retires whatever was there, and every anchor already armed with its public half needs
re-arming everywhere it was used. Manual mapping (registering the plugged-in device as
handle N without generating anything) is CLI-only — `keysetup --map N`. The panel polls
live while open (2s) so swapping physical keys shows up without reopening it; a device
that's detected but not yet mapped to any slot shows its raw fingerprint so "is this
even seeing my key" has a direct answer.

## The CLI (same verbs, no browser)

```sh
src/bin/mudra init                            # configure your roster, key home, etc.
src/bin/mudra status [--json] [--no-remote]   # your roster at a glance
src/bin/mudra audit  [--remote]               # invariants: same keys everywhere,
                                              # embedded twins identical, principals sane
src/bin/mudra sync-signers <repo> [--dry]     # rebuild an anchor from the key home
                                              # (rebuild-from-all, refuses on a wrong count)
src/bin/mudra arm <repo>                      # rebuild + scoped commit + push, one act
src/bin/mudra seal <repo> [--key N]           # the full ceremony, terminal edition
src/bin/mudra keysetup                        # your handles: which are filled, which
                                              # device is plugged in and mapped to what
src/bin/mudra keysetup --slot N [--force]     # mint a new hardware key into slot N
src/bin/mudra keysetup --map N                # register the plugged-in device as slot N
```

## Environment

`mudra init` writes `~/.config/mudra/config.json` with all of these except the last two
(session-only, never persisted). Every var below overrides the config file for a one-off run.

| var | default | meaning |
|---|---|---|
| `MUDRA_REPO_ROOT` | `~/code/REPOS` | where your repos live |
| `MUDRA_REPOS` | *(empty — configure your own)* | comma-separated roster |
| `MUDRA_KEY_HOME` | `~/.ssh/mudra-master` | canonical key home |
| `MUDRA_KEY_PREFIX` | `master` | key file/RP-ID naming — files become `id_<prefix>_N` |
| `MUDRA_EXPECTED_KEYS` | `4` | how many signing keys (quorum size) |
| `MUDRA_NAMESPACE_TAG` | *(none)* | extra namespace segment on every anchor line |
| `MUDRA_ROOT_LAYOUT_REPOS` | *(empty)* | comma-separated repos NOT on the `packaging/` layout |
| `MUDRA_SIGN_KEY` | `<key_home>/id_<prefix>_1` | which handle to sign with |
| `MUDRA_KEYMAP_PATH` | `~/.config/mudra/keymap.json` | device-fingerprint → handle map |
| `MUDRA_CONFIG_PATH` | `~/.config/mudra/config.json` | where `mudra init` writes/reads |
| `MUDRA_PORT` | `7770` | desk port, 127.0.0.1 only |

## Test

```sh
make smoke     # offline: fixtures + throwaway keys, no gh, no hardware
```

Free software, GPLv3, stdlib-only, no telemetry. mudra doesn't ship anything of its own
to end users; it's the desk your own releases cross on their way out. Currently supports
GitHub Releases only (via the `gh` CLI) and Yubico hardware for auto-detecting which
physical key is plugged in — signing itself works with any FIDO2 key, `ssh-keygen -Y`
doesn't care who made it, but auto-detect (picking your inserted key without having to
select it manually) is Yubico-specific for now.
