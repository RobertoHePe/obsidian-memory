---
name: obsidian-memory
description: Use when reading, searching, updating, or handing off project memory stored in the repository's Obsidian vault.
version: 4
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

## How to update memory

When the repository instructions trigger a memory update, use these targets:

| Information | Write target |
|---|---|
| Current goal, verified implementation state, active constraint, blocker, or risk | Update `state.md`; remove or correct stale statements. |
| Concrete next actions or priorities | Update `backlog.md`; complete or remove stale tasks instead of keeping a progress diary. |
| Accepted choice and rationale | Append a short entry to `decisions.md`. |
| Stable architecture, runbook, or domain detail too large for startup context | Write or update a focused note and add a short route in `index.md`. |

Never hand-edit a marked `start.md`; it is generated from the editable sources.

After durable source edits when work is continuing without a handoff:

```bash
bash .obsidian-memory/scripts/memory.sh refresh
```

At a meaningful handoff, first update state/backlog/decisions, then run:

```bash
bash .obsidian-memory/scripts/memory.sh new-session
```

Fill the new session note's outcome, decisions, files/tests, next action, and links.

Existing vault notes and old project scripts are preserved. Generated routes use standard Markdown links; existing and human-authored Obsidian wikilinks remain valid.
