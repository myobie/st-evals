# compose-global-skill — global (user-level) skills fire through a compose

**Discriminates:** does a **GLOBAL** (user-level, `~/.claude/skills`) skill — which convoy does *not* put in the
repo or the persona overlay — still get **called** in an agent composed into a repo? i.e. does convoy's setup
shadow/break the user's global-skill environment? (held-out)

**Capabilities required:** `convoy,st,pty,git` (+ `claude` and a test `ANTHROPIC_API_KEY` for the live layer) ·
run `bin/st-evals preflight`.

## What it proves (Nathan's mandate)

A composed agent must keep the user's global skills. This is the distinct case from
[`compose-config-load`](../compose-config-load/README.md) (which proves a **repo-local** skill loads): here the
skill lives at the **user/global** level, and we prove the compose doesn't shadow it.

## The auth wall (why the live layer is gated)

To test `~/.claude/skills`-scope **without polluting the user's real global skills**, the only isolation is a
relocated config dir (`--config-dir` / sandboxed HOME). But a relocated config dir **can't use the keychain-locked
oauth** — verified: `claude` says *"Not logged in"*, copying the login pointer doesn't restore it, and there's no
`ANTHROPIC_API_KEY`. So a fully-isolated **live** run needs a test key. This is the same wall `skill-inheritance`
deferred personal-scope for. The cell handles it honestly:

- **NO-SHADOW (box-free, the provable heart):** compose into a repo and prove the compose does **not** relocate the
  config dir (no `CLAUDE_CONFIG_DIR` in `pty.toml`), disable skills (no `--config-dir`/`--disable-slash-commands`),
  or scope them away (settings.local.json is hooks-only) — so the user's `~/.claude/skills` stay discoverable.
- **GLOBAL-SKILL-FIRES (live, gated):** with a test `ANTHROPIC_API_KEY`, install a nonce global skill in an
  **isolated** config dir, compose an agent there (`--config-dir`), and assert it writes the nonce; a no-skill
  **negative control** with the same kick must not. Without a key, this **skips-with-reason** and NO-SHADOW carries it.

> **Live layer is HELD pending Nathan's decision** among three isolations: **(a)** a *guarded temp-install* of a
> nonce-named skill in the real `~/.claude/skills` with guaranteed cleanup + assert-clean (full live proof, no key,
> but transiently touches the real config — machine-changing); **(b)** the test-API-key + `--config-dir` route
> built here (never touches the real config; needs a key); **(c)** deterministic-only. The NO-SHADOW core ships now
> regardless.

## Critical isolation

The test global skill lives **only** in the run's isolated config dir (`$SB/cfg`, via `--config-dir`) — **never**
in the real `~/.claude/skills`. The grader hard-gates that the real `~/.claude/skills` is byte-identical
before/after and never contains the test skill.

## Run it

Box-free: `fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`. Live (needs a key): `ANTHROPIC_API_KEY=… fixture/spin.sh`,
then `fixture/grade.sh <SB>`. Zero-orphan teardown; verify `~/.claude/skills` unchanged after.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md).
