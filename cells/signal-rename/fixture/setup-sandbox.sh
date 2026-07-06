#!/usr/bin/env bash
# Materialize the signal-rename sandbox: a single WORKSPACE repo built from the bundled synthetic graph
# (fixture/seed-graph/), a bare origin, and one full clone per agent. The packages (signal = base, signal-relay,
# signal-hub, config = app.toml) are siblings in the workspace, so the consumers' relative `_signal.js` shims +
# the integration test resolve with ZERO node_modules (hermetic, offline, deterministic).
# The cross-repo acceptance test (signal-hub/test/integration.test.js) is HELD OUT to $SB/.held-out/ — no agent
# sees it; grade.sh runs it against the integrated, renamed workspace.
# Personas + `st launch` + the hermetic kick happen AFTER this (spin.sh). See ../task.toml.
#
#   ./setup-sandbox.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/signal-rename
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/signal-rename}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAPH="$HERE/seed-graph"          # bundled with the cell — no external repo needed

echo "== clean =="
rm -rf "$SB"; mkdir -p "$SB"
SEED="$SB/.seed"; mkdir -p "$SEED"

echo "== seed: assemble the workspace (signal + signal-relay + signal-hub + config) =="
cp -R "$GRAPH/signal" "$GRAPH/signal-relay" "$GRAPH/signal-hub" "$SEED/"
mkdir -p "$SEED/config"
cp "$GRAPH/app.toml" "$SEED/config/app.toml"

echo "== HOLD OUT the cross-repo acceptance test (no agent may see it) =="
mkdir -p "$SB/.held-out"
mv "$SEED/signal-hub/test/integration.test.js" "$SB/.held-out/integration.test.js"

echo "== seed: workspace root (documents the packages; sig-sup's lane) =="
cat > "$SEED/package.json" <<'JSON'
{
  "name": "signal-workspace",
  "private": true,
  "version": "0.0.0",
  "description": "A workspace of interdependent packages: @acme/signal (base) + signal-relay + signal-hub.",
  "workspaces": ["signal", "signal-relay", "signal-hub"]
}
JSON

cat > "$SEED/README.md" <<'MD'
# signal-workspace

A workspace of interdependent packages:

- **signal/** — `@acme/signal`, the base product (an in-process named signal bus) + the `signal` CLI.
- **signal-relay/** — relays product signals between hubs (peerDep `@acme/signal`).
- **signal-hub/** — hosts product signals at `signal://` addresses (peerDep `@acme/signal`).
- **config/app.toml** — the product config.

Each package runs its own tests with `node --test`. The consumers resolve the base by a relative shim
(`src/_signal.js`), so no install is required.
MD

cat > "$SEED/.gitignore" <<'GI'
node_modules/
.DS_Store
# eval agent infra — never commit into the workspace
CLAUDE.md
PERSONA.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
.seed/
GI

echo "== git init seed + bare origin =="
git -C "$SEED" init -q -b main
git -C "$SEED" add -A
git -C "$SEED" -c user.name="eval-seed" -c user.email="seed@local" commit -q -m "seed: synthetic signal workspace (base + relay + hub + config)"
SEED_COMMIT="$(git -C "$SEED" rev-parse --short HEAD)"
git clone -q --bare "$SEED" "$SB/origin.git"

echo "== clone one full workspace copy per agent (distinct authors -> isolation is attributable) =="
# Each agent gets the FULL workspace (so the relative shims resolve) but only commits within its lane:
#   sig-base -> signal/ · sig-relay -> signal-relay/ · sig-hub -> signal-hub/ · sig-sup -> config/ + root + integration.
for a in sup base relay hub; do
  git clone -q "$SB/origin.git" "$SB/$a"
  git -C "$SB/$a" remote set-url origin "$SB/origin.git"
  git -C "$SB/$a" config user.name  "sig-$a"
  git -C "$SB/$a" config user.email "sig-$a@eval.local"
done

echo
echo "SANDBOX READY: $SB   (seed $SEED_COMMIT)"
echo "  origin.git  sup/ base/ relay/ hub/   held-out: .held-out/integration.test.js"
echo "  packages: signal/ (base) signal-relay/ signal-hub/ config/app.toml"
echo "next: spin.sh — compose per-agent personas, launch each (st launch), seed the kick into sig-sup's inbox."
