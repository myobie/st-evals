#!/usr/bin/env bash
# Archive a tui-build run's PRODUCT (the integration lead's built agent-viz) + the seed prototypes (demo
# candidates) to a stable, grabbable path. The built viz is folder-generic + st-only (reads whatever ST_ROOT
# points at via `st agents`). grade.sh calls this after a run; can also run standalone to grab the seed candidates.
#   ./copy-artifact.sh [SANDBOX] [DEST]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/tui-build}"
runid="$(cat "$SB/.stev/runid" 2>/dev/null || echo run)"
DEST="${2:-$SB/tui-build-artifacts/$runid}"
mkdir -p "$DEST"

# 1. the run's PRODUCT — the integration lead's integrated agent-viz (main = the built TUI), if a run happened.
if [ -d "$SB/sup/src" ]; then
  ( cd "$SB/sup" && tar --exclude=node_modules --exclude=.git -cf - . ) \
    | ( mkdir -p "$DEST/agent-viz-built" && cd "$DEST/agent-viz-built" && tar -xf - )
  echo "  archived BUILT product -> $DEST/agent-viz-built/  (folder-generic: ST_ROOT=<net> npm start)"
else
  echo "  (no built product at $SB/sup — no run yet; archiving the seed candidates only)"
fi

# 2. the seed prototypes as demo candidates (always available products).
mkdir -p "$DEST/seed-protos"; cp "$HERE/seed-protos/"*.ts "$DEST/seed-protos/" 2>/dev/null || true
echo "  archived seed-proto candidates -> $DEST/seed-protos/"

echo "ARTIFACTS at: $DEST"
echo "  (you grab the best; every view reads any network via 'st agents' — folder-generic, st-only, no app.)"
