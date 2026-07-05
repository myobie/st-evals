<!--
HERMETIC KICK for TEAM-STANDUP P5 (the LIVE proof). This is the ONLY input to the team — no live agent
prompts anyone. spin.sh strips this HTML header and materializes the rest into the CoS's inbox as a valid
coord filename (<13-digit-ms>-<6alnum>.md) with a boot-time ms so the boot ritual ACTS on it rather than
archiving it as stale backlog. `from: jordan` is the frozen synthetic principal (reproducible, not a live
sender). The task is small + verifiable + real; it is DELEGATED, so it names WHAT is needed, not who does it.
-->
---
from: jordan
subject: "need completeTask(id) in taskflow — stand up someone to own it"
priority: high
---
Hey — small but real one for the `taskflow` backend. We need a `completeTask(id)` function:

- it marks the task with that id as **done** and **returns the updated task**, and
- it **throws** if the id doesn't exist — no silent no-op.

Add it to the `taskflow` repo with a test that would catch a regression, and keep the suite green.

I don't want you touching the code yourself — **stand up someone to OWN `taskflow`** and drive it through.
Tell me how you split it, and confirm back when it's green.
