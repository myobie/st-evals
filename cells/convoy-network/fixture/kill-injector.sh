#!/usr/bin/env bash
# The novel harness piece: kill the worker's session mid-run so `convoy up` must RESPAWN it (the reboot's
# respawn-ownership gate — scripted fault injection, NOT a human rescue). Waits for a deterministic checkpoint
# (cap-wk received cap-cos's delegation), pty-kills cap-wk's session, and records the kill. convoy up's next
# reconcile respawns it (resuming its session) -> a `respawn` event in the --json log; the worker resumes + finishes.
#   ./kill-injector.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/convoy-network}"
NET="$SB/net"; export ST_ROOT="$NET"
# Checkpoint: wait until cap-wk has the delegation (a message from cap-cos in its inbox/archive).
for _ in $(seq 1 60); do
  grep -lqRE '^from:[[:space:]]*cap-cos' "$NET/cap-wk/inbox" "$NET/cap-wk/archive" 2>/dev/null && break
  sleep 2
done
# Find cap-wk's pty session + kill it (the fault).
sess="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -oE 'cap-wk[A-Za-z0-9_-]*' | head -1)"
[ -n "$sess" ] || sess="cap-wk"
pty kill "$sess" >/dev/null 2>&1 || true
printf 'killed %s at %s\n' "$sess" "$(date +%s)" > "$SB/.kill.log"
echo "INJECTED: killed cap-wk session '$sess'. convoy up must RESPAWN it next reconcile. Grade once the loop settles."
