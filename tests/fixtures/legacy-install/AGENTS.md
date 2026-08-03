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
