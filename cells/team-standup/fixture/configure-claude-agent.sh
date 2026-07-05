#!/usr/bin/env bash
# Wire the TEAM-STANDUP CoS as a spawn-capable Claude agent on an ISOLATED bus root ($SB/st-root, never
# the live network): coord MCP + asyncRewake hook + pty.toml (HB-3 env explicit) + pre-trust + bootstrap
# jsonl. ONLY the CoS is wired here — the CoS stands up taskflow-dev itself via `st launch` (that IS the
# P5 test). Posture: CoS = bypassPermissions (spawn-capable; it shells `st launch` + `pty up`).
#   ./configure-claude-agent.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
STR="$SB/st-root"
HOOKS="${ST_HOOKS_DIR:?set ST_HOOKS_DIR to <smalltalk>/examples/claude-code/hooks}"
id="cos"; d="$SB/cos"; mode="bypassPermissions"
# The pty session namespace is GLOBAL (unlike the coord bus, which we isolate via ST_ROOT). If you already
# run a chief-of-staff pty session (prefix `cos`), give this eval CoS a DISTINCT pty PREFIX so `pty up`
# can't clobber it. The coord identity stays `cos` (on the isolated sandbox bus); only the pty prefix differs.
PTY_PREFIX="ts-cos"
sid="$(uuidgen | tr 'A-Z' 'a-z')"

# Pre-trust the CoS dir for Claude Code (skip the folder-trust gate on launch).
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json"); d=json.load(open(p))
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

mkdir -p "$STR/$id/inbox" "$STR/$id/archive"; printf 'available\n' > "$STR/$id/status"
mkdir -p "$d/.claude"; printf '%s\n' "$sid" > "$d/.claude-session-id"

cat > "$d/.mcp.json" <<JSON
{
  "mcpServers": {
    "coord": { "type": "stdio", "command": "$(command -v coord || echo coord)", "args": ["mcp", "--channel"], "env": {} }
  }
}
JSON

cat > "$d/.claude/settings.local.json" <<JSON
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "enabledMcpjsonServers": ["coord"],
  "enableAllProjectMcpServers": true,
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "$HOOKS/session-start.sh", "async": true, "asyncRewake": true }] }],
    "StopFailure": [{ "hooks": [{ "type": "command", "command": "$HOOKS/stop-failure.sh" }] }]
  }
}
JSON

# HB-3: pin every identity var to the CoS in its own pty.toml env, and pin ST_ROOT/COORD_ROOT to the
# ISOLATED sandbox bus so nothing touches the live network. (COORD_IDENTITY=cos here is correct for the
# CoS; it can leak into a child via `st launch`, but the child's ST_AGENT wins — see the worker persona.)
cat > "$d/pty.toml" <<TOML
prefix = "$PTY_PREFIX"

[sessions.claude]
command = "claude --permission-mode $mode --dangerously-load-development-channels server:st --resume $sid"
tags = { role = "agent" }

[sessions.claude.env]
ST_AGENT = "$id"
COORD_IDENTITY = "$id"
ST_IDENTITY = "$id"
ST_ROOT = "$STR"
COORD_ROOT = "$STR"
TOML

( cd "$d" && timeout 90 env ST_AGENT="$id" ST_ROOT="$STR" COORD_ROOT="$STR" claude --print --session-id "$sid" "session init" >/dev/null 2>&1 ) \
  && echo "  bootstrapped jsonl" || echo "  (bootstrap best-effort/timed out; continuing)"

echo "configured $id  (sid=$sid, pty session=$PTY_PREFIX-claude, bypassPermissions, isolated bus=$STR, asyncRewake, pre-trusted)"
