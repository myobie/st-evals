#!/usr/bin/env bash
# Materialize the weird-git-setup sandbox: a synthetic MEGAREPO — a BARE canonical repo + two LINKED WORKTREES
# (not a plain clone) — with a small Node project + a planted bug. Deterministic, offline, public-safe (no real
# repo/operator tokens). The agent is stood up (convoy add) INSIDE `wt/feature` and must get working despite the
# worktree layout: `.git` is a FILE (a `gitdir:` pointer), the object store lives in the bare repo, and a commit
# must land on THIS worktree's branch — not the bare repo, not the sibling `wt/main`.
#   ./setup-sandbox.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/weird-git-setup
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/weird-git-setup}"

echo "== clean =="
rm -rf "$SB"; mkdir -p "$SB"
SEED="$SB/.seed"

echo "== seed the project (clampkit: a tiny Node lib with a PLANTED bug + a failing test) =="
mkdir -p "$SEED/src" "$SEED/test"
cat > "$SEED/package.json" <<'JSON'
{
  "name": "clampkit",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "description": "Clamp numbers into an inclusive range.",
  "scripts": { "test": "node --test" }
}
JSON
# BUG: the above-range branch returns `lo` instead of `hi` (a real off-by-meaning bug).
cat > "$SEED/src/clamp.js" <<'JS'
// Clamp `n` into the inclusive range [lo, hi].
export function clamp(n, lo, hi) {
  if (n < lo) return lo;
  if (n > hi) return lo; // BUG: an above-range value should clamp to `hi`, not `lo`.
  return n;
}
JS
cat > "$SEED/test/clamp.test.js" <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { clamp } from "../src/clamp.js";

test("in-range values pass through", () => { assert.equal(clamp(5, 0, 10), 5); });
test("below-range values clamp to lo", () => { assert.equal(clamp(-3, 0, 10), 0); });
test("above-range values clamp to hi", () => { assert.equal(clamp(15, 0, 10), 10); }); // RED on the planted bug
JS
cat > "$SEED/README.md" <<'MD'
# clampkit
`clamp(n, lo, hi)` clamps a number into the inclusive range `[lo, hi]`. Run `npm test` (`node --test`).
MD

echo "== git init seed -> bare canonical.git =="
git -C "$SEED" init -q -b main
git -C "$SEED" add -A
git -C "$SEED" -c user.name="eval-seed" -c user.email="seed@eval.local" commit -q -m "clampkit: initial (has a planted above-range bug)"
git clone -q --bare "$SEED" "$SB/canonical.git"

echo "== add TWO linked worktrees off the bare canonical (the megarepo shape) =="
# wt/main tracks main; wt/feature is a new branch off main — the agent works here.
git -C "$SB/canonical.git" worktree add -q "$SB/wt/main" main
git -C "$SB/canonical.git" worktree add -q -b feature "$SB/wt/feature" main

echo "== pin PER-WORKTREE git authors (linked worktrees SHARE the repo config; enable worktreeConfig so each" \
     "worktree's author is distinct -> isolation is attributable) =="
git -C "$SB/canonical.git" config extensions.worktreeConfig true
# Worktrees of a bare repo inherit core.bare=true from the SHARED config; with worktreeConfig on that makes git
# treat the worktree as bare and refuse add/commit ("must be run in a work tree"). Override core.bare=false
# per-worktree so the checkouts are functional. (A real weird-git gotcha — the fixture handles it so the AGENT
# gets a working worktree; the agent's job is resolving/committing, not repairing core.bare.)
git -C "$SB/wt/feature" config --worktree core.bare false
git -C "$SB/wt/main"    config --worktree core.bare false
git -C "$SB/wt/feature" config --worktree user.name  "wt-feature"
git -C "$SB/wt/feature" config --worktree user.email "wt-feature@eval.local"
git -C "$SB/wt/main"    config --worktree user.name  "wt-main"
git -C "$SB/wt/main"    config --worktree user.email "wt-main@eval.local"

echo
echo "SANDBOX READY: $SB"
echo "  canonical.git (BARE object store + refs)"
echo "  wt/main    (branch main)      — sibling worktree, must stay untouched"
echo "  wt/feature (branch feature)   — the agent's worktree (.git is a FILE -> $(cat "$SB/wt/feature/.git" 2>/dev/null))"
echo "  planted bug: src/clamp.js above-range branch returns lo (should be hi); test/clamp.test.js line 3 is RED."
echo "next: spin.sh — convoy init the bus, seed the kick, convoy add the worker INTO wt/feature."
