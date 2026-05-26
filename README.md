# Obsidian Memory

Durable project memory for AI-assisted development. Stop losing context between sessions.

## What This Is

A lightweight, file-based memory system that uses an [Obsidian](https://obsidian.md)-compatible vault as the canonical record of project state. Unlike conversation context, which disappears when a session ends, the vault persists across sessions, tools, and AI assistants.

**The problem:** You finish a coding session with an AI assistant. Tomorrow you start a new chat and the assistant has no idea what you built yesterday.

**The solution:** A strict read/write protocol where every AI session starts by reading project state from files, and ends by writing what was done back to those same files.

**AGENTS.md is the canonical entry point.** OpenCode reads it automatically at every session start, so the vault protocol lives there. The agent never needs to be told to read AGENTS.md — it already happens.

## Session Start Triggers

If you are an AI assistant, this skill **must be considered active** at the start of every session when ANY of the following are true:

- The project has (or should have) an Obsidian vault
- The last session note is dated before today (new calendar day)
- Uncommitted git changes exist in the repository
- Files have been modified more recently than the latest session note
- You were given this README link to set up project memory

**Before doing any work, ALWAYS run change detection.**

## Quick Start

If you are an AI assistant reading this link, follow these steps to set up the vault in the target repository.

### Step 1 — Check if a vault already exists

Look for these files:
```
AGENTS.md
vault/00_Index.md
vault/12_Session_Rules.md
vault/13_Current_State.md
vault/14_Backlog.md
```

If they exist, skip to **Step 3**.

### Step 2 — Create the vault (if missing)

Create the following directory structure and files. Use the exact filenames shown.

**Directories:**
```
vault/
vault/sessions/
vault/daily/
vault/systems/
vault/references/
scripts/
```

**Files to create:**

`vault/00_Index.md`:
```markdown
# Index

This is the root index for the project Obsidian vault.

## Core Documents

- [[01_Project_Brief]] — What we are building and why.
- [[02_Architecture]] — Technical design and system overview.
- [[03_Roadmap]] — Phases and milestones.
- [[10_Open_Questions]] — Unresolved questions.
- [[11_Decisions_Log]] — Record of design and technical decisions.

## Session & AI Memory

- [[12_Session_Rules]] — Rules for every AI assistant session.
- [[13_Current_State]] — What is implemented right now.
- [[14_Backlog]] — Upcoming tasks organized by area.
- [[15_Testing_Checklist]] — Manual checks before declaring a feature done.
- [[16_Prompts]] — Reusable prompts for AI assistants.

## Directories

- `daily/` — Daily standup / journal notes.
- `sessions/` — Per-session notes from AI assistants.
- `systems/` — Deep dives into individual systems.
- `references/` — External links, articles, and inspiration.

#index #project-memory
```

`vault/12_Session_Rules.md`:
```markdown
# AI Assistant Session Rules

## The Vault Is Canonical Project Memory

Every session must read from and write to the vault. Do not rely on conversation context alone. The vault is the durable record of what has been built, decided, and planned.

## Session Start Routine

Before writing code, read:
1. `AGENTS.md` (already read automatically by OpenCode; contains behavioral guidelines + vault protocol)
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
```

`vault/13_Current_State.md`:
```markdown
# Current State

## Project Phase

Phase 0 — Initial setup and planning.

## Implemented Systems

- [x] Repository structure
- [x] Obsidian vault with session memory rules

## Missing Systems

List major systems not yet started.

## Known Issues

List blockers, bugs, or technical debt.

## Last Session Summary

**Session:** `vault/sessions/YYYYMMDD_HHMM_session.md`

Brief summary of what was done last time.

#state #current
```

`vault/14_Backlog.md`:
```markdown
# Backlog

## Setup
- [x] Create repo structure
- [x] Write documentation

## Feature Area A
- [ ] Task one
- [ ] Task two

## Feature Area B
- [ ] Task three

## Documentation
- [ ] Fill in open questions

#backlog #planning
```

`vault/11_Decisions_Log.md`:
```markdown
# Decisions Log

| Date | Decision | Reason | Impact |
|------|----------|--------|--------|
| YYYY-MM-DD | Example decision | Why it was made | What it affects |

#decisions #log
```

### Step 3 — Create helper scripts

Create `scripts/new_session.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SESSIONS_DIR="${REPO_ROOT}/vault/sessions"

TIMESTAMP=$(date +"%Y%m%d_%H%M")
SESSION_FILE="${SESSIONS_DIR}/${TIMESTAMP}_session.md"

echo "=== New Session Note ==="
mkdir -p "${SESSIONS_DIR}"

cat > "${SESSION_FILE}" << 'EOF'
# Session: YYYY-MM-DD HH:MM

## Context Read
- [ ] CODEX.md
- [ ] vault/00_Index.md
- [ ] vault/12_Session_Rules.md
- [ ] vault/13_Current_State.md
- [ ] vault/14_Backlog.md
- [ ] Previous session note (if applicable)

## Goals
1.
2.
3.

## Work Completed
- [ ]

## Decisions
| Decision | Reason | Impact |
|----------|--------|--------|
| | | |

## Files Changed
- `path/to/file`

## Tests / Checks Run
- [ ] `bash scripts/check_repo.sh`

## Current State Update
- Phase:
- Systems:
- Blockers:

## Backlog Changes
- Added:
- Completed:
- Removed:

## Next Recommended Task
1.

## Notes for Next Session
-

#session
EOF

echo "Created: ${SESSION_FILE}"

# Update index
bash "${SCRIPT_DIR}/update_session_index.sh"

echo ""
echo "Next:"
echo "  1) Edit the session note with your goals and findings."
echo "  2) Update vault/13_Current_State.md and vault/14_Backlog.md."
```

Create `scripts/update_session_index.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SESSIONS_DIR="${REPO_ROOT}/vault/sessions"
INDEX_FILE="${SESSIONS_DIR}/README.md"

echo "=== Updating Session Index ==="

mkdir -p "${SESSIONS_DIR}"

cat > "${INDEX_FILE}" << 'EOF'
# Session Notes Index

All AI assistant sessions are recorded here. Sessions are listed in chronological order.

EOF

shopt -s nullglob
files=("${SESSIONS_DIR}"/*.md)
if [[ ${#files[@]} -gt 0 ]]; then
    mapfile -t sorted < <(printf '%s\n' "${files[@]}" | sort)
    for f in "${sorted[@]}"; do
        name=$(basename "$f")
        if [[ "$name" == "README.md" ]]; then
            continue
        fi
        echo "- [${name}](./${name})" >> "${INDEX_FILE}"
    done
else
    echo "- No sessions yet." >> "${INDEX_FILE}"
fi

echo "Updated: ${INDEX_FILE}"
```

Make them executable:
```bash
chmod +x scripts/*.sh
```

Run the index generator once:
```bash
bash scripts/update_session_index.sh
```

### Step 4 — Ensure AGENTS.md exists

AGENTS.md is the canonical entry point. OpenCode reads it automatically at every session start. It must contain behavioral guidelines and the vault session protocol.

Create `AGENTS.md` if it does not exist:

```markdown
# Global Instructions

Behavioral guidelines and vault session protocol for all AI assistant sessions.

## Repository Session Protocol

Before doing any work, follow the repository session protocol.

**Step 0 — Change Detection (mandatory):**

Run `bash scripts/detect_changes.sh` (or check manually):
1. Find the latest session note filename (sort `vault/sessions/*.md`)
2. Extract the date (`YYYYMMDD` from the first 8 characters)
3. If the date is **not today's date** → **Date gap detected**. Force full vault re-read.
4. Check for files modified since the latest session note:
   ```bash
   find . -type f -newer vault/sessions/LATEST_NOTE.md ! -path '*/.git/*' ! -path '*/vault/sessions/*'
   ```
5. Check `git status --porcelain` for uncommitted changes.

If **any** check reveals changes, perform a full vault re-read before trusting any conversation context.

**Read:**
- AGENTS.md (this file)
- vault/00_Index.md
- vault/12_Session_Rules.md
- vault/13_Current_State.md
- vault/14_Backlog.md
- latest note in vault/sessions/

**Then summarize:**
1. Current project state.
2. Relevant backlog items.
3. Files likely to be touched.
4. Risks or unclear assumptions.

**After the work, update:**
- vault/13_Current_State.md
- vault/14_Backlog.md
- vault/11_Decisions_Log.md if decisions were made
- a new session note in vault/sessions/

**Also run:**
- `bash scripts/update_session_index.sh`

**Environment constraints:**
- Do not overwrite user work. Inspect files first; append or update carefully.
- Keep tools, caches, and local installs inside the project folder when practical.
```

Optional: create `CODEX.md` as a human-readable companion with lighter operational instructions. The canonical protocol lives in `AGENTS.md`.

### Step 5 — Verify

Run:
```bash
ls vault/
ls vault/sessions/
ls scripts/
```

You should see all files created above. The vault is now ready.

## How It Works

### Every Session Start

**Step 0 — Change Detection (mandatory):**

Run `bash scripts/detect_changes.sh` (or check manually):
1. Find the latest session note filename (sort `vault/sessions/*.md`)
2. Extract the date (`YYYYMMDD` from the first 8 characters)
3. If the date is **not today's date** → **Date gap detected**. Force full vault re-read.
4. Check for files modified since the latest session note:
   ```bash
   find . -type f -newer vault/sessions/LATEST_NOTE.md ! -path '*/.git/*' ! -path '*/vault/sessions/*'
   ```
5. Check `git status --porcelain` for uncommitted changes.

If **any** check reveals changes, perform a full vault re-read. Do not trust conversation context.

**Step 1 — Read vault in strict order:**
1. `AGENTS.md` — already read automatically by OpenCode; contains behavioral guidelines + vault protocol
2. `vault/00_Index.md` — navigation hub
3. `vault/12_Session_Rules.md` — session protocol
4. `vault/13_Current_State.md` — what's implemented now
5. `vault/14_Backlog.md` — upcoming tasks
6. Latest `vault/sessions/YYYYMMDD_HHMM_session.md` — what happened last time

After reading, the AI summarizes:
- Current project state
- Relevant backlog items
- Files likely to be touched
- Risks or unclear assumptions

### Every Session End

The AI updates in strict order:
1. `vault/13_Current_State.md` — reflect what is now implemented
2. `vault/14_Backlog.md` — mark tasks done, add new ones
3. `vault/11_Decisions_Log.md` — record any decisions made (with date, reason, impact)
4. Create a new `vault/sessions/YYYYMMDD_HHMM_session.md` — goals, work completed, files changed, tests run, next recommended tasks
5. Run `scripts/update_session_index.sh` — rebuild the session index

## File Reference

| File | Purpose | Update Frequency |
|------|---------|------------------|
| `AGENTS.md` | Behavioral guidelines + vault protocol (canonical entry point, read automatically) | When rules change |
| `00_Index.md` | Navigation hub, wikilinks | Rarely |
| `11_Decisions_Log.md` | Dated decisions with reason + impact | When deciding |
| `12_Session_Rules.md` | AI behavior rules, read/write order | When protocol changes |
| `13_Current_State.md` | Implemented systems, known issues, blockers | Every session |
| `14_Backlog.md` | Tasks by area, checkbox progress | Every session |
| `sessions/YYYYMMDD_HHMM_session.md` | Goals, work, files changed, tests, next tasks | Every session |

## For Humans

### Opening in Obsidian

1. Install [Obsidian](https://obsidian.md)
2. Open the repository folder as a vault
3. The wiki-links (`[[File_Name]]`) become clickable navigation

### Why Obsidian?

- Markdown-native (no lock-in)
- Wiki-links for fast navigation
- Graph view to see connections
- Works offline
- Free for personal use

## Repository Structure

```
obsidian-memory/
  README.md                 # This file
  SKILL.md                  # Agent-facing skill reference
  init.sh                   # One-command vault scaffold
  templates/                # Starter files for new vaults
    00_Index.md
    11_Decisions_Log.md
    12_Session_Rules.md
    13_Current_State.md
    14_Backlog.md
    session-note.md
  scripts/                  # Automation helpers
    new_session.sh
    update_session_index.sh
    detect_changes.sh       # Detects date gaps and external changes
```

When applied to a project, the vault lives alongside the codebase:

```
my-project/
  AGENTS.md                 # Canonical entry point (read automatically by OpenCode)
  CODEX.md                  # Optional human-readable companion
  src/
  vault/
    00_Index.md
    11_Decisions_Log.md
    12_Session_Rules.md
    13_Current_State.md
    14_Backlog.md
    sessions/
  scripts/
    new_session.sh
    update_session_index.sh
    detect_changes.sh
```

## Companion Skills

For richer Obsidian vault interactions, install these skills from `https://github.com/kepano/obsidian-skills`:

| Skill | Purpose |
|-------|---------|
| `obsidian-markdown` | Obsidian Flavored Markdown with wikilinks, callouts, properties |
| `obsidian-bases` | Database-like views with filters, formulas, summaries |
| `json-canvas` | Visual canvases, mind maps, flowcharts |
| `obsidian-cli` | Vault interaction via CLI (read, create, search, manage) |
| `defuddle` | Extract clean markdown from web pages |

**Installation:**
- **Claude Code:** Clone into `/.claude/skills/`
- **OpenCode:** `git clone https://github.com/kepano/obsidian-skills.git ~/.opencode/skills/obsidian-skills`
- **Codex CLI:** Copy `skills/` into `~/.codex/skills/`

## License

MIT — use it, fork it, adapt it.
