#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (convoy-doctor-preinit) — DETERMINISTIC, box-free, no LLM. Guards the Johannes FIRST-COMMAND UX
# (redesign, convoy #63/3fc9dc32d): a brand-new user who runs `convoy doctor` BEFORE `convoy init` must get a
# friendly neutral pointer ("network: no network here yet — run convoy init") + rc=0 — NOT the old scary
# ✗ named network / ✗ smalltalk MISSING failure wall (rc=1). Captures:
#   pre.out/pre.rc   — `convoy doctor --quick --network <FRESH uninitialized path>`  (neutral line, rc 0)
#   post.out/post.rc — same on a POST-init net (the full Structure check list, NOT the neutral line) = the contrast
#
# ISOLATION: scoped with --network + ambient ST_ROOT/PTY_ROOT/CONVOY_NETWORK unset (a bare doctor hits the real
# default net); --quick does not spawn agents. Never touches the live fleet.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdp}"
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"
cv(){ env -u ST_ROOT -u PTY_ROOT -u CONVOY_NETWORK convoy "$@"; }

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/shape.txt"; exit 0
fi
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
  git -C "$(dirname "$cvr")/.." diff --quiet 2>/dev/null && echo "convoy_worktree=clean" || echo "convoy_worktree=DIRTY (ahead of committed sha)"
} > "$P/convoy-version.txt" 2>/dev/null || true

fresh="$SB/fresh"   # a FRESH, uninitialized network path (never `convoy init`ed)
post="$SB/post"     # a POST-init net (the contrast)
mkdir -p "$fresh"
mega="$SB/mega"; mkdir -p "$mega"; git -C "$mega" init -q; git -C "$mega" config user.email m@e.l; git -C "$mega" config user.name m
printf '# m\n' > "$mega/README.md"; git -C "$mega" add -A && git -C "$mega" commit -q -m seed
cv init "$post" --megarepo "$mega" --quiet >/dev/null 2>&1

echo "== convoy doctor --quick on a FRESH (uninitialized) net + a POST-init net =="
cv doctor --quick --network "$fresh" > "$P/pre.out"  2>&1; echo "$?" > "$P/pre.rc"
cv doctor --quick --network "$post"  > "$P/post.out" 2>&1; echo "$?" > "$P/post.rc"

echo "== capture the shape =="
{
  echo "pre_rc=$(cat "$P/pre.rc")"
  grep -qiE 'no network here yet|no network here' "$P/pre.out" && echo "pre_neutral=yes" || echo "pre_neutral=no"
  # the OLD scary wall must be GONE from the pre-init output
  grep -qiE '✗ named network|MISSING:' "$P/pre.out" && echo "pre_scary_wall=yes" || echo "pre_scary_wall=no"
  # CONTRAST (mutation-valid): a POST-init net shows the real checks, NOT the neutral line.
  echo "post_rc=$(cat "$P/post.rc")"
  grep -qiE 'no network here yet' "$P/post.out" && echo "post_neutral=yes" || echo "post_neutral=no"
  grep -q '^Structure —' "$P/post.out" && echo "post_has_checks=yes" || echo "post_has_checks=no"
} > "$P/shape.txt"
sed 's/^/     /' "$P/shape.txt"

echo "== teardown =="; cv down "$post" --force >/dev/null 2>&1 || true

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
