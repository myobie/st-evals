# evals → st2 phase-2 board — cells migrated to the `type = batch` / st-eval format

**Verdict: the migration works.** The generator (`bin/gen-batch.sh`) migrates each st2-green team-loop cell
into a self-contained `type = batch` agent-spec that **wraps the cell's fixtures byte-identical** (see
`BATCH-SPECS.md`), and `st2 batch <catalog> <cell>` runs it end-to-end: setup → run (seats + kick +
grade-poll `done-when`) → grade (the UNCHANGED `grade.sh`, verdict `grader-output`).

**16 / 18 team-loop cells green as batch specs** (17/18 migrate to runnable specs; 1 model-variance fail; 1
seam-edge that doesn't extract). Every executor gap surfaced during phase-2 was fixed same-session by
st2-claude (auto-pretrust; the seat-wake dual-bus fix; `done-when { grade }` grade-poll = the gate's
poll-until-grade-green), and every generator bug fixed (render-agent `--extra-arg` threading, the
grade-wrapper shebang + no-arg + `EVAL_SANDBOX`).

## Board (via `st2 batch`, grade-poll)

| cell | batch verdict | note |
| --- | --- | --- |
| license-mit | **PASS** 10/0 | reference; real relicense commit |
| license-mit-codex | **PASS** 10/0 | |
| ghost-bug | **PASS** 10/0 | debug: root-cause + mutation-valid regression |
| ghost-bug-codex | **PASS** 10/0 | debug, codex |
| feature-fit | **PASS** 10/0 | output-signaling grader (always-exit-0) — verdict via `grader-output`, honest |
| docs | **PASS** 11/0 | output-signaling grader |
| ding-mode | **PASS** 8/0 | no-MCP ding coordination |
| ding-reply | **PASS** | |
| inbox-hygiene | **PASS** 4/0 | |
| incident-response | **PASS** 6/0 | |
| migration | **PASS** 13/0 | held-out |
| poisoned-pr | **PASS** 8/0 | review: caught the planted defect |
| restart-continuity | **PASS** 14/0 | |
| security-audit | **PASS** 10/0 | |
| team-standup | **PASS** 13/0 | CoS stands up a specialist (1 declared seat; specialist runtime-spawned) |
| test-writing | **PASS** 6/0 | mutation-kill headline |
| poisoned-pr-codex | **FAIL** 3/3 | **model-variance, not a batch bug.** The codex *review* cell is model-dependent (greened in the gate only on the 30-min re-run); it MIGRATED + ran, the single-run verdict didn't reach REQUEST-CHANGES-catching-the-defect. A re-run may pass; same cell-difficulty as the gate's murky reds. |
| weird-git-setup | **n/a (seam-edge)** | uses raw `convoy add` (megarepo worktree-launch case), NOT the `stev_convoy_add` seam → the dry-run extractor finds no seats. Generator TODO: special-case the megarepo launch, or route the cell through the seam. Not a batch/migration failure. |

## CoS phase-2 sample target (honesty, per cell — all uniform by construction in `bin/gen-batch.sh`)

1. **grade stage invokes the UNCHANGED `cells/<cell>/fixture/grade.sh`** via its own shebang, **no positional
   arg + `EVAL_SANDBOX` set** — reproducing exactly how the graders ran in the repoint gate (the fix for the
   feature-fit/docs/ghost-bug-codex wrapper bugs the shepherd sweep caught). No inlined/edited grader.
2. **`grade.sh` byte-identical** to the fixture (diff vs the gate; the generator never touches it).
3. **verdict `grader-output`** — parses `[PASS]`/`[FAIL]` output, not exit code (anti-hollow-green).

Batch-specs path/naming + the format: `BATCH-SPECS.md`. Generator: `bin/gen-batch.sh`. Per-cell run logs
retained.
