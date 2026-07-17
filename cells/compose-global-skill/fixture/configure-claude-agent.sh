#!/usr/bin/env bash
# Launch a compose-global-skill agent via REAL convoy with an ISOLATED config dir (--config-dir), so its
# GLOBAL/user-level skills come from that sandbox (never the real ~/.claude/skills). Because a relocated config
# dir cannot use the keychain-locked oauth, the session authenticates via a test ANTHROPIC_API_KEY, which we inject
# into the session env by editing the pty.toml convoy wrote (the reliable pattern — convoy passes a fixed env), then
# re-launching just the claude session. REQUIRES ANTHROPIC_API_KEY in the environment (spin.sh gates on it).
#   ./configure-claude-agent.sh [SANDBOX] <ID> <DIR> <CONFIG_DIR>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"; id="${2:?id}"; dir="${3:?dir}"; cfg="${4:?config-dir}"
NET="${ST_ROOT:?configure: export ST_ROOT (spin.sh does)}"
: "${ANTHROPIC_API_KEY:?configure: ANTHROPIC_API_KEY required for the isolated-config live layer (spin.sh gates on it)}"
PR="$NET/pty"; SESS="silber.$id-claude"

# convoy add with the isolated config dir (writes $dir/pty.toml + boots the session).
convoy add worker --identity "$id" --network "$NET" --dir "$dir" --persona "$SB/personas-local/$id.md" --harness claude --config-dir "$cfg"

# Inject ANTHROPIC_API_KEY into the [sessions.claude.env] block so the relocated-config session can authenticate,
# then re-launch the claude session from the edited toml (pty up reads it fresh; ding sidecar left running).
python3 - "$dir/pty.toml" <<'PY'
import sys, os
toml = sys.argv[1]
lines = open(toml).read().splitlines(keepends=True)
out, in_env, added = [], False, False
for ln in lines:
    out.append(ln)
    if ln.strip() == "[sessions.claude.env]" and not added:
        out.append('ANTHROPIC_API_KEY = "%s"\n' % os.environ["ANTHROPIC_API_KEY"]); in_env = True; added = True
open(toml, "w").write("".join(out))
print("injected ANTHROPIC_API_KEY into pty.toml [sessions.claude.env]" if added else "no env block found")
PY

pty --root "$PR" down "$dir" claude >/dev/null 2>&1 || true
pty --root "$PR" kill "$SESS" >/dev/null 2>&1 || true
sleep 1
rm -f "$PR/silber.$id.json" "$PR/silber.$id.pid" "$PR/silber.$id.events.jsonl" "$PR/silber.$id.sock"
pty --root "$PR" up "$dir" claude 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -1
echo "launched $id (isolated config dir $cfg, key-injected)"
