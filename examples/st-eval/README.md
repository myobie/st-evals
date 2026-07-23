# Reference `st-eval` specs — evals in the new `type = batch` format

These are **concrete, readable examples** of an eval expressed in the new format, so you can open and
critique the shape without running anything. Three cells:

| dir | cell | what it exercises |
| --- | --- | --- |
| [`license-mit/`](license-mit/) | simplest reference | sup + worker; worker makes a real relicense commit |
| [`ghost-bug/`](ghost-bug/) | debug | root-cause a planted bug + write a mutation-valid regression |
| [`ghost-bug-codex/`](ghost-bug-codex/) | debug, codex model | same task, codex-harnessed seats |

Each dir holds the three things that make one eval:

- **`agent.kdl`** — **the eval itself**: a `type = batch` agent-spec declaring the setup → run → grade DAG.
  This is the format under review. It is fully portable — only seat ids and `$CATALOG`-relative paths,
  no absolute/machine paths.
- **`kick.md`** — the task message delivered to the supervisor seat to start the run (the cell's unchanged kick).
- **`grade.sh`** — the grade-wrapper. It shells the cell's **unchanged** held-out grader
  (`cells/<cell>/fixture/grade.sh`) via its own shebang, no positional arg, only `EVAL_SANDBOX` — exactly
  how the grader ran in the repoint gate. (Committed here with `<repo>`/`<sandbox-parent>` placeholders;
  the generator fills real paths per run.)

Format doc: [`../../BATCH-SPECS.md`](../../BATCH-SPECS.md). Full results across all cells:
[`../../EVALS-ST2-PHASE2-BOARD.md`](../../EVALS-ST2-PHASE2-BOARD.md).

## How to read `agent.kdl`

```kdl
run {
  seat "mix-worker" { agent "mix-worker" }        // the seats st2 spins up for the run
  seat "mix-sup"    { agent "mix-sup" }
  kick      { to "mix-sup"; from-file "$CATALOG/kick.md" }   // start message → the supervisor
  done-when { grade; timeout "1200s" }            // GRADE-POLL: run ends when the held-out grader PASSes
}
stage "setup" { exec { command "true" } }         // world pre-built (see "convoy-state" below)
stage "run"   { after "setup"; run }
stage "grade" { after "run"; exec { command "sh $CATALOG/scripts/grade.sh" }; verdict "grader-output" }
```

Two properties are what make it honest, uniform across every cell (see `BATCH-SPECS.md` for the diff target):

1. **`done-when { grade }`** — the run doesn't end on a supervisor "got it, delegated" ack; it polls the
   **held-out grader** every few seconds until the acceptance criteria actually pass (or the timeout →
   honest FAIL on the final state). Same poll-until-green as the repoint gate.
2. **`verdict "grader-output"`** — the score comes from the grader's `[PASS]`/`[FAIL]` **output**
   (PASS iff ≥1 `[PASS]` & 0 `[FAIL]`), never the exit code. Anti-hollow-green.

## Committed-source vs generated-per-run — the open format call

Today these specs are **generated per run** by `bin/gen-batch.sh` from the cell's existing fixtures (they're
a byte-identical *wrap* — the generator edits no `setup-sandbox.sh` / `compose-persona.sh` / `grade.sh` /
`kick`). These committed copies are **reference snapshots**, not the source of truth.

The design decision to make: **should the `.kdl` become the committed source** (spec-first — you write/read
the spec, the fixtures shrink to what it references) **or stay generated** (fixtures-first — `spin.sh` stays
authoritative, the spec is derived)? That's the call to make on review — both are cheap from here.

## convoy-state (honest)

**The batch run is convoy-free / pure st2.** Seats are rendered with `st2 render-agent` and run by
`st2 batch`; no convoy binary is invoked. The convoy scaffolding you saw in `cells/*/fixture/spin.sh`
(`stev_convoy_init`, `stev_convoy_add`) is **not called in this path** — the generator runs `spin.sh` only
in `STEV_DRYRUN` mode, where those seams are **stubbed** (they record the seats/kick to a file and return;
they never shell convoy), and st2 does the actual rendering + running.

The honest caveat: the **name** `convoy` still lingers in the `spin.sh` source (that's what you spotted).
It's legacy — in the repoint gate those `stev_convoy_*` seams *dispatch* to st2 under `STEV_RUNNER=st2`
(real convoy runs only under `STEV_RUNNER=convoy`, the retiring baseline). Retiring the name entirely —
`spin.sh` gone, the spec's own `setup` stage owning the render (right now `setup` is a no-op and the world
is pre-built) — is the tracked "self-contained render-in-setup" follow-up. No real convoy dependency remains
in the new-format run; the cleanup is cosmetic + tracked.
