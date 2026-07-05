# ding-mode — no-MCP participation cell

**Discriminates:** is **ding-only** a first-class network experience — good boot, clean `[DING]` handling, natural coordination @ 0 rescues — or a degraded fallback? (held-out; the no-MCP shape)

**Capabilities required:** `claude,st,pty,git,node`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## What it proves

Some environments can't run MCP servers at all (locked-down hosts, some sandboxes). There, a Claude agent
joins the network the way Codex does: launched with **`st launch claude --ding`** — no MCP wiring, an
**`st ding` sidecar** delivers inbound messages as `[DING] `-prefixed pokes, and the **`st` CLI** does every
bus op (send / ls / read / reply / archive / status). A ding-mode Claude gets **no MCP system-prompt**, so
nothing tells it it's on a bus or how to participate — it must get that from its **persona**. This cell
launches a **fully no-MCP 2-agent team** and grades whether an explicit ding-mode bus-participant blurb makes
them genuinely competent. The task (implement `slugify` to an exact spec) is deliberately small so the focus
is the *coordination experience*, not task difficulty.

## Run it

`fixture/spin.sh` is **self-isolating** — it creates and exports its own scratch bus root at `$SB/st-root`;
`st launch` bakes that into every session's env (agent **and** ding sidecar), so nothing touches your live
network. You only need `PERSONAS_DIR` (the runner sets it). Run it: `fixture/spin.sh` (auto-materializes the
sandbox if absent), or `bin/st-evals run ding-mode`.

`spin.sh` launches `dm-dev` (owns `widget`) and `dm-sup` (coordinate-only) — **both `--ding`, no MCP** — seeds
the hermetic kick, and lets them self-organize over ding + the CLI. Each agent has two pty sessions: the
claude session (`<id>-<stev-prefix>`) and its ding sidecar (`<id>-ding`); both are torn down zero-orphan.

- Grade: `fixture/grade.sh <SB>`  ·  Tear down: `bin/st-evals teardown <SB>` (removes the agents **and** the ding sidecars)

## Grading — the EXPERIENCE, not just delivery

Held-out (`task.toml` `[grader]`), mechanized in `fixture/grade.sh`:
- **Task correct** — `slugify` meets the spec on held-out cases (run, not eyeballed) + suite green.
- **No MCP** (hard) — neither agent dir has a `.mcp.json`: the launch was genuinely MCP-less.
- **(a) Boot without MCP** — the seeded kick got drained to `dm-sup`'s archive over the CLI (boot ritual ran, no channel-injection).
- **(b) `[DING]` handled cleanly** — `dm-dev` read + archived the delegation **and** replied (the ding-delivered task was handled end-to-end via CLI).
- **(c) Coordination natural** — the delegate → report → confirm loop is bus-visible.
- **Isolation** (hard gate) — only `dm-dev` authored `widget` commits; the supervisor owns no repo.
- **Autonomy is the headline: rescues = 0.** Any human poke/un-stick (or having to teach it the CLI) means ding-only was *not* first-class.

This run also doubles as the **acceptance test for `st launch claude --ding`** (#58).

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
