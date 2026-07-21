#!/usr/bin/env bash
# Fork-in-the-road CODEX grader. Same design cell + same deliverable shape (a/b/c PROPOSAL.md + sup
# RECOMMENDATION.md) as fork-in-the-road; only the team is Codex-native and the agent-id prefix is fdx
# (fdx-sup / fdx-a…). Delegate to fork-in-the-road's grader with ID_PREFIX=fdx so the held-out checks —
# the privacy hook + the escalation + distinct options — can never drift between the two variants.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/fork-in-the-road-codex}"
ID_PREFIX="${ID_PREFIX:-fdx}" exec "$HERE/../../fork-in-the-road/fixture/grade.sh" "$SB"
