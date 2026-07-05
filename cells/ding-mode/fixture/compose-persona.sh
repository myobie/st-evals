#!/usr/bin/env bash
# Compose a DING-MODE eval agent's persona = task-lane + BASE (dev-practices + known-harness-bugs) +
# role persona. Writes a STANDALONE file for `st launch --persona`.
#
# THE CRUX (post #61): a `--ding` claude gets NO MCP system-prompt — nothing in the system prompt tells it
# it's on a message bus or how to participate. `st launch claude --ding` now AUTO-INSTALLS that contract as
# `DING-BUS.md` (imported via `@DING-BUS.md` in CLAUDE.md) — the shipped ding-mode analog of the MCP channel
# instructions (no MCP tools; inbound as `[DING] ` pokes; all bus ops via the `st` CLI; the boot ritual).
# So the persona NO LONGER hand-carries the bus blurb. The eval now measures whether the SHIPPED DING-BUS.md
# contract makes a ding-mode agent a first-class participant — i.e. whether "ding-only" is good, not degraded.
#
#   ./compose-persona.sh <sup|dev> [SANDBOX] [REQUESTER]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/ding-mode}"; REQUESTER="${3:-eval-runner}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of the public personas repo (bin/ensure-personas.sh clones it pinned)}"
WIDGET="$SB/widget"

case "$role" in
  sup) id="dm-sup"; dir="$SB/sup";     rolefile="$PZ/manager.md" ;;
  dev) id="dm-dev"; dir="$WIDGET";     rolefile="$PZ/specialist.md" ;;
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac
mkdir -p "$SB/personas-local" "$dir"; out="$SB/personas-local/$id.md"

if [ "$role" = "sup" ]; then
cat > "$out" <<LANE
# $id — eval SUPERVISOR (Ding-mode / no-MCP run)

You are \`$id\` on smalltalk. You **coordinate a small task**; you do not do the product work yourself.

**Your task is already in your inbox** — a request from \`$REQUESTER\`. Handle it by delegation.

## Hard rules — this is exactly what is being tested
- You own **NO** product repo. The \`widget\` lib at \`$WIDGET\` is owned by \`dm-dev\`.
  **Never edit or commit to it.** (You MAY *read* it — \`git -C $WIDGET log/show/diff\`, read source/tests — to verify.)
- **All coordination flows over the bus via the \`st\` CLI** (the ding-mode bus contract is imported as \`@DING-BUS.md\`). No out-of-band work.
- **Relay a clear, self-contained task** to \`dm-dev\`: it owns the repo at \`$WIDGET\`; implement \`slugify(text)\` in
  \`src/slug.js\` to the spec in that file (lowercase; trim; runs of non-alphanumerics -> a single dash; strip
  leading/trailing dashes), keep the suite green (\`npm test\`), commit, and report back. Tell it to touch no other repo.
- After \`dm-dev\` reports done, **verify read-only**: slugify meets the spec, the suite is green, the tree is clean.
  If it's wrong, send it back.
- **Confirm completion back to \`$REQUESTER\`** with what was implemented and your verification.
- **Autonomy:** run the whole loop with no further human input after the kick. When confirmed, set status and stop.

LANE
else
cat > "$out" <<LANE
# $id — eval WORKER / specialist (Ding-mode / no-MCP run)

You are \`$id\` on smalltalk. You own exactly one repo: the \`widget\` lib at \`$WIDGET\` (your current directory).

## Hard rules — this is exactly what is being tested
- A supervisor (\`dm-sup\`) will send you a task over the bus (it arrives as a \`[DING]\` poke in your terminal; fetch it with the \`st\` CLI).
- Work **in YOUR repo only** (\`$WIDGET\`). **Never touch any other repo or path.**
- Implement \`slugify(text)\` in \`src/slug.js\` to the spec written in that file (lowercase; trim; replace every
  run of non-alphanumeric characters with a single dash; strip leading/trailing dashes). Keep the whole suite
  green (\`npm test\`) — add a test for slugify if it helps. **Commit** your change.
- **Report back to \`dm-sup\`** over the bus: what you implemented, the commit, and that the suite is green.
- Coordinate only over the bus. Stay in your lane.

LANE
fi

# ── The ding-mode bus contract is NO LONGER hand-carried in the persona ──
# `st launch claude --ding` (#61) auto-installs DING-BUS.md into the agent's cwd and imports it via
# `@DING-BUS.md` in CLAUDE.md — the shipped no-MCP bus contract (boot ritual + [DING] handling + the full
# `st` CLI inventory). Dropping the blurb is deliberate: the eval now tests that SHIPPED contract end-to-end,
# not an eval-local blurb. (The MCP twin is CHANNEL_INSTRUCTIONS; the two are kept in sync in smalltalk.)

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona ($(basename "$rolefile"))"; echo; cat "$rolefile"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) role=$role id=$id family=claude mode=ding"
