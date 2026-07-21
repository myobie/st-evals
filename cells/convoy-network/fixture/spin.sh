#!/usr/bin/env bash
# Spin the convoy-network CAPSTONE (the reboot go/no-go): `convoy add` a cos + worker (ding, NO MCP), seed the
# task, and HOST them with `convoy up` (foreground supervisor + respawn, --json event stream). Stand up → host →
# message → threaded reply, all ding/no-MCP/no-app; a mid-run kill (kill-injector) the host must RESPAWN. AFTER setup.
#   ./spin.sh [SANDBOX]        # needs: CONVOY_BIN (a convoy with `up`), PERSONAS_DIR.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"                # stev_seed_kick (deliver the kick over the real bus)
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/convoy-network}"
CONVOY="${CONVOY_BIN:-convoy}"
NET="$SB/net"
[ -d "$NET" ] || "$HERE/setup-sandbox.sh" "$SB"
export ST_ROOT="$NET"                                # the isolated network — never the operator's live one

echo "== compose personas (cos + worker; ding, no MCP) =="
"$HERE/compose-persona.sh" cos "$SB" >/dev/null
"$HERE/compose-persona.sh" worker "$SB" >/dev/null

echo "== convoy add the worker (ding, auto — NO MCP) =="
# --force makes the declare idempotent (overwrites an existing catalog entry) — the modern replacement for the
# removed `convoy remove ... --yes` pre-clean (`--yes` is gone from `convoy add`; there is no `convoy remove`).
"$CONVOY" add worker --identity cap-wk --network "$NET" --dir "$SB/worker" --persona "$SB/personas-local/cap-wk.md" --force

echo "== convoy add the cos (ding, bypass, PERMANENT — the respawn target) =="
"$CONVOY" add cos --identity cap-cos --network "$NET" --dir "$SB/cos" --persona "$SB/personas-local/cap-cos.md" --permanent --force

echo "== HOST with 'convoy up' (foreground supervisor + respawn; --json event stream captured) =="
# `convoy up` (continuous) reconciles the declared catalog (cap-cos + cap-wk) and LAUNCHES them. We host
# FIRST, then deliver the kick — convoy runs the bus at $NET/smalltalk/<host>.cap-cos, so the pre-convoy
# $NET/cap-cos/inbox file-drop landed where nobody watched (the kick never reached cap-cos → hollow spin).
: > "$SB/.convoy-up.log"
"$CONVOY" up "$NET" --json >> "$SB/.convoy-up.log" 2>&1 &
echo $! > "$SB/.convoy-up.pid"
echo "   convoy up hosting (pid $(cat "$SB/.convoy-up.pid")); events -> $SB/.convoy-up.log"

echo "== deliver the requester's kick to cap-cos over the REAL bus once convoy up registers it =="
# stev_seed_kick waits for cap-cos to register its host-prefixed bus dir (convoy up is booting it), then
# st-sends the kick (from cap-req, per the kick's from:) and returns the delivered filename for the
# threaded-reply grader check. Pre-create cap-req's box so the on-thread reply has somewhere to land.
mkdir -p "$NET/smalltalk/cap-req/inbox" "$NET/smalltalk/cap-req/archive"
kickfn="$(stev_seed_kick "$NET" "cap-cos" "$HERE/kick.md")"
printf '%s\n' "$kickfn" > "$SB/.kick-filename"; echo "   delivered kick -> cap-cos ($kickfn)"

echo
echo "SPUN (convoy-network, isolated net $NET). convoy up HOSTS cap-cos (permanent) + cap-wk (ding, no MCP)."
echo "OBSERVE: cap-cos delegates to cap-wk -> cap-wk reads ANSWER.txt + replies on-thread -> cap-cos replies to"
echo "  cap-req on-thread. INJECT the mid-run kill: $HERE/kill-injector.sh \"$SB\"  (convoy up must RESPAWN cap-wk)."
echo "GRADE:    $HERE/grade.sh \"$SB\""
echo "TEARDOWN: kill \$(cat $SB/.convoy-up.pid) 2>/dev/null; $CONVOY down \"$NET\" --force   (down is the only path that kills sessions)"
