# Using mudra

Everything the CLI and the GUI can do. If you just want to clear the queue, `make serve` (or
click the app-grid icon) and use the GUI — this file is for everything past that.

## The desk (GUI)

```sh
make serve              # http://127.0.0.1:7770, loopback only
src/bin/mudra open       # opens it in your browser, already authenticated
```

Once installed (`make install`), `mudra serve` runs as a systemd `--user` unit and starts with
your graphical session — `systemctl --user status mudra` / `restart mudra` /
`journalctl --user -u mudra` are the usual levers.

Every repo renders as a card: version, tag state, anchor state (armed / inert / none),
embedded-copy drift, working-tree dirt, and the derived verdict. Releases **AWAITING SEAL**
carry a button. If the anchor is still inert, the button reads **ARM + SEAL** and demands an
extra confirmation first — arming pins the master identity fail-closed *forever*, so it asks
once, deliberately, rather than being a checkbox you can miss. The ceremony streams its steps
into a live log; when it needs your hardware key, the desk says so plainly. After upload,
mudra re-downloads everything and verifies hash chain + signature exactly as an end user
would — a card only ever reads "sealed" once that's been *proven*, not just uploaded.

The key-picker dropdown remembers which physical key handle N pairs with, once you've sealed
with it successfully — see `src/bin/mudra`'s device-fingerprint ladder in
[ARCHITECTURE.md](ARCHITECTURE.md) if you're curious how.

## The CLI (same verbs, no browser)

```sh
src/bin/mudra status [--json] [--no-remote]   # the family at a glance; --no-remote skips
                                              # every gh call (offline, faster, no seal state)
src/bin/mudra audit  [--remote]               # family invariants: same 4 canonical keys
                                              # everywhere, embedded twins byte-identical,
                                              # principals/namespaces sane. Exits nonzero
                                              # and lists findings on any violation.
src/bin/mudra sync-signers <repo> [--dry]     # rebuild <repo>'s anchor from the canonical
                                              # key home (rebuild-from-all, refuses on
                                              # anything but exactly 4 keys). --dry prints
                                              # the would-be anchor body without writing.
src/bin/mudra seal <repo> [--arm] [--key N]   # the full ceremony, terminal edition. --arm
                                              # is required the first time a repo's anchor
                                              # is inert; --key picks which physical handle
                                              # to sign with when auto-detection can't.
src/bin/mudra open [--print]                  # launch the browser into a running serve's
                                              # authenticated desk; --print just prints the URL
```

`audit` never fails on a dirty working tree or an untagged repo — those are normal states
mid-development. It fails only when a checked **invariant** is actually broken: a divergent
armed anchor, a malformed principal/namespace line, or an embedded `install.sh` copy that no
longer matches its anchor file.

## Environment

| var | default | meaning |
|---|---|---|
| `MUDRA_REPO_ROOT` | `~/code/REPOS` | where the family lives |
| `MUDRA_REPOS` | the nine tracked repos | comma-separated roster override |
| `MUDRA_KEY_HOME` | `~/.ssh/asuramaya-master` | canonical key home (ruling 13ee52ce) |
| `MUDRA_SIGN_KEY` | `…/id_asuramaya_master_1` | which handle to sign with, absent `--key` |
| `MUDRA_PORT` | `7770` | desk port, 127.0.0.1 only, no override reaches beyond loopback |

## Troubleshooting

**"unauthorized — open the URL the serve command printed"** — the token in your URL/cookie
doesn't match the currently running `serve`. Restart wipes the token; use `mudra open`
instead of a bookmarked URL, or re-read the current one from
`journalctl --user -u mudra -n 20`.

**"mudra desk isn't running (stale session, pid N is gone)"** from `mudra open`** — the
recorded session outlived the process that wrote it (a crash, or the machine slept through a
restart). `systemctl --user restart mudra`.

**"invalid format" after the touch** — the physical key you signed with doesn't hold the
credential for the handle mudra picked. Handle N pairs with physical key N; the GUI's
key-picker and `seal --key N` both let you correct it and retry — a wrong pick can only ever
fail cleanly, never sign with the wrong identity.

**polkit falls back to token-only with a stderr warning** — `make install-polkit` hasn't run
yet (needs root, once). Expected on a fresh checkout; see
[src/polkit/README.md](../src/polkit/README.md).
