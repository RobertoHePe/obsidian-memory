#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
SOURCE_SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

STRICT=0
REPORT_PATH=""
TARGET_ARG=""

usage() {
    cat <<'EOF'
Usage: init.sh [--non-interactive] [--strict] [--report FILE] [TARGET]

Install or migrate project memory without deleting or overwriting user content.

  --non-interactive  Accepted for explicit CI use; operation is always non-interactive.
  --strict           Exit 2 when an unsafe path or preserved conflict is found.
  --report FILE      Write the printed migration report (explicitly replaces FILE).
  -h, --help         Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --non-interactive)
            shift
            ;;
        --strict)
            STRICT=1
            shift
            ;;
        --report)
            [[ $# -ge 2 ]] || { echo "ERROR: --report requires a path." >&2; exit 64; }
            REPORT_PATH=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            [[ $# -le 1 ]] || { echo "ERROR: only one target directory is allowed." >&2; exit 64; }
            if [[ $# -eq 1 ]]; then
                TARGET_ARG=$1
            fi
            break
            ;;
        -*)
            echo "ERROR: unknown option: $1" >&2
            usage >&2
            exit 64
            ;;
        *)
            [[ -z "${TARGET_ARG}" ]] || { echo "ERROR: only one target directory is allowed." >&2; exit 64; }
            TARGET_ARG=$1
            shift
            ;;
    esac
done

TARGET_ARG=${TARGET_ARG:-.}

if [[ -n "${REPORT_PATH}" ]]; then
    REPORT_PARENT=$(dirname -- "${REPORT_PATH}")
    if [[ -L "${REPORT_PARENT}" ]]; then
        echo "ERROR: refusing to write a report through a symlinked parent path: ${REPORT_PARENT}" >&2
        exit 2
    fi
    if [[ ! -d "${REPORT_PARENT}" ]]; then
        echo "ERROR: report parent must be an existing non-symlink directory: ${REPORT_PARENT}" >&2
        exit 2
    fi
    REPORT_PARENT_LOGICAL=$(cd "${REPORT_PARENT}" && pwd -L)
    REPORT_PARENT_PHYSICAL=$(cd "${REPORT_PARENT}" && pwd -P)
    if [[ "${REPORT_PARENT_LOGICAL}" != "${REPORT_PARENT_PHYSICAL}" ]]; then
        echo "ERROR: refusing to write a report through a symlinked parent path: ${REPORT_PARENT}" >&2
        exit 2
    fi
    REPORT_PATH="${REPORT_PARENT_PHYSICAL}/$(basename -- "${REPORT_PATH}")"
    if [[ -L "${REPORT_PATH}" || -d "${REPORT_PATH}" ]]; then
        echo "ERROR: refusing to replace report symlink or directory: ${REPORT_PATH}" >&2
        exit 2
    fi
fi

reject_target_symlink_components() {
    local path=$1 current component
    if [[ "${path}" == /* ]]; then
        current=/
    else
        current=$(pwd -P)
    fi
    local IFS=/
    read -r -a components <<< "${path}"
    for component in "${components[@]}"; do
        case "${component}" in
            ''|.) continue ;;
            ..) current=$(dirname -- "${current}") ;;
            *)
                if [[ "${current}" == / ]]; then
                    current="/${component}"
                else
                    current="${current}/${component}"
                fi
                if [[ -L "${current}" ]]; then
                    echo "ERROR: refusing to install through a symlinked target path: ${current}" >&2
                    exit 2
                fi
                ;;
        esac
    done
}

reject_target_symlink_components "${TARGET_ARG}"
mkdir -p -- "${TARGET_ARG}"
TARGET_DIR="$(cd "${TARGET_ARG}" && pwd -P)"
if [[ "${TARGET_DIR}" == / ]]; then
    echo "ERROR: refusing to install into the filesystem root." >&2
    exit 2
fi

REPORT_TMP=$(mktemp "${TMPDIR:-/tmp}/obsidian-memory-report.XXXXXX")
trap 'rm -f -- "${REPORT_TMP}"' EXIT

CREATED=0
MERGED=0
PRESERVED=0
UNCHANGED=0
CONFLICTS=0
INSTALL_READY=1

report() {
    printf '%s\n' "$*" >> "${REPORT_TMP}"
}

relative_path() {
    case "$1" in
        "${TARGET_DIR}") printf '.' ;;
        "${TARGET_DIR}"/*) printf '%s' "${1#"${TARGET_DIR}"/}" ;;
        *) printf '%s' "$1" ;;
    esac
}

record() {
    local kind=$1
    local path=$2
    local detail=${3:-}
    local relative
    relative=$(relative_path "${path}")
    if [[ -n "${detail}" ]]; then
        report "${kind} ${relative} — ${detail}"
    else
        report "${kind} ${relative}"
    fi
}

ensure_directory() {
    local path=$1
    if [[ -L "${path}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${path}" "refusing to follow a directory symlink"
        return 1
    fi
    if [[ -e "${path}" && ! -d "${path}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${path}" "a non-directory occupies the required path"
        return 1
    fi
    if [[ ! -d "${path}" ]]; then
        mkdir -p -- "${path}"
        CREATED=$((CREATED + 1))
        record "CREATED" "${path}" "directory"
    fi
}

validate_bundle_parents() {
    local bundle="${TARGET_DIR}/.obsidian-memory"
    local resources="${bundle}/scripts"

    if [[ -L "${bundle}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        INSTALL_READY=0
        record "CONFLICT" "${bundle}" "refusing to install through a skill-bundle symlink"
        return
    fi
    if [[ -e "${bundle}" && ! -d "${bundle}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        INSTALL_READY=0
        record "CONFLICT" "${bundle}" "a non-directory occupies the skill-bundle path"
        return
    fi
    if [[ -d "${bundle}" && -L "${resources}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        INSTALL_READY=0
        record "CONFLICT" "${resources}" "refusing to install through a skill-resource symlink"
        return
    fi
    if [[ -d "${bundle}" && -e "${resources}" && ! -d "${resources}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        INSTALL_READY=0
        record "CONFLICT" "${resources}" "a non-directory occupies the skill-resource path"
    fi
}

has_uppercase_memory_signature() {
    local path=$1
    local matches=0
    [[ -d "${path}" && ! -L "${path}" ]] || return 1
    if [[ -d "${path}/.obsidian" && ! -L "${path}/.obsidian" ]]; then
        return 0
    fi
    if [[ -d "${path}/Agent Memory" && ! -L "${path}/Agent Memory" \
        && -f "${path}/Agent Memory/.format-version" && ! -L "${path}/Agent Memory/.format-version" ]]; then
        return 0
    fi
    [[ -f "${path}/00_Index.md" && ! -L "${path}/00_Index.md" ]] && matches=$((matches + 1))
    [[ -f "${path}/13_Current_State.md" && ! -L "${path}/13_Current_State.md" ]] && matches=$((matches + 1))
    [[ -f "${path}/14_Backlog.md" && ! -L "${path}/14_Backlog.md" ]] && matches=$((matches + 1))
    [[ -d "${path}/sessions" && ! -L "${path}/sessions" ]] && matches=$((matches + 1))
    [[ "${matches}" -ge 2 ]]
}

select_vault_layout() {
    local vault_found=0 memory_found=0
    VAULT_NAME=""
    VAULT_EXISTED=0

    if [[ -L "${TARGET_DIR}/vault" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${TARGET_DIR}/vault" "refusing to inspect a legacy vault symlink"
    elif [[ -d "${TARGET_DIR}/vault" ]]; then
        vault_found=1
    fi

    if [[ -L "${TARGET_DIR}/Memory" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${TARGET_DIR}/Memory" "refusing to inspect an uppercase memory symlink"
    elif has_uppercase_memory_signature "${TARGET_DIR}/Memory"; then
        memory_found=1
    fi

    if [[ "${vault_found}" -eq 1 && "${memory_found}" -eq 1 ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${TARGET_DIR}" "both vault/ and signature-matched Memory/ exist; neither was selected automatically"
    elif [[ "${vault_found}" -eq 1 ]]; then
        VAULT_NAME="vault"
        if [[ -f "${TARGET_DIR}/vault/Agent Memory/.format-version" && ! -L "${TARGET_DIR}/vault/Agent Memory/.format-version" ]]; then
            VAULT_EXISTED=0
        else
            VAULT_EXISTED=1
        fi
    elif [[ "${memory_found}" -eq 1 ]]; then
        VAULT_NAME="Memory"
        if [[ -f "${TARGET_DIR}/Memory/Agent Memory/.format-version" && ! -L "${TARGET_DIR}/Memory/Agent Memory/.format-version" ]]; then
            VAULT_EXISTED=0
        else
            VAULT_EXISTED=1
        fi
    elif [[ -e "${TARGET_DIR}/Memory" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${TARGET_DIR}/Memory" "existing directory is not recognizable as an Obsidian or project-memory vault"
    elif [[ -e "${TARGET_DIR}/memory" || -L "${TARGET_DIR}/memory" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${TARGET_DIR}/memory" "old outside-vault agent memory was preserved; move or reconcile it before installing the canonical layout"
    else
        VAULT_NAME="Memory"
    fi

    if [[ -n "${VAULT_NAME}" ]]; then
        VAULT_DIR="${TARGET_DIR}/${VAULT_NAME}"
        AGENT_DIR="${VAULT_DIR}/Agent Memory"
        AGENT_REL="${VAULT_NAME}/Agent Memory"
    fi
}

atomic_copy() {
    local source=$1
    local destination=$2
    local temporary
    temporary=$(mktemp "${destination}.tmp.XXXXXX")
    cp -- "${source}" "${temporary}"
    chmod 644 -- "${temporary}"
    mv -- "${temporary}" "${destination}"
}

install_user_file() {
    local source=$1
    local destination=$2
    if [[ -L "${destination}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${destination}" "refusing to replace a symlink"
    elif [[ -d "${destination}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${destination}" "a directory occupies the file path"
    elif [[ -e "${destination}" ]]; then
        PRESERVED=$((PRESERVED + 1))
        record "PRESERVED" "${destination}" "existing user-owned memory source"
    else
        atomic_copy "${source}" "${destination}"
        CREATED=$((CREATED + 1))
        record "CREATED" "${destination}"
    fi
}

install_managed_file() {
    local source=$1
    local destination=$2
    local executable=${3:-0}
    local checksum incoming

    if [[ -L "${destination}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${destination}" "refusing to replace a symlink"
        return
    fi
    if [[ -d "${destination}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${destination}" "a directory occupies the file path"
        return
    fi
    if [[ ! -e "${destination}" ]]; then
        atomic_copy "${source}" "${destination}"
        if [[ "${executable}" -eq 1 ]]; then
            chmod 755 -- "${destination}"
        fi
        CREATED=$((CREATED + 1))
        record "CREATED" "${destination}"
        return
    fi
    if cmp -s -- "${source}" "${destination}"; then
        UNCHANGED=$((UNCHANGED + 1))
        record "UNCHANGED" "${destination}" "managed file already current"
        return
    fi

    checksum=$(cksum < "${source}" | awk '{print $1 "-" $2}')
    incoming="${destination}.incoming-${checksum}"
    if [[ -L "${incoming}" || -d "${incoming}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${destination}" "preserved; incoming candidate path is unsafe: $(relative_path "${incoming}")"
        return
    fi
    if [[ ! -e "${incoming}" ]]; then
        atomic_copy "${source}" "${incoming}"
        if [[ "${executable}" -eq 1 ]]; then
            chmod 755 -- "${incoming}"
        fi
        CREATED=$((CREATED + 1))
    elif ! cmp -s -- "${source}" "${incoming}"; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${destination}" "preserved; existing incoming candidate also differs"
        return
    fi
    CONFLICTS=$((CONFLICTS + 1))
    record "CONFLICT" "${destination}" "preserved; review $(relative_path "${incoming}")"
}

install_agents_instructions() {
    local agents="${TARGET_DIR}/AGENTS.md"
    local block="${TEMPLATES_DIR}/agents-memory-block.md"
    local old_block="${TEMPLATES_DIR}/agents-memory-block-v2-root-scripts.md"
    local start_marker='<!-- obsidian-memory:start v2 -->'
    local end_marker='<!-- obsidian-memory:end v2 -->'
    local start_count end_count start_line end_line checksum backup_dir backup temporary current_block

    if [[ -L "${agents}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${agents}" "refusing to modify a symlink"
        return
    fi
    if [[ -d "${agents}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${agents}" "a directory occupies the file path"
        return
    fi
    if [[ ! -e "${agents}" ]]; then
        atomic_copy "${TEMPLATES_DIR}/AGENTS.md" "${agents}"
        CREATED=$((CREATED + 1))
        record "CREATED" "${agents}" "compact memory entry point"
        return
    fi

    start_count=$(grep -F -x -c -- "${start_marker}" "${agents}" || true)
    end_count=$(grep -F -x -c -- "${end_marker}" "${agents}" || true)
    if [[ "${start_count}" -eq 1 && "${end_count}" -eq 1 ]]; then
        start_line=$(grep -F -x -n -- "${start_marker}" "${agents}")
        end_line=$(grep -F -x -n -- "${end_marker}" "${agents}")
        start_line=${start_line%%:*}
        end_line=${end_line%%:*}
        if [[ "${start_line}" -lt "${end_line}" ]]; then
            current_block=$(mktemp "${TMPDIR:-/tmp}/obsidian-memory-agents-block.XXXXXX")
            sed -n "${start_line},${end_line}p" "${agents}" > "${current_block}"
            if cmp -s -- "${block}" "${current_block}"; then
                rm -f -- "${current_block}"
                UNCHANGED=$((UNCHANGED + 1))
                record "UNCHANGED" "${agents}" "managed memory block already current"
                return
            fi
            if cmp -s -- "${old_block}" "${current_block}"; then
                rm -f -- "${current_block}"
                backup_dir="${TARGET_DIR}/.memory-backups"
                if ! ensure_directory "${backup_dir}"; then
                    record "CONFLICT" "${agents}" "could not create a safe backup directory; old managed block preserved"
                    return
                fi
                checksum=$(cksum < "${agents}" | awk '{print $1 "-" $2}')
                backup="${backup_dir}/AGENTS.md.${checksum}.bak"
                if [[ -L "${backup}" || -d "${backup}" ]]; then
                    CONFLICTS=$((CONFLICTS + 1))
                    record "CONFLICT" "${agents}" "backup path is unsafe; old managed block preserved"
                    return
                fi
                if [[ ! -e "${backup}" ]]; then
                    atomic_copy "${agents}" "${backup}"
                    CREATED=$((CREATED + 1))
                    record "BACKUP" "${backup}" "exact pre-upgrade AGENTS.md content"
                elif ! cmp -s -- "${agents}" "${backup}"; then
                    CONFLICTS=$((CONFLICTS + 1))
                    record "CONFLICT" "${agents}" "backup checksum collision; old managed block preserved"
                    return
                fi
                temporary=$(mktemp "${agents}.tmp.XXXXXX")
                head -n "$((start_line - 1))" "${agents}" > "${temporary}"
                cat -- "${block}" >> "${temporary}"
                tail -n "+$((end_line + 1))" "${agents}" >> "${temporary}"
                chmod --reference="${agents}" "${temporary}"
                mv -- "${temporary}" "${agents}"
                MERGED=$((MERGED + 1))
                record "MIGRATED" "${agents}" "updated exact managed block to the repo-local skill command; original saved in $(relative_path "${backup}")"
                return
            fi
            rm -f -- "${current_block}"
            PRESERVED=$((PRESERVED + 1))
            record "PRESERVED" "${agents}" "memory block already present; user edits retained"
            return
        fi
    fi
    if [[ "${start_count}" -ne 0 || "${end_count}" -ne 0 ]]; then
        install_managed_file "${block}" "${agents}.memory-block" 0
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${agents}" "malformed or duplicate memory markers; original preserved"
        return
    fi

    backup_dir="${TARGET_DIR}/.memory-backups"
    if ! ensure_directory "${backup_dir}"; then
        record "CONFLICT" "${agents}" "could not create a safe backup directory; original preserved"
        return
    fi
    checksum=$(cksum < "${agents}" | awk '{print $1 "-" $2}')
    backup="${backup_dir}/AGENTS.md.${checksum}.bak"
    if [[ -L "${backup}" || -d "${backup}" ]]; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${agents}" "backup path is unsafe; original preserved"
        return
    fi
    if [[ ! -e "${backup}" ]]; then
        atomic_copy "${agents}" "${backup}"
        CREATED=$((CREATED + 1))
        record "BACKUP" "${backup}" "exact pre-merge AGENTS.md content"
    elif ! cmp -s -- "${agents}" "${backup}"; then
        CONFLICTS=$((CONFLICTS + 1))
        record "CONFLICT" "${agents}" "backup checksum collision; original preserved"
        return
    fi

    temporary=$(mktemp "${TARGET_DIR}/.AGENTS.md.tmp.XXXXXX")
    cp -p -- "${agents}" "${temporary}"
    printf '\n' >> "${temporary}"
    cat -- "${block}" >> "${temporary}"
    mv -- "${temporary}" "${agents}"
    MERGED=$((MERGED + 1))
    record "MERGED" "${agents}" "appended compact block; original saved in $(relative_path "${backup}")"
}

refresh_start() {
    local output status=0 action detail
    set +e
    output=$(MEMORY_ROOT="${TARGET_DIR}" bash "${SOURCE_SCRIPTS_DIR}/memory.sh" refresh 2>&1)
    status=$?
    set -e
    action=${output%% *}
    detail=${output#* }
    case "${status}:${action}" in
        0:CREATED)
            CREATED=$((CREATED + 1))
            record "CREATED" "${AGENT_DIR}/start.md" "generated bounded digest"
            ;;
        0:UNCHANGED)
            UNCHANGED=$((UNCHANGED + 1))
            record "UNCHANGED" "${AGENT_DIR}/start.md" "generated digest already current"
            ;;
        0:REFRESHED)
            MERGED=$((MERGED + 1))
            record "REFRESHED" "${AGENT_DIR}/start.md" "source memory changed"
            ;;
        2:CONFLICT)
            CONFLICTS=$((CONFLICTS + 1))
            record "CONFLICT" "${AGENT_DIR}/start.md" "${detail}"
            ;;
        *)
            CONFLICTS=$((CONFLICTS + 1))
            record "CONFLICT" "${AGENT_DIR}/start.md" "digest refresh failed (${status}): ${output}"
            ;;
    esac
}

report "Obsidian Memory migration report"
report "Target: ${TARGET_DIR}"
report "Policy: preserve user files; stage managed conflicts; never delete"
report ""

select_vault_layout
if [[ -n "${VAULT_NAME}" ]]; then
    validate_bundle_parents
fi

if [[ -n "${VAULT_NAME}" && "${INSTALL_READY}" -eq 1 ]] && ensure_directory "${VAULT_DIR}"; then
    if ensure_directory "${AGENT_DIR}"; then
        ensure_directory "${AGENT_DIR}/sessions" || true
    fi
fi
if [[ -n "${VAULT_NAME}" && "${INSTALL_READY}" -eq 1 ]]; then
    if ensure_directory "${TARGET_DIR}/.obsidian-memory"; then
        ensure_directory "${TARGET_DIR}/.obsidian-memory/scripts" || true
    fi
fi

if [[ -n "${VAULT_NAME}" && "${INSTALL_READY}" -eq 1 && -d "${AGENT_DIR}" && ! -L "${AGENT_DIR}" ]]; then
    if [[ "${VAULT_EXISTED}" -eq 1 ]]; then
        install_user_file "${TEMPLATES_DIR}/state-legacy.md" "${AGENT_DIR}/state.md"
        install_user_file "${TEMPLATES_DIR}/backlog-legacy.md" "${AGENT_DIR}/backlog.md"
        install_user_file "${TEMPLATES_DIR}/index-legacy.md" "${AGENT_DIR}/index.md"
        install_user_file "${TEMPLATES_DIR}/vault.md" "${AGENT_DIR}/vault.md"
        PRESERVED=$((PRESERVED + 1))
        record "PRESERVED" "${VAULT_DIR}" "existing files remain in place; Agent Memory was added inside the vault"
    else
        install_user_file "${TEMPLATES_DIR}/state.md" "${AGENT_DIR}/state.md"
        install_user_file "${TEMPLATES_DIR}/backlog.md" "${AGENT_DIR}/backlog.md"
        install_user_file "${TEMPLATES_DIR}/index.md" "${AGENT_DIR}/index.md"
    fi
    install_user_file "${TEMPLATES_DIR}/decisions.md" "${AGENT_DIR}/decisions.md"
    if [[ -d "${AGENT_DIR}/sessions" && ! -L "${AGENT_DIR}/sessions" ]]; then
        install_user_file "${TEMPLATES_DIR}/sessions-index.md" "${AGENT_DIR}/sessions/index.md"
    fi
    install_managed_file "${TEMPLATES_DIR}/format-version" "${AGENT_DIR}/.format-version" 0
fi

if [[ -n "${VAULT_NAME}" && "${INSTALL_READY}" -eq 1 && -d "${TARGET_DIR}/.obsidian-memory" && ! -L "${TARGET_DIR}/.obsidian-memory" ]]; then
    install_managed_file "${TEMPLATES_DIR}/runtime-skill.md" "${TARGET_DIR}/.obsidian-memory/SKILL.md" 0
    if [[ -d "${TARGET_DIR}/.obsidian-memory/scripts" && ! -L "${TARGET_DIR}/.obsidian-memory/scripts" ]]; then
        install_managed_file "${SOURCE_SCRIPTS_DIR}/memory.sh" "${TARGET_DIR}/.obsidian-memory/scripts/memory.sh" 1
    fi
fi

if [[ -n "${VAULT_NAME}" && "${INSTALL_READY}" -eq 1 ]]; then
    install_agents_instructions
fi

if [[ -n "${VAULT_NAME}" && "${INSTALL_READY}" -eq 1 && -d "${AGENT_DIR}" && ! -L "${AGENT_DIR}" ]]; then
    refresh_start
fi

report ""
report "Summary: created=${CREATED} merged=${MERGED} preserved=${PRESERVED} unchanged=${UNCHANGED} conflicts=${CONFLICTS}"
if [[ "${CONFLICTS}" -gt 0 ]]; then
    report "Result: completed with preserved conflicts; review each CONFLICT and incoming candidate."
else
    report "Result: complete; no user-authored memory was overwritten or deleted."
fi
if [[ -n "${VAULT_NAME}" && "${INSTALL_READY}" -eq 1 ]]; then
    report "Startup: follow AGENTS.md and run bash .obsidian-memory/scripts/memory.sh startup; resolve any reported managed conflict before use."
else
    report "Startup: not installed; resolve the reported layout or skill-bundle conflict and rerun."
fi

cat -- "${REPORT_TMP}"

if [[ -n "${REPORT_PATH}" ]]; then
    REPORT_OUTPUT_TMP=$(mktemp "${REPORT_PATH}.tmp.XXXXXX")
    cp -- "${REPORT_TMP}" "${REPORT_OUTPUT_TMP}"
    mv -- "${REPORT_OUTPUT_TMP}" "${REPORT_PATH}"
fi

if [[ "${STRICT}" -eq 1 && "${CONFLICTS}" -gt 0 ]]; then
    exit 2
fi
