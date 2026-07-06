<!--
HERMETIC KICK for the signal-rename cell. The ONLY input to the team — no live agent prompts anyone.
spin.sh strips this HTML header and drops the frontmatter+body into sig-sup's inbox as a valid coord message
(boot-time ms filename). `from:` is a SYNTHETIC requester (morgan) — reproducible, not a live sender.
-->
---
from: morgan
subject: "rename our `signal` product to `beacon` across the stack"
priority: high
---
We're renaming our product from `signal` to `beacon`. It ripples across the whole stack — please coordinate it:

- **signal** (base): the npm package `@acme/signal` → `@acme/beacon`, the `signal` CLI bin → `beacon`,
  README/docs, internal product references.
- **signal-relay** (consumer): the `@acme/signal` peerDependency + imports/product references, docs.
- **signal-hub** (consumer): the product references + the `signal://` resource scheme → `beacon://`.
- **config**: `app.toml` (the product config — that one's yours).

**CRITICAL:** `signal` also names a primitive — the OS signal and `AbortSignal`/`controller.signal`. Do **not**
rename the primitive, only the product. A blind find-replace will break things.

Keep every repo's test suite green (`node --test`). **Sequence** the cutover so consumers never reference a name
the base no longer provides — rename the base first, and a backward-compat/alias window is fine (have the base
export both names briefly), mirroring a dual-honor cutover. Each of you touches only the repo you own; coordinate
everything else by message.

When it's done, tell me how you decomposed + sequenced it, and any problems you hit.
