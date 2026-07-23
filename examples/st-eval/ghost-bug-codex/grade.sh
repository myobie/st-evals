#!/usr/bin/env sh
# Written per-run by bin/gen-batch.sh to $CATALOG/scripts/grade.sh (paths below are filled with the
# run's real absolute paths). Runs the cell's UNCHANGED held-out grader — cells/ghost-bug-codex/fixture/grade.sh —
# via ITS OWN shebang (bash: graders use $HERE/BASH_SOURCE/[[ ]]), with NO positional arg and only
# EVAL_SANDBOX set: exactly how the grader ran in the repoint gate. The spec's `verdict "grader-output"`
# parses the grader's [PASS]/[FAIL] OUTPUT (PASS iff >=1 [PASS] & 0 [FAIL]), never the exit code.
EVAL_SANDBOX="<sandbox-parent>" exec "<repo>/cells/ghost-bug-codex/fixture/grade.sh"
