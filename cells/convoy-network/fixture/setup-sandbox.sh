#!/usr/bin/env bash
# Materialize the convoy-network capstone sandbox: an isolated smalltalk network (`convoy init`) + the agent
# working dirs + a tiny hermetic task token. spin.sh then `convoy add`s a cos + worker (ding, NO MCP) and hosts
# them with `convoy up`. Fully synthetic + hermetic — its own ST_ROOT, never the operator's live network.
#   ./setup-sandbox.sh [SANDBOX]
#   needs: CONVOY_BIN (the `convoy` with `up` — the installed 0.1.0 lacks it; set to a built binary until re-published).
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/convoy-network}"
CONVOY="${CONVOY_BIN:-convoy}"
rm -rf "$SB"; mkdir -p "$SB/cos" "$SB/worker"
NET="$SB/net"; mkdir -p "$NET"                       # convoy/st init requires the target dir to EXIST first
# Create + wire the isolated network (ST_ROOT, bus layout, hooks).
"$CONVOY" init "$NET" >/dev/null 2>&1 || { echo "convoy init failed (needs a 'convoy' on PATH + the dir to exist)"; exit 1; }
# The worker's tiny task token — it must read this + reply with it (the loop's payload; keeps the task trivial so
# the cell measures HOSTING + respawn + the threaded reply loop, not the work).
printf 'CONVOY-CAPSTONE-TOKEN: hosted-and-resumed-ok\n' > "$SB/worker/ANSWER.txt"
echo "SANDBOX READY: $SB   (network=$NET; agent dirs cos/ + worker/ + ANSWER.txt)"
