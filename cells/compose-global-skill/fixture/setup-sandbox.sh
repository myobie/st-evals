#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Materialize the compose-global-skill sandbox. Proves a GLOBAL (user-level) skill still fires through a convoy
# compose — the distinct case from compose-config-load (which proves a REPO-LOCAL skill). Produces:
#   $SB/repo        a repo that does NOT contain the test skill (committed clean) — the agent is composed here.
#   $SB/cfg         an ISOLATED claude config dir whose skills/ holds the test GLOBAL skill (nonce token). This is
#                   the "global/personal ~/.claude/skills scope", relocated to a sandbox via convoy add --config-dir
#                   so the eval NEVER touches Nathan's real ~/.claude/skills.
#   $SB/cfg-empty   a control config dir with the SAME shape but NO test skill (negative control).
#   $SB/.stev/token-global   the per-run nonce (GLOBAL-SKILL-<nonce>) — lives ONLY in the global skill body.
#
# CRITICAL ISOLATION: the test global skill is installed under $SB/cfg/skills, NEVER under ~/.claude/skills. The
# grader verifies the real ~/.claude/skills is unchanged after teardown. Short path (pty socket ~90-byte limit).
#   ./setup-sandbox.sh [SANDBOX_BASE]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"
rm -rf "$SB"; mkdir -p "$SB/.stev"

nonce() { head -c 5 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
GLOBAL="GLOBAL-SKILL-$(nonce)"
printf '%s\n' "$GLOBAL" > "$SB/.stev/token-global"

# The repo the agent is composed into — deliberately has NO skill of its own (so a fired skill can ONLY be the
# global one, never repo-local).
repo="$SB/repo"; mkdir -p "$repo"
printf '# compose-global-skill test repo\n\nThis repo has NO skills of its own. Any skill the agent fires must come\nfrom the GLOBAL (user-level, --config-dir) skills scope.\n' > "$repo/CLAUDE.md"
git -C "$repo" init -q
git -C "$repo" config user.name  "gs-agent"
git -C "$repo" config user.email "gs-agent@eval.local"
git -C "$repo" add -A && git -C "$repo" commit -q -m "compose-global-skill: seed repo (no repo-local skill)"

# The ISOLATED global skill (the token lives ONLY here). $SB/cfg is a self-contained config dir the live layer
# points convoy at via --config-dir — so this "global" skill is isolated from the real ~/.claude/skills.
mkdir -p "$SB/cfg/skills/globalgreet" "$SB/cfg-empty/skills"
cat > "$SB/cfg/skills/globalgreet/SKILL.md" <<SKILL
---
name: globalgreet
description: A GLOBAL (user-level) skill. Use when asked to run the global greeting or the global-skill check.
---
# globalgreet
When you use this skill, the global token is exactly:

    $GLOBAL

If asked to WRITE it, write that exact value (and nothing else) to a file named GLOBAL_SKILL.txt in your current
working directory: \`printf '%s\\n' '$GLOBAL' > GLOBAL_SKILL.txt\`.
SKILL

echo "SANDBOX READY: $SB"
echo "  repo (no local skill): $repo"
echo "  ISOLATED global skill: $SB/cfg/skills/globalgreet/SKILL.md  token=$GLOBAL  (NOT ~/.claude/skills)"
echo "  control config dir (no skill): $SB/cfg-empty"
