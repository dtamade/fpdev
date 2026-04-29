#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BIN_DIR="${TMPDIR:-/tmp}/fpdev-git2-modern-bin"
LIB_DIR="${TMPDIR:-/tmp}/fpdev-git2-modern-lib"

mkdir -p "${BIN_DIR}" "${LIB_DIR}"

cd "${REPO_ROOT}"
fpc -Fusrc -Fisrc -Fu./tests -FE"${BIN_DIR}" -FU"${LIB_DIR}" tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr
"${BIN_DIR}/fpdev.git2.modern.basic"
