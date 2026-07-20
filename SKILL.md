---
name: evals
description: Run isolation-gated, held-out-graded agent-team evals for the compoundingtech network (convoy + smalltalk + pty). Use when asked to run an eval cell, check which cells a setup can run, smoke-test that a network is wired correctly, or add a new eval cell.
---

# evals — agent-team eval suite

`evals` runs **isolation-gated, held-out-graded** evals for agent *teams* on the compoundingtech network.
The thing under test is the **whole network** — **convoy** (orchestrator: compose / doctor / up), **smalltalk**
(`st`: the message bus + hooks + context), and **pty** (the terminal-session harness) — not any one model.
Each cell seeds one instruction, lets a real team self-organize, then grades the result with a check the
team never sees. These are **not** smalltalk-only evals: cells exercise convoy, st, **and** pty.

## Run it

The runner is `bin/evals` (a POSIX shell script — nothing to install from evals itself):

```sh
bin/evals preflight       # detect installed capabilities → which cells you can run
bin/evals readiness       # first-boot smoke: bus works, agents spawn, messages round-trip
bin/evals list            # the cell catalogue (type · ship/flag · caps)
bin/evals run <cell>      # run one cell end-to-end (ensures the pinned personas first)
bin/evals teardown <SB>   # pty kill+rm every session a run left behind + neuter its pty.toml
```

Every run is **isolated**: it materializes a throwaway sandbox at a frozen commit, uses a scratch network
root, and never touches the live network. The teardown command to reap a run's sessions is printed at the
end of the run.

## Requirements

All on `PATH` (`bin/evals preflight` verifies and maps them to runnable cells):

- **smalltalk** (`st`) — the message bus — https://github.com/compoundingtech/smalltalk
- **pty** — the terminal-session harness — https://github.com/compoundingtech/pty
- **convoy** — the orchestrator (needed by the convoy cells) — https://github.com/compoundingtech/convoy
- `git`; `node` for cells whose sample services are JS
- at least one agent harness: `claude` and/or `codex`, or `ollama` + a GLM model

A cell runs only if **every** capability it lists is present. **Cross-family judging** (a quality judge from
a different model family than the subject) unlocks once ≥2 families are installed.

## Env a run may need

Each cell's `README.md` says which it needs. Common ones:

- `ST_ROOT` — a scratch network root (throwaway)
- `PTY_ROOT` — a scratch pty root (per-network isolation)
- `ST_HOOKS_DIR` — your `<smalltalk>/examples/claude-code/hooks`
- `PERSONAS_DIR` — a checkout of the public [`personas`](https://github.com/compoundingtech/personas) repo
  (`bin/ensure-personas.sh` clones it pinned for you)
- runner toggles: `EVAL_DING=1` (or `bin/evals run <cell> --ding`) to exercise the no-MCP ding path;
  `EVALS_MANIFEST` to point at an alternate `cells.manifest`

**Never** set/override `ST_AGENT` for the runner itself — it is the per-agent identity var the cells manage.

## Layout

```
bin/evals            the runner
cells.manifest       one row per cell: name | type | ship | caps | discriminator  (sorted by name)
REGISTRY.md          the human catalogue: discriminator + held-out acceptance + caps per cell
COVERAGE.md          which cells exercise convoy / st / pty, and the open gaps
framework.md         the axes, isolation gate, visible/held-out split, run lifecycle
cells/<cell>/        one scenario: task.toml + README.md + fixture/ (setup/compose/spin/grade)
```

## Add a cell

1. Add a row to `cells.manifest` **at its sorted (alphabetical) position** — `name | type | ship | caps | discriminator`.
2. `cells/<name>/fixture/setup-sandbox.sh` — materialize a small **synthetic** world frozen at a base commit
   (no real repos/identities); make the visible suite green.
3. `cells/<name>/fixture/kick-*.md` — the single frozen instruction the supervisor wakes to (don't
   over-specify the solution; the system should have to *emerge* it).
4. `cells/<name>/fixture/grade.sh` — mechanize ground-truth checks, including a **held-out** check a
   unit-test edit can't fake (replay against the base commit, an independent correctness gate, a cold-reader,
   a mutation score).
5. `cells/<name>/task.toml` + `README.md` — the spec + how to run it. Add the matching `REGISTRY.md` row
   (also at its sorted position).

Keep the sandbox synthetic and the grader honest: it must accept *any* correct solution (not one canonical
diff) and still discriminate bad from good (validate it on a deliberately-wrong mock).
