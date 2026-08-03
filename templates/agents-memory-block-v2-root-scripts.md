<!-- obsidian-memory:start v2 -->
## Project memory

Run `bash scripts/memory.sh startup` before work; it prints only a valid bounded generated digest. Then run `bash scripts/memory.sh status` for the active vault path and a brief freshness signal. Run `bash scripts/memory.sh list`, or search with `bash scripts/memory.sh search -- "term"`, only when the task needs detail.

Edit `state.md` and `backlog.md` in the vault's `Agent Memory/` directory, not the generated digest. Record durable choices in its `decisions.md`. At a meaningful handoff, run `bash scripts/memory.sh new-session`; it creates a compact note, updates the session index, and refreshes the digest. Run `bash scripts/memory.sh refresh` after other source edits. Do not copy transcripts or full command output into memory.
<!-- obsidian-memory:end v2 -->
