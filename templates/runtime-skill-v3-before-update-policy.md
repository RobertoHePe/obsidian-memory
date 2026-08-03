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

Edit `state.md`, `backlog.md`, and `decisions.md` inside the active vault's `Agent Memory/` directory. Never hand-edit a marked `start.md`.

After source edits:

```bash
bash .obsidian-memory/scripts/memory.sh refresh
```

At a meaningful handoff:

```bash
bash .obsidian-memory/scripts/memory.sh new-session
```

Existing vault notes and old project scripts are preserved. Generated routes use standard Markdown links; existing and human-authored Obsidian wikilinks remain valid.
