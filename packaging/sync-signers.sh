#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# `make sync-signers` — rebuild packaging/release-signing/allowed_signers from
# the fleet's canonical pubkeys, per ~/code/REPOS/RELEASE.md's sync-signers
# doctrine. No embedded install.sh twin to sync — mudra has no install.sh (it
# installs through make targets, see docs/ARCHITECTURE.md's Standard
# exemptions table), so this script is shorter than a pill's by exactly that
# section.
#
# Canonical key home (operator ruling 13ee52ce): ~/.ssh/asuramaya-master/ —
# OUTSIDE every repo, never committed, never a sibling checkout. This is a
# LOCAL-ONLY act by construction: CI can never reach $HOME, so
# .github/workflows/signing-sync.yml asserts internal consistency only
# (well-formed anchor), never canonical equality.
#
# ALWAYS a full rebuild, never an append: RA's first ceremony left 3 of 4
# keys unpinned across other repos by appending one key at a time. Refuses to
# run unless it finds exactly 4 canonical keys, so a partial/broken key home
# can't silently produce a partial anchor.
#
# SEQUENCING: this populates the anchor. Per RELEASE.md and the operator's
# explicit gate on this repo, run it ONLY as part of mudra's own first
# signed release, at the operator's hand — never earlier. Building this
# script is not running it.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
PRINCIPAL="mudra"
NAMESPACES="mudra-release,pills-tag"

KEY_HOME="${KEY_HOME:-$HOME/.ssh/asuramaya-master}"
if [[ ! -d "$KEY_HOME" ]]; then
  echo "ERROR: canonical key home not found at $KEY_HOME." >&2
  echo "       Set KEY_HOME=/path/to/asuramaya-master and retry." >&2
  exit 1
fi

mapfile -t pubs < <(find "$KEY_HOME" -maxdepth 1 -name '*.pub' | LC_ALL=C sort)
if [[ "${#pubs[@]}" -ne 4 ]]; then
  echo "ERROR: expected exactly 4 canonical pubkeys in $KEY_HOME, found ${#pubs[@]}." >&2
  echo "       Never partially sync — see RELEASE.md's sync-signers section." >&2
  exit 1
fi

anchor="$HERE/release-signing/allowed_signers"
tmp="$(mktemp)"
for p in "${pubs[@]}"; do
  printf '%s namespaces="%s" %s\n' "$PRINCIPAL" "$NAMESPACES" "$(cat "$p")"
done > "$tmp"
mv "$tmp" "$anchor"
echo "rebuilt $anchor from ${#pubs[@]} canonical keys ($KEY_HOME)"
