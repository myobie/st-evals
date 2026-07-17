<!-- Hermetic kick: triggers the compose-global-skill check. Names NO token — the worker can only do the task by
     invoking the GLOBAL skill it discovered through the compose (the token lives only in that skill's body). -->
---
from: requester
subject: "compose-global-skill check"
---
Please run the **global-skill check** now, in your repo:

Use your **globalgreet** skill (it is a user/global-level skill available to you) and follow its instructions —
**write the global token to a file named `GLOBAL_SKILL.txt`** in your current working directory (the exact value
the skill gives you, nothing else).

Do not guess or invent the value — use only what the globalgreet skill tells you. If you do not have a globalgreet
skill available, reply saying so and write nothing. When `GLOBAL_SKILL.txt` is written, reply that the check is done.
