#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Launch one DING-MODE Claude eval agent via the REAL `st launch claude --ding` (#58): NO MCP wiring
# (.mcp.json skipped), channel OFF, an `st ding` sidecar for inbox delivery, Claude hooks still generated.
# The agent joins the network via the `st` CLI + ding pokes — the no-MCP shape (some hosts can't run MCP servers).
#
# Same isolation + zero-orphan discipline as the other cells, with ONE extra teardown target:
#   - RISK 2 (isolation): spin.sh exports ST_ROOT/COORD_ROOT; st launch bakes ST_ROOT into BOTH the agent
#     session AND the ding sidecar env -> both bind the ISOLATED bus, live network untouched.
#   - RISK 1 + ding (zero-orphan): --session-name "$(stev_prefix ...)" makes the agent session collision-proof;
#     the ding sidecar is named literally `ding` -> pty key `<id>-ding` (prefix=<id>). We stev_track_extra
#     BOTH the agent session (`<id>-<pfx>`) AND the ding session (`<id>-ding`) so teardown removes the pair.
#
#   ./configure-claude-agent.sh <sup|dev> [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/ding-mode}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # collision-proof pty prefix; idempotent

case "$role" in
  sup) id="dm-sup"; d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  dev) id="dm-dev"; d="$SB/widget"; mode="auto" ;;                # owns the repo; no child agents
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh $role first" >&2; exit 1; }
pfx="$(stev_prefix "$SB" "$id")"     # stev-<cell>-<runid>-<id>
sess="$id-$pfx"                       # agent pty session <identity>-<session-name>
dingsess="$id-ding"                   # ding sidecar pty session (prefix=<id>, session-name=`ding`)

# Pre-create the FULL coord dir on the ISOLATED bus (inbox+archive+status) — the ding sidecar watches
# inbox/, and the agent's `st` CLI ops resolve against it. So the boot ritual + delivery both work.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the folder for Claude Code (skip the workspace-trust gate). Belt-and-suspenders with --unattended.
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Launch via the real `st launch claude --ding`: no MCP, ding sidecar, hooks still generated. It inherits
# ST_ROOT/COORD_ROOT from this process's env (exported by spin.sh) -> agent + ding bind the ISOLATED bus.
( cd "$d" && st launch claude --ding \
    --identity "$id" \
    --session-name "$pfx" \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

# Register BOTH resulting session names so teardown is zero-orphan (both outside our prefix stem).
stev_track_extra "$SB" "$sess"
stev_track_extra "$SB" "$dingsess"

echo "launched $id  (DING MODE: no MCP; agent session=$sess + ding sidecar=$dingsess; --permission-mode $mode, isolated bus=$ROOT, persona=$persona)"
