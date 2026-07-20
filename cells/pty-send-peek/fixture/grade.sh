#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for PTY-SEND-PEEK. Asserts the POSITIVE pty verb-surface round-trip from the session's
# REAL captured screen (never a self-report): `pty send` delivered input the process ACTED on, and `pty peek`
# returned that real output. Mutation-valid via the negative control (the ACK token was ABSENT before the send,
# so peek reflects real state, not an always-pass) + a per-run RANDOM token (no fixture can pre-bake the ACK).
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/psp}"
P="$SB/.probe"
pass=0; fail=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
g(){ grep -q "^$1\$" "$P/shape.txt"; }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'PROBE-SKIP' "$P/shape.txt" 2>/dev/null; then sk "pty not available"; echo "SCORE: skipped"; exit 0; fi
[ -f "$P/pty-version.txt" ] && { echo "pty under test:"; sed 's/^/  /' "$P/pty-version.txt"; }
tok="$(sed -n 's/^tok=//p' "$P/shape.txt")"

echo
echo "== SESSION REAL (hard gate) — the round-trip targeted a real live pty session =="
g "session_listed=yes" && ok "the scratch PTY_ROOT lists the session (pty send/peek addressed a real running session)" \
                       || no "the session was not listed — nothing real to send to / peek at"

echo
echo "== NEGATIVE CONTROL (hard gate, MUTATION-VALID) — the ACK was ABSENT before the send =="
g "pre_ack=no" && ok "before the send, the screen did NOT contain ACK:$tok — peek reflects real state (not an always-pass)" \
              || no "the ACK token was already on screen before the send — the check is vacuous (peek isn't reflecting the send)"

echo
echo "== ROUND-TRIP (hard gate) — pty send delivered input the process ACTED on, and pty peek saw it =="
g "post_ack=yes" && ok "after the send, pty peek shows ACK:$tok — the process RECEIVED + ACTED on the sent bytes (the ACK prefix is the process's, not terminal echo), and peek returned the real output" \
                 || no "no ACK:$tok on screen after the send — pty send did not deliver, the process didn't act, or pty peek didn't return the real output"
# independent check against the captured screen, not just the probe's boolean
if [ -n "$tok" ] && grep -q "ACK:$tok" "$P/post.out" 2>/dev/null; then ok "captured post-send screen independently contains ACK:$tok (random per-run token — ungameable)"; \
else no "the captured post-send screen does not contain ACK:$tok"; fi

echo
echo "== ISOLATION (hard gate) — the session stayed in the scratch registry, not the global one =="
g "global_leak=no" && ok "the session is NOT visible in the operator's global pty registry (--root scoped it to the sandbox)" \
                   || no "LEAK: the session appeared in the global pty registry (PTY_ROOT isolation failed)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> pty-send-peek: PASS — the pty verb surface works end-to-end: \`pty send\` injects input the session's"
  echo "    process acts on, and \`pty peek\` returns the real live output (proven with a random per-run token +"
  echo "    an absent-before / present-after contrast), all isolated to a scratch PTY_ROOT."
else
  echo "==> pty-send-peek: FAIL — the pty send/peek round-trip did not hold (send didn't deliver, the process"
  echo "    didn't act, peek returned stale/fake output, or the session leaked the isolation boundary)."
fi
[ "$fail" -eq 0 ]
