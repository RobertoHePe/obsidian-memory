<!-- obsidian-memory:start v2 -->
## Project memory

At the start of each agent session, from the repository root:

1. Read `.obsidian-memory/SKILL.md`; it is the authoritative memory procedure.
2. Run `bash .obsidian-memory/scripts/memory.sh startup`.
3. Retrieve additional memory only when the current task requires it, following the skill's progressive-disclosure workflow.

Treat the active Obsidian vault as canonical durable memory. Never hand-edit the generated `start.md`, preload the complete vault, or copy transcripts and large command outputs into memory. Before a meaningful handoff, update the editable memory sources and follow the skill's handoff procedure.

If the skill, helper, or validated startup digest is missing or refused, report the problem instead of bypassing the memory safeguards.
<!-- obsidian-memory:end v2 -->
