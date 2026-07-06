#!/usr/bin/env bash
# One-command graded run of two-networks-coexist (INFRA battery — deterministic, no `claude`, runs on any box).
# Materializes two networks, brings both live (real concurrent traffic + a per-net pty session), runs the held-out
# cross-talk probe battery BOTH directions, asserts liveness (positive control), and tears down to ZERO orphans
# across BOTH pty roots. ISOLATION is the whole grade; liveness proves the nets were live during probing.
#   ./grade.sh [SANDBOX]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/two-networks-coexist}"
RA="$SB/st-root-a"; RB="$SB/st-root-b"

echo "== materialize + spin both networks (concurrent) =="
"$HERE/setup-sandbox.sh" "$SB" >/dev/null
"$HERE/spin.sh" "$SB" >/dev/null
PA="$(cat "$SB/.pty-root-a" 2>/dev/null)"; PB="$(cat "$SB/.pty-root-b" 2>/dev/null)"

echo "== ISOLATION (hard gate — the held-out probe battery, both directions) =="
"$HERE/probe-battery.sh" "$SB"; probe_rc=$?

echo "== LIVENESS (positive control — both nets did real work concurrently) =="
lf=0
if grep -q 'version = 1' "$SB/A-widget/widget.txt" 2>/dev/null && grep -q 'version = 1' "$SB/B-widget/widget.txt" 2>/dev/null; then
  echo "  [PASS] both widgets bumped to v1 (each wk did its task in its own net)"
else echo "  [FAIL] a widget was not bumped — a net was not live"; lf=1; fi
if [ "$(ls -1 "$RA/sup/inbox" 2>/dev/null | wc -l | tr -d ' ')" -ge 1 ] && [ "$(ls -1 "$RB/sup/inbox" 2>/dev/null | wc -l | tr -d ' ')" -ge 1 ]; then
  echo "  [PASS] both sups received their own wk's report (concurrent bus traffic)"
else echo "  [FAIL] a sup received no report"; lf=1; fi

echo "== TEARDOWN (zero orphans across BOTH pty roots) =="
pty --root "$PA" kill 2na-wk >/dev/null 2>&1; pty --root "$PB" kill 2nb-wk >/dev/null 2>&1
pty --root "$PA" gc >/dev/null 2>&1; pty --root "$PB" gc >/dev/null 2>&1
orphans=$(( $(pty --root "$PA" ls 2>/dev/null | grep -c '2na-wk') + $(pty --root "$PB" ls 2>/dev/null | grep -c '2nb-wk') ))
[ "$orphans" -eq 0 ] && echo "  [PASS] 0 pty orphans across both roots" || echo "  [FAIL] $orphans pty orphan(s) remain"
[ -n "$PA" ] && rm -rf "$(dirname "$PA")" 2>/dev/null   # /tmp/2net-<pid>

echo
if [ "$probe_rc" -eq 0 ] && [ "$lf" -eq 0 ] && [ "$orphans" -eq 0 ]; then
  echo "==> two-networks-coexist: PASS — zero cross-talk both directions; both nets live; zero orphans."
  exit 0
else
  echo "==> two-networks-coexist: FAIL — see [FAIL] rows (probe_rc=$probe_rc liveness_fail=$lf orphans=$orphans)."
  exit 1
fi
