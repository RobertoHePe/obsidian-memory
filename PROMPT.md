# Retroactive Vault Bootstrap Prompt

> **Companion file to the `obsidian-memory` skill.** Referenced from `SKILL.md` in the "Setup from Scratch" section. Use this when you have an existing project with substantial work done, but no (or an incomplete) Obsidian memory vault.
>
> The AI will examine the codebase, git history, and any existing documentation to construct or update a durable project memory vault retrospectively.

Use this prompt when you have an existing project with substantial work done, but no (or an incomplete) Obsidian memory vault. The AI will examine the codebase, git history, and any existing documentation to construct or update a durable project memory vault.

---

## PROMPT — Copy and paste this into your AI assistant

```
You are bootstrapping (or updating) an Obsidian memory vault for a project that already has significant work completed. Do not write new code. Your job is to inspect the existing codebase, git history, and any documentation, then create or update the vault files so future AI sessions can resume with full context.

## Step 1 — Inspect the Project

Run these commands and analyze the output:

1. Check if a vault already exists:
   ls -la vault/ 2>/dev/null || echo "No vault directory found"
   ls -la AGENTS.md 2>/dev/null || echo "No AGENTS.md found"

2. Understand the codebase structure:
   find . -type f ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/__pycache__/*' ! -path '*/.venv/*' ! -path '*/dist/*' ! -path '*/build/*' | sort | head -100

3. Read key config files (if they exist):
   - README.md
   - package.json, pyproject.toml, Cargo.toml, go.mod, etc.
   - Any existing docs/ folder

4. Analyze git history for context:
   git log --oneline -30
   git log --format="%h %s" --all -- *.md *.json *.toml *.yaml *.yml | head -30
   git branch -a

5. Check for uncommitted changes:
   git status --short

6. Look for any existing session notes or decision logs:
   find . -type f -name "*session*" -o -name "*decision*" -o -name "*log*" | grep -v .git

## Step 2 — Infer Project State from Evidence

Based on your inspection, deduce:

- **Project name and purpose** — from README, package metadata, folder names
- **Tech stack** — languages, frameworks, build tools, dependencies
- **Architecture** — how the project is organized (frontend, backend, services, modules)
- **Current phase** — early prototype, MVP, production, maintenance?
- **Implemented systems** — what major features/components exist and work
- **Missing systems** — what is clearly planned but not started
- **Known issues / blockers** — TODO comments, failing tests, incomplete features
- **Key decisions** — tech choices visible in dependencies, folder structure, config

## Step 3 — Create / Update the Vault

If the vault does not exist, create the directory structure and all files below.
If it exists, update the files to reflect reality — do not overwrite with blank templates.

### Directory structure to ensure exists:
```
vault/
  sessions/
  daily/
  systems/
  references/
scripts/
```

### Files to create / update:

#### AGENTS.md (project root)
Create if missing. Include:
- Project name and one-line description
- Behavioral guidelines (read vault first, update vault last)
- The standard session protocol (read AGENTS.md → vault/00_Index.md → 12_Session_Rules.md → 13_Current_State.md → 14_Backlog.md → latest session note)
- Change detection: run `bash scripts/detect_changes.sh` at every session start
- Environment constraints (no overwriting user work, keep tools local)

#### vault/00_Index.md
Navigation hub with [[WikiLinks]] to:
- [[01_Project_Brief]] — inferred from README/code
- [[02_Architecture]] — inferred from folder structure
- [[03_Roadmap]] — inferred from git history + unfinished features
- [[10_Open_Questions]] — anything unclear from inspection
- [[11_Decisions_Log]] — key technical choices
- [[12_Session_Rules]] — AI behavior rules
- [[13_Current_State]] — live implementation status
- [[14_Backlog]] — upcoming tasks
- [[15_Testing_Checklist]] — manual checks for this project
- [[16_Prompts]] — reusable prompts

Also list the directory structure: `daily/`, `sessions/`, `systems/`, `references/`.

#### vault/12_Session_Rules.md
Standard rules adapted to this project. Include project-specific quirks if any (e.g., "Always run `npm run lint` before committing", "Database migrations live in /migrations").

#### vault/13_Current_State.md
Write a comprehensive, evidence-based summary:
- **Project Phase:** inferred from codebase maturity
- **Implemented Systems:** list with checkboxes, based on actual files and working code
- **Missing Systems:** based on TODOs, stub files, unimplemented routes, placeholder UI
- **Known Issues:** compile errors, failing tests, security concerns, tech debt
- **Last Session Summary:** if no session notes exist, write: "No prior AI sessions recorded. Vault bootstrapped on YYYY-MM-DD from codebase inspection."

#### vault/14_Backlog.md
Organize tasks by area (Setup, Feature Area A, Feature Area B, Infrastructure, Documentation). Base this on:
- Unfinished features visible in code
- TODO/FIXME comments in the codebase
- Missing tests, docs, or deployment configs
- Inferred next steps from the current state

Use checkboxes. Mark items that are already done.

#### vault/11_Decisions_Log.md
Create a table with Date | Decision | Reason | Impact.
Infer decisions from:
- Framework/library choices (React vs Vue, FastAPI vs Flask, etc.)
- Folder structure conventions
- Build tool choices (Vite, Webpack, Poetry, etc.)
- Database choices
- Any `.cursorrules`, `.ai-guidelines`, or similar files

If you cannot infer a date, use the date of the earliest related commit or the repo creation date.

#### vault/sessions/YYYYMMDD_HHMM_bootstrap.md
Create ONE retroactive session note summarizing everything you discovered. Use this template:

```markdown
# Session: YYYY-MM-DD HH:MM — Vault Bootstrap

## Context Read
- [x] README.md
- [x] package.json / pyproject.toml / equivalent
- [x] Git history (last 30 commits)
- [x] Codebase structure
- [x] Existing documentation

## Goals
1. Inspect the existing codebase and understand what has been built.
2. Infer project architecture, decisions, and current state.
3. Create or update the Obsidian memory vault with accurate, evidence-based records.

## Work Completed
- [x] Analyzed codebase structure and tech stack
- [x] Reviewed git history for context and decisions
- [x] Created/updated AGENTS.md
- [x] Created/updated vault/00_Index.md
- [x] Created/updated vault/12_Session_Rules.md
- [x] Created/updated vault/13_Current_State.md
- [x] Created/updated vault/14_Backlog.md
- [x] Created/updated vault/11_Decisions_Log.md
- [x] Created this bootstrap session note
- [x] Ran scripts/update_session_index.sh

## Decisions
| Decision | Reason | Impact |
|----------|--------|--------|
| (list any decisions made during bootstrap) | | |

## Files Changed
- AGENTS.md
- vault/00_Index.md
- vault/12_Session_Rules.md
- vault/13_Current_State.md
- vault/14_Backlog.md
- vault/11_Decisions_Log.md
- vault/sessions/YYYYMMDD_HHMM_bootstrap.md

## Tests / Checks Run
- [x] Verified vault file structure
- [x] Verified all links and wikilinks are consistent
- [x] Checked git status for unexpected changes

## Current State Update
- Phase: (inferred phase)
- Systems: (summary of what's working)
- Blockers: (none / list)

## Backlog Changes
- Added: (list tasks added based on inspection)
- Completed: (list tasks already done in the codebase)
- Removed: (none)

## Next Recommended Task
1. (first concrete task for the next AI session)
2. (second concrete task)

## Notes for Next Session
- The vault is now the canonical source of truth.
- Always run `bash scripts/detect_changes.sh` at session start.
- Do not trust conversation context alone.

#session #bootstrap
```

### Scripts to ensure exist

If `scripts/` does not exist or is missing files, create them:

**scripts/new_session.sh** — creates a new session note from template.
**scripts/update_session_index.sh** — rebuilds `vault/sessions/README.md`.
**scripts/detect_changes.sh** — detects date gaps and external modifications.

Use the canonical versions from the obsidian-memory skill (or reconstruct them if unavailable).

## Step 4 — Validation

After creating/updating all files, run:
1. `bash scripts/update_session_index.sh`
2. Verify `vault/sessions/README.md` lists the bootstrap session.
3. Scan all vault files for broken `[[WikiLinks]]` or inconsistent formatting.
4. Run any project-specific validation (lint, typecheck, tests) to ensure you did not break anything.

## Step 5 — Final Summary

Report back to the user:
- What phase the project appears to be in
- The most important things already implemented
- The highest-priority backlog items inferred from the code
- Any assumptions you had to make due to missing information
- A reminder that the vault is now live and future sessions should follow the read/write protocol
```

---

## How to Use This Prompt

1. **Copy the entire code block above** (the text between the triple backticks after `## PROMPT`).
2. **Paste it into your AI assistant** (Claude, OpenCode, ChatGPT, etc.).
3. **Ensure the AI has access to the project directory** so it can run the inspection commands.
4. **Review the generated vault files** before trusting them — the AI may make incorrect assumptions.
5. **Iterate** — if the AI misses something, tell it to re-inspect specific files or commits.

---

## Post-Bootstrap Checklist for the Human

After the AI completes the bootstrap:

- [ ] Review `vault/13_Current_State.md` for accuracy
- [ ] Review `vault/14_Backlog.md` — remove anything already done, add anything missing
- [ ] Review `vault/11_Decisions_Log.md` — fill in dates/reasons you remember
- [ ] Review `AGENTS.md` — add project-specific behavioral rules
- [ ] Commit the vault: `git add vault/ AGENTS.md scripts/ && git commit -m "Bootstrap Obsidian memory vault"`
- [ ] Open the project folder in [Obsidian](https://obsidian.md) to browse the wiki-linked vault

The vault is now ready. Every future AI session should read it first and update it last.
