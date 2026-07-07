#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for weird-git-setup. The DISCRIMINATOR: did the agent resolve its WORKTREE and commit the
# fix ON THE FEATURE BRANCH — not main, not the bare repo, not the sibling wt/main — with the suite green? A naive
# agent that mishandles the `.git`-as-file / shared-store layout commits nowhere useful, or leaks into main.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/weird-git-setup}"
WT="$SB/wt/feature"; BARE="$SB/canonical.git"; WTMAIN="$SB/wt/main"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

[ -d "$BARE" ] && [ -e "$WT/.git" ] || { echo "no sandbox at $SB — did setup/spin run?"; exit 1; }
SEED="$(git -C "$BARE" rev-list --max-parents=0 main 2>/dev/null | tail -1)"   # the seed root commit on main

echo "== WORKTREE SANITY (the layout the agent had to cope with) =="
[ -f "$WT/.git" ] && ok "wt/feature is a linked worktree (.git is a FILE, not a dir)" || no "wt/feature .git is not a file — not a worktree?"
[ "$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "feature" ] && ok "wt/feature is on branch 'feature'" || no "wt/feature is not on 'feature'"

echo "== TASK SUCCESS (hard gate — suite green IN THE WORKTREE) =="
( cd "$WT" && node --test >/dev/null 2>&1 ) && ok "node --test GREEN in wt/feature (the above-range bug is fixed)" || no "node --test RED in wt/feature (bug not fixed / suite broken)"

echo "== LAYOUT DETECTION / BRANCH ATTRIBUTION (the discriminator) =="
ahead="$(git -C "$WT" rev-list --count "$SEED"..HEAD 2>/dev/null || echo 0)"
[ "${ahead:-0}" -ge 1 ] && ok "the fix is committed on 'feature' ($ahead commit(s) beyond the seed)" || no "no commit on 'feature' beyond the seed — the agent didn't commit its fix on this worktree's branch"
tipae="$(git -C "$WT" show -s --format='%ae' HEAD 2>/dev/null)"
case "$tipae" in
  wt-feature@*) ok "feature tip authored by the worktree's pinned author ($tipae)" ;;
  *seed@*)      no "feature tip is still the seed commit (no agent work landed on this branch)" ;;
  *)            wn "feature tip authored by unexpected '$tipae' — eyeball it" ;;
esac
[ "$(git -C "$BARE" rev-parse main 2>/dev/null)" = "$SEED" ] && ok "canonical 'main' UNCHANGED (no leak into the bare repo)" || no "canonical 'main' MOVED — the agent committed to the wrong branch/repo"
if [ -d "$WTMAIN" ]; then
  { [ "$(git -C "$WTMAIN" rev-parse HEAD 2>/dev/null)" = "$SEED" ] && [ -z "$(git -C "$WTMAIN" status --porcelain 2>/dev/null)" ]; } \
    && ok "sibling wt/main clean + at seed (untouched)" || no "sibling wt/main was modified — cross-worktree leak"
fi

echo "== FIX CORRECTNESS + REGRESSION TEST =="
tcount="$(git -C "$WT" show HEAD:test/clamp.test.js 2>/dev/null | grep -cE '^[[:space:]]*test\(' || echo 0)"
[ "${tcount:-0}" -ge 4 ] && ok "a regression test was added (test/clamp.test.js has $tcount cases; seed had 3)" || wn "no extra test case beyond the seed's 3 — regression test may be missing (confirm)"

echo
echo "SCORE (mechanical): $pass PASS / $fail FAIL / $warn WARN"
echo "AUTONOMY (the live-grade HEADLINE): rescues to get working despite the weird git — target 0 (read the run log)."
[ "$fail" -eq 0 ] && echo "==> weird-git-setup: mechanical gates held (worktree resolved · fix on feature · suite green · no cross-worktree leak). Autonomy verdict needs the live run." \
                   || echo "==> weird-git-setup: FAIL — see [FAIL] rows."
[ "$fail" -eq 0 ]
