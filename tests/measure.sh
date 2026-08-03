#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MEASURE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/obsidian-memory-measure.XXXXXX")
trap 'rm -rf -- "${MEASURE_TMP}"' EXIT

bash "${ROOT}/init.sh" --non-interactive "${MEASURE_TMP}/new-install" >/dev/null
bash "${ROOT}/scripts/measure_context.sh" \
    "${ROOT}/tests/fixtures/legacy-install" \
    "${MEASURE_TMP}/new-install"
