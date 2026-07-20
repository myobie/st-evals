# pty-send-peek

**Type:** pty / verb-surface · **Ship:** ship

**Capabilities required:** `pty,git` · run `bin/evals preflight` to confirm. No LLM, no bus, no convoy — pure
pty. Deterministic: a random per-run token + a fixed ACK-reader process, so the outcome is fully determined.

**Discriminates:** does the **pty verb surface actually work** — does `pty send` deliver bytes the session's
process receives and acts on, and does `pty peek` return the session's real live output? The suite spawns and
restarts sessions everywhere as plumbing, and `two-networks-coexist` asserts that *cross-network* peek/send is
**refused** — but nothing grades peek/send as a **working capability**. This is that positive round-trip.

## What it proves

The session runs a deterministic **ACK-reader** (`printf READY`, then `ACK:<line>` per input line):

- **Round-trip:** `pty send <id> --seq "<tok>" --seq key:return` injects a **random per-run** token; then
  `pty peek --plain` shows `ACK:<tok>`. The `ACK:` prefix is emitted by the **process**, so a matching ACK
  proves the process *received and acted on* the sent bytes (not just terminal echo), and that peek returned
  the real output.
- **Negative control (mutation-valid):** a peek taken **before** the send does **not** contain `ACK:<tok>` —
  so peek reflects real state and the ACK appears only because `pty send` delivered the input. The token is
  random per run, so no fixture can pre-bake the screen.
- **Isolation:** the session lives in a scratch `PTY_ROOT` (`pty --root`); the grader asserts it is **invisible**
  in the operator's global pty registry.

## Run it

```sh
fixture/probe.sh <SB>   # spawn the ACK-reader, send a random token, capture the screen before + after
fixture/grade.sh <SB>   # assert the round-trip + negative control + isolation (from the captured screen)
```

or `bin/evals run pty-send-peek` (runs probe then grade). Use a SHORT `<SB>` (e.g. `/tmp/psp`) so the pty unix
socket path stays under 104 bytes. Net-free and self-cleaning (the session is `kill`+`rm`'d at the end).
