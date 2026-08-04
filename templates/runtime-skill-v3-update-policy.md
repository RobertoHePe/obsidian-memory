---
name: obsidian-memory
description: Use when reading, searching, updating, or handing off project memory stored in the repository's Obsidian vault.
version: 3
---

# Obsidian Memory

Use the bounded generated digest before opening detailed memory:

```bash
bash .obsidian-memory/scripts/memory.sh startup
bash .obsidian-memory/scripts/memory.sh status
```

Retrieve more only when needed:

```bash
bash .obsidian-memory/scripts/memory.sh list
bash .obsidian-memory/scripts/memory.sh search -- "literal term"
```

## Update policy

Update memory only when something durable changed that a future agent would otherwise need to rediscover. Do not write memory merely because files changed or a command ran.

| Durable change | Write target |
|---|---|
| Current goal, verified implementation state, active constraint, blocker, or risk changed | Update `state.md`; remove or correct stale statements. |
| Concrete next actions or priorities changed | Update `backlog.md`; complete or remove stale tasks instead of keeping a progress diary. |
| An accepted choice constrains future work | Append the choice and short rationale to `decisions.md`. |
| Stable architecture, runbook, or domain detail is too large for startup context | Write or update a focused note and add a short route in `index.md`. |
| Work reaches a meaningful handoff: session end, context switch, blocker, or completed milestone | Update the sources above, then create one compact session note with outcome, evidence, and next action. |

Do not store transcripts, large command output, exhaustive diffs, temporary hypotheses, secrets, or facts that are cheap to recover from code and version control. Never hand-edit a marked `start.md`.

After durable source edits when work is continuing without a handoff:

```bash
bash .obsidian-memory/scripts/memory.sh refresh
```

At a meaningful handoff, first update state/backlog/decisions, then run:

```bash
bash .obsidian-memory/scripts/memory.sh new-session
```

Fill the new session note's outcome, decisions, files/tests, next action, and links. If no durable information changed, do not update memory or create a session note.

Existing vault notes and old project scripts are preserved. Generated routes use standard Markdown links; existing and human-authored Obsidian wikilinks remain valid.
