#!/usr/bin/env bash
# Spin the two-networks-coexist INFRA run: bring BOTH networks live concurrently with real traffic + a per-net
# pty session, so the probe battery has a live two-tenant state to test. PURE INFRA — the harness plays the
# agents (no `claude`), so this runs on ANY box regardless of load. Each network:
#   - its `wk` commits a one-line change in its OWN widget (the liveness task) + reports to its OWN `sup` over its
#     OWN ST_ROOT (real concurrent bus traffic);
#   - gets a cheap `sleep` pty session in its OWN SHORT PTY_ROOT (the 104-byte unix-socket-path limit forbids a
#     deep root — a real build constraint, see the pty investigation).
# Records the two PTY_ROOTs to $SB/.pty-root-{a,b} for probe-battery.sh + teardown.
#   ./spin.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/two-networks-coexist
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/two-networks-coexist}"
[ -d "$SB/st-root-a" ] || "$HERE/setup-sandbox.sh" "$SB"
RA="$SB/st-root-a"; RB="$SB/st-root-b"

# SHORT per-network PTY_ROOTs (socket path must stay < 104 bytes — deep sandbox paths overflow it).
PR="/tmp/2net-$$"; PA="$PR/a"; PB="$PR/b"; mkdir -p "$PA" "$PB"
printf '%s\n' "$PA" > "$SB/.pty-root-a"
printf '%s\n' "$PB" > "$SB/.pty-root-b"

# liveness: each wk bumps its own widget + reports to its own sup, over its own root (real concurrent traffic).
live() {
  local r="$1" widget="$2"
  printf 'version = 1\n' > "$widget/widget.txt"
  git -C "$widget" add -A
  git -C "$widget" -c user.name=wk -c user.email=wk@eval.local commit -q -m "wk: bump widget to v1"
  ST_ROOT="$r" st message send sup --from wk --subject "widget done" \
    -m "bumped $(basename "$widget") to v1" >/dev/null
}
echo "== bring both networks live (concurrent real traffic: wk bumps widget + reports to sup) =="
live "$RA" "$SB/A-widget"
live "$RB" "$SB/B-widget"

# a cheap pty session per network, each pinned to its OWN short PTY_ROOT (short ids too).
pty --root "$PA" run -d --id 2na-wk -- sleep 600 >/dev/null 2>&1
pty --root "$PB" run -d --id 2nb-wk -- sleep 600 >/dev/null 2>&1

echo
echo "TWO NETWORKS LIVE:"
echo "  A: ST_ROOT=$RA  PTY_ROOT=$PA  (pty session 2na-wk)  widget committed + reported"
echo "  B: ST_ROOT=$RB  PTY_ROOT=$PB  (pty session 2nb-wk)  widget committed + reported"
echo "next: probe-battery.sh \"$SB\"   (or grade.sh for the full graded run + teardown)"
