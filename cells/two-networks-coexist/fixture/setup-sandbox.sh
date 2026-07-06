#!/usr/bin/env bash
# Materialize the two-networks-coexist sandbox: TWO disjoint smalltalk networks (A + B) side by side, each with
# its own ST_ROOT + agent dirs + a tiny widget repo. Deterministic + offline; no personas, no claude (the infra
# probe battery plays the agents via shell). Network B deliberately REUSES A's identities (sup, wk) — the
# same-identity COLLISION — plus a B-only `beacon-b` for the cross-address probe.
# spin-two.sh (concurrent traffic + cheap per-net pty sessions) + probe-battery.sh run after this.
#   ./setup-sandbox.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/two-networks-coexist
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/two-networks-coexist}"
RA="$SB/st-root-a"; RB="$SB/st-root-b"

echo "== clean =="
rm -rf "$SB"; mkdir -p "$SB"

# agent <root> <id> [status] -> dir + inbox/archive + status file
agent() { local r="$1" id="$2" st="${3:-available}"; mkdir -p "$r/$id/inbox" "$r/$id/archive"; printf '%s\n' "$st" > "$r/$id/status"; }

echo "== network A (ST_ROOT_A): sup + wk + beacon-a (A-only) =="
agent "$RA" sup
agent "$RA" wk
agent "$RA" beacon-a

echo "== network B (ST_ROOT_B): sup + wk (COLLISION with A) + beacon-b (B-only) =="
agent "$RB" sup
agent "$RB" wk
agent "$RB" beacon-b

# tiny widget repo per network — the liveness task target (its wk changes one line + commits concurrently).
widget() { local dir="$1"; mkdir -p "$dir"; printf 'version = 0\n' > "$dir/widget.txt"
  git -C "$dir" init -q -b main; git -C "$dir" add -A
  git -C "$dir" -c user.name="wk" -c user.email="wk@eval.local" commit -q -m "seed widget"; }
echo "== widget repos (A-widget for A/wk, B-widget for B/wk) =="
widget "$SB/A-widget"
widget "$SB/B-widget"

echo
echo "SANDBOX READY: $SB"
echo "  network A: $RA   agents: sup, wk, beacon-a   repo: A-widget"
echo "  network B: $RB   agents: sup, wk [collision], beacon-b   repo: B-widget"
echo "next: spin-two.sh — drive concurrent traffic in both roots + a cheap pty session per net, then probe-battery.sh."
