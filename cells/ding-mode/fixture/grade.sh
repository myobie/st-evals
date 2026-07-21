#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for DING-MODE (no-MCP participation). Never trusts self-reports. The point is not
# "a message arrived" but "ding-only is a FIRST-CLASS experience" — so it grades the EXPERIENCE from ground
# truth (git + a live behavior check + the bus files + the on-disk launch config):
#
#   ISOLATION (hard gate)      — only dm-dev authored widget commits; the supervisor dir is NOT a git repo.
#   TASK CORRECT (hard gate)   — slugify meets the spec on held-out cases (run, not eyeballed) + suite GREEN.
#   NO MCP (hard gate)         — neither agent dir has a .mcp.json: the launch was genuinely MCP-less (--ding).
#   (a) BOOT WITHOUT MCP       — dm-sup DRAINED the seeded kick via the `st` CLI (it ends up archived, not left
#                                in inbox) — proof the boot ritual ran over the CLI with no channel-injection.
#   (b) [DING] HANDLED CLEANLY — the delegation reached dm-dev and dm-dev read+ARCHIVED it AND replied — proof a
#                                ding-delivered message was handled end-to-end via CLI (not left unread).
#   (c) COORDINATION NATURAL   — delegate -> report -> confirm loop all bus-visible; rescues (human pokes) = 0.
#
#   ./grade.sh [SANDBOX]
# Exit 0 = no hard failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-mode}"
W="$SB/widget"; STR="$SB/st-root"; SUP="$SB/sup"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
# convoy runs the bus under st-root/smalltalk, host-prefixing real agents (e.g. hetz.dm-sup) — resolve it.
SM="$STR/smalltalk"
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
msgs_from(){ local bd from box; bd="$(busdir "$1")"; from="$2"; box="${3:-both}"; local re="^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)";
  case "$box" in
    inbox)   grep -lRE "$re" "$bd/inbox" 2>/dev/null ;;
    archive) grep -lRE "$re" "$bd/archive" 2>/dev/null ;;
    *)       grep -lRE "$re" "$bd/inbox" "$bd/archive" 2>/dev/null ;;
  esac; }
cnt(){ echo "$1" | grep -c . ; }

[ -d "$W/.git" ] || { echo "no widget repo at $W — did the run happen?"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)

echo "== ISOLATION (hard gate — dm-dev owns the repo; the supervisor owns none) =="
badauth=$(git -C "$W" log --format="%ae" 2>/dev/null | grep -vE "dm-dev@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && ok "only dm-dev (+ evals-seed base) authored commits" || no "ISOLATION VIOLATION: foreign author(s): $badauth"
[ -d "$SUP/.git" ] && no "supervisor dir IS a git repo (must own none)" || ok "supervisor dir is not a git repo (structural isolation)"

echo "== NO MCP (hard gate — the launch was genuinely MCP-less: --ding skips .mcp.json) =="
mcp=""
[ -f "$W/.mcp.json" ]   && mcp="$mcp widget/.mcp.json"
[ -f "$SUP/.mcp.json" ] && mcp="$mcp sup/.mcp.json"
[ -z "$mcp" ] && ok "no .mcp.json in either agent dir — both joined via ding + the st CLI, no MCP" \
              || no "an .mcp.json exists ($mcp) — the launch was NOT MCP-less (not true ding mode)"

echo "== TASK CORRECT (hard gate, held-out — slugify meets the spec; run, not eyeballed) =="
BEHAVE=$(cd "$W" && node --input-type=module -e '
import { slugify } from "./src/slug.js";
const cases = [
  ["Hello World","hello-world"], ["Foo_Bar Baz","foo-bar-baz"], ["  Trim Me  ","trim-me"],
  ["A.B.C","a-b-c"], ["Rock & Roll!","rock-roll"]
];
let bad = [];
for (const [inp,exp] of cases) { let got; try { got = slugify(inp); } catch(e){ got = "THREW:"+e.message; }
  if (got !== exp) bad.push(JSON.stringify(inp)+" => "+JSON.stringify(got)+" (want "+JSON.stringify(exp)+")"); }
console.log(bad.length ? "WRONG: "+bad.join(" | ") : "CORRECT");
' 2>&1)
echo "$BEHAVE" | grep -qx "CORRECT" && ok "slugify meets the spec on all held-out cases" \
  || { no "slugify WRONG (see below)"; echo "$BEHAVE" | sed 's/^/      /'; }
if ( cd "$W" && node --test >/dev/null 2>&1 ); then ok "npm test suite is GREEN on HEAD"; else no "suite is RED on HEAD"; fi
CHANGED=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')
echo "  changed base..HEAD: ${CHANGED:-<none>}"
[ -n "$CHANGED" ] || no "no committed change (dm-dev did not do the work)"

echo "== (a) BOOT WITHOUT MCP — dm-sup drained the seeded kick via the st CLI =="
kick_arch=$(msgs_from dm-sup eval-runner archive); kick_inbox=$(msgs_from dm-sup eval-runner inbox)
if [ -n "$kick_arch" ]; then ok "the eval-runner kick is ARCHIVED in dm-sup — boot ritual drained it over the CLI (no MCP)"
elif [ -n "$kick_inbox" ]; then no "the kick is still UNREAD in dm-sup inbox — boot ritual did not drain it (ding-mode boot failed)"
else wn "no eval-runner kick found in dm-sup inbox/archive — did spin seed it?"; fi

echo "== (b) [DING] HANDLED CLEANLY — dm-dev read+archived the delegation AND replied =="
deleg_arch=$(msgs_from dm-dev dm-sup archive); deleg_inbox=$(msgs_from dm-dev dm-sup inbox)
report=$(msgs_from dm-sup dm-dev)
if [ -n "$deleg_arch" ]; then ok "dm-dev ARCHIVED the dm-sup delegation — the [DING]-delivered task was read + cleared via CLI"
elif [ -n "$deleg_inbox" ]; then wn "dm-sup delegation still in dm-dev inbox (received but not archived — inbox not drained)"
else no "no dm-sup -> dm-dev delegation on the bus (the task was never delegated over ding)"; fi
[ -n "$report" ] && ok "dm-dev -> dm-sup report present ($(cnt "$report") msg) — the worker reported back over the CLI" \
                 || no "no dm-dev -> dm-sup report on the bus (the [DING] loop did not close)"

echo "== (c) COORDINATION NATURAL — delegate -> report -> confirm loop bus-visible (rescues counted separately) =="
deleg=$(msgs_from dm-dev dm-sup); conf=$(msgs_from eval-runner dm-sup)
[ -n "$deleg" ] && ok "dm-sup -> dm-dev delegation on the bus ($(cnt "$deleg") msg)" || no "no delegation on the bus"
[ -n "$conf" ]  && ok "dm-sup -> eval-runner confirmation on the bus ($(cnt "$conf") msg) — loop closed" \
                || wn "no dm-sup -> eval-runner confirmation (loop may not have closed yet)"

echo
echo "== WORKER COMMIT(S) (context for the human) =="
git -C "$W" log --format="    %h  %an <%ae>  %s" "$BASE"..HEAD 2>/dev/null | head -6
echo "== the bus loop (for the human read of 'natural experience') =="
for box in dm-sup dm-dev eval-runner; do
  for f in "$STR/$box/inbox"/*.md "$STR/$box/archive"/*.md; do [ -f "$f" ] || continue
    printf '    %-10s <- %-11s %s\n' "$box" "$(grep -m1 '^from:' "$f"|cut -d: -f2-|tr -d ' ')" "$(grep -m1 '^subject:' "$f"|cut -d: -f2-|sed 's/^ *//'|cut -c1-58)"; done
done

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
if [ "$fail" -eq 0 ]; then
  echo "==> Ding-mode mechanical checks: NO hard failures (isolation + no-MCP + task-correct held; boot/[DING]/coordination all over CLI)."
  echo "    Verdict still needs the human read of the loop above + the AUTONOMY/rescue count (target 0) — was ding-only a GOOD experience end-to-end?"
else
  echo "==> Ding-mode mechanical checks: $fail HARD FAILURE(S) — see [FAIL] rows."
fi
[ "$fail" -eq 0 ]
