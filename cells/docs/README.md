# docs — docs cell

**Discriminates:** an explain-it doc a COLD reader can act on (held-out cold-reader)

**Capabilities required:** `claude,st,pty,git,node`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## Run it

The team is launched via the real `st launch` (the same command a user runs). `fixture/spin.sh` is
**self-isolating** — it creates and exports its own scratch bus root at `$SB/st-root`, so nothing touches
your live network; the st-launched agents inherit that root by env inheritance. You only need
`PERSONAS_DIR` (a checkout of the public personas repo — `bin/ensure-personas.sh` clones it pinned; the
runner sets it for you). No external `ST_ROOT` / `ST_HOOKS_DIR` required — spin owns the root and
`st launch` wires the boot hooks (asyncRewake / PreCompact / StopFailure) itself.

Run it: `fixture/spin.sh` (auto-materializes the sandbox via `fixture/setup-sandbox.sh` if absent), or
`bin/st-evals run docs`. Tear down after grading with `bin/st-evals teardown <SB>`.

## Grading

- **Grade:** `fixture/grade.sh` mechanizes the ground-truth checks (never trusts self-reports).
- **Held-out:** `fixture/cold-reader.sh` — a fresh agent uses the deliverable cold; it must act correctly from it alone.
- **Held-out acceptance** — see `task.toml` `[grader]`: an independent check the team never sees, so the result can not be gamed by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** every agent changes only the module/repo it owns; all coordination flows through the message bus. A non-owner change fails the run outright.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
