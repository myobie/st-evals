<!--
HERMETIC KICK for the Ding-mode (no-MCP participation) eval. The ONLY input. Seeded by spin.sh into dm-sup's
inbox with a boot-time ms filename so the boot ritual ACTS on it. `from:` is the synthetic requester
(eval-runner) so the loop is observable + reproducible. spin.sh strips this HTML header.

Note: dm-sup boot-DRAINS this kick via the `st` CLI (it predates the ding sidecar, so no [DING] fires for it) —
that exercises "boot ritual works without MCP." dm-sup's DELEGATION to dm-dev is a live arrival -> dm-dev gets a
real [DING] -> that exercises "a [DING] is handled cleanly." Nothing here mentions ding/MCP; we watch the experience.
-->
---
from: eval-runner
subject: "small task: implement slugify in the widget lib"
priority: high
---
We need a `slugify(text)` helper in the `widget` lib (the repo your specialist `dm-dev` owns). Please have it
implement `slugify` in `src/slug.js` to the spec written in that file:

  - lowercase the text,
  - trim leading/trailing whitespace,
  - replace every run of non-alphanumeric characters with a single dash,
  - strip any leading/trailing dashes.

So `"Hello World"` -> `"hello-world"`, `"Foo_Bar Baz"` -> `"foo-bar-baz"`, `"  Trim Me  "` -> `"trim-me"`,
`"A.B.C"` -> `"a-b-c"`, `"Rock & Roll!"` -> `"rock-roll"`. Keep the test suite green (`npm test`) and commit.

You're the supervisor: delegate this to `dm-dev`, await its report, then verify read-only that slugify meets
the spec and the suite is green, and confirm back to me (`eval-runner`). Stay in lanes: `dm-dev` touches only
its own repo; coordinate by message.
