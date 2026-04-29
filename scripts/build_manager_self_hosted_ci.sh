#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_ROOT="${FPDEV_TEST_TMPDIR:-${TMPDIR:-/tmp}}/fpdev-build-manager-ci.$$"

cleanup() {
  rm -rf "${TMP_ROOT}" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p \
  "${TMP_ROOT}/bin" \
  "${TMP_ROOT}/lib/logger" \
  "${TMP_ROOT}/lib/testresults" \
  "${TMP_ROOT}/lib/strict" \
  "${TMP_ROOT}/lib/fullbuild"
cd "${REPO_ROOT}"

echo "[build-manager-ci] checking local toolchain"
bash scripts/check_toolchain.sh

echo "[build-manager-ci] running docs truth contracts"
python3 -m unittest \
  tests.test_build_manager_docs_truth_contract \
  tests.test_contributor_docs_contract \
  -v

echo "[build-manager-ci] compiling focused BuildManager suites"
fpc -B -Fusrc -Fisrc -Fu./tests \
  -FE"${TMP_ROOT}/bin" -FU"${TMP_ROOT}/lib/logger" \
  tests/test_build_logger.lpr
fpc -B -Fusrc -Fisrc -Fu./tests \
  -FE"${TMP_ROOT}/bin" -FU"${TMP_ROOT}/lib/testresults" \
  tests/test_build_testresultsflow.lpr
fpc -B -Fusrc -Fisrc -Fu./tests \
  -FE"${TMP_ROOT}/bin" -FU"${TMP_ROOT}/lib/strict" \
  tests/fpdev.build.manager/test_build_manager_make_missing.lpr
fpc -B -Fusrc -Fisrc -Fu./tests \
  -FE"${TMP_ROOT}/bin" -FU"${TMP_ROOT}/lib/fullbuild" \
  tests/test_build_fullbuildflow.lpr

echo "[build-manager-ci] running focused BuildManager suites"
"${TMP_ROOT}/bin/test_build_logger"
"${TMP_ROOT}/bin/test_build_testresultsflow"
"${TMP_ROOT}/bin/test_build_manager_make_missing"
"${TMP_ROOT}/bin/test_build_fullbuildflow"

echo "[build-manager-ci] running demo strict suites"
bash tests/fpdev.build.manager/run_tests.sh

echo "[build-manager-ci] complete"
