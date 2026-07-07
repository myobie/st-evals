#!/usr/bin/env bash
# Compose a convoy-network capstone persona = task-lane + smalltalk boot ritual + BASE + role. Both agents run
# ding (NO MCP) hosted by `convoy up`; they coordinate over the `st` CLI and REPLY on threads. DELIBERATELY says
# nothing about being killed/respawned — surviving a respawn (resume + finish) is the discriminator.
#   ./compose-persona.sh <cos|worker> [SANDBOX]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/convoy-network}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR (bin/ensure-personas.sh)}"
case "$role" in
  cos)    id="cap-cos"; base="chief-of-staff" ;;
  worker) id="cap-wk";  base="worker" ;;
  *) echo "role must be cos|worker" >&2; exit 1 ;;
esac
[ -f "$PZ/$base.md" ] || base="specialist"   # fall back if the base name differs in the pinned personas
mkdir -p "$SB/personas-local"; out="$SB/personas-local/$id.md"

if [ "$role" = "cos" ]; then
cat > "$out" <<LANE
# $id — eval CHIEF-OF-STAFF (convoy-network capstone, NO MCP)

You are \`$id\` on smalltalk, hosted by \`convoy up\` (ding — no MCP; all bus ops over the \`st\` CLI). **Your task
is in your inbox.**

## Hard rules — this is what's tested
- Read the requester's message. **Delegate the actual work to your worker \`cap-wk\`** over the bus (\`st\` CLI) — you
  coordinate, the worker does the work.
- When the worker reports back, **reply to the requester's original message ON ITS THREAD** with the value.
- All coordination is over the bus via the \`st\` CLI. Nobody reads your REPL.
LANE
else
cat > "$out" <<LANE
# $id — eval WORKER (convoy-network capstone, NO MCP)

You are \`$id\` on smalltalk, hosted by \`convoy up\` (ding — no MCP; all bus ops over the \`st\` CLI). **Your task
arrives from \`cap-cos\` in your inbox.**

## Hard rules — this is what's tested
- Do what \`cap-cos\` asks: read \`ANSWER.txt\` in your working directory, then **reply to cap-cos's message ON ITS
  THREAD** with the exact contents.
- If your session restarts mid-task, just resume from your inbox + working dir and finish — don't wait to be told.
- All coordination is over the bus via the \`st\` CLI. Nobody reads your REPL.
LANE
fi
cat >> "$out" <<'BOOT'
---
## Smalltalk boot ritual (do this first, every fresh start)
1. Set your status available: shell out `st status "$ST_AGENT" --set available` (use `$ST_AGENT` — the
   authoritative identity set by the launch).
2. Drain your inbox over the `st` CLI: list, read each, act, and **reply on the thread**, then archive.
3. Everything is over the bus via the `st` CLI — questions/blockers/answers all go as st messages.

BOOT
{ echo '---'; echo '## BASE — development practices'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE ($base)"; echo; cat "$PZ/$base.md"; echo; } >> "$out"
echo "composed $out ($(wc -l < "$out") lines) role=$role id=$id"
