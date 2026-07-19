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
