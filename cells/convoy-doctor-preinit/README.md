# convoy-doctor-preinit — a fresh user's FIRST `convoy doctor` is friendly, not a failure wall

**Discriminates:** does a brand-new user's very first `convoy doctor` — run BEFORE any `convoy init` — get a
friendly neutral pointer + `rc=0`, or the old scary `✗ named network` / `✗ smalltalk MISSING` blocking wall
(`rc=1`)? (deterministic, held-out, no LLM)

**Capabilities required:** `convoy,st,pty,git` · run `bin/evals preflight`. Box-free (`--quick` spawns no agents).

## What it proves (the Johannes first-command UX)

`convoy doctor` is the first thing a new user runs to sanity-check their setup. Pre-#63, a fresh machine got three
red ✗ and `rc=1` — a failure wall that reads as **"convoy is broken"** when the real answer is **"you just haven't
run `convoy init` yet"**. Redesign #63 (convoy `3fc9dc32d`) turns that into a friendly next-step. This cell guards
that UX so it can't regress back to the scary wall.

## Two assertions

- **PRE-INIT NEUTRAL (hard gate):** on a FRESH, never-init'd path, `convoy doctor --quick --network <fresh>` exits
  **`rc=0`** and stdout carries the neutral **"no network here yet — run convoy init"** pointer — and does **NOT**
  contain the old `✗ named network` / `MISSING:` wall. A first run reads as a next-step, not a breakage.
- **POST-INIT CONTRAST (mutation-valid):** the neutral pointer is PRE-init-specific — a real, `convoy init`'d net
  does **not** print "no network here yet"; it still shows the full **Structure** check list. This proves the
  pre-init line is scoped to fresh nets (not vacuously always-neutral, and doctor isn't degraded on real nets).

## Critical isolation

doctor is scoped with **`--network <sandbox>`** and the ambient `ST_ROOT`/`PTY_ROOT`/`CONVOY_NETWORK` are **unset**
— a bare `convoy doctor` (or one relying on `ST_ROOT`) hits the operator's **real default network**. `--quick`
spawns no agents. This cell never touches the live fleet.

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`, or `bin/evals run convoy-doctor-preinit`. Greenfield-safe;
zero-orphan teardown.

See `task.toml` for the full spec. Sibling:
[`convoy-doctor-structure`](../convoy-doctor-structure/README.md) — the POST-init narrated structure proof this
complements (pre-init neutral here; post-init structure-correct there).
