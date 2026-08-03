# Project Agent Instructions

<!-- obsidian-memory:start v2 -->
## Project memory

Read `.obsidian-memory/SKILL.md`, then run `bash .obsidian-memory/scripts/memory.sh startup` before work; it prints only a valid bounded generated digest. Run `bash .obsidian-memory/scripts/memory.sh status` for the active vault path and a brief freshness signal. Run `bash .obsidian-memory/scripts/memory.sh list`, or search with `bash .obsidian-memory/scripts/memory.sh search -- "term"`, only when the task needs detail.

Edit `state.md` and `backlog.md` in the vault's `Agent Memory/` directory, not the generated digest. Record durable choices in its `decisions.md`. At a meaningful handoff, run `bash .obsidian-memory/scripts/memory.sh new-session`; it creates a compact note, updates the session index, and refreshes the digest. Run `bash .obsidian-memory/scripts/memory.sh refresh` after other source edits. Do not copy transcripts or full command output into memory.
<!-- obsidian-memory:end v2 -->
