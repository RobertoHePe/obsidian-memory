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
