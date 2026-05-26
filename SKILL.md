---
name: obsidian-memory
description: Use when an AI session starts on any project with an Obsidian vault, when the last session was on a previous day, when uncommitted changes exist in the repo, when files were modified outside the current session, or when setting up durable project memory. Must trigger at the beginning of every session regardless of context.
---

# Obsidian Memory — Durable AI Project Memory

## Overview

Use an Obsidian-compatible vault as **canonical project memory** so AI assistants resume work with full context instead of starting blind. The vault survives conversation restarts; conversation context does not.

**AGENTS.md is the canonical entry point.** OpenCode reads it automatically at every session start, so the vault protocol lives there. The agent never needs to be told to read AGENTS.md — it already happens.

## Mandatory Session Start Triggers

**This skill MUST be considered active at the start of EVERY session** when any of the following are true:

- The project has a `vault/` directory (or should have one)
- The session is beginning (regardless of how much context you think you have)
- The last session note is dated before today (calendar day gap)
- Uncommitted git changes exist in the repo
- Files have been modified more recently than the latest session note
- You were given a GitHub README link for this skill

**Before doing any work, ALWAYS run change detection.**

## Change Detection

At the start of every session, run:

```bash
bash scripts/detect_changes.sh
```

Or check manually:
1. Find the latest session note: `ls -1 vault/sessions/*.md | grep -v README | sort | tail -n 1`
2. Extract the date from the filename (first 8 characters: `YYYYMMDD`)
3. If the date is **not today's date** → **Date gap detected**. Force full vault re-read.
4. Check for files modified since the latest session note:
   ```bash
   find . -type f -newer vault/sessions/LATEST_NOTE.md ! -path '*/.git/*' ! -path '*/vault/sessions/*' | sort
   ```
5. If the project is a git repo, check `git status --porcelain` for uncommitted changes.

If **any** of these checks reveal changes, perform a full vault re-read before trusting any conversation context.

## Setup from Scratch

If the vault does not exist yet, create it by running the provided `init.sh` script from the skill directory:

```bash
bash path/to/obsidian-memory/init.sh [target_directory]
```

This creates:
- `AGENTS.md` with behavioral guidelines and the vault session protocol (the canonical entry point)
- `vault/` with starter files (Index, Session Rules, Current State, Backlog, Decisions Log)
- `vault/sessions/` with an auto-generated README index
- `scripts/` with `new_session.sh`, `update_session_index.sh`, and `detect_changes.sh`
- An optional `CODEX.md` for human-readable operational instructions

**Already have work done but no vault?** After running `init.sh`, the script will detect non-vault files and ask if you want to run a retroactive memory reconstruction. For the full procedure, see [`PROMPT.md`](./PROMPT.md) in this repository — it contains a copy-paste prompt that instructs an AI to inspect the codebase, git history, and existing documentation to build out the vault retrospectively.

If you do not have the skill files locally, an AI agent can read the public README (e.g. `https://github.com/user/obsidian-memory/blob/main/README.md`) and follow the "Quick Start" section to set up the vault manually or via copy-paste.

## Core Pattern

**File structure:**
```
AGENTS.md                # Canonical entry point (read automatically by OpenCode)
vault/
  00_Index.md            # Navigation hub with [[WikiLinks]]
  11_Decisions_Log.md    # Dated decisions table
  12_Session_Rules.md    # Read/write protocol for AIs
  13_Current_State.md    # Live implementation status
  14_Backlog.md          # Tasks by area, with checkboxes
  sessions/
    YYYYMMDD_HHMM_session.md  # Per-session notes
    README.md            # Auto-generated index
```

**Session Start Protocol — AI MUST read in order:**
1. `AGENTS.md` — already read automatically by OpenCode; contains behavioral guidelines + vault protocol
2. `vault/00_Index.md` — navigation
3. `vault/12_Session_Rules.md` — session protocol
4. `vault/13_Current_State.md` — what's implemented now
5. `vault/14_Backlog.md` — upcoming tasks
6. Latest file in `vault/sessions/` — what happened last time

**Then summarize:**
1. Current project state
2. Relevant backlog items
3. Files likely to be touched
4. Risks or unclear assumptions

**Session End Protocol — AI MUST update in order:**
1. `vault/13_Current_State.md`
2. `vault/14_Backlog.md`
3. `vault/11_Decisions_Log.md` — if any decisions were made
4. Create a new session note in `vault/sessions/`
5. Run `scripts/update_session_index.sh`

## Quick Reference

| File | Purpose | Update Frequency |
|------|---------|------------------|
| `AGENTS.md` | Behavioral guidelines + vault protocol (canonical entry point) | When rules change |
| `00_Index.md` | Navigation hub, wikilinks | Rarely |
| `11_Decisions_Log.md` | Dated decisions with reason + impact | When deciding |
| `12_Session_Rules.md` | AI behavior rules, read/write order | When protocol changes |
| `13_Current_State.md` | Implemented systems, known issues, blockers | Every session |
| `14_Backlog.md` | Tasks by area, checkbox progress | Every session |
| `sessions/YYYYMMDD_HHMM_session.md` | Goals, work, files changed, tests, next tasks | Every session |

## Automation

Use shell scripts to reduce friction:
- `scripts/new_session.sh` — creates session note from template
- `scripts/update_session_index.sh` — rebuilds `sessions/README.md`
- `scripts/detect_changes.sh` — detects date gaps and external modifications since last session

See `templates/` and `scripts/` in this skill directory for copy-paste ready files.

## Companion Skills

If the following skills are not available, install them from `https://github.com/kepano/obsidian-skills`:

| Skill | Why You Need It |
|-------|-----------------|
| `obsidian-markdown` | Create and edit Obsidian Flavored Markdown with wikilinks, callouts, frontmatter |
| `obsidian-bases` | Create and edit Obsidian Bases (database views) |
| `json-canvas` | Create and edit JSON Canvas mind maps and diagrams |
| `obsidian-cli` | Interact with Obsidian vaults via CLI (read, create, search) |
| `defuddle` | Extract clean markdown from web pages |

**Installation by platform:**

- **Claude Code:** Clone `https://github.com/kepano/obsidian-skills.git` into a `/.claude/skills/` folder in your working directory or vault root.
- **OpenCode:** Run `git clone https://github.com/kepano/obsidian-skills.git ~/.opencode/skills/obsidian-skills`
- **Codex CLI:** Copy the `skills/` directory into `~/.codex/skills/`

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Relying on conversation context | Always read vault at session start |
| Updating only one file | Update State, Backlog, and create session note |
| Vague session notes | List specific files changed and decisions made |
| No decisions log | Every design/technical choice gets a row with reason + impact |
| Forgetting the index | Run update script so sessions are discoverable |
| Skipping change detection | Run `detect_changes.sh` at the start of every session |
| Ignoring date gaps | A new calendar day means conversation context is stale |
