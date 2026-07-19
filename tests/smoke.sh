#!/usr/bin/env bash
# mudra smoke — offline, fixture-only: no gh, no network, no real keys.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MUDRA="$HERE/bin/mudra"
FAIL=0
say() { echo "$@"; }
die() { echo "SMOKE FAIL: $*" >&2; FAIL=1; }

python3 -m py_compile "$MUDRA" && say "py_compile: ok" || die "py_compile"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# Fixture: a fake key home (4 throwaway ed25519 pubs) + a fake repo.
mkdir -p "$T/keys" "$T/repos/fakepill/release-signing"
for i in 1 2 3 4; do
  ssh-keygen -q -t ed25519 -N '' -C "fake-master-$i" -f "$T/keys/id_fake_$i"
done
( cd "$T/repos/fakepill" && git init -q . && echo 0.0.1 > VERSION \
  && touch release-signing/allowed_signers \
  && printf "#!/bin/sh\nRELEASE_ALLOWED_SIGNERS=''\n" > install.sh \
  && git add -A && git -c user.email=s@s -c user.name=s commit -qm x )

ENV="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakepill MUDRA_KEY_HOME=$T/keys"

# status --no-remote --json names the repo and derives a state
out="$(env $ENV "$MUDRA" status --no-remote --json)" \
  && echo "$out" | grep -q '"fakepill"' && echo "$out" | grep -q '"state"' \
  && say "status: ok" || die "status --no-remote --json"

# sync-signers: rebuild-from-all — 4 lines, principal + namespace, embedded twin synced
env $ENV "$MUDRA" sync-signers fakepill >/dev/null || die "sync-signers rc"
n="$(grep -c '^fakepill namespaces="fakepill-release,pills-tag" ' \
     "$T/repos/fakepill/release-signing/allowed_signers")"
[ "$n" = 4 ] && say "sync-signers: 4 canonical lines ok" || die "anchor lines: $n"
grep -q 'fakepill-release' "$T/repos/fakepill/install.sh" \
  && say "embedded twin: synced ok" || die "embedded twin not rewritten"

# audit: armed fixture matching its own canon must be CLEAN
env $ENV "$MUDRA" audit >/dev/null 2>&1 \
  && say "audit: clean on coherent fixture" || die "audit rc on coherent fixture"

# refusal: 3-key canon must refuse the rebuild
rm "$T/keys/id_fake_4.pub"
env $ENV "$MUDRA" sync-signers fakepill >/dev/null 2>&1 \
  && die "sync-signers accepted 3 keys" || say "sync-signers: refuses !=4 keys ok"

# audit: divergence must be FOUND — anchor now differs from (3-key) canon
env $ENV "$MUDRA" audit >/dev/null 2>&1 \
  && die "audit missed key-home divergence" || say "audit: catches divergence ok"

[ "$FAIL" = 0 ] && echo "SMOKE OK" || { echo "SMOKE FAILED"; exit 1; }
