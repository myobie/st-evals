#!/usr/bin/env bash
# Compose the weird-git-setup worker persona = task-lane + smalltalk boot ritual + BASE (dev-practices +
# known-harness-bugs) + specialist role. DELIBERATELY says NOTHING about worktrees / megarepos / where the repo
# "really" lives — the whole point of this cell is whether the agent figures out its own git context. Fed to
# `convoy add worker --persona`.
#   ./compose-persona.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/weird-git-setup}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of github.com/compoundingtech/personas (bin/ensure-personas.sh)}"
id="wg-dev"
mkdir -p "$SB/personas-local"; out="$SB/personas-local/$id.md"

cat > "$out" <<LANE
# $id — eval WORKER (weird-git-setup run)

You are \`$id\` on smalltalk. **Your task is in your inbox.** Do it in the repo checkout you are running in.

## Hard rules — this is exactly what is being tested
- **Work in the checkout you were launched in**, and **commit your change on this checkout's branch.** Figure out
  the repo's git setup yourself — where you are, what branch you're on, and how to commit *here* — and get it right.
  Don't assume anything about the layout.
- **Root-cause** the failing test (don't delete or skip it); keep the suite green (\`node --test\`).
- **Add a regression test** that would catch the exact bug.
- Report to the requester over smalltalk when the suite is green and your fix is committed.

LANE
cat >> "$out" <<'BOOT'
---
## Smalltalk boot ritual (do this first, every fresh start)
1. Set your status available: `st status "$ST_AGENT" --set available` (use `$ST_AGENT`, the authoritative identity).
2. Drain your inbox: list, read, act, archive. Your task is there.
3. Then do the task. Questions/blockers/"done" go over smalltalk to your correspondent — nobody reads your REPL.

BOOT
{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE (specialist)"; echo; cat "$PZ/specialist.md"; echo; } >> "$out"
echo "composed $out ($(wc -l < "$out") lines) id=$id"
