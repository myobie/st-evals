#!/usr/bin/env bash
# run.sh (pty-send-peek) — the `bin/evals run pty-send-peek` entry point: probe then grade, in one shot.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-/tmp}/psp}"
"$HERE/probe.sh" "$SB"
echo
"$HERE/grade.sh" "$SB"
