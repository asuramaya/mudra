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

# MUDRA_CONFIG_PATH points at a path that never exists, on every env string
# in this file: without it, any of these calls would fall through to this
# machine's REAL ~/.config/mudra/config.json (roster, namespace tag, etc.)
# for whatever this fixture's env doesn't explicitly override — silently
# contaminating a fixture-only test with real local configuration.
ENV="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakepill,fakepackaged,rotten-apple,fakeunknown MUDRA_KEY_HOME=$T/keys MUDRA_ROOT_LAYOUT_REPOS=rotten-apple MUDRA_NAMESPACE_TAG=pills-tag MUDRA_CONFIG_PATH=$T/no-config.json"

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

# NEGATIVE CONTROL: same repo, root-layout exception NOT configured this
# time (MUDRA_ROOT_LAYOUT_REPOS simply omitted) -> must NOT read armed. A
# green positive alone can't tell "the carve-out works" from "something
# else resolved it"; this is the other half of the proof. Now that the
# exception set is config/env-driven rather than a hardcoded literal, the
# negative control is just running with it unset — no sed'd throwaway copy
# of the script needed.
out="$(env MUDRA_REPO_ROOT="$T/repos" MUDRA_REPOS=rotten-apple MUDRA_KEY_HOME="$T/keys" \
       MUDRA_CONFIG_PATH="$T/no-config.json" "$MUDRA" status --no-remote --json)"
echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); \
   r=[x for x in d['repos'] if x['name']=='rotten-apple'][0]; \
   sys.exit(0 if r['anchor']=='unrecognized-layout' else 1)" \
  && say "negative control: without the exception configured, rotten-apple reads unrecognized-layout ok" \
  || die "negative control: rotten-apple stayed armed with the exception unconfigured — carve-out isn't load-bearing"

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
ENV2="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakepill,fakepackaged MUDRA_KEY_HOME=$T/keys MUDRA_CONFIG_PATH=$T/no-config.json"
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

# namespace has no forced second tag when MUDRA_NAMESPACE_TAG isn't
# configured (ENV2 doesn't set it) — the old hardcoded ",pills-tag" is gone,
# a stranger's anchor shouldn't carry a family tag they never asked for
grep -q 'fakepackaged namespaces="fakepackaged-release" ' \
     "$T/repos/fakepackaged/packaging/release-signing/allowed_signers" \
  && say "sync-signers: namespace carries no unconfigured tag ok" \
  || die "namespace included a tag that was never configured"

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
ENV3="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakearm MUDRA_KEY_HOME=$T/keys MUDRA_CONFIG_PATH=$T/no-config.json GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=s@s"
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
ENV4="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=fakearm2 MUDRA_KEY_HOME=$T/keys MUDRA_CONFIG_PATH=$T/no-config.json GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=s@s"
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

# KEY SETUP WIZARD: keysetup's own key-file naming is MUDRA_KEY_PREFIX-driven
# (id_<prefix>_N — set explicitly below, not left at whatever the default
# happens to be, so this test stays correct regardless of default drift),
# unrelated to whatever names sit in a MUDRA_KEY_HOME used for arming/
# sealing above. Needs its own, separate, initially-empty key home.
mkdir -p "$T/bin"
REAL_SSH_KEYGEN="$(command -v ssh-keygen)"
# Real hardware (-t ed25519-sk) can't exist in a sandbox and can't be
# touched by anything but the operator's own hand — this test double
# substitutes a plain ed25519 key for that ONE invocation shape (dropping
# the sk-only -O flags a non-hardware key type would reject) and passes
# every other call (fingerprint listing, etc.) straight through to the
# real ssh-keygen untouched, so the wizard's own plumbing — arg
# construction, the refuse-without-force guard, success/failure handling —
# is exercised without ever pretending to prove real FIDO2 generation works.
cat > "$T/bin/ssh-keygen" <<SHIM
#!/usr/bin/env python3
import subprocess, sys
args = sys.argv[1:]
if "-t" in args and args[args.index("-t") + 1] == "ed25519-sk":
    out, skip = [], 0
    for a in args:
        if skip: skip -= 1; continue
        if a == "-t": out += ["-t", "ed25519"]; skip = 1; continue
        if a == "-O": skip = 1; continue
        out.append(a)
    sys.exit(subprocess.call(["$REAL_SSH_KEYGEN"] + out))
sys.exit(subprocess.call(["$REAL_SSH_KEYGEN"] + args))
SHIM
chmod +x "$T/bin/ssh-keygen"

# MUDRA_KEYMAP_PATH keeps device-fingerprint learning off the real
# ~/.config/mudra/keymap.json: this is the first path through smoke.sh that
# ever calls learn_key() (arm/sync-signers never touch it), and on any
# machine with a real hardware key plugged in, an unsandboxed run would
# silently map that real device to this test's throwaway slot.
ENV5="MUDRA_KEY_HOME=$T/keys3 MUDRA_KEYMAP_PATH=$T/keymap.json MUDRA_KEY_PREFIX=fake_master MUDRA_CONFIG_PATH=$T/no-config.json PATH=$T/bin:$PATH"

# fresh key home: not on disk yet, every slot reads empty rather than erroring
out="$(env $ENV5 "$MUDRA" keysetup 2>&1)"
echo "$out" | grep -q "MISSING" && [ "$(echo "$out" | grep -c 'slot .: empty')" = 4 ] \
  && say "keysetup: fresh key home reads all 4 slots empty ok" \
  || die "keysetup status on a fresh key home: $out"

# generate into an empty slot
out="$(env $ENV5 "$MUDRA" keysetup --slot 1 2>&1)"
rc=$?
if [ "$rc" = 0 ] && [ -s "$T/keys3/id_fake_master_1.pub" ] \
   && [ -e "$T/keys3/id_fake_master_1" ]; then
  say "keysetup: generates a fresh slot ok (respects MUDRA_KEY_PREFIX)"
else
  die "keysetup --slot 1 didn't provision (rc=$rc): $out"
fi

# RP-ID/comment derives from KEY_PREFIX with underscores turned to hyphens
# (id_fake_master_1's file stem keeps the underscore; the FIDO2
# application/comment convention uses hyphens) — the one place the prefix
# is rendered two different ways from the same config value.
grep -q ' fake-master-1$' "$T/keys3/id_fake_master_1.pub" \
  && say "keysetup: RP-ID/comment derives fake-master-1 from prefix fake_master ok" \
  || die "RP-ID/comment didn't derive correctly from MUDRA_KEY_PREFIX: $(cat "$T/keys3/id_fake_master_1.pub")"

# refuses to clobber an occupied slot without --force
out="$(env $ENV5 "$MUDRA" keysetup --slot 1 2>&1)"
rc=$?
if [ "$rc" != 0 ] && echo "$out" | grep -qi "already has a key"; then
  say "keysetup: refuses an occupied slot without --force ok"
else
  die "keysetup didn't refuse to clobber an occupied slot (rc=$rc): $out"
fi

# --force replaces it cleanly
env $ENV5 "$MUDRA" keysetup --slot 1 --force >/dev/null 2>&1 \
  && say "keysetup: --force replaces an occupied slot ok" \
  || die "keysetup --force did not succeed on an occupied slot"

# --map: either registers whatever device is plugged in, or refuses
# cleanly if none is — never a raw traceback either way. Whether a real
# hardware key happens to be plugged into the machine running this test is
# environment-dependent (CI never has one; a dev box sometimes does), so
# this checks the behavior that matches whichever state is actually true
# rather than assuming one.
out="$(env $ENV5 "$MUDRA" keysetup --map 2 2>&1)"
rc=$?
if echo "$out" | grep -q "Traceback"; then
  die "keysetup --map crashed instead of a clean result: $out"
elif [ "$rc" = 0 ]; then
  echo "$out" | grep -q "^slot 2 <- " \
    && say "keysetup: --map registers the currently-detected device ok" \
    || die "keysetup --map exited 0 but printed something unexpected: $out"
else
  echo "$out" | grep -qi "no single connected key" \
    && say "keysetup: --map with no device connected fails clean ok" \
    || die "keysetup --map failed for the wrong reason: $out"
fi

# LIVE CONFIG RELOAD (msg 3439): a restart-based test proves nothing here —
# the bug was specifically that a LONG-RUNNING `mudra serve` process froze
# REPO_ROOT/KEY_HOME/ROSTER/etc at import time and never re-read config.json,
# so an operator's own hand-edit (or the setup tab's own write_config())
# landed on disk but kept serving the old roster until the unit died. This
# starts a real `mudra serve`, edits config.json UNDER THE LIVE PROCESS with
# a plain overwrite (not mudra's own write_config() -- proving the fix
# covers an EXTERNAL edit, the path the operator actually took, not just
# mudra's own save path), and asserts /api/status's own observation changed.
# A fresh HOME keeps write_session()'s session.json (no MUDRA_* override
# exists for it) away from anything else this file has touched.
mkdir -p "$T/livehome/.config/mudra" "$T/repos/livecfg-a/packaging" "$T/repos/livecfg-b/packaging"
for r in livecfg-a livecfg-b; do
  ( cd "$T/repos/$r" && git init -q . && echo 0.0.1 > packaging/VERSION \
    && git add -A && git -c user.email=s@s -c user.name=s commit -qm x )
done
LIVECFG="$T/livehome/.config/mudra/config.json"
printf '{"repos": ["livecfg-a"]}' > "$LIVECFG"
LIVEPORT=27771
env HOME="$T/livehome" MUDRA_CONFIG_PATH="$LIVECFG" MUDRA_REPO_ROOT="$T/repos" \
    MUDRA_KEY_HOME="$T/keys" MUDRA_PORT="$LIVEPORT" "$MUDRA" serve \
    >"$T/live-serve.log" 2>&1 &
LIVE_PID=$!
LIVE_TOKEN=""
for _ in $(seq 1 50); do
  if [ -f "$T/livehome/.config/mudra/session.json" ]; then
    LIVE_TOKEN="$(python3 -c "import json;print(json.load(open('$T/livehome/.config/mudra/session.json'))['token'])" 2>/dev/null)"
    [ -n "$LIVE_TOKEN" ] && break
  fi
  sleep 0.1
done
if [ -z "$LIVE_TOKEN" ]; then
  die "live-reload: mudra serve never started: $(cat "$T/live-serve.log")"
else
  before="$(curl -s "http://127.0.0.1:$LIVEPORT/api/status?token=$LIVE_TOKEN" \
    | python3 -c "import json,sys; print(','.join(sorted(r['name'] for r in json.load(sys.stdin)['repos'])))" 2>/dev/null)"
  printf '{"repos": ["livecfg-b"]}' > "$LIVECFG"
  after="$(curl -s "http://127.0.0.1:$LIVEPORT/api/status?token=$LIVE_TOKEN" \
    | python3 -c "import json,sys; print(','.join(sorted(r['name'] for r in json.load(sys.stdin)['repos'])))" 2>/dev/null)"
  if [ "$before" = "livecfg-a" ] && [ "$after" = "livecfg-b" ]; then
    say "live-reload: a live serve process picks up an external config.json edit, no restart ok"
  else
    die "live-reload: process kept serving a stale roster after an external edit (before=$before after=$after)"
  fi
fi
kill "$LIVE_PID" 2>/dev/null
wait "$LIVE_PID" 2>/dev/null

# NEGATIVE CONTROL for sync-signers' missing-repo guard: a roster entry with
# no matching directory at all (a rename, or a name that never existed) must
# refuse rather than os.makedirs() + write a signer file into a path nothing
# tracks -- the "dangerous door" half of msg 3439 (thread 6c3ec0b4). Must
# NOT create the directory.
ENV6="MUDRA_REPO_ROOT=$T/repos MUDRA_REPOS=ghost-repo MUDRA_KEY_HOME=$T/keys MUDRA_CONFIG_PATH=$T/no-config.json"
out="$(env $ENV6 "$MUDRA" sync-signers ghost-repo 2>&1)"
rc=$?
if [ "$rc" != 0 ] && echo "$out" | grep -qi "missing" && [ ! -e "$T/repos/ghost-repo" ]; then
  say "sync-signers: refuses a missing repo instead of resurrecting a skeleton dir ok"
else
  die "sync-signers: missing-repo guard didn't fire (rc=$rc, dir exists=$([ -e "$T/repos/ghost-repo" ] && echo yes || echo no)): $out"
fi

[ "$FAIL" = 0 ] && echo "SMOKE OK" || { echo "SMOKE FAILED"; exit 1; }
