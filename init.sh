#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "${TARGET_DIR}" && pwd)"

echo "=== Obsidian Memory Vault Setup ==="
echo "Target: ${TARGET_DIR}"
echo ""

# Create directories
mkdir -p "${TARGET_DIR}/vault/sessions"
mkdir -p "${TARGET_DIR}/vault/daily"
mkdir -p "${TARGET_DIR}/vault/systems"
mkdir -p "${TARGET_DIR}/vault/references"
mkdir -p "${TARGET_DIR}/scripts"

echo "Directories created."

# Copy templates
cp "${TEMPLATES_DIR}/00_Index.md" "${TARGET_DIR}/vault/00_Index.md"
cp "${TEMPLATES_DIR}/11_Decisions_Log.md" "${TARGET_DIR}/vault/11_Decisions_Log.md"
cp "${TEMPLATES_DIR}/12_Session_Rules.md" "${TARGET_DIR}/vault/12_Session_Rules.md"
cp "${TEMPLATES_DIR}/13_Current_State.md" "${TARGET_DIR}/vault/13_Current_State.md"
cp "${TEMPLATES_DIR}/14_Backlog.md" "${TARGET_DIR}/vault/14_Backlog.md"

echo "Vault files copied."

# Copy scripts
cp "${SCRIPTS_DIR}/new_session.sh" "${TARGET_DIR}/scripts/new_session.sh"
cp "${SCRIPTS_DIR}/update_session_index.sh" "${TARGET_DIR}/scripts/update_session_index.sh"
cp "${SCRIPTS_DIR}/detect_changes.sh" "${TARGET_DIR}/scripts/detect_changes.sh"
chmod +x "${TARGET_DIR}/scripts/"*.sh

echo "Scripts copied."

# Create initial session index
bash "${TARGET_DIR}/scripts/update_session_index.sh"

# Create AGENTS.md if not exists
if [[ ! -f "${TARGET_DIR}/AGENTS.md" ]]; then
    cat > "${TARGET_DIR}/AGENTS.md" << 'EOF'
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
EOF
    echo "Created: ${TARGET_DIR}/AGENTS.md"
else
    echo "AGENTS.md already exists — skipping."
fi

# Create optional CODEX.md for human-readable companion
if [[ ! -f "${TARGET_DIR}/CODEX.md" && ! -f "${TARGET_DIR}/AGENTS.md" ]]; then
    cat > "${TARGET_DIR}/CODEX.md" << 'EOF'
# AI Assistant Operational Instructions (CODEX.md)

Human-readable companion to AGENTS.md. The canonical protocol lives in AGENTS.md, which OpenCode reads automatically.

## Session Start Checklist

At the start of every session:
1. AGENTS.md is read automatically by OpenCode
2. Read `vault/00_Index.md`
3. Read `vault/12_Session_Rules.md`
4. Read `vault/13_Current_State.md`
5. Read `vault/14_Backlog.md`
6. Read the latest file in `vault/sessions/`, if any

## Session End Checklist

At the end of every session, update in order:
1. `vault/13_Current_State.md`
2. `vault/14_Backlog.md`
3. `vault/11_Decisions_Log.md` — if any decisions were made
4. Create a new session note in `vault/sessions/`
5. Run `scripts/update_session_index.sh`
EOF
    echo "Created: ${TARGET_DIR}/CODEX.md"
fi

echo ""
echo "=== Basic Setup Complete ==="
echo ""

# --- Retroactive Memory Reconstruction Prompt ---

# Detect if there are pre-existing project files outside the vault
EXISTING_FILES=$(find "${TARGET_DIR}" -type f \
  ! -path '*/.git/*' \
  ! -path '*/vault/*' \
  ! -path '*/scripts/*' \
  ! -name 'AGENTS.md' \
  ! -name 'CODEX.md' \
  | head -n 1)

if [[ -n "${EXISTING_FILES}" ]]; then
    echo "⚠️  Detected existing project files outside the vault."
    echo ""
    echo "This project already has work done, but the vault is empty."
    echo "You can run a retroactive memory reconstruction to have an AI inspect"
    echo "the codebase, git history, and existing docs to build out the vault."
    echo ""
    read -r -p "Run retroactive memory reconstruction now? [y/N] " REPLY
    echo ""

    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
        echo "=== Retroactive Memory Reconstruction ==="
        echo ""
        echo "Proceeding with retroactive memory reconstruction."
        echo ""

        AGENT_INSTRUCTION_FILE="${SCRIPT_DIR}/BUILD_RETROACTIVE_MEMORY.md"

        if [[ -f "${AGENT_INSTRUCTION_FILE}" ]]; then
            echo "AGENT INSTRUCTION — READ AND EXECUTE:"
            echo "  ${AGENT_INSTRUCTION_FILE}"
            echo ""
            echo "The AI agent should now automatically inspect the codebase,"
            echo "git history, and existing docs, then populate the vault."
            echo ""
            echo "If you are not running inside an AI assistant session, open"
            echo "the file above and paste its contents into your AI tool."
        else
            echo "BUILD_RETROACTIVE_MEMORY.md not found in ${SCRIPT_DIR}."
            echo "Please download it from the obsidian-memory repository:"
            echo "  https://github.com/RobertoHePe/obsidian-memory/blob/main/BUILD_RETROACTIVE_MEMORY.md"
        fi
        echo ""
        echo "After reconstruction finishes, review the vault files and commit:"
        echo "  git add vault/ AGENTS.md scripts/ && git commit -m 'Bootstrap Obsidian memory vault'"
        echo ""
    else
        echo "Skipping retroactive reconstruction."
        echo ""
        echo "Next steps:"
        echo "  1) Edit ${TARGET_DIR}/AGENTS.md with project-specific behavioral guidelines."
        echo "  2) Edit vault files to match your project."
        echo "  3) Run: bash scripts/new_session.sh"
        echo ""
        echo "If you change your mind, the full retroactive reconstruction protocol is in:"
        echo "  ${SCRIPT_DIR}/BUILD_RETROACTIVE_MEMORY.md"
        echo ""
    fi
else
    echo "Next steps:"
    echo "  1) Edit ${TARGET_DIR}/AGENTS.md with project-specific behavioral guidelines."
    echo "  2) Edit vault files to match your project."
    echo "  3) Run: bash scripts/new_session.sh"
    echo ""
fi

echo "Every session, the AI MUST:"
echo "  1) Run: bash scripts/detect_changes.sh"
echo "  2) Read AGENTS.md (automatic) + vault/12_Session_Rules.md"
echo "  3) Read vault/13_Current_State.md + vault/14_Backlog.md"
echo "  4) Read the latest session note"
echo "  5) Update vault files and create a new session note before ending"
