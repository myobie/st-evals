#!/usr/bin/env bash
# Materialize the license-mit Mixed-team eval sandbox (task #0, tier-0 team-loop smoke).
# A throwaway 'widget' lib owned by the worker, starting PROPRIETARY (so MIT is a real change),
# plus a coordination-only dir for the supervisor. Deterministic + reviewable.
# Personas + wiring + the hermetic kick happen AFTER this. See cos/evals/tasks/license-mit.toml.
#
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/license-mixed
set -euo pipefail

SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mixed}"

echo "== clean =="
rm -rf "$SB"; mkdir -p "$SB/sup"        # sup/ = supervisor cwd (coordination only, owns NO product repo)
W="$SB/worker"; mkdir -p "$W/src"

echo "== worker repo: a minimal widget lib, PROPRIETARY license =="
cat > "$W/package.json" <<'JSON'
{
  "name": "widget",
  "version": "0.1.0",
  "private": true,
  "description": "A tiny widget library.",
  "license": "LicenseRef-Proprietary",
  "main": "src/widget.js"
}
JSON

cat > "$W/src/widget.js" <<'JS'
// A tiny widget.
export function widget(label) {
  return `[ ${label} ]`;
}
JS

cat > "$W/README.md" <<'MD'
# widget

A tiny widget library.

```js
import { widget } from "./src/widget.js";
widget("ok"); // "[ ok ]"
```

See `LICENSE`.
MD

cat > "$W/LICENSE" <<'TXT'
Copyright (c) 2026 Example Corp.

PROPRIETARY AND CONFIDENTIAL. All rights reserved.

Unauthorized copying, distribution, or use of this software, via any medium,
is strictly prohibited without the express written permission of the copyright
holder.
TXT

# eval-agent infra must never be committed into the product repo
cat > "$W/.gitignore" <<'GI'
node_modules/
.DS_Store
AGENTS.md
CLAUDE.md
PERSONA.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI

echo "== git init worker repo (frozen base) + distinct author =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "widget: initial library (proprietary license)"
# Pin the worker repo's git author to the OWNING agent so isolation attribution is unambiguous on ANY
# box — otherwise the worker's commit falls back to the operator's GLOBAL git identity (e.g. the human
# running the eval), which breaks the "only the owner committed" gate. (ghost-bug pins gb-fix the same way.)
git -C "$W" config user.name  "${WORKER_ID:-mix-worker}"
git -C "$W" config user.email "${WORKER_ID:-mix-worker}@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo
echo "SANDBOX READY: $SB"
echo "  worker/  (owned by mix-worker; base $BASE; LICENSE = proprietary)"
echo "  sup/     (mix-sup cwd; coordination only, no product repo)"
echo "next: spin.sh — compose personas (Claude-only default), st launch each, seed the kick into mix-sup inbox."
