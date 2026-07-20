#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (pty-send-peek) — DETERMINISTIC, no LLM. The POSITIVE pty verb-surface round-trip: proves
# `pty send` injects input the session's process ACTS on, and `pty peek` returns the session's REAL live
# output. Every other cell only spawns/restarts sessions or asserts cross-network peek/send is REFUSED
# (two-networks-coexist) — none grade peek/send as a working capability. This closes that hole.
#
# The session runs a deterministic ACK-reader: it prints READY, then for each input line prints "ACK:<line>".
# The "ACK:" prefix is emitted by the PROCESS, so a matching ACK in the screen proves the process RECEIVED and
# ACTED on the sent bytes — not merely that the terminal echoed them back. The token is RANDOM per run, so no
# fixture can pre-bake the expected output.
#   pre.out  — peek BEFORE the send: the ACK token must be ABSENT (peek reflects real state / negative control)
#   post.out — peek AFTER the send:  the ACK token must be PRESENT (send delivered → process acted → peek saw it)
#
# ISOLATION: the session lives in a scratch PTY_ROOT (--root), never the operator's global pty registry. Short
# root path (unix socket path < 104 bytes). Torn down (kill + rm) at the end.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-/tmp}/psp}"   # SHORT path (pty unix-socket path must stay < 104 bytes)
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"
PR="$SB/r"; mkdir -p "$PR"             # scratch PTY_ROOT (isolated registry)
ID="psp-wk"
pk(){ pty --root "$PR" "$@"; }

if ! command -v pty >/dev/null 2>&1; then
  echo "SKIP: pty not on PATH" >&2; printf 'PROBE-SKIP\n' > "$P/shape.txt"; exit 0
fi
{ pty --version 2>&1 | head -1
  ptb="$(command -v pty 2>/dev/null)"; ptr="$(readlink -f "$ptb" 2>/dev/null || realpath "$ptb" 2>/dev/null || echo "$ptb")"
  git -C "$(dirname "$ptr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/pty_git_sha=/'
} > "$P/pty-version.txt" 2>/dev/null || true

tok="PSP-$$-${RANDOM}${RANDOM}"        # random per run — ungameable (no fixture can pre-bake ACK:<tok>)
echo "== spawn a deterministic ACK-reader session in the scratch PTY_ROOT =="
pk run -d --id "$ID" -- sh -c 'printf "READY\n"; while IFS= read -r line; do printf "ACK:%s\n" "$line"; done' >/dev/null 2>&1
pk peek --plain --wait "READY" -t 15 "$ID" >/dev/null 2>&1 && echo "     reader READY" || echo "     reader did not signal READY"

echo "== NEGATIVE control: peek BEFORE sending (the ACK token must be ABSENT) =="
pk peek --plain "$ID" > "$P/pre.out" 2>/dev/null || true

echo "== SEND the random token + Return (pty send) =="
pk send "$ID" --seq "$tok" --seq key:return >/dev/null 2>&1

echo "== POSITIVE: wait for the process's ACK, then peek the real screen (pty peek) =="
pk peek --plain --wait "ACK:$tok" -t 15 "$ID" >/dev/null 2>&1 || true
pk peek --plain "$ID" > "$P/post.out" 2>/dev/null || true

echo "== capture the shape =="
{
  echo "tok=$tok"
  pk ls 2>/dev/null | grep -q "$ID"                     && echo "session_listed=yes"  || echo "session_listed=no"
  grep -q "ACK:$tok" "$P/pre.out"  2>/dev/null          && echo "pre_ack=yes"         || echo "pre_ack=no"
  grep -q "ACK:$tok" "$P/post.out" 2>/dev/null          && echo "post_ack=yes"        || echo "post_ack=no"
  grep -q "$tok"     "$P/post.out" 2>/dev/null          && echo "post_saw_token=yes"  || echo "post_saw_token=no"
  # isolation: the session must NOT be visible in the operator's GLOBAL pty registry (no --root)
  pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -q "$ID" && echo "global_leak=yes" || echo "global_leak=no"
} > "$P/shape.txt"
sed 's/^/     /' "$P/shape.txt"

echo "== teardown =="
pk kill "$ID" >/dev/null 2>&1 || true
pk rm "$ID"   >/dev/null 2>&1 || true
echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
