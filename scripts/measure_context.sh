#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

usage() {
    cat <<'EOF'
Usage: scripts/measure_context.sh LEGACY_INSTALL NEW_INSTALL

Compare the exact static files mandated at startup by the legacy and new
protocols. Reports bytes, lines, and whitespace-delimited words. These are
deterministic size proxies, not model-tokenizer counts.
EOF
}

[[ $# -eq 2 ]] || { usage >&2; exit 64; }
LEGACY_ROOT="$(cd "$1" && pwd -P)"
NEW_ROOT="$(cd "$2" && pwd -P)"

if [[ -d "${NEW_ROOT}/Memory/Agent Memory" && ! -L "${NEW_ROOT}/Memory/Agent Memory" ]]; then
    NEW_MEMORY="${NEW_ROOT}/Memory/Agent Memory"
elif [[ -d "${NEW_ROOT}/vault/Agent Memory" && ! -L "${NEW_ROOT}/vault/Agent Memory" ]]; then
    NEW_MEMORY="${NEW_ROOT}/vault/Agent Memory"
elif [[ -d "${NEW_ROOT}/memory" && ! -L "${NEW_ROOT}/memory" ]]; then
    NEW_MEMORY="${NEW_ROOT}/memory"
else
    echo "ERROR: no safe Agent Memory directory found in new install." >&2
    exit 1
fi

latest_legacy=$(find "${LEGACY_ROOT}/vault/sessions" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' -print 2>/dev/null \
    | sort \
    | tail -n 1)

[[ -n "${latest_legacy}" ]] || { echo "ERROR: no legacy session note found." >&2; exit 1; }

legacy_files=(
    "${LEGACY_ROOT}/AGENTS.md"
    "${LEGACY_ROOT}/vault/00_Index.md"
    "${LEGACY_ROOT}/vault/12_Session_Rules.md"
    "${LEGACY_ROOT}/vault/13_Current_State.md"
    "${LEGACY_ROOT}/vault/14_Backlog.md"
    "${latest_legacy}"
)
new_files=(
    "${NEW_ROOT}/AGENTS.md"
    "${NEW_MEMORY}/start.md"
)

for file in "${legacy_files[@]}" "${new_files[@]}"; do
    [[ -f "${file}" ]] || { echo "ERROR: required measurement input missing: ${file}" >&2; exit 1; }
done

sum_metric() {
    local metric=$1
    shift
    local total=0 value file
    for file in "$@"; do
        case "${metric}" in
            bytes) value=$(wc -c < "${file}") ;;
            lines) value=$(wc -l < "${file}") ;;
            words) value=$(wc -w < "${file}") ;;
        esac
        value=${value//[[:space:]]/}
        total=$((total + value))
    done
    printf '%s' "${total}"
}

legacy_bytes=$(sum_metric bytes "${legacy_files[@]}")
legacy_lines=$(sum_metric lines "${legacy_files[@]}")
legacy_words=$(sum_metric words "${legacy_files[@]}")
new_bytes=$(sum_metric bytes "${new_files[@]}")
new_lines=$(sum_metric lines "${new_files[@]}")
new_words=$(sum_metric words "${new_files[@]}")

percentage() {
    awk -v old="$1" -v new="$2" 'BEGIN { if (old == 0) print "n/a"; else printf "%.1f%%", ((old-new)/old)*100 }'
}

echo "Static startup context measurement (proxies; not tokenizer-exact)"
printf '%-28s %12s %12s %12s\n' "metric" "legacy" "new" "reduction"
printf '%-28s %12s %12s %12s\n' "bytes (exact)" "${legacy_bytes}" "${new_bytes}" "$(percentage "${legacy_bytes}" "${new_bytes}")"
printf '%-28s %12s %12s %12s\n' "lines (newline count)" "${legacy_lines}" "${new_lines}" "$(percentage "${legacy_lines}" "${new_lines}")"
printf '%-28s %12s %12s %12s\n' "words (wc whitespace proxy)" "${legacy_words}" "${new_words}" "$(percentage "${legacy_words}" "${new_words}")"

echo
echo "Legacy mandatory files:"
for file in "${legacy_files[@]}"; do
    echo "  ${file#"${LEGACY_ROOT}"/}"
done
echo "New default files:"
for file in "${new_files[@]}"; do
    echo "  ${file#"${NEW_ROOT}"/}"
done

if grep -Fq 'scripts/memory.sh list' "${NEW_ROOT}/AGENTS.md" \
    && grep -Fq '[Index](index.md)' "${NEW_MEMORY}/start.md" \
    && grep -Fq '(sessions/index.md)' "${NEW_MEMORY}/index.md" \
    && grep -Fq '<!-- obsidian-memory:generated-start v2 -->' "${NEW_MEMORY}/start.md"; then
    echo "Discovery check: PASS (managed digest links detail index and session history)"
else
    echo "Discovery check: FAIL (startup reduction removed required discovery paths or marker)" >&2
    exit 1
fi
