# AI Assistant Session Rules

This document is the canonical reference for how AI assistants must behave when working on this project.

## The Vault Is Canonical Project Memory

Every session must read from and write to the vault. Do not rely on conversation context alone. The vault is the durable record of what has been built, decided, and planned.

**AGENTS.md is the canonical entry point.** OpenCode reads it automatically at every session start. It contains behavioral guidelines and the vault session protocol.

## Session Start Routine

Before writing code, read:
1. `AGENTS.md` (already read automatically; contains behavioral guidelines + vault protocol)
2. `vault/00_Index.md`
3. `vault/12_Session_Rules.md`
4. `vault/13_Current_State.md`
5. `vault/14_Backlog.md`
6. Latest file in `vault/sessions/`

## Session End Routine

Before ending the session, update:
1. `vault/13_Current_State.md`
2. `vault/14_Backlog.md`
3. `vault/11_Decisions_Log.md` — if any decisions were made
4. Create a new session note in `vault/sessions/`
5. Run `scripts/update_session_index.sh`

## Preferred Task Style

- Small changes.
- Inspect first.
- Document decisions.
- Update the vault.
- Commit-ready diffs.

## Communication

- Use relative links in Markdown.
- Use Obsidian-friendly `[[WikiLinks]]` where helpful.
- Tag notes with relevant tags (e.g., `#design`, `#technical`).

#codex #rules
