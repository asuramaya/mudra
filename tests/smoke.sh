#!/usr/bin/env bash
# mudra smoke — offline, fixture-only: no gh, no network, no real keys.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MUDRA="$HERE/src/bin/mudra"
FAIL=0
say() { echo "$@"; }
die() { echo "SMOKE FAIL: $*" >&2; FAIL=1; }

python3 -m py_compile "$MUDRA" && say "py_compile: ok" || die "py_compile"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# Fixture: a fake key home (4 throwaway ed25519 pubs) + a fake repo already
# on packaging/ (REPO-STANDARD.md's now-universal layout for the eight repos
# it covers — the straddle that used to read a root fallback is gone as of
# 0.6.0) with an empty anchor already present: the shape of a repo that has
# shipped the verify mechanism but never armed.
mkdir -p "$T/keys" "$T/repos/fakepill/packaging/release-signing"
for i in 1 2 3 4; do
  ssh-keygen -q -t ed25519 -N '' -C "fake-master-$i" -f "$T/keys/id_fake_$i"
done
( cd "$T/repos/fakepill" && git init -q . && echo 0.0.1 > packaging/VERSION \
  && touch packaging/release-signing/allowed_signers \
  && printf "#!/bin/sh\nRELEASE_ALLOWED_SIGNERS=''\n" > install.sh \
  && git add -A && git -c user.email=s@s -c user.name=s commit -qm x )

# Second fixture: packaging/VERSION present, NO anchor directory anywhere —
# gestalt's and sutra's real shape. Covers the first-ever-arm path (must
# CREATE packaging/release-signing/) and that a repo with no anchor in
# existence yet reads anchor=none rather than erroring.
mkdir -p "$T/repos/fakepackaged/packaging"
( cd "$T/repos/fakepackaged" && git init -q . \
  && echo 0.1.0 > packaging/VERSION \
  && git add -A && git -c user.email=s@s -c user.name=s commit -qm x )

# Third fixture: the NAMED root-layout exception (rotten-apple's real
# shape) — no packaging/ directory at all, no VERSION file (Cargo.toml
# instead), anchor at the pre-convergence root location, genuinely armed.
# Must read anchor=armed via the root path, not silently miss it.
mkdir -p "$T/repos/rotten-apple/release-signing"
( cd "$T/repos/rotten-apple" && git init -q . \
  && printf '[workspace.package]\nversion = "0.0.1"\n' > Cargo.toml \
  && printf 'rotten-apple namespaces="rotten-apple-release" %s %s fake\n' \
       "$(awk '{print $1}' "$T/keys/id_fake_1.pub")" \
       "$(awk '{print $2}' "$T/keys/id_fake_1.pub")" \
     > release-signing/allowed_signers \
  && git add -A && git -c user.email=s@s -c user.name=s commit -qm x )

# Fourth fixture: matches NEITHER shape — no packaging/VERSION, not in the
# named exception set. Must FAIL LOUDLY (anchor=unrecognized-layout, a
# hard audit finding), never silently read as anchor=none — that silence
# is exactly what let a real armed anchor (rotten-apple, for real) go
# invisible before this fixture existed.
mkdir -p "$T/repos/fakeunknown"
( cd "$T/repos/fakeunknown" && git init -q . && echo 0.1.0 > VERSION \
  && git add -A && git -c user.email=s@s -c user.name=s commit -qm x )

ENV="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakepill,fakepackaged,rotten-apple,fakeunknown MUDRA_KEY_HOME=$T/keys"

# status --no-remote --json names the repo and derives a state
out="$(env $ENV "$MUDRA" status --no-remote --json)" \
  && echo "$out" | grep -q '"fakepill"' && echo "$out" | grep -q '"state"' \
  && say "status: ok" || die "status --no-remote --json"

# status reads VERSION from packaging/ — the only path now, not a fallback
out="$(env $ENV "$MUDRA" status --no-remote --json)" \
  && echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); \
     r=[x for x in d['repos'] if x['name']=='fakepackaged'][0]; \
     sys.exit(0 if r['version']=='0.1.0' else 1)" \
  && say "version_path: reads packaging/VERSION ok" \
  || die "version not read from packaging/VERSION"

# no anchor in existence yet -> anchor=none, not an error and not "missing"
out="$(env $ENV "$MUDRA" status --no-remote --json)" \
  && echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); \
     r=[x for x in d['repos'] if x['name']=='fakepackaged'][0]; \
     sys.exit(0 if r['anchor']=='none' and not r.get('missing') else 1)" \
  && say "anchor_file: no anchor anywhere reads anchor=none ok (gestalt/sutra's shape)" \
  || die "a repo with no anchor in either location didn't read anchor=none"

# NAMED EXCEPTION: rotten-apple's shape reads armed via the root path
out="$(env $ENV "$MUDRA" status --no-remote --json)" \
  && echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); \
     r=[x for x in d['repos'] if x['name']=='rotten-apple'][0]; \
     sys.exit(0 if r['anchor']=='armed' else 1)" \
  && say "named exception: rotten-apple's root-layout anchor reads armed ok" \
  || die "rotten-apple's root anchor was not read as armed"

# NEGATIVE CONTROL: same repo, named exception removed from a throwaway
# copy of the script -> must NOT read armed. A green positive alone can't
# tell "the carve-out works" from "something else resolved it"; this is
# the other half of the proof. The copy has to live beside the real script
# (never AS the real script — removed in the same breath) so its own
# _self_path/packaging-VERSION self-read still resolves; a copy dropped in
# an unrelated scratch dir fails before it even reaches the code under test.
NEGCTRL="$HERE/src/bin/mudra_negctrl.py"
sed 's/_ROOT_LAYOUT_REPOS = {"rotten-apple"}/_ROOT_LAYOUT_REPOS = set()/' "$MUDRA" > "$NEGCTRL"
out="$(env MUDRA_REPO_ROOT="$T/repos" MUDRA_REPOS=rotten-apple MUDRA_KEY_HOME="$T/keys" \
       python3 "$NEGCTRL" status --no-remote --json)"
rm -f "$NEGCTRL"
echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); \
   r=[x for x in d['repos'] if x['name']=='rotten-apple'][0]; \
   sys.exit(0 if r['anchor']=='unrecognized-layout' else 1)" \
  && say "negative control: removing the exception flips rotten-apple away from armed ok" \
  || die "negative control: rotten-apple stayed armed with the exception removed — carve-out isn't load-bearing"

# FAIL LOUD: a repo matching neither shape must not silently read anchor=none
out="$(env $ENV "$MUDRA" status --no-remote --json)" \
  && echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); \
     r=[x for x in d['repos'] if x['name']=='fakeunknown'][0]; \
     sys.exit(0 if r['anchor']=='unrecognized-layout' else 1)" \
  && say "fail-loud: unrecognized layout reads a distinct anchor value ok" \
  || die "a repo matching neither shape silently read as something other than unrecognized-layout"
env $ENV "$MUDRA" audit >/dev/null 2>&1 \
  && die "audit passed with an unrecognized-layout repo in the roster" \
  || say "fail-loud: audit treats unrecognized-layout as a hard finding ok"

# sync-signers: rebuild-from-all — 4 lines, principal + namespace, embedded twin synced
env $ENV "$MUDRA" sync-signers fakepill >/dev/null || die "sync-signers rc"
n="$(grep -c '^fakepill namespaces="fakepill-release,pills-tag" ' \
     "$T/repos/fakepill/packaging/release-signing/allowed_signers")"
[ "$n" = 4 ] && say "sync-signers: 4 canonical lines ok" || die "anchor lines: $n"
grep -q 'fakepill-release' "$T/repos/fakepill/install.sh" \
  && say "embedded twin: synced ok" || die "embedded twin not rewritten"

# audit: armed fixture matching its own canon must be CLEAN (drop the
# unrecognized/rotten-apple fixtures from the roster for this check — they
# are exercised above on their own terms)
ENV2="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakepill,fakepackaged MUDRA_KEY_HOME=$T/keys"
env $ENV2 "$MUDRA" audit >/dev/null 2>&1 \
  && say "audit: clean on coherent fixture" || die "audit rc on coherent fixture"

# refusal: 3-key canon must refuse the rebuild
rm "$T/keys/id_fake_4.pub"
env $ENV2 "$MUDRA" sync-signers fakepill >/dev/null 2>&1 \
  && die "sync-signers accepted 3 keys" || say "sync-signers: refuses !=4 keys ok"

# audit: divergence must be FOUND — anchor now differs from (3-key) canon
env $ENV2 "$MUDRA" audit >/dev/null 2>&1 \
  && die "audit missed key-home divergence" || say "audit: catches divergence ok"

# first-ever arm: must CREATE packaging/release-signing/, the only location
# (id_fake_4.pub was removed above — restore all 4 for this repo's own arm)
for i in 1 2 3 4; do
  [ -f "$T/keys/id_fake_$i.pub" ] || ssh-keygen -q -y -f "$T/keys/id_fake_$i" \
    > "$T/keys/id_fake_$i.pub" 2>/dev/null
done
env $ENV2 "$MUDRA" sync-signers fakepackaged >/dev/null 2>&1
if [ -s "$T/repos/fakepackaged/packaging/release-signing/allowed_signers" ] \
   && [ ! -e "$T/repos/fakepackaged/release-signing" ]; then
  say "sync-signers: fresh anchor created under packaging/ ok"
else
  die "fresh anchor landed at the wrong path"
fi

# ARM CEREMONY (`mudra arm <repo>`, the standalone act split out from seal):
# writes the anchor, then a SCOPED commit, then push — needs a real git
# remote to prove the push actually happened, not just assume it. A local
# bare repo works fine and lets the push be verified in the remote itself.
mkdir -p "$T/repos/fakearm/packaging"
BARE="$T/bare-fakearm.git"
git init -q --bare -b main "$BARE"
( cd "$T/repos/fakearm" && git init -q -b main . \
  && echo 0.0.1 > packaging/VERSION \
  && git add -A && git -c user.email=s@s -c user.name=s commit -qm x \
  && git remote add origin "$BARE" \
  && git push -q -u origin main )

# GIT_AUTHOR_*/GIT_COMMITTER_* here, not relied-on ambient config: the
# ceremony's own arming commit (src/bin/mudra's _arm()) never sets an
# identity itself — it's meant to be the operator's own hand, using
# whatever git identity they already have configured, same as any commit
# they make anywhere. That's fine on a real machine that's been committing
# all day; it is NOT fine for a hermetic test, which must not assume the
# runner has any global git identity at all (CI doesn't, and the smoke
# suite caught exactly that gap the first time it actually ran on one).
ENV3="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakearm MUDRA_KEY_HOME=$T/keys GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=s@s"
arm_out="$(env $ENV3 "$MUDRA" arm fakearm 2>&1)"
rc=$?
if [ "$rc" = 0 ] \
   && [ -s "$T/repos/fakearm/packaging/release-signing/allowed_signers" ] \
   && git -C "$T/repos/fakearm" log -1 --format=%s | grep -q "arm release verification" \
   && git -C "$BARE" log -1 --format=%s main | grep -q "arm release verification"; then
  say "arm: write+commit+push ceremony ok (verified in the bare remote, not just locally)"
else
  die "arm ceremony didn't write+commit+push correctly (rc=$rc): $arm_out"
fi

# arm refuses an already-armed repo rather than silently re-arming
env $ENV3 "$MUDRA" arm fakearm >/dev/null 2>&1 \
  && die "arm accepted an already-armed repo" \
  || say "arm: refuses an already-armed repo ok"

# arm must surface a CLEAN failure on a bad key count, not a raw traceback.
# sync_signers() raises SystemExit for its own CLI entry point's sake;
# `except Exception` does not catch that (BaseException, not Exception) —
# the ceremony has to convert it, or this fails silently in the log instead
# of reporting why.
mkdir -p "$T/repos/fakearm2/packaging"
BARE2="$T/bare-fakearm2.git"
git init -q --bare -b main "$BARE2"
( cd "$T/repos/fakearm2" && git init -q -b main . \
  && echo 0.0.1 > packaging/VERSION \
  && git add -A && git -c user.email=s@s -c user.name=s commit -qm x \
  && git remote add origin "$BARE2" \
  && git push -q -u origin main )
rm -f "$T/keys/id_fake_4.pub"
ENV4="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakearm2 MUDRA_KEY_HOME=$T/keys GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=s@s"
out="$(env $ENV4 "$MUDRA" arm fakearm2 2>&1)"
rc=$?
if [ "$rc" != 0 ] && echo "$out" | grep -qi "refusing\|expected"; then
  say "arm: SystemExit from sync_signers surfaces as a clean failure, not a crash ok"
else
  die "arm's SystemExit-catching didn't work: rc=$rc out=$out"
fi
for i in 1 2 3 4; do
  [ -f "$T/keys/id_fake_$i.pub" ] || ssh-keygen -q -y -f "$T/keys/id_fake_$i" \
    > "$T/keys/id_fake_$i.pub" 2>/dev/null
done

[ "$FAIL" = 0 ] && echo "SMOKE OK" || { echo "SMOKE FAILED"; exit 1; }
