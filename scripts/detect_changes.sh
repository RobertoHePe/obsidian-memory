#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"
REPO_ROOT="$(cd "${TARGET_DIR}" && pwd)"
SESSIONS_DIR="${REPO_ROOT}/vault/sessions"

TODAY=$(date +"%Y%m%d")
CHANGED_FILES=0
DATE_GAP=0
GIT_CHANGES=0

echo "=== Obsidian Memory Change Detection ==="
echo ""

# Check for AGENTS.md
if [[ ! -f "${REPO_ROOT}/AGENTS.md" ]]; then
    echo "WARNING: AGENTS.md not found in ${REPO_ROOT}"
    echo "This is the canonical entry point. Create it with behavioral guidelines + vault protocol."
    echo ""
fi

# Find latest session note
LATEST_SESSION=""
if [[ -d "${SESSIONS_DIR}" ]]; then
    LATEST_SESSION=$(find "${SESSIONS_DIR}" -maxdepth 1 -name '*.md' ! -name 'README.md' -printf '%f\n' 2>/dev/null | sort | tail -n 1 || true)
fi

if [[ -z "${LATEST_SESSION}" ]]; then
    echo "WARNING: No session notes found in ${SESSIONS_DIR}"
    echo "This appears to be a fresh vault or sessions were never created."
    echo ""
    echo "ACTION: Perform a full vault read and create the first session note."
    exit 1
fi

# Extract date from session filename (YYYYMMDD_HHMM_session.md)
SESSION_DATE="${LATEST_SESSION:0:8}"
echo "Latest session note: ${LATEST_SESSION}"
echo "Session date: ${SESSION_DATE}"
echo "Today: ${TODAY}"
echo ""

# Check date gap
if [[ "${SESSION_DATE}" != "${TODAY}" ]]; then
    DATE_GAP=1
    echo "DETECTED: Date gap. Last session was on ${SESSION_DATE}, today is ${TODAY}."
    echo "ACTION: Force full vault re-read. Do not rely on conversation context."
    echo ""
fi

# Find files modified since the latest session note
if [[ -f "${SESSIONS_DIR}/${LATEST_SESSION}" ]]; then
    echo "Checking for files modified since last session..."
    MODIFIED_FILES=$(find "${REPO_ROOT}" -type f -newer "${SESSIONS_DIR}/${LATEST_SESSION}" \
        ! -path "*/.git/*" \
        ! -path "*/vault/sessions/*" \
        ! -path "*/node_modules/*" \
        ! -path "*/.cache/*" \
        ! -path "*/.tmp/*" \
        2>/dev/null | sort || true)

    if [[ -n "${MODIFIED_FILES}" ]]; then
        CHANGED_FILES=1
        FILE_COUNT=$(echo "${MODIFIED_FILES}" | wc -l)
        echo "DETECTED: ${FILE_COUNT} file(s) modified since last session note."
        echo "Modified files:"
        echo "${MODIFIED_FILES}" | sed 's|^|  - |'
        echo ""
        echo "ACTION: Review these files before making new changes. They may contain unrecorded work."
        echo ""
    else
        echo "OK: No files modified since last session note."
        echo ""
    fi
fi

# Check git status for uncommitted changes
if [[ -d "${REPO_ROOT}/.git" ]]; then
    cd "${REPO_ROOT}"
    UNCOMMITTED=$(git status --porcelain 2>/dev/null || true)
    if [[ -n "${UNCOMMITTED}" ]]; then
        GIT_CHANGES=1
        echo "DETECTED: Uncommitted git changes."
        echo "${UNCOMMITTED}" | sed 's|^|  |'
        echo ""
        echo "ACTION: These changes may not be reflected in the vault. Review and update vault state if needed."
        echo ""
    else
        echo "OK: No uncommitted git changes."
        echo ""
    fi
fi

# Summary
if [[ ${DATE_GAP} -eq 0 && ${CHANGED_FILES} -eq 0 && ${GIT_CHANGES} -eq 0 ]]; then
    echo "=== Result: CLEAN ==="
    echo "No external changes detected since last session. Safe to continue."
    exit 0
else
    echo "=== Result: CHANGES DETECTED ==="
    [[ ${DATE_GAP} -eq 1 ]] && echo "  - Date gap (new day)"
    [[ ${CHANGED_FILES} -eq 1 ]] && echo "  - Files modified outside session"
    [[ ${GIT_CHANGES} -eq 1 ]] && echo "  - Uncommitted git changes"
    echo ""
    echo "MANDATORY: Perform full vault re-read before proceeding with any work."
    exit 2
fi
