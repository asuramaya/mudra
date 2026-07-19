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
