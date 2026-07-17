#!/usr/bin/env bash
# Spin the compose-global-skill live layer. GATED on a test ANTHROPIC_API_KEY: isolating the GLOBAL skill requires
# a relocated config dir (--config-dir), which cannot use the keychain-locked oauth — so the live agents auth via a
# test key. WITHOUT a key this exits cleanly (the box-free NO-SHADOW deterministic core carries the proof — run
# probe.sh + grade.sh). WITH a key it composes two agents on ISOLATED config dirs:
#   • gsw   --config-dir $SB/cfg       (the GLOBAL skill 'globalgreet' present) -> must write $SB/repo/GLOBAL_SKILL.txt = token
#   • gsnc  --config-dir $SB/cfg-empty (NO global skill)                        -> must NOT emit the token (negative control)
# The token lives only in the skill body + the kick names no token, so a sentinel is ungameable proof the GLOBAL
# skill fired through the compose. CRITICAL: the test skill lives only in $SB/cfg — never real ~/.claude/skills.
#   ./spin.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"
NET="$SB/net"; export ST_ROOT="$NET"
[ -d "$SB/repo/.git" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "== compose-global-skill LIVE layer GATED: no ANTHROPIC_API_KEY =="
  echo "   Isolating a GLOBAL skill needs a relocated config dir (--config-dir), which breaks keychain oauth, so"
  echo "   the live agents need a test key. Set ANTHROPIC_API_KEY and re-run to exercise the live headline."
  echo "   The box-free NO-SHADOW deterministic core proves the compose does not shadow global-skill discovery:"
  echo "     $HERE/probe.sh \"$SB\" && $HERE/grade.sh \"$SB\""
  exit 0
fi

stev_init "compose-global-skill" "$SB"
export PTY_ROOT="$(stev_pty_root "$SB")"
STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down ==" >&2; stev_convoy_teardown "$STEV_NET"; stev_teardown "$SB"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/4  convoy init isolated net + a control repo copy =="
stev_convoy_init "$NET"
[ -d "$SB/control/.git" ] || cp -R "$SB/repo" "$SB/control"

echo "== 2/4  compose personas (positive gsw + negative-control gsnc) =="
"$HERE/compose-persona.sh" "$SB" gsw  "$SB/repo"
"$HERE/compose-persona.sh" "$SB" gsnc "$SB/control"

echo "== 3/4  convoy add both with ISOLATED config dirs (gsw: global skill present; gsnc: cfg-empty) =="
convoy pretrust "$SB/repo" "$SB/control" >/dev/null 2>&1 || true
"$HERE/configure-claude-agent.sh" "$SB" gsw  "$SB/repo"    "$SB/cfg"
"$HERE/configure-claude-agent.sh" "$SB" gsnc "$SB/control" "$SB/cfg-empty"

echo "== 4/4  seed the SAME kick into both inboxes =="
seed_kick(){ local who="$1"; mkdir -p "$NET/$who/inbox"
  local ms=$(( $(date +%s) * 1000 )); local sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
  sed -n '/^---$/,$p' "$HERE/kick.md" > "$NET/$who/inbox/${ms}-${sfx}.md"; echo "   kick -> $NET/$who/inbox/${ms}-${sfx}.md"; }
seed_kick gsw
seed_kick gsnc

echo
echo "SPUN (compose-global-skill live layer, isolated net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'gsw|gsnc' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE: gsw (global skill present) writes \$SB/repo/GLOBAL_SKILL.txt=token; gsnc (no skill) writes nothing."
echo "GRADE:    $HERE/grade.sh \"$SB\"   (run probe.sh too for the box-free NO-SHADOW core)"
echo "TEARDOWN: bin/st-evals teardown \"$SB\"   (or convoy down \"$NET\" --force; rm -rf \"$SB\"). Verify ~/.claude/skills unchanged."
