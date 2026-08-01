# Security Policy

## Supported versions

mudra is pre-1.0; only the latest release receives fixes.

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead, use GitHub's
private vulnerability reporting:

- Go to the repo's **Security** tab → **Report a vulnerability**.

You'll get an acknowledgement, and a fix or mitigation will be coordinated before any
public disclosure.

## Scope notes

mudra is the pill family's **release-seal desk** — a maintainer-side tool, not shipped
to end users. It derives a seal queue from published releases, audits release
invariants, and drives the operator's signing ceremony. Its security model rests on a
few load-bearing invariants, each carved from a real incident:

- **mudra never holds key material.** The signing keys live in the operator's FIDO2
  hardware (non-extractable); mudra shells out to `ssh-keygen -Y` and the physical
  touch is the operator's alone. mudra builds the desk, never the hand. A vulnerability
  that made mudra able to sign without that touch would be critical.
- **The GUI binds `127.0.0.1` only, with a per-boot session token** — never LAN, never
  `0.0.0.0`. Loopback is same-host/any-user reachable, so the token is what keeps the
  desk yours. Report anything that widens that bind or leaks the token.
- **Arming commits are scoped** to exactly the trust-anchor files — never `git add -A`
  (a stray `git add -A` once staged session files into a public arming commit; no
  credentials leaked, but the history was rewritten by hand to remove them).
- **Sealed releases are never re-cut**, and the trust anchor is fail-closed once armed:
  a populated `allowed_signers` makes signature verification mandatory forever.
- **`SHA256SUMS` is the universal manifest**; the signature covers the manifest, which
  covers every artifact.

mudra reads published release metadata (via `gh`/the GitHub API) and local repository
state; it has no write path to key material and performs no unattended signing. Report
issues in upstream tools it invokes (`git`, `gh`, `ssh-keygen`) to their respective
projects.
