#!/usr/bin/env bash
# Capture the worktree's git-context GROUND TRUTH (the "weird git" the agent must resolve) — the held-out
# reference grade.sh checks the agent's committed result against. Writes $SB/.layout-<phase>.txt.
#   ./layout-probe.sh [SANDBOX] [phase]   # phase: pre (before the agent) | post (after)
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/weird-git-setup}"; phase="${2:-pre}"
WT="$SB/wt/feature"
{
  echo "phase: $phase"
  echo "dot_git_is_file: $([ -f "$WT/.git" ] && echo yes || echo no)"      # the trap: .git is a FILE in a worktree
  echo "dot_git_contents: $(cat "$WT/.git" 2>/dev/null)"                    # gitdir: <bare>/worktrees/<name>
  echo "show_toplevel: $(git -C "$WT" rev-parse --show-toplevel 2>/dev/null)"
  echo "git_dir: $(git -C "$WT" rev-parse --git-dir 2>/dev/null)"          # lives in the BARE repo, shared store
  echo "branch: $(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "feature_head: $(git -C "$WT" rev-parse HEAD 2>/dev/null)"
  echo "main_head: $(git -C "$SB/canonical.git" rev-parse main 2>/dev/null)"   # must NOT move (sibling untouched)
} > "$SB/.layout-$phase.txt"
echo "layout probe ($phase) -> $SB/.layout-$phase.txt"
