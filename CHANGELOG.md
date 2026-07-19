# Changelog

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
