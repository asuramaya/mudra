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

## The desk (GUI)

```sh
make serve          # → http://127.0.0.1:7770 (localhost only)
```

Every repo renders as a card: version, tag state, anchor state
(armed ⚔ / inert / none), embedded-copy drift, working-tree dirt, and the
derived verdict. Releases AWAITING SEAL carry the button. If the anchor is
still inert, the button reads ARM + SEAL and demands an extra confirmation —
arming pins the master identity fail-closed *forever*. The ceremony streams
its steps live; when it's time, the desk lights up: 👆 TOUCH YOUR KEY NOW.
After upload, mudra re-downloads everything and verifies hash chain +
signature exactly as an end user would — sealed means *proven* sealed.

## The CLI (same verbs, no browser)

```sh
bin/mudra status [--json] [--no-remote]   # the family at a glance
bin/mudra audit  [--remote]               # invariants: same 4 keys everywhere,
                                          # embedded twins identical, principals sane
bin/mudra sync-signers <repo> [--dry]     # rebuild an anchor from the key home
                                          # (rebuild-from-all, refuses != 4 keys)
bin/mudra seal <repo> [--arm]             # the full ceremony, terminal edition
```

## Environment

| var | default | meaning |
|---|---|---|
| `MUDRA_REPO_ROOT` | `~/code/REPOS` | where the family lives |
| `MUDRA_REPOS` | the six pills | comma-separated roster |
| `MUDRA_KEY_HOME` | `~/.ssh/asuramaya-master` | canonical key home (ruling 13ee52ce) |
| `MUDRA_SIGN_KEY` | `…/id_asuramaya_master_1` | which handle to sign with |
| `MUDRA_PORT` | `7770` | desk port, 127.0.0.1 only |

## Test

```sh
make smoke     # offline: fixtures + throwaway keys, no gh, no hardware
```

Free software, GPLv3, stdlib-only, no telemetry. Not a pill — mudra ships to
no one; it is the desk the family's releases cross on their way out.
