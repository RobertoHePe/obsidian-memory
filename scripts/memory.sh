#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${MEMORY_ROOT:-}" ]]; then
    REPO_ROOT="$(cd "${MEMORY_ROOT}" && pwd -P)"
elif [[ "$(basename -- "$(dirname -- "${SCRIPT_DIR}")")" == .obsidian-memory ]]; then
    REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
else
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
fi

detect_agent_memory() {
    local candidates=() candidate vault
    for vault in "${REPO_ROOT}/Memory" "${REPO_ROOT}/vault"; do
        candidate="${vault}/Agent Memory"
        if [[ -L "${vault}" && ( -e "${candidate}" || -L "${candidate}" ) ]]; then
            echo "ERROR: refusing to use Agent Memory through a symlinked vault: ${vault#"${REPO_ROOT}"/}" >&2
            exit 2
        fi
        if [[ -d "${candidate}" && ! -L "${candidate}" ]]; then
            candidates+=("${candidate}")
        fi
    done
    candidate="${REPO_ROOT}/memory"
    if [[ -d "${candidate}" && ! -L "${candidate}" ]]; then
        candidates+=("${candidate}")
    fi
    if [[ "${#candidates[@]}" -gt 1 ]]; then
        echo "ERROR: multiple agent-memory directories found; keep one canonical store." >&2
        exit 2
    fi
    if [[ "${#candidates[@]}" -eq 1 ]]; then
        MEMORY_DIR=${candidates[0]}
    else
        MEMORY_DIR="${REPO_ROOT}/Memory/Agent Memory"
    fi
}

detect_agent_memory
READ_ONLY_COMPAT=0
if [[ "${MEMORY_DIR}" == "${REPO_ROOT}/memory" ]]; then
    READ_ONLY_COMPAT=1
fi
MEMORY_REL=${MEMORY_DIR#"${REPO_ROOT}"/}
if [[ "${READ_ONLY_COMPAT}" -eq 1 ]]; then
    VAULT_DIR=${MEMORY_DIR}
    VAULT_REL=none
else
    VAULT_DIR=$(dirname -- "${MEMORY_DIR}")
    VAULT_REL=${VAULT_DIR#"${REPO_ROOT}"/}
fi
SESSIONS_DIR="${MEMORY_DIR}/sessions"
START_MARKER='<!-- obsidian-memory:generated-start v2 -->'
END_MARKER='<!-- /obsidian-memory:generated-start v2 -->'
MAX_START_LINES=80
MAX_START_BYTES=3000

usage() {
    cat <<'EOF'
Usage: .obsidian-memory/scripts/memory.sh COMMAND [ARGUMENT]

Commands:
  startup              Print only the generated bounded startup digest.
  status               Print a concise handoff and tracked-change summary.
  list                 Print the progressive-disclosure memory index.
  search -- QUERY      Search current and migrated Markdown without an LLM.
  refresh              Atomically regenerate Agent Memory/start.md from sources.
  new-session          Create a unique compact handoff, index it, then refresh.
EOF
}

require_memory() {
    if [[ -L "${VAULT_DIR}" || -L "${MEMORY_DIR}" || ! -d "${MEMORY_DIR}" ]]; then
        echo "ERROR: safe Agent Memory directory not found under ${REPO_ROOT}. Run init.sh first." >&2
        exit 1
    fi
}

require_writable_layout() {
    if [[ "${READ_ONLY_COMPAT}" -eq 1 ]]; then
        echo "ERROR: old top-level memory/ is read-only compatibility; migrate it into an Obsidian vault before writing." >&2
        exit 2
    fi
}

require_sources() {
    require_memory
    local source
    for source in state.md backlog.md index.md decisions.md sessions/index.md; do
        if [[ -L "${MEMORY_DIR}/${source}" || ! -f "${MEMORY_DIR}/${source}" ]]; then
            echo "ERROR: required memory source is missing or a symlink: ${MEMORY_REL}/${source}" >&2
            return 1
        fi
    done
}

latest_session() {
    if [[ -L "${SESSIONS_DIR}" || ! -d "${SESSIONS_DIR}" ]]; then
        return 0
    fi
    find "${SESSIONS_DIR}" -maxdepth 1 -type f -name '*.md' ! -name 'index.md' -print 2>/dev/null \
        | LC_ALL=C sort \
        | tail -n 1
}

extract_section() {
    local file=$1
    local heading=$2
    awk -v wanted="${heading}" '
        $0 == wanted { active = 1; next }
        active && /^# / { exit }
        active && /[^[:space:]]/ { print }
    ' "${file}"
}

budget_line() {
    local value=$1
    local maximum=$2
    local bytes
    local LC_ALL=C
    bytes=${#value}
    if [[ "${bytes}" -gt "${maximum}" ]]; then
        printf '%s' '- Oversized line; see source.'
    else
        printf '%s' "${value}"
    fi
}

render_section() {
    local title=$1
    local file=$2
    local heading=$3
    local maximum_lines=$4
    local line_limit=$5
    local filter=${6:-all}
    local count=0 line

    printf '## %s\n' "${title}"
    while IFS= read -r line; do
        if [[ "${filter}" == "unchecked" ]] \
            && ! [[ "${line}" =~ ^[[:space:]]*[-\*][[:space:]]+\[[[:space:]]\] ]]; then
            continue
        fi
        budget_line "${line}" "${line_limit}"
        printf '\n'
        count=$((count + 1))
        [[ "${count}" -ge "${maximum_lines}" ]] && break
    done < <(extract_section "${file}" "${heading}")
    if [[ "${count}" -eq 0 ]]; then
        printf '%s\n' '- None recorded.'
    fi
    printf '\n'
}

render_recent() {
    local line_limit=$1
    local count=0 line
    printf '## Recent\n'
    while IFS= read -r line; do
        line=${line//](.\//](sessions/}
        budget_line "${line}" "${line_limit}"
        printf '\n'
        count=$((count + 1))
    done < <(
        grep -E '^[[:space:]]*-[[:space:]]+\[[^]]+\]\(' "${SESSIONS_DIR}/index.md" 2>/dev/null \
            | tail -n 5 \
            | awk '{ entries[NR] = $0 } END { for (i = NR; i >= 1; i--) print entries[i] }'
    )
    if [[ "${count}" -eq 0 ]]; then
        printf '%s\n' '- No session handoffs yet.'
    fi
    printf '\n'
}

render_with_limit() {
    local destination=$1
    local line_limit=$2
    {
        printf '%s\n' "${START_MARKER}"
        printf '%s\n\n' '# Project Memory — Generated Digest'
        printf '%s\n\n' 'Generated from `state.md`, `backlog.md`, and `sessions/index.md`. Edit sources, then run `bash .obsidian-memory/scripts/memory.sh refresh`.'
        render_section 'Now' "${MEMORY_DIR}/state.md" '# Now' 12 "${line_limit}"
        render_section 'Active' "${MEMORY_DIR}/backlog.md" '# Active' 5 "${line_limit}" unchecked
        render_recent "${line_limit}"
        render_section 'Constraints' "${MEMORY_DIR}/state.md" '# Constraints' 3 "${line_limit}"
        render_section 'Risks' "${MEMORY_DIR}/state.md" '# Risks' 3 "${line_limit}"
        printf '%s\n' '## Routes'
        printf '%s\n' '- [Index](index.md)'
        printf '%s\n' '- [State](state.md)'
        printf '%s\n' '- [Backlog](backlog.md)'
        printf '%s\n' '- [Decisions](decisions.md)'
        printf '%s\n' '- [Sessions](sessions/index.md)'
        if [[ -f "${MEMORY_DIR}/vault.md" && ! -L "${MEMORY_DIR}/vault.md" ]]; then
            printf '%s\n' '- [Existing vault notes](vault.md)'
        fi
        printf '\n%s\n' "${END_MARKER}"
    } > "${destination}"
}

render_digest() {
    require_sources
    local render_tmp line_limit lines bytes
    render_tmp=$(mktemp "${TMPDIR:-/tmp}/obsidian-memory-render.XXXXXX")
    for line_limit in 160 120 96 72; do
        render_with_limit "${render_tmp}" "${line_limit}"
        lines=$(wc -l < "${render_tmp}")
        bytes=$(wc -c < "${render_tmp}")
        lines=${lines//[[:space:]]/}
        bytes=${bytes//[[:space:]]/}
        if [[ "${lines}" -le "${MAX_START_LINES}" && "${bytes}" -le "${MAX_START_BYTES}" ]]; then
            cat -- "${render_tmp}"
            rm -f -- "${render_tmp}"
            return 0
        fi
    done
    rm -f -- "${render_tmp}"
    echo "ERROR: fixed digest routes exceed the ${MAX_START_LINES}-line/${MAX_START_BYTES}-byte cap." >&2
    return 1
}

is_managed_start() {
    local file=$1
    local start_count end_count start_line end_line total_lines
    start_count=$(grep -F -x -c -- "${START_MARKER}" "${file}" || true)
    end_count=$(grep -F -x -c -- "${END_MARKER}" "${file}" || true)
    [[ "${start_count}" -eq 1 && "${end_count}" -eq 1 ]] || return 1
    start_line=$(grep -F -x -n -- "${START_MARKER}" "${file}")
    end_line=$(grep -F -x -n -- "${END_MARKER}" "${file}")
    start_line=${start_line%%:*}
    end_line=${end_line%%:*}
    total_lines=$(awk 'END { print NR }' "${file}")
    [[ "${start_line}" -eq 1 && "${start_line}" -lt "${end_line}" && "${end_line}" -eq "${total_lines}" ]]
}

refresh_digest() {
    require_sources
    local destination="${MEMORY_DIR}/start.md"
    local rendered staged checksum incoming
    rendered=$(mktemp "${TMPDIR:-/tmp}/obsidian-memory-start.XXXXXX")
    if ! render_digest > "${rendered}"; then
        rm -f -- "${rendered}"
        return 1
    fi
    chmod 644 -- "${rendered}"

    if [[ -L "${destination}" || -d "${destination}" ]]; then
        rm -f -- "${rendered}"
        echo "CONFLICT unsafe destination; preserved ${MEMORY_REL}/start.md"
        return 2
    fi
    if [[ ! -e "${destination}" ]]; then
        staged=$(mktemp "${destination}.tmp.XXXXXX")
        cp -- "${rendered}" "${staged}"
        chmod 644 -- "${staged}"
        mv -- "${staged}" "${destination}"
        rm -f -- "${rendered}"
        echo "CREATED ${MEMORY_REL}/start.md"
        return 0
    fi
    if is_managed_start "${destination}"; then
        if cmp -s -- "${rendered}" "${destination}"; then
            rm -f -- "${rendered}"
            echo "UNCHANGED ${MEMORY_REL}/start.md"
        else
            staged=$(mktemp "${destination}.tmp.XXXXXX")
            cp -- "${rendered}" "${staged}"
            chmod 644 -- "${staged}"
            mv -- "${staged}" "${destination}"
            rm -f -- "${rendered}"
            echo "REFRESHED ${MEMORY_REL}/start.md"
        fi
        return 0
    fi

    checksum=$(cksum < "${rendered}" | awk '{print $1 "-" $2}')
    incoming="${destination}.incoming-${checksum}"
    if [[ -L "${incoming}" || -d "${incoming}" ]]; then
        rm -f -- "${rendered}"
        echo "CONFLICT unmarked start preserved; candidate path is unsafe"
        return 2
    fi
    if [[ ! -e "${incoming}" ]]; then
        staged=$(mktemp "${incoming}.tmp.XXXXXX")
        cp -- "${rendered}" "${staged}"
        chmod 644 -- "${staged}"
        mv -- "${staged}" "${incoming}"
        rm -f -- "${rendered}"
    elif cmp -s -- "${rendered}" "${incoming}"; then
        rm -f -- "${rendered}"
    else
        rm -f -- "${rendered}"
        echo "CONFLICT unmarked start preserved; candidate checksum collision"
        return 2
    fi
    echo "CONFLICT unmarked start preserved; review ${incoming#"${REPO_ROOT}"/}"
    return 2
}

command=${1:-}
case "${command}" in
    startup)
        [[ $# -eq 1 ]] || { usage >&2; exit 64; }
        require_memory
        [[ -f "${MEMORY_DIR}/start.md" && ! -L "${MEMORY_DIR}/start.md" ]] \
            || { echo "ERROR: ${MEMORY_REL}/start.md is missing or unsafe. Run refresh." >&2; exit 1; }
        if ! is_managed_start "${MEMORY_DIR}/start.md"; then
            echo "ERROR: ${MEMORY_REL}/start.md is user-owned or malformed; refusing to print it as a generated digest. Run refresh and review the staged candidate." >&2
            exit 2
        fi
        start_lines=$(wc -l < "${MEMORY_DIR}/start.md")
        start_bytes=$(wc -c < "${MEMORY_DIR}/start.md")
        start_lines=${start_lines//[[:space:]]/}
        start_bytes=${start_bytes//[[:space:]]/}
        if [[ "${start_lines}" -gt "${MAX_START_LINES}" || "${start_bytes}" -gt "${MAX_START_BYTES}" ]]; then
            echo "ERROR: managed ${MEMORY_REL}/start.md exceeds the ${MAX_START_LINES}-line/${MAX_START_BYTES}-byte cap. Run refresh." >&2
            exit 2
        fi
        cat -- "${MEMORY_DIR}/start.md"
        ;;
    status)
        [[ $# -eq 1 ]] || { usage >&2; exit 64; }
        require_memory
        latest=$(latest_session)
        if [[ -n "${latest}" ]]; then
            echo "memory: ready; latest session: ${latest#"${REPO_ROOT}"/}"
        else
            echo "memory: ready; latest session: none"
        fi
        if [[ "${READ_ONLY_COMPAT}" -eq 1 ]]; then
            echo "vault: none; agent memory: ${MEMORY_REL}/ (read-only compatibility)"
        else
            echo "vault: ${VAULT_REL}/; agent memory: ${MEMORY_REL}/"
        fi
        if git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            changes=$(git -C "${REPO_ROOT}" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
            echo "tracked git changes: ${changes} (inspect only task-relevant paths)"
        fi
        ;;
    list)
        [[ $# -eq 1 ]] || { usage >&2; exit 64; }
        require_memory
        cat -- "${MEMORY_DIR}/index.md"
        ;;
    search)
        require_memory
        shift
        if [[ ${1:-} == "--" ]]; then
            shift
        fi
        [[ $# -eq 1 && -n "$1" ]] || { echo "ERROR: search requires one non-empty literal query." >&2; usage >&2; exit 64; }
        roots=("${VAULT_DIR}")
        if ! grep -r -n -F --include='*.md' -- "$1" "${roots[@]}"; then
            echo "No memory matches."
        fi
        ;;
    render)
        [[ $# -eq 1 ]] || { usage >&2; exit 64; }
        render_digest
        ;;
    refresh)
        [[ $# -eq 1 ]] || { usage >&2; exit 64; }
        require_writable_layout
        refresh_digest
        ;;
    new-session)
        [[ $# -eq 1 ]] || { usage >&2; exit 64; }
        require_writable_layout
        require_sources
        if [[ -L "${SESSIONS_DIR}" ]]; then
            echo "ERROR: refusing to write through ${MEMORY_REL}/sessions symlink." >&2
            exit 2
        fi
        mkdir -p -- "${SESSIONS_DIR}"
        index="${SESSIONS_DIR}/index.md"
        if [[ -L "${index}" || -d "${index}" ]]; then
            echo "ERROR: refusing to replace unsafe ${MEMORY_REL}/sessions/index.md." >&2
            exit 2
        fi
        timestamp=${MEMORY_TIMESTAMP:-$(date +"%Y%m%d_%H%M%S")}
        if [[ ! "${timestamp}" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
            echo "ERROR: MEMORY_TIMESTAMP must match YYYYMMDD_HHMMSS." >&2
            exit 64
        fi
        stem="${timestamp}_session"
        note="${SESSIONS_DIR}/${stem}.md"
        suffix=1
        while [[ -e "${note}" || -L "${note}" ]]; do
            suffix=$((suffix + 1))
            note="${SESSIONS_DIR}/${stem}_${suffix}.md"
        done
        display_time=$(date +"%Y-%m-%d %H:%M:%S %Z")
        temporary=$(mktemp "${note}.tmp.XXXXXX")
        cat > "${temporary}" <<EOF
# Session Handoff — ${display_time}

- Goal:
- Outcome:
- Decisions:
- Files/tests:
- Next:
- Details/links:
EOF
        chmod 644 -- "${temporary}"
        mv -- "${temporary}" "${note}"

        index_tmp=$(mktemp "${index}.tmp.XXXXXX")
        if [[ -f "${index}" ]]; then
            cp -- "${index}" "${index_tmp}"
        else
            printf '# Session History\n\nCompact handoffs are appended below. Read only when the current task needs history.\n\n' > "${index_tmp}"
        fi
        printf -- '- [%s](./%s)\n' "$(basename "${note}" .md)" "$(basename "${note}")" >> "${index_tmp}"
        chmod 644 -- "${index_tmp}"
        mv -- "${index_tmp}" "${index}"
        echo "Created: ${note#"${REPO_ROOT}"/}"
        refresh_digest
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
