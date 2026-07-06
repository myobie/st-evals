#!/usr/bin/env bash
# Launch one signal-rename Claude eval agent via the REAL `st launch` (not a homegrown config writer).
# `st launch` writes .mcp.json (server `st`), the boot hooks (asyncRewake/PreCompact/StopFailure), the
# session-id, pty.toml, installs the composed persona (--persona), and starts the pty session. We add the two
# things st launch does NOT do for an eval:
#   1. ISOLATION: the isolated coordination bus reaches the agent by ENV INHERITANCE — spin.sh exports
#      ST_ROOT/COORD_ROOT before calling this, so st launch -> pty session -> claude -> the `st` MCP server all
#      inherit the isolated root (the agent registers on $ST_ROOT; the live bus is untouched).
#   2. ZERO-ORPHAN TEARDOWN: --session-name "$(stev_prefix ...)" makes the pty session name collision-proof
#      (`<id>-stev-<cell>-<runid>-<id>`, never a bare `<id>-claude`); stev_track_extra registers that EXACT name
#      so `st-evals teardown` removes it.
# Each agent's cwd = the repo it OWNS (sup -> signal-config; base -> signal; relay -> signal-relay; hub -> signal-hub).
# Permission POSTURE: SUPERVISOR = bypassPermissions (integration + git + runs suites across the stack); product
# workers = auto.
#   ./configure-claude-agent.sh <sup|base|relay|hub> [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/signal-rename}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # collision-proof pty prefix; idempotent (standalone-safe)

case "$role" in
  sup)   id="sig-sup";   d="$SB/sup";   mode="bypassPermissions" ;;   # integration lead; owns app.toml
  base)  id="sig-base";  d="$SB/base";  mode="auto" ;;                # owns the base package
  relay) id="sig-relay"; d="$SB/relay"; mode="auto" ;;                # owns signal-relay (the trap repo)
  hub)   id="sig-hub";   d="$SB/hub";   mode="auto" ;;                # owns signal-hub (the scheme)
  *) echo "role must be sup|base|relay|hub" >&2; exit 1 ;;
esac
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh $role first" >&2; exit 1; }
pfx="$(stev_prefix "$SB" "$id")"     # stev-<cell>-<runid>-<id>
sess="$id-$pfx"                       # st launch names the pty session <identity>-<session-name>

# Pre-create the FULL coord dir on the ISOLATED bus so the boot ritual doesn't rabbit-hole for its own folder.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the folder for Claude Code (skip the workspace-trust gate). --unattended also auto-pokes startup
# gates, but pre-trust is deterministic + cheap — keep both.
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Register the EXACT session name BEFORE launching, so a kill mid-launch (e.g. a wedged bootstrap under machine
# load) still tears the session down — the post-launch position orphaned a session when configure was killed
# mid-st-launch. The name is deterministic ($id-$pfx), known before the launch; registering an un-launched name
# is harmless (teardown's pty kill on a missing session is a no-op).
stev_track_extra "$SB" "$sess"
stev_ding_on && stev_track_extra "$SB" "$id-ding" || true

# Launch via the real st launch; it inherits ST_ROOT/COORD_ROOT from this process (exported by spin.sh) ->
# the agent binds the ISOLATED bus. --unattended bakes the startup auto-poker; --session-name is collision-proof.
( cd "$d" && st launch claude $(stev_ding_flags) \
    --identity "$id" \
    --session-name "$pfx" \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

echo "launched $id  (pty session=$sess, --permission-mode $mode, isolated bus=$ROOT, persona=$persona, asyncRewake)"
