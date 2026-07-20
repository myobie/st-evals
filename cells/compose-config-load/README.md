# compose-config-load — the composed repo's CLAUDE.md + skills still load

**Discriminates:** after a convoy agent is composed into a repo, does that repo's **own CLAUDE.md** (loaded through
convoy's additive `CLAUDE.local.md` layering, not clobbered) and its **project skills** still load and work? (held-out)

**Capabilities required:** `convoy,st,pty,git` (+ `claude` for the live headline) · run `bin/evals preflight`.

## What it proves (Nathan's mandate)

*"A composed agent's own CLAUDE.md + skills still load and work."* When convoy composes an agent into a repo it
writes an **additive** `CLAUDE.local.md` (which `@`-imports `PERSONA.md` + `DING-BUS.md`) **alongside** the repo's
tracked `CLAUDE.md` — Claude Code loads both, so the repo's instructions are layered, not replaced — and the
repo's project skills auto-load via `--dir`. This cell proves + guards that: the repo's own config survives the
compose and the agent actually follows it.

## Two tiers (mirrors restorability)

- **Deterministic core — `fixture/probe.sh` (box-free):** compose into a *copy* of the repo and assert the loading
  path is intact — CLAUDE.md **byte-identical** after `convoy add` (untouched), `CLAUDE.local.md` present +
  `@`-imports + **coexists** with CLAUDE.md (layered, not replaced), and the secret/skill tokens survive + stay tracked.
- **Live headline — `fixture/spin.sh` (rides the box):** the agent, kicked over the bus, writes `SECRET.txt` (the
  secret from its repo `CLAUDE.md`) and `GREET.txt` (via its project **greet** skill). Each token is **per-run
  nonce'd** and lives **only** in its file body (never in the kick) — so a sentinel bearing it is ungameable
  proof that config loaded.

**Mutation-valid at both layers (prove *loading*, not *echo*):**
- **TOKEN-SOURCE** (box-free): the per-run token appears in **no** agent-visible file except its source
  (`CLAUDE.md` / `SKILL.md`) — not the kick, persona, `CLAUDE.local.md`, `PERSONA.md`, `DING-BUS.md`, or
  `settings.local.json` — so a positive sentinel can only be loading.
- **NEGATIVE CONTROL** (live): a second repo with a **different** secret and **no** greet skill, run with the
  **same** kick, must **not** emit the real tokens. Same harness, only the repo config differs → proves the
  positive run read its *own* CLAUDE.md/skill, not that the token echoed in via the kick.

## Run it

Deterministic (no box): `fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`. Full live run: `fixture/spin.sh`, or
`bin/evals run compose-config-load`. Self-isolating (isolated convoy net + decoupled short `PTY_ROOT`);
zero-orphan teardown. Needs `PERSONAS_DIR` (runner-set).

## Grading

See `task.toml` `[grader]`. A false PASS is impossible: the per-run tokens live only in the repo's own
CLAUDE.md/skill body, so `SECRET.txt`/`GREET.txt` bearing them can only come from actually loading that config
through the compose — not from the kick or the persona. A clobbered CLAUDE.md is caught deterministically.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md). Sibling:
[`clean-compose`](../clean-compose/README.md) proves the same compose adds **zero repo pollution**.
