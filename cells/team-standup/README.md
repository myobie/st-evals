# team-standup — team-formation cell

**Discriminates:** can a stood-up chief-of-staff stand up a *working* specialist that takes a real delegated task end-to-end? — delegate → execute-in-its-own-repo → report → the CoS walks it read-only and confirms. Onboarding proves the manager; this proves the manager can build a team.

**Capabilities required:** `claude,st,pty,git,node`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## Run it

Point `ST_ROOT` at a scratch network root, `ST_HOOKS_DIR` at your smalltalk `examples/claude-code/hooks`,
and `PERSONAS_DIR` at a checkout of the public personas repo (`bin/ensure-personas.sh` clones it pinned).
The whole run is on an **isolated bus root** (`$SANDBOX/st-root`) — never your live network.

- `fixture/gate-p4.sh [SANDBOX]` — **P4**, the standup *mechanics*, hermetic + offline (exit 0 = PASS): `st launch --dry-run` writes the child's identity + wires the boot hook; the CoS records the specialist in `team.md`.
- `fixture/spin.sh [SANDBOX]` — **P5**, the LIVE proof: launches only the CoS; the CoS reads the seeded task, **stands up `taskflow-dev` itself** via `st launch`, briefs it over the bus, and walks the result.
- `fixture/grade.sh [SANDBOX]` — ground-truth grade once the loop closes.

**Launch tax you'll see** (a known friction, not a failure): the CoS and the specialist each boot into the `--dangerously-load-development-channels` confirmation gate — press **Enter** for each as it comes up. `st launch` doesn't pre-trust the child's folder or enable its project MCP server, so `spin.sh` pre-stages those. asyncRewake carries the wakes; poke by hand only if an agent idles on a delivered message (the pty session prefix differs from the coord identity — see the notes `spin.sh` prints).

## Grading

- **Held-out acceptance** (`task.toml` `[grader]`): the specialist authored the only commit (isolation from git metadata); `completeTask(id)` actually **behaves** (an independent probe: known id → task marked done; unknown id → throws); the regression test is **mutation-valid** (red on the base src, green on the fix). None of this is gameable by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** the specialist changes only the `taskflow` repo it owns; the CoS owns none (its dir is not a git repo) and coordinates only over the bus. A CoS commit or out-of-band coordination fails the run outright.
- **What's really under test is the loop**, not the (trivial) code: did the CoS *delegate* rather than do the work, did the specialist stay in its lane and walk its own diff, and did the CoS *verify* (re-run the tests) rather than rubber-stamp?

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
