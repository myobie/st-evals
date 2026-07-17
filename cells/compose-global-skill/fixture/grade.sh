#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for COMPOSE-GLOBAL-SKILL. Proves a GLOBAL (user-level) skill still fires through a convoy
# compose — i.e. the compose does not SHADOW/BREAK global-skill discovery. Deterministic core (box-free) + a live
# headline (gated on auth: an isolated config dir cannot use the keychain-locked oauth, so the live layer runs only
# with a test ANTHROPIC_API_KEY; else it SKIPS-WITH-REASON and the deterministic core carries the proof).
#
# CRITICAL ISOLATION: the test global skill lives ONLY in the run's isolated config dir ($SB/cfg via --config-dir),
# never in the real ~/.claude/skills. This grader HARD-GATES that the real ~/.claude/skills is unchanged.
#   ./grade.sh [SANDBOX]
# Exit 0 = no hard failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"
P="$SB/.probe"
GLOBAL="$(tr -d '\r\n' < "$SB/.stev/token-global" 2>/dev/null)"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
[ -n "$GLOBAL" ] && echo "global-skill token this run: $GLOBAL"
if grep -q 'CONVOY-MISSING' "$P/pty-env.txt" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi

echo
echo "== NO-SHADOW (hard, deterministic) — the compose does not relocate/disable/scope-away global-skill discovery =="
if [ -f "$P/no-shadow.txt" ]; then
  grep -q '^env_sets_config_dir=no' "$P/no-shadow.txt" && ok "convoy pty.toml sets NO CLAUDE_CONFIG_DIR — the agent uses the DEFAULT config dir, where global (~/.claude/skills) skills live => discoverable" \
                                                        || no "convoy pty.toml SETS CLAUDE_CONFIG_DIR — it relocates the config dir, which would shadow the user's global skills"
  grep -q '^cmd_relocates_or_disables=no' "$P/no-shadow.txt" && ok "the launch command carries no --config-dir and no --disable-slash-commands (skills not relocated or disabled)" \
                                                             || no "the launch command relocates the config dir or disables skills"
  grep -q '^settings_touches_skills=no' "$P/no-shadow.txt" && ok "convoy settings.local.json is additive (hooks only) — it touches NO skill key, so it cannot suppress global-skill discovery" \
                                                           || no "convoy settings.local.json touches a skill key (disableAllSkills / skill scoping) — could suppress global skills"
else
  sk "no no-shadow.txt — run probe.sh"
fi

# --- live headline (gated on auth) ------------------------------------------------------------------------------
senteq(){ local f="$1" want="$2"; [ -f "$f" ] || return 2; [ "$(tr -d '[:space:]' < "$f")" = "$want" ] && return 0 || return 1; }

echo
echo "== GLOBAL SKILL FIRES (headline, rides the box; gated on auth) — the composed agent used the GLOBAL skill =="
POS="$SB/repo/GLOBAL_SKILL.txt"
senteq "$POS" "$GLOBAL"; r=$?
if   [ $r = 0 ]; then ok "GLOBAL_SKILL.txt carries the exact per-run token — the GLOBAL skill LOADED + fired through the compose"
elif [ $r = 2 ]; then sk "no GLOBAL_SKILL.txt — live layer not exercised (isolating global skills relocates the config dir, which breaks keychain auth; needs a test ANTHROPIC_API_KEY). The NO-SHADOW deterministic core carries the proof."
else                  no "GLOBAL_SKILL.txt present but token mismatch — the agent did not get it from the global skill"; fi

echo
echo "== NEGATIVE CONTROL (headline, gated) — same kick, config dir WITHOUT the global skill => must NOT emit the token =="
CTL="$SB/control/GLOBAL_SKILL.txt"
if [ ! -f "$POS" ]; then
  sk "negative control not exercised (no live run) — NO-SHADOW carries the box-free proof"
else
  senteq "$CTL" "$GLOBAL"; r=$?
  if [ $r = 0 ]; then no "CONTROL emitted the global token with NO global skill installed — echo/leak, not skill-firing!"
  else               ok "control did not emit the global token (its config dir had no such skill) — the positive came from the loaded global skill"; fi
fi

echo
echo "== ISOLATION (hard gate — the eval touched NO real global skill; no session leak) =="
ls -1 "${HOME:-/nonexistent}/.claude/skills" 2>/dev/null | sort > "$P/real-skills-after.txt" || true
if diff -q "$P/real-skills-before.txt" "$P/real-skills-after.txt" >/dev/null 2>&1; then
  ok "real ~/.claude/skills is UNCHANGED (before == after) — the test global skill stayed isolated in \$SB/cfg"
else
  no "real ~/.claude/skills CHANGED — the eval polluted the user's global skills:"; diff "$P/real-skills-before.txt" "$P/real-skills-after.txt" | sed 's/^/        /'
fi
grep -q 'globalgreet' "$P/real-skills-after.txt" 2>/dev/null && no "the test skill 'globalgreet' LEAKED into real ~/.claude/skills" \
                                                             || ok "no test skill 'globalgreet' in real ~/.claude/skills (install stayed in the isolated config dir)"
leak_pty="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -c 'gsw' || true)"
[ "${leak_pty:-0}" = 0 ] && ok "no gsw session in the operator's global pty root (isolated net only)" \
                         || no "LEAK: gsw session in the global pty root (pty=$leak_pty)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> compose-global-skill: NO hard failures. The convoy compose does NOT shadow global-skill discovery"
  echo "    (no config-dir relocation, no skill-disable, additive settings), so a user's ~/.claude/skills stay"
  echo "    callable through the compose — and the eval touched no real global skill. Live firing rides the box"
  echo "    (gated on a test API key, since isolating global skills breaks keychain auth)."
else
  echo "==> compose-global-skill: $fail HARD FAILURE(S) — see [FAIL] rows."
fi
[ "$fail" -eq 0 ]
