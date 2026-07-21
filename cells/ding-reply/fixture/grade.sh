#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Grader for ding-reply. THE DISCRIMINATOR: did the agent reply to the seeded message via `st message reply`
# (the threaded CLI verb) — proven by the reply landing in the requester's inbox with `in-reply-to: <kick>` —
# carrying the ANSWER.txt token, with NO MCP? Fails LOUD if the CLI reply verb is missing/broken — the exact
# coverage the reply bug slipped through. A plain `st message send` (no in-reply-to) does NOT pass.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-reply}"
STR="$SB/st-root"; AGENT="dr-agent"; REQ="dr-req"; d="$SB/work"
# convoy runs the bus under st-root/smalltalk, host-prefixing real agents (e.g. hetz.dr-agent; the synthetic
# requester dr-req stays bare). Resolve an id to its bus dir + build a host-prefix-tolerant `from:` regex.
SM="$STR/smalltalk"
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
pfrom(){ printf '^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?%s([[:space:]]|$)' "$1"; }
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

[ -d "$STR" ] || { echo "no bus at $STR — did spin run?"; exit 1; }
kickfn="$(cat "$SB/.stev/kick-filename" 2>/dev/null)"
token="$(tr -d '\r\n' < "$d/ANSWER.txt" 2>/dev/null)"

echo "== NO MCP (hard gate — the MCP-less config: --ding skips .mcp.json) =="
[ -f "$d/.mcp.json" ] && no "an .mcp.json exists in the agent dir — NOT MCP-less (not true ding mode)" \
                       || ok "no .mcp.json in the agent dir — the agent joined via ding + the st CLI, no MCP"

echo "== BOOT (the [DING]-delivered kick was drained over the CLI) =="
if grep -lqRE "$(pfrom "$REQ")" "$(busdir "$AGENT")/archive" 2>/dev/null; then
  ok "the requester's kick is ARCHIVED in $AGENT — boot ritual drained it via the st CLI"
elif grep -lqRE "$(pfrom "$REQ")" "$(busdir "$AGENT")/inbox" 2>/dev/null; then
  wn "the kick is still UNREAD in $AGENT inbox — received but not archived (inbox not drained)"
else
  no "no requester kick found in $AGENT inbox/archive — did spin seed it?"
fi

echo "== THREADED REPLY (hard gate — the discriminator: st message reply, not send) =="
reply="$(grep -lRE "$(pfrom "$AGENT")" "$(busdir "$REQ")/inbox" "$(busdir "$REQ")/archive" 2>/dev/null | head -1)"
if [ -z "$reply" ]; then
  no "NO reply from $AGENT in $REQ's inbox — the agent never replied over the bus ('st message reply' may be missing/broken)"
else
  ok "a reply from $AGENT landed in $REQ's inbox ($(basename "$reply"))"
  irt="$(grep -E '^in-reply-to:' "$reply" 2>/dev/null | head -1 | sed 's/^in-reply-to:[[:space:]]*//')"
  if [ -n "$kickfn" ] && [ "$irt" = "$kickfn" ]; then
    ok "the reply is THREADED — in-reply-to: $irt == the seeded kick (proves 'st message reply', not a fresh send)"
  elif [ -n "$irt" ]; then
    wn "reply has in-reply-to: $irt but not the kick ($kickfn) — threaded, but confirm it's the right thread"
  else
    no "the reply has NO in-reply-to — a plain 'st message send', NOT the threaded 'st message reply' (the exact bug case)"
  fi
  if [ -n "$token" ] && grep -qF "$token" "$reply"; then
    ok "the reply body carries the ANSWER.txt token ($token) — the agent read the file + answered correctly"
  else
    no "the reply body does NOT carry the ANSWER.txt token ($token) — wrong/missing answer"
  fi
fi

echo
echo "SCORE (mechanical): $pass PASS / $fail FAIL / $warn WARN"
echo "AUTONOMY (headline): rescues to boot + reply over ding/CLI with no MCP — target 0 (from the run log)."
[ "$fail" -eq 0 ] && echo "==> ding-reply: PASS — no-MCP ding boot + a THREADED st-message-reply carrying the right answer. The MCP-less reply path works end-to-end." \
                   || echo "==> ding-reply: FAIL — see [FAIL] rows (this is exactly the coverage the reply bug needed)."
[ "$fail" -eq 0 ]
