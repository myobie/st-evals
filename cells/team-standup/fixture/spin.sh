#!/usr/bin/env bash
# Spin TEAM-STANDUP P5 — the LIVE proof (CoS delegates -> specialist executes -> CoS walks).
# Only the CoS is launched by us; the CoS stands up taskflow-dev ITSELF via `st launch` (that's the test).
# Runs setup-sandbox.sh if the sandbox is absent, composes personas, wires the CoS on an ISOLATED bus root,
# pre-stages the worker's Claude harness gates, seeds the hermetic kick, and launches the CoS.
#
#   ./spin.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
STR="$SB/st-root"
W="$SB/taskflow"
HOOKS="${ST_HOOKS_DIR:?set ST_HOOKS_DIR to <smalltalk>/examples/claude-code/hooks}"
# Collision-proof per-run pty prefix (shared harness). The CoS is ours (stev-prefixed); the worker is
# st-launched by the CoS (named by its identity, outside our prefix), so we register it for teardown.
stev_init "$(basename "$(dirname "$HERE")")" "$SB"; stev_arm_teardown "$SB"
COS_PREFIX="$(stev_prefix "$SB" cos)"; WORKER_PREFIX="taskflow"
COS_SESSION="${COS_PREFIX}-claude"; WORKER_SESSION="${WORKER_PREFIX}-claude"
stev_track_extra "$SB" "$WORKER_SESSION"

[ -d "$W" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

echo "== 1/6  compose CoS + specialist personas (pinned public personas) =="
"$HERE/compose-persona.sh" cos "$SB"
"$HERE/compose-persona.sh" taskflow-dev "$SB"

echo "== 2/6  wire the CoS (spawn-capable, bypass, isolated bus root) =="
"$HERE/configure-claude-agent.sh" "$SB"

echo "== 3/6  pre-stage the worker's Claude harness startup-gates =="
# FRICTION (recorded): `st launch` writes the child's pty.toml + .mcp.json + persona + boot hooks, but it
# does NOT pre-trust the child's folder or set enableAllProjectMcpServers — so a freshly stood-up
# specialist would hit the folder-trust + MCP-enable startup gates and stall until a pty poke. We pre-stage
# exactly those gates here (the same harness infra every cell stages); the CoS's live `st launch` still
# installs the persona, generates pty.toml (ST_AGENT=taskflow-dev), and boots the worker — the graded acts
# (spawn, brief, walk) are untouched.
python3 - "$W" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json"); d=json.load(open(p))
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY
mkdir -p "$W/.claude"
cat > "$W/.claude/settings.local.json" <<JSON
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
echo "   pre-trusted $W + staged .claude/settings.local.json (asyncRewake + MCP-enable)"

echo "== 4/6  pre-create jordan on the sandbox bus (the CoS confirms back to them) =="
mkdir -p "$STR/jordan/inbox" "$STR/jordan/archive"; printf 'available\n' > "$STR/jordan/status"

echo "== 5/6  seed the delegated task into the CoS inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/cos/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/cos/inbox/${ms}-${sfx}.md"

echo "== 6/6  launch the CoS (pty up) =="
( cd "$SB/cos" && pty up )

echo
echo "SPUN (TEAM-STANDUP P5). sessions:"; pty ls 2>/dev/null | grep -E "ts-cos-|taskflow-" || pty ls 2>/dev/null || true
echo
echo "OBSERVE the loop (isolated bus at $STR; CoS pty session = $COS_SESSION):"
echo "  cos boots -> reads Jordan's task -> \`st launch\` taskflow-dev -> records it in team.md"
echo "   -> briefs taskflow-dev over the bus -> taskflow-dev adds completeTask + test, commits, reports"
echo "   -> cos WALKS read-only (behaves? test real? green? lane held?) -> records done -> confirms to jordan"
echo
echo "WAKE: asyncRewake is primary (wired for both). The generic shepherd-poke.sh can't back these up —"
echo "  it keys pty session == coord identity, but BOTH agents here have pty-prefix != identity"
echo "  (CoS: $COS_SESSION vs identity cos; specialist: $WORKER_SESSION vs identity taskflow-dev)."
echo "  If either idles on a delivered message, poke by hand (a tracked HB-4 poke):"
echo "    pty send $COS_SESSION    --with-delay 0.4 --seq key:ctrl+u --seq 'read your inbox and proceed' --seq key:return"
echo "    pty send $WORKER_SESSION --with-delay 0.4 --seq key:ctrl+u --seq 'read your inbox and proceed' --seq key:return"
echo
echo "GRADE when the loop closes:  fixtures/team-standup/grade.sh \"$SB\""
echo "TEARDOWN after grading: neuter each pty.toml -> .done, \`pty kill\`/\`pty rm\` the sessions, remove \$SB."
