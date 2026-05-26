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

# List session files in order
shopt -s nullglob
files=("${SESSIONS_DIR}"/*.md)
if [[ ${#files[@]} -gt 0 ]]; then
    mapfile -t sorted < <(printf '%s\n' "${files[@]}" | sort)
    for f in "${sorted[@]}"; do
        name=$(basename "$f")
        # Skip the index itself
        if [[ "$name" == "README.md" ]]; then
            continue
        fi
        echo "- [${name}](./${name})" >> "${INDEX_FILE}"
    done
else
    echo "- No sessions yet." >> "${INDEX_FILE}"
fi

echo "Updated: ${INDEX_FILE}"
