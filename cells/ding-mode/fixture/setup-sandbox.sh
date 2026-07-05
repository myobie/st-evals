#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Materialize the DING-MODE (no-MCP participation) eval sandbox. A tiny `widget` lib with one
# function to implement (`slugify`). The point of this cell is NOT the task difficulty — it is
# whether a FULLY NO-MCP Claude team (both agents launched `st launch claude --ding`) is a
# FIRST-CLASS participant: boot ritual over the `st` CLI, inbound messages delivered as `[DING]`
# pokes and handled cleanly (read/reply/archive via CLI), and a natural delegate->execute->report
# ->verify loop — 0 rescues. This is the no-MCP shape (some hosts can't run MCP servers).
#
# The task is small + deterministic so the FOCUS is the ding-mode coordination experience:
#   implement slugify(text) to an EXACT spec (the kick lists the cases), keep the suite green, commit.
#
#   ./setup-sandbox.sh [SANDBOX]      # builds ${EVAL_SANDBOX:-./.sandbox}/ding-mode
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-mode}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"        # sup/ = coordinate-only, owns NO repo
W="$SB/widget"; mkdir -p "$W/src" "$W/test"

echo "== widget repo: slugify stub (to be implemented by dm-dev over ding) =="
cat > "$W/src/slug.js" <<'JS'
// slugify(text): turn a title into a URL slug.
//
// SPEC (implement to exactly this — the held-out grade checks these cases):
//   - lowercase the text
//   - trim leading/trailing whitespace
//   - replace every run of non-alphanumeric characters with a single dash
//   - strip any leading/trailing dashes
// Examples: "Hello World" -> "hello-world"; "Foo_Bar Baz" -> "foo-bar-baz";
//           "  Trim Me  " -> "trim-me"; "A.B.C" -> "a-b-c"; "Rock & Roll!" -> "rock-roll".
export function slugify(text) {
  throw new Error("slugify not implemented");
}
JS

cat > "$W/src/index.js" <<'JS'
export { slugify } from "./slug.js";
JS

# Seed suite: GREEN (asserts the module shape only — behavior is implemented by the worker).
cat > "$W/test/slug.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { slugify } from "../src/slug.js";

test("slugify is exported as a function", () => {
  assert.equal(typeof slugify, "function");
});
JS

cat > "$W/package.json" <<'JSON'
{
  "name": "widget",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "A tiny string-utility lib.",
  "main": "src/index.js",
  "scripts": { "test": "node --test" }
}
JSON

cat > "$W/README.md" <<'MD'
# widget

A tiny string-utility lib.

```js
import { slugify } from "./src/index.js";
slugify("Hello World");   // "hello-world"
```

`slugify` lives in `src/slug.js` (see the spec in that file). Run the tests with `npm test`.
MD

cat > "$W/.gitignore" <<'GI'
node_modules/
.DS_Store
CLAUDE.md
AGENTS.md
PERSONA.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI

echo "== git init widget repo (frozen base) + distinct author (dm-dev) =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "widget: slugify stub + green suite"
git -C "$W" config user.name  "dm-dev"
git -C "$W" config user.email "dm-dev@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo "== sanity: suite is GREEN at seed (stub not yet implemented) =="
( cd "$W" && node --test >/dev/null 2>&1 && echo "  suite: GREEN (module-shape test passes; behavior TODO)" || echo "  !! suite unexpectedly RED at seed" )
echo "== sanity: slugify throws until implemented =="
THROWS=$(cd "$W" && node --input-type=module -e '
import { slugify } from "./src/slug.js";
try { slugify("x"); console.log("DID-NOT-THROW"); } catch { console.log("throws-as-expected"); }
' 2>&1)
echo "  slugify('x') => $THROWS"

echo
echo "SANDBOX READY: $SB   (widget base $BASE; author dm-dev)"
echo "  widget/  the string-util lib (owned by dm-dev; GREEN suite; slugify stub to implement)"
echo "  sup/     coordinate-only (dm-sup cwd; owns no repo)"
echo "next: compose ding-mode personas + launch BOTH agents via 'st launch claude --ding' (no MCP), seed the"
echo "      kick into dm-sup inbox, spin. Grade with grade.sh (task-correct + isolation + the ding-experience asserts)."
