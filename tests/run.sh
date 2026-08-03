#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
INIT="${ROOT}/init.sh"
FIXTURE="${ROOT}/tests/fixtures/legacy-install"
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/obsidian-memory-tests.XXXXXX")
trap 'rm -rf -- "${TEST_TMP}"' EXIT

PASSED=0

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file() {
    [[ -f "$1" ]] || fail "expected file: $1"
}

assert_contains() {
    grep -Fq -- "$2" "$1" || fail "expected '$2' in $1"
}

assert_count() {
    local expected=$1 pattern=$2 file=$3 actual
    actual=$(grep -F -c -- "${pattern}" "${file}" || true)
    [[ "${actual}" -eq "${expected}" ]] || fail "expected ${expected} occurrences of '${pattern}' in ${file}; got ${actual}"
}

pass() {
    PASSED=$((PASSED + 1))
    echo "ok ${PASSED} - $1"
}

snapshot_tree() {
    local root=$1
    find "${root}" -type f -exec cksum {} \; | LC_ALL=C sort
    find "${root}" -type f -exec stat -c 'file mode=%a mtime=%Y size=%s path=%n' {} \; | LC_ALL=C sort
    find "${root}" -type d -exec stat -c 'dir mode=%a mtime=%Y path=%n' {} \; | LC_ALL=C sort
    find "${root}" -type l -printf 'link=%p -> %l\n' | LC_ALL=C sort
}

snapshot_existing_vault() {
    local root=$1
    local agent="${root}/Agent Memory"
    find "${root}" -mindepth 1 -path "${agent}" -prune -o -type f -exec cksum {} \; | LC_ALL=C sort
    find "${root}" -mindepth 1 -path "${agent}" -prune -o -type f -exec stat -c 'file mode=%a mtime=%Y size=%s path=%n' {} \; | LC_ALL=C sort
    find "${root}" -mindepth 1 -path "${agent}" -prune -o -type d -exec stat -c 'dir mode=%a mtime=%Y path=%n' {} \; | LC_ALL=C sort
    find "${root}" -mindepth 1 -path "${agent}" -prune -o -type l -printf 'link=%p -> %l\n' | LC_ALL=C sort
}

section_count() {
    local file=$1 heading=$2
    awk -v wanted="${heading}" '
        $0 == wanted { active = 1; next }
        active && /^## / { exit }
        active && /[^[:space:]]/ { count++ }
        END { print count + 0 }
    ' "${file}"
}

# Clean, non-interactive install in a path containing ordinary shell metacharacters.
clean="${TEST_TMP}/project space [x] \$dollar;semi &"
mkdir -p "${clean}/scripts"
printf 'project-script-sentinel\n' > "${clean}/scripts/memory.sh"
chmod 640 "${clean}/scripts/memory.sh"
clean_scripts_before=$(snapshot_tree "${clean}/scripts")
bash "${INIT}" --non-interactive "${clean}" </dev/null > "${TEST_TMP}/clean-report.txt"
clean_memory="${clean}/Memory/Agent Memory"
clean_helper="${clean}/.obsidian-memory/scripts/memory.sh"
assert_file "${clean}/AGENTS.md"
assert_file "${clean_memory}/start.md"
assert_file "${clean_memory}/state.md"
assert_file "${clean_memory}/backlog.md"
assert_file "${clean_memory}/index.md"
assert_file "${clean_helper}"
assert_file "${clean}/.obsidian-memory/SKILL.md"
[[ -x "${clean_helper}" ]] || fail "memory helper is not executable"
[[ "$(snapshot_tree "${clean}/scripts")" == "${clean_scripts_before}" ]] || fail "installer modified the target repository's scripts directory"
[[ ! -e "${clean}/scripts/measure_context.sh" ]] || fail "development measurement helper was installed into target scripts"
[[ ! -e "${clean}/vault" ]] || fail "clean install unexpectedly created a lowercase vault"
assert_contains "${clean}/AGENTS.md" '.obsidian-memory/scripts/memory.sh startup'
assert_contains "${clean}/AGENTS.md" '.obsidian-memory/SKILL.md'
assert_contains "${clean}/AGENTS.md" 'only when the task needs detail.'
assert_contains "${clean_memory}/start.md" '<!-- obsidian-memory:generated-start v2 -->'
assert_contains "${clean_memory}/start.md" '[Index](index.md)'
for source_note in state.md backlog.md decisions.md index.md sessions/index.md; do
    if grep -Eq '^(type|status|generated):' "${clean_memory}/${source_note}"; then
        fail "unused schema metadata remains in ${source_note}"
    fi
done
[[ "$(wc -l < "${clean_memory}/start.md")" -le 80 ]] || fail "clean digest exceeds line cap"
[[ "$(wc -c < "${clean_memory}/start.md")" -le 3000 ]] || fail "clean digest exceeds byte cap"
"${clean_helper}" startup > "${TEST_TMP}/startup.txt"
cmp -s "${clean_memory}/start.md" "${TEST_TMP}/startup.txt" || fail "startup did not print the managed digest exactly"
"${clean_helper}" status > "${TEST_TMP}/status.txt"
assert_contains "${TEST_TMP}/status.txt" 'memory: ready'
pass "clean installation creates a useful bounded digest and is special-path safe"

# Populated legacy migration preserves every legacy byte, mode, mtime, and helper.
legacy="${TEST_TMP}/legacy migration"
mkdir -p "${legacy}"
cp -R "${FIXTURE}/." "${legacy}/"
mkdir -p "${legacy}/scripts" "${legacy}/vault/sessions"
printf '%s' 'USER INSTRUCTIONS: keep exactly; no trailing newline' > "${legacy}/AGENTS.md"
printf '%s\n' '# custom decisions' 'sentinel decisions' > "${legacy}/vault/11_Decisions_Log.md"
printf '%s\n' '# custom session index' 'sentinel index' > "${legacy}/vault/sessions/README.md"
printf '%s\n' '# later session' 'sentinel history' > "${legacy}/vault/sessions/20261231_2359_session.md"
weird_name='- note [x] $() `ticks`; semi.md'
printf '%s\n' 'literal $(touch SHOULD_NOT_EXIST) and searchable-weird-memory' > "${legacy}/vault/${weird_name}"
printf '%s\n' '#!/usr/bin/env bash' 'echo user-new-session' > "${legacy}/scripts/new_session.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo user-index' > "${legacy}/scripts/update_session_index.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo user-detect' > "${legacy}/scripts/detect_changes.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo unrelated' > "${legacy}/scripts/user tool.sh"
chmod 640 "${legacy}/scripts/new_session.sh" "${legacy}/scripts/update_session_index.sh" "${legacy}/scripts/detect_changes.sh" "${legacy}/scripts/user tool.sh"

mkdir -p "${TEST_TMP}/before"
cp "${legacy}/AGENTS.md" "${TEST_TMP}/before/AGENTS.md"
cp "${legacy}/scripts/new_session.sh" "${TEST_TMP}/before/new_session.sh"
cp "${legacy}/scripts/update_session_index.sh" "${TEST_TMP}/before/update_session_index.sh"
cp "${legacy}/scripts/detect_changes.sh" "${TEST_TMP}/before/detect_changes.sh"
cp "${legacy}/scripts/user tool.sh" "${TEST_TMP}/before/user tool.sh"
snapshot_tree "${legacy}/scripts" > "${TEST_TMP}/before/legacy-scripts.txt"
snapshot_existing_vault "${legacy}/vault" > "${TEST_TMP}/before/vault-snapshot.txt"

bash "${INIT}" --non-interactive "${legacy}" > "${TEST_TMP}/legacy-report-1.txt"
snapshot_existing_vault "${legacy}/vault" > "${TEST_TMP}/after-vault-snapshot.txt"
cmp -s "${TEST_TMP}/before/vault-snapshot.txt" "${TEST_TMP}/after-vault-snapshot.txt" || fail "a legacy vault file, mode, or mtime changed"
cmp -s "${legacy}/scripts/new_session.sh" "${TEST_TMP}/before/new_session.sh" || fail "modified helper changed"
cmp -s "${legacy}/scripts/update_session_index.sh" "${TEST_TMP}/before/update_session_index.sh" || fail "modified index helper changed"
cmp -s "${legacy}/scripts/detect_changes.sh" "${TEST_TMP}/before/detect_changes.sh" || fail "modified detection helper changed"
cmp -s "${legacy}/scripts/user tool.sh" "${TEST_TMP}/before/user tool.sh" || fail "unrelated helper changed"
snapshot_tree "${legacy}/scripts" > "${TEST_TMP}/after-legacy-scripts.txt"
cmp -s "${TEST_TMP}/before/legacy-scripts.txt" "${TEST_TMP}/after-legacy-scripts.txt" || fail "legacy project scripts directory changed"
for old_helper in new_session.sh update_session_index.sh detect_changes.sh 'user tool.sh'; do
    [[ "$(stat -c '%a' "${legacy}/scripts/${old_helper}")" == 640 ]] || fail "modified helper mode changed: ${old_helper}"
done
backup=$(find "${legacy}/.memory-backups" -maxdepth 1 -type f -name 'AGENTS.md.*.bak' -print)
[[ -n "${backup}" ]] || fail "AGENTS backup missing"
cmp -s "${backup}" "${TEST_TMP}/before/AGENTS.md" || fail "AGENTS backup content is not exact"
assert_contains "${legacy}/AGENTS.md" 'USER INSTRUCTIONS: keep exactly; no trailing newline'
assert_count 1 '<!-- obsidian-memory:start v2 -->' "${legacy}/AGENTS.md"
legacy_memory="${legacy}/vault/Agent Memory"
assert_contains "${legacy_memory}/state.md" 'Existing Obsidian notes remain unchanged'
assert_contains "${legacy_memory}/start.md" '[Existing vault notes](vault.md)'
assert_contains "${legacy_memory}/vault.md" '../sessions/README.md'
"${legacy}/.obsidian-memory/scripts/memory.sh" search -- 'searchable-weird-memory' > "${TEST_TMP}/search.txt"
assert_contains "${TEST_TMP}/search.txt" "${weird_name}"
[[ ! -e "${legacy}/SHOULD_NOT_EXIST" ]] || fail "shell metacharacters were executed"

# Normalize mtimes, then prove a second installer run performs no filesystem mutation.
find "${legacy}" -type f -exec touch -t 200001010000 {} +
find "${legacy}" -depth -type d -exec touch -t 200001010000 {} +
snapshot_tree "${legacy}" > "${TEST_TMP}/legacy-snapshot-1.txt"
bash "${INIT}" --non-interactive "${legacy}" > "${TEST_TMP}/legacy-report-2.txt"
snapshot_tree "${legacy}" > "${TEST_TMP}/legacy-snapshot-2.txt"
cmp -s "${TEST_TMP}/legacy-snapshot-1.txt" "${TEST_TMP}/legacy-snapshot-2.txt" || fail "second migration changed filesystem content, metadata, or entries"
assert_count 1 '<!-- obsidian-memory:start v2 -->' "${legacy}/AGENTS.md"
[[ "$(find "${legacy}/.memory-backups" -type f | wc -l | tr -d ' ')" -eq 1 ]] || fail "second run created another backup"
pass "legacy memory and helpers migrate byte-for-byte with true second-run idempotency"

# Exact previous managed instructions migrate to the repo-local skill; old project scripts remain untouched.
old_bundle_layout="${TEST_TMP}/previous root scripts layout"
mkdir -p "${old_bundle_layout}/Memory/.obsidian" "${old_bundle_layout}/scripts"
{
    printf '%s\n\n' '# Existing project instructions' 'keep-before-block'
    cat "${ROOT}/templates/agents-memory-block-v2-root-scripts.md"
    printf '\n%s\n' 'keep-after-block'
} > "${old_bundle_layout}/AGENTS.md"
chmod 640 "${old_bundle_layout}/AGENTS.md"
printf 'old-managed-or-user-helper\n' > "${old_bundle_layout}/scripts/memory.sh"
printf 'old-measurement-helper\n' > "${old_bundle_layout}/scripts/measure_context.sh"
printf 'application-script\n' > "${old_bundle_layout}/scripts/deploy.sh"
cp "${old_bundle_layout}/AGENTS.md" "${TEST_TMP}/before/old-layout-AGENTS.md"
snapshot_tree "${old_bundle_layout}/scripts" > "${TEST_TMP}/before/old-layout-scripts.txt"
bash "${INIT}" --non-interactive "${old_bundle_layout}" > "${TEST_TMP}/old-layout-report.txt"
snapshot_tree "${old_bundle_layout}/scripts" > "${TEST_TMP}/after-old-layout-scripts.txt"
cmp -s "${TEST_TMP}/before/old-layout-scripts.txt" "${TEST_TMP}/after-old-layout-scripts.txt" \
    || fail "previous-layout project scripts changed during skill migration"
assert_contains "${old_bundle_layout}/AGENTS.md" 'keep-before-block'
assert_contains "${old_bundle_layout}/AGENTS.md" 'keep-after-block'
assert_contains "${old_bundle_layout}/AGENTS.md" '.obsidian-memory/scripts/memory.sh startup'
if grep -Fq 'bash scripts/memory.sh startup' "${old_bundle_layout}/AGENTS.md"; then
    fail "exact previous managed AGENTS block still routes to root scripts"
fi
[[ "$(stat -c '%a' "${old_bundle_layout}/AGENTS.md")" == 640 ]] || fail "AGENTS mode changed during managed-block migration"
old_agents_backup=$(find "${old_bundle_layout}/.memory-backups" -maxdepth 1 -type f -name 'AGENTS.md.*.bak' -print)
[[ -n "${old_agents_backup}" ]] || fail "previous-layout AGENTS backup missing"
cmp -s "${old_agents_backup}" "${TEST_TMP}/before/old-layout-AGENTS.md" || fail "previous-layout AGENTS backup is not exact"
assert_file "${old_bundle_layout}/.obsidian-memory/SKILL.md"
assert_file "${old_bundle_layout}/.obsidian-memory/scripts/memory.sh"
snapshot_tree "${old_bundle_layout}" > "${TEST_TMP}/old-layout-project-1.txt"
bash "${INIT}" --non-interactive "${old_bundle_layout}" > "${TEST_TMP}/old-layout-report-2.txt"
snapshot_tree "${old_bundle_layout}" > "${TEST_TMP}/old-layout-project-2.txt"
cmp -s "${TEST_TMP}/old-layout-project-1.txt" "${TEST_TMP}/old-layout-project-2.txt" \
    || fail "second previous-layout migration changed filesystem content or metadata"
pass "previous root-script instructions migrate to the skill without touching old scripts"

# Recognize an existing uppercase Memory vault by either .obsidian or multiple signatures.
uppercase="${TEST_TMP}/uppercase memory vault"
mkdir -p "${uppercase}/Memory/sessions" "${uppercase}/Memory/.obsidian" "${uppercase}/Memory/Nested Notes" "${uppercase}/Memory/scripts"
printf '%s\n' '# Index' 'uppercase-index-sentinel' > "${uppercase}/Memory/00_Index.md"
printf '%s\n' '# Current State' 'uppercase-search-sentinel' > "${uppercase}/Memory/13_Current_State.md"
printf '%s\n' '# Backlog' '- [ ] preserve uppercase vault' > "${uppercase}/Memory/14_Backlog.md"
printf '%s\n' '# Decisions' 'uppercase-decision-sentinel' > "${uppercase}/Memory/11_Decisions_Log.md"
printf '%s\n' '# Session Rules' 'uppercase-rules-sentinel' > "${uppercase}/Memory/12_Session_Rules.md"
printf '%s\n' '# Session Notes Index' '- [old](./20260722_old.md)' > "${uppercase}/Memory/sessions/README.md"
printf '%s\n' '# Old Session' 'uppercase-session-sentinel' > "${uppercase}/Memory/sessions/20260722_old.md"
printf '%s\n' '{"vault":"settings"}' > "${uppercase}/Memory/.obsidian/app.json"
printf '%s\n' 'nested-uppercase-sentinel' > "${uppercase}/Memory/Nested Notes/note [x] &.md"
printf '%s\n' '#!/usr/bin/env bash' 'echo uppercase-helper' > "${uppercase}/Memory/scripts/new_session.sh"
chmod 640 "${uppercase}/Memory/scripts/new_session.sh"
snapshot_existing_vault "${uppercase}/Memory" > "${TEST_TMP}/uppercase-memory-before.txt"
bash "${INIT}" --non-interactive "${uppercase}" > "${TEST_TMP}/uppercase-report-1.txt"
snapshot_existing_vault "${uppercase}/Memory" > "${TEST_TMP}/uppercase-memory-after.txt"
cmp -s "${TEST_TMP}/uppercase-memory-before.txt" "${TEST_TMP}/uppercase-memory-after.txt" \
    || fail "uppercase Memory vault content or metadata changed"
uppercase_memory="${uppercase}/Memory/Agent Memory"
assert_contains "${uppercase_memory}/vault.md" '../13_Current_State.md'
assert_contains "${uppercase_memory}/start.md" '[Existing vault notes](vault.md)'
assert_contains "${TEST_TMP}/uppercase-report-1.txt" 'PRESERVED Memory'
"${uppercase}/.obsidian-memory/scripts/memory.sh" search -- 'nested-uppercase-sentinel' > "${TEST_TMP}/uppercase-search.txt"
assert_contains "${TEST_TMP}/uppercase-search.txt" 'Nested Notes/note [x] &.md'
"${uppercase}/.obsidian-memory/scripts/memory.sh" status > "${TEST_TMP}/uppercase-status.txt"
assert_contains "${TEST_TMP}/uppercase-status.txt" 'vault: Memory/; agent memory: Memory/Agent Memory/'
snapshot_tree "${uppercase}" > "${TEST_TMP}/uppercase-project-1.txt"
bash "${INIT}" --non-interactive "${uppercase}" > "${TEST_TMP}/uppercase-report-2.txt"
snapshot_tree "${uppercase}" > "${TEST_TMP}/uppercase-project-2.txt"
cmp -s "${TEST_TMP}/uppercase-project-1.txt" "${TEST_TMP}/uppercase-project-2.txt" \
    || fail "uppercase Memory migration was not idempotent"

unrelated_memory="${TEST_TMP}/unrelated uppercase directory"
mkdir -p "${unrelated_memory}/Memory"
printf '%s\n' 'not a project memory vault' > "${unrelated_memory}/Memory/random.md"
bash "${INIT}" "${unrelated_memory}" > /dev/null
[[ ! -e "${unrelated_memory}/Memory/Agent Memory" ]] || fail "unrelated Memory directory was misclassified as a vault"
[[ ! -e "${unrelated_memory}/.obsidian-memory" && ! -e "${unrelated_memory}/AGENTS.md" ]] \
    || fail "ambiguous Memory layout received a partial installation"

both_layouts="${TEST_TMP}/both vault layouts"
mkdir -p "${both_layouts}/vault" "${both_layouts}/Memory"
printf '# Index\n' > "${both_layouts}/Memory/00_Index.md"
printf '# State\n' > "${both_layouts}/Memory/13_Current_State.md"
set +e
bash "${INIT}" --strict "${both_layouts}" > "${TEST_TMP}/both-layouts.txt"
both_status=$?
set -e
[[ "${both_status}" -eq 2 ]] || fail "ambiguous dual-vault layout should fail strict installation"
[[ ! -e "${both_layouts}/vault/Agent Memory" && ! -e "${both_layouts}/Memory/Agent Memory" ]] \
    || fail "ambiguous dual-vault layout received Agent Memory"
[[ ! -e "${both_layouts}/.obsidian-memory" && ! -e "${both_layouts}/AGENTS.md" ]] \
    || fail "ambiguous dual-vault layout received a partial installation"
pass "signature-matched uppercase Memory vaults migrate safely without misclassifying arbitrary directories"

# Existing user sources and an unmarked start are preserved; managed conflicts stage once.
existing="${TEST_TMP}/existing agent memory"
bash "${INIT}" "${existing}" > /dev/null
existing_memory="${existing}/Memory/Agent Memory"
existing_helper="${existing}/.obsidian-memory/scripts/memory.sh"
printf '\nuser-owned state detail\n' >> "${existing_memory}/state.md"
cp "${existing_memory}/state.md" "${TEST_TMP}/before/existing-state.md"
printf '%s\n' '# My manually curated start' 'do not replace this' > "${existing_memory}/start.md"
cp "${existing_memory}/start.md" "${TEST_TMP}/before/existing-start.md"
printf '\n# user customization\n' >> "${existing_helper}"
cp "${existing_helper}" "${TEST_TMP}/before/existing-helper.sh"
set +e
bash "${INIT}" --strict "${existing}" > "${TEST_TMP}/strict-report-1.txt"
strict_status=$?
set -e
[[ "${strict_status}" -eq 2 ]] || fail "strict conflict run should exit 2"
cmp -s "${existing_memory}/state.md" "${TEST_TMP}/before/existing-state.md" || fail "existing state changed"
cmp -s "${existing_memory}/start.md" "${TEST_TMP}/before/existing-start.md" || fail "unmarked start changed"
cmp -s "${existing_helper}" "${TEST_TMP}/before/existing-helper.sh" || fail "custom managed helper changed"
start_candidates=$(find "${existing_memory}" -maxdepth 1 -type f -name 'start.md.incoming-*' | wc -l | tr -d ' ')
helper_candidates=$(find "${existing}/.obsidian-memory/scripts" -maxdepth 1 -type f -name 'memory.sh.incoming-*' | wc -l | tr -d ' ')
[[ "${start_candidates}" -eq 1 ]] || fail "expected one deterministic digest candidate"
[[ "${helper_candidates}" -eq 1 ]] || fail "expected one deterministic helper candidate"
set +e
bash "${INIT}" --strict "${existing}" > "${TEST_TMP}/strict-report-2.txt"
strict_status=$?
set -e
[[ "${strict_status}" -eq 2 ]] || fail "strict rerun should report unresolved conflicts"
[[ "$(find "${existing_memory}" -maxdepth 1 -type f -name 'start.md.incoming-*' | wc -l | tr -d ' ')" -eq 1 ]] || fail "strict rerun multiplied digest candidates"
[[ "$(find "${existing}/.obsidian-memory/scripts" -maxdepth 1 -type f -name 'memory.sh.incoming-*' | wc -l | tr -d ' ')" -eq 1 ]] || fail "strict rerun multiplied helper candidates"
assert_contains "${TEST_TMP}/strict-report-1.txt" 'CONFLICT .obsidian-memory/scripts/memory.sh'
assert_contains "${TEST_TMP}/strict-report-1.txt" 'unmarked start preserved'
set +e
"${existing_helper}" startup > "${TEST_TMP}/unmarked-startup.txt" 2> "${TEST_TMP}/unmarked-startup-error.txt"
startup_status=$?
set -e
[[ "${startup_status}" -eq 2 ]] || fail "startup should refuse an unmarked user-owned start"
[[ ! -s "${TEST_TMP}/unmarked-startup.txt" ]] || fail "startup printed an unmarked user-owned start"
assert_contains "${TEST_TMP}/unmarked-startup-error.txt" 'refusing to print it as a generated digest'
pass "existing sources and unmarked digest are preserved with deterministic conflicts"

# Content outside an otherwise valid generated envelope is user-owned and must survive.
extended="${TEST_TMP}/extended marked start"
bash "${INIT}" "${extended}" > /dev/null
extended_memory="${extended}/Memory/Agent Memory"
printf '%s\n' 'user note outside generated envelope' >> "${extended_memory}/start.md"
cp "${extended_memory}/start.md" "${TEST_TMP}/before/extended-start.md"
set +e
bash "${INIT}" --strict "${extended}" > "${TEST_TMP}/extended-report.txt"
extended_status=$?
set -e
[[ "${extended_status}" -eq 2 ]] || fail "extended marked start should be preserved as a conflict"
cmp -s "${extended_memory}/start.md" "${TEST_TMP}/before/extended-start.md" || fail "content outside generated envelope was overwritten"
[[ "$(find "${extended_memory}" -maxdepth 1 -type f -name 'start.md.incoming-*' | wc -l | tr -d ' ')" -eq 1 ]] \
    || fail "extended marked start did not receive one generated candidate"
set +e
"${extended}/.obsidian-memory/scripts/memory.sh" startup > "${TEST_TMP}/extended-startup.txt" 2> /dev/null
extended_startup_status=$?
set -e
[[ "${extended_startup_status}" -eq 2 && ! -s "${TEST_TMP}/extended-startup.txt" ]] \
    || fail "startup printed an externally extended start"
pass "content outside the generated start envelope is treated as user-owned"

# Old top-level memory remains readable but mutating commands are refused.
old_compat="${TEST_TMP}/old top-level compatibility"
mkdir -p "${old_compat}/.obsidian-memory/scripts"
cp -a "${clean_memory}" "${old_compat}/memory"
set +e
bash "${INIT}" --strict "${old_compat}" > "${TEST_TMP}/old-compat-install.txt"
old_install_status=$?
set -e
[[ "${old_install_status}" -eq 2 ]] || fail "old outside-vault memory should require explicit reconciliation"
[[ ! -e "${old_compat}/AGENTS.md" ]] || fail "old outside-vault memory received a partial installation"
cp "${ROOT}/scripts/memory.sh" "${old_compat}/.obsidian-memory/scripts/memory.sh"
printf 'outside-memory-search-sentinel\n' > "${old_compat}/outside.md"
snapshot_tree "${old_compat}/memory" > "${TEST_TMP}/before/old-compat.txt"
"${old_compat}/.obsidian-memory/scripts/memory.sh" startup > /dev/null
"${old_compat}/.obsidian-memory/scripts/memory.sh" status > "${TEST_TMP}/old-compat-status.txt"
"${old_compat}/.obsidian-memory/scripts/memory.sh" search -- 'outside-memory-search-sentinel' > "${TEST_TMP}/old-compat-search.txt"
set +e
"${old_compat}/.obsidian-memory/scripts/memory.sh" refresh > /dev/null 2> "${TEST_TMP}/old-compat-refresh.txt"
old_refresh_status=$?
MEMORY_TIMESTAMP=20260803_130000 "${old_compat}/.obsidian-memory/scripts/memory.sh" new-session > /dev/null 2> "${TEST_TMP}/old-compat-session.txt"
old_session_status=$?
set -e
[[ "${old_refresh_status}" -eq 2 && "${old_session_status}" -eq 2 ]] || fail "old top-level memory accepted a mutating command"
snapshot_tree "${old_compat}/memory" > "${TEST_TMP}/old-compat-after.txt"
cmp -s "${TEST_TMP}/before/old-compat.txt" "${TEST_TMP}/old-compat-after.txt" || fail "read-only compatibility changed old top-level memory"
assert_contains "${TEST_TMP}/old-compat-refresh.txt" 'read-only compatibility'
assert_contains "${TEST_TMP}/old-compat-status.txt" 'vault: none; agent memory: memory/ (read-only compatibility)'
assert_contains "${TEST_TMP}/old-compat-search.txt" 'No memory matches.'

# New session names never overwrite and always refresh Recent links.
MEMORY_TIMESTAMP=20260731_120000 "${clean_helper}" new-session > "${TEST_TMP}/session-1.txt"
first_note="${clean_memory}/sessions/20260731_120000_session.md"
assert_file "${first_note}"
printf '\nfirst-note-sentinel\n' >> "${first_note}"
MEMORY_TIMESTAMP=20260731_120000 "${clean_helper}" new-session > "${TEST_TMP}/session-2.txt"
assert_file "${clean_memory}/sessions/20260731_120000_session_2.md"
assert_contains "${first_note}" 'first-note-sentinel'
assert_count 2 '20260731_120000_session' "${clean_memory}/sessions/index.md"
assert_contains "${clean_memory}/start.md" '[20260731_120000_session_2](sessions/20260731_120000_session_2.md)'
[[ -f "${clean_memory}/sessions/20260731_120000_session_2.md" ]] || fail "recent digest link target does not resolve from start.md"
assert_contains "${TEST_TMP}/session-2.txt" 'REFRESHED Memory/Agent Memory/start.md'
pass "same-second handoffs are non-destructive and refresh the digest"

# Malformed AGENTS markers and symlink destinations fail closed in strict mode.
unsafe="${TEST_TMP}/unsafe"
mkdir -p "${unsafe}/.obsidian-memory/scripts"
printf '%s\n' '<!-- obsidian-memory:start v2 -->' 'custom partial block' > "${unsafe}/AGENTS.md"
outside="${TEST_TMP}/outside-helper"
printf '%s\n' 'outside sentinel' > "${outside}"
ln -s "${outside}" "${unsafe}/.obsidian-memory/scripts/memory.sh"
set +e
bash "${INIT}" --strict "${unsafe}" > "${TEST_TMP}/unsafe-report.txt"
unsafe_status=$?
set -e
[[ "${unsafe_status}" -eq 2 ]] || fail "unsafe strict install should exit 2"
assert_contains "${outside}" 'outside sentinel'
assert_count 1 '<!-- obsidian-memory:start v2 -->' "${unsafe}/AGENTS.md"
assert_contains "${TEST_TMP}/unsafe-report.txt" 'refusing to replace a symlink'
assert_contains "${TEST_TMP}/unsafe-report.txt" 'malformed or duplicate memory markers'
pass "malformed instructions and symlinks are preserved and reported"

# Unsafe parent symlinks must not receive child writes, including report output.
target_real="${TEST_TMP}/target symlink real"
target_link="${TEST_TMP}/target symlink"
mkdir -p "${target_real}"
ln -s "${target_real}" "${target_link}"
set +e
bash "${INIT}" --strict "${target_link}" > /dev/null 2> "${TEST_TMP}/target-symlink-error.txt"
target_link_status=$?
set -e
[[ "${target_link_status}" -eq 2 ]] || fail "symlink supplied as installer target should be refused"
[[ ! -e "${target_real}/Memory" && ! -e "${target_real}/AGENTS.md" ]] || fail "installer wrote through a symlinked target root"
assert_contains "${TEST_TMP}/target-symlink-error.txt" 'symlinked target path'

target_parent_real="${TEST_TMP}/target parent real"
target_parent_link="${TEST_TMP}/target parent link"
mkdir -p "${target_parent_real}"
ln -s "${target_parent_real}" "${target_parent_link}"
set +e
bash "${INIT}" --strict "${target_parent_link}/new project" > /dev/null 2> "${TEST_TMP}/target-parent-error.txt"
target_parent_status=$?
set -e
[[ "${target_parent_status}" -eq 2 ]] || fail "symlinked ancestor of installer target should be refused"
[[ ! -e "${target_parent_real}/new project" ]] || fail "installer created a target through a symlinked ancestor"

bundle_parent_unsafe="${TEST_TMP}/skill bundle parent symlink"
outside_bundle="${TEST_TMP}/outside skill bundle"
mkdir -p "${bundle_parent_unsafe}/Memory/.obsidian" "${outside_bundle}"
printf 'outside-bundle-sentinel\n' > "${outside_bundle}/sentinel"
bundle_before=$(snapshot_tree "${bundle_parent_unsafe}/Memory")
outside_bundle_before=$(snapshot_tree "${outside_bundle}")
ln -s "${outside_bundle}" "${bundle_parent_unsafe}/.obsidian-memory"
set +e
bash "${INIT}" --strict "${bundle_parent_unsafe}" > "${TEST_TMP}/bundle-parent-report.txt"
bundle_parent_status=$?
set -e
[[ "${bundle_parent_status}" -eq 2 ]] || fail "symlinked skill-bundle parent should fail strict installation"
[[ "$(snapshot_tree "${bundle_parent_unsafe}/Memory")" == "${bundle_before}" ]] || fail "skill-bundle parent conflict modified the existing vault"
[[ "$(snapshot_tree "${outside_bundle}")" == "${outside_bundle_before}" ]] || fail "skill-bundle parent symlink caused an external write"
[[ ! -e "${bundle_parent_unsafe}/Memory/Agent Memory" && ! -e "${bundle_parent_unsafe}/AGENTS.md" ]] \
    || fail "skill-bundle parent conflict left a partial installation"
assert_contains "${TEST_TMP}/bundle-parent-report.txt" 'CONFLICT .obsidian-memory'

parent_unsafe="${TEST_TMP}/parent symlink unsafe"
outside_memory="${TEST_TMP}/outside memory"
mkdir -p "${parent_unsafe}/Memory/.obsidian" "${outside_memory}"
ln -s "${outside_memory}" "${parent_unsafe}/Memory/Agent Memory"
set +e
bash "${INIT}" --strict "${parent_unsafe}" > "${TEST_TMP}/parent-unsafe-report.txt"
parent_unsafe_status=$?
set -e
[[ "${parent_unsafe_status}" -eq 2 ]] || fail "symlinked Agent Memory parent should make strict install fail"
[[ ! -e "${outside_memory}/sessions" ]] || fail "installer wrote sessions through a rejected Agent Memory symlink"
assert_contains "${TEST_TMP}/parent-unsafe-report.txt" 'refusing to follow a directory symlink'

helper_parent_unsafe="${TEST_TMP}/helper symlinked vault parent"
outside_helper_vault="${TEST_TMP}/outside helper vault"
mkdir -p "${helper_parent_unsafe}/.obsidian-memory/scripts" "${outside_helper_vault}"
cp "${ROOT}/scripts/memory.sh" "${helper_parent_unsafe}/.obsidian-memory/scripts/memory.sh"
cp -a "${clean_memory}" "${outside_helper_vault}/Agent Memory"
ln -s "${outside_helper_vault}" "${helper_parent_unsafe}/Memory"
helper_start_before=$(cksum "${outside_helper_vault}/Agent Memory/start.md")
set +e
"${helper_parent_unsafe}/.obsidian-memory/scripts/memory.sh" refresh > "${TEST_TMP}/helper-parent-unsafe.txt" 2>&1
helper_parent_status=$?
set -e
[[ "${helper_parent_status}" -eq 2 ]] || fail "memory helper accepted Agent Memory through a symlinked vault parent"
[[ "$(cksum "${outside_helper_vault}/Agent Memory/start.md")" == "${helper_start_before}" ]] || fail "memory helper wrote through a symlinked vault parent"
assert_contains "${TEST_TMP}/helper-parent-unsafe.txt" 'refusing to use Agent Memory through a symlinked vault'

report_real="${TEST_TMP}/report real"
report_link="${TEST_TMP}/report link"
mkdir -p "${report_real}"
ln -s "${report_real}" "${report_link}"
report_rejected_target="${TEST_TMP}/report rejected target"
set +e
bash "${INIT}" --report "${report_link}/migration.txt" "${report_rejected_target}" > /dev/null 2> "${TEST_TMP}/report-link-error.txt"
report_link_status=$?
set -e
[[ "${report_link_status}" -eq 2 ]] || fail "symlinked report parent should be refused"
[[ ! -e "${report_real}/migration.txt" ]] || fail "installer wrote a report through a symlinked parent"
[[ ! -e "${report_rejected_target}" ]] || fail "installer modified the target before rejecting an unsafe report path"
assert_contains "${TEST_TMP}/report-link-error.txt" 'symlinked parent path'
bash "${INIT}" --report "${TEST_TMP}/migration.txt" "${clean}" > /dev/null
assert_file "${TEST_TMP}/migration.txt"
pass "rejected parent symlinks receive no child or report writes"

# Large source/history growth cannot inflate the generated cold-start digest.
growth="${TEST_TMP}/growth"
bash "${INIT}" "${growth}" > /dev/null
growth_memory="${growth}/Memory/Agent Memory"
growth_helper="${growth}/.obsidian-memory/scripts/memory.sh"
{
    printf '%s\n\n' '# Now'
    for ((i = 1; i <= 400; i++)); do
        printf -- '- Current-state fact %03d with enough explanatory text to exercise deterministic truncation.\n' "${i}"
    done
    printf '\n%s\n\n' '# Constraints'
    for ((i = 1; i <= 20; i++)); do
        printf -- '- Constraint %03d with supporting detail.\n' "${i}"
    done
    printf '\n%s\n\n' '# Risks'
    for ((i = 1; i <= 20; i++)); do
        printf -- '- Risk %03d with supporting detail.\n' "${i}"
    done
    printf '\n%s\n' '# Detail'
    printf '%s\n' 'Long-form state remains here.'
} > "${growth_memory}/state.md"
{
    printf '%s\n\n' '# Active'
    for ((i = 1; i <= 400; i++)); do
        printf -- '- [ ] Backlog task %03d with detail that remains in the source file.\n' "${i}"
    done
} > "${growth_memory}/backlog.md"
for ((i = 1; i <= 60; i++)); do
    MEMORY_TIMESTAMP=20260803_120000 "${growth_helper}" new-session > /dev/null
done
start_lines=$(wc -l < "${growth_memory}/start.md" | tr -d ' ')
start_bytes=$(wc -c < "${growth_memory}/start.md" | tr -d ' ')
[[ "${start_lines}" -le 80 ]] || fail "growth digest exceeds 80 lines: ${start_lines}"
[[ "${start_bytes}" -le 3000 ]] || fail "growth digest exceeds 3000 bytes: ${start_bytes}"
[[ "$(section_count "${growth_memory}/start.md" '## Now')" -le 12 ]] || fail "growth digest includes more than 12 Now lines"
[[ "$(section_count "${growth_memory}/start.md" '## Active')" -le 5 ]] || fail "growth digest includes more than 5 Active tasks"
[[ "$(section_count "${growth_memory}/start.md" '## Recent')" -le 5 ]] || fail "growth digest includes more than 5 Recent links"
assert_contains "${growth_memory}/state.md" 'Current-state fact 400'
assert_contains "${growth_memory}/backlog.md" 'Backlog task 400'
session_count=$(find "${growth_memory}/sessions" -maxdepth 1 -type f -name '*_session*.md' | wc -l | tr -d ' ')
[[ "${session_count}" -eq 60 ]] || fail "expected 60 retained session notes; got ${session_count}"
[[ "$(grep -F -c -- '- [20260803_120000_session' "${growth_memory}/sessions/index.md")" -eq 60 ]] || fail "session index lost history"
assert_contains "${growth_memory}/start.md" '[State](state.md)'
assert_contains "${growth_memory}/start.md" '[Backlog](backlog.md)'
assert_contains "${growth_memory}/start.md" '[Decisions](decisions.md)'
assert_contains "${growth_memory}/start.md" '[Sessions](sessions/index.md)'
touch -t 200001010000 "${growth_memory}/start.md"
start_snapshot=$(stat -c '%Y %s' "${growth_memory}/start.md")
refresh_output=$("${growth_helper}" refresh)
[[ "${refresh_output}" == 'UNCHANGED Memory/Agent Memory/start.md' ]] || fail "unchanged refresh did not report unchanged"
[[ "$(stat -c '%Y %s' "${growth_memory}/start.md")" == "${start_snapshot}" ]] || fail "unchanged refresh changed digest metadata"
pass "400-line state, 400 tasks, and 60 sessions remain behind a hard bounded digest"

# Byte budgeting must not change when the caller's character locale changes.
unicode="${TEST_TMP}/unicode locale"
bash "${INIT}" "${unicode}" > /dev/null
unicode_memory="${unicode}/Memory/Agent Memory"
unicode_helper="${unicode}/.obsidian-memory/scripts/memory.sh"
unicode_line='- '
for ((i = 1; i <= 80; i++)); do
    unicode_line+='🙂'
done
printf '# Now\n\n%s\n\n# Constraints\n\n- Keep Unicode in the source.\n\n# Risks\n\n- None.\n' "${unicode_line}" > "${unicode_memory}/state.md"
LC_ALL=C "${unicode_helper}" refresh > /dev/null
cp "${unicode_memory}/start.md" "${TEST_TMP}/before/unicode-start.md"
utf8_locale=$(locale -a 2>/dev/null | awk 'tolower($0) == "c.utf8" || tolower($0) == "c.utf-8" { print; exit }')
if [[ -n "${utf8_locale}" ]]; then
    locale_refresh=$(LC_ALL="${utf8_locale}" "${unicode_helper}" refresh)
    [[ "${locale_refresh}" == 'UNCHANGED Memory/Agent Memory/start.md' ]] || fail "Unicode digest changed across C locales"
    cmp -s "${unicode_memory}/start.md" "${TEST_TMP}/before/unicode-start.md" || fail "Unicode digest bytes depend on locale"
fi
assert_contains "${unicode_memory}/start.md" 'Oversized line; see source.'
assert_contains "${unicode_memory}/state.md" '🙂'
pass "Unicode source stays intact and digest byte budgeting is locale-independent"

# Deterministic startup-size proxies and retained discovery routes.
measurement=$(bash "${ROOT}/scripts/measure_context.sh" "${FIXTURE}" "${clean}")
printf '%s\n' "${measurement}" > "${TEST_TMP}/measurement.txt"
awk '/bytes \(exact\)/ { if ($3 <= $4 || (($3-$4)*100/$3) < 50) exit 1; found=1 } END { if (!found) exit 1 }' "${TEST_TMP}/measurement.txt" \
    || fail "byte proxy did not show at least 50% reduction"
awk '/words \(wc whitespace proxy\)/ { if ($5 <= $6) exit 1; found=1 } END { if (!found) exit 1 }' "${TEST_TMP}/measurement.txt" \
    || fail "word proxy did not decrease"
assert_contains "${TEST_TMP}/measurement.txt" 'not tokenizer-exact'
assert_contains "${TEST_TMP}/measurement.txt" 'Discovery check: PASS'
pass "measurement reports an honest reduction and verifies discovery"

echo "1..${PASSED}"
