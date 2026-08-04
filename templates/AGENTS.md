# Project Agent Instructions

<!-- obsidian-memory:start v2 -->
## Project memory

At the start of each agent session, from the repository root:

1. Read `.obsidian-memory/SKILL.md`; it is the authoritative memory procedure.
2. Run `bash .obsidian-memory/scripts/memory.sh startup`.
3. Retrieve additional memory only when the current task requires it, following the skill's progressive-disclosure workflow.

Update durable project memory during work whenever any of these changes:

- the current goal, verified implementation state, active constraint, blocker, or risk;
- concrete next actions or priorities;
- an accepted decision that constrains future work;
- stable architecture, runbook, or domain knowledge that a future agent would otherwise need to rediscover.

Before a meaningful handoff—session end, context switch, blocker, or completed milestone—update the relevant memory and create a compact handoff using the skill's procedure. If no durable information changed, do not write memory merely because files changed or commands ran.

Treat the active Obsidian vault as canonical durable memory. Never hand-edit the generated `start.md`, preload the complete vault, or copy transcripts, secrets, or large command outputs into memory. Use `.obsidian-memory/SKILL.md` for where and how to write, refresh, search, and create handoffs.

If the skill, helper, or validated startup digest is missing or refused, report the problem instead of bypassing the memory safeguards.
<!-- obsidian-memory:end v2 -->
