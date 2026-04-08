#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release_acceptance_linux.sh [--with-install] [--keep-temp]

Run the bounded Linux release acceptance lane for FPDev v2.1.0.

This script verifies:
  - local toolchain prerequisites
  - test inventory sync
  - Python regression suite
  - focused IO bridge stability gate
  - full Pascal regression suite
  - shared Release build entrypoint
  - CLI smoke commands with isolated FPDEV data roots

Options:
  --with-install  Also run the network-gated isolated binary-install lane
  --keep-temp     Keep the temporary FPDEV data root for debugging
  --help,-h       Show this help

Output:
  logs/release_acceptance/<timestamp>/
EOF
}

WITH_INSTALL=0
KEEP_TEMP=0

for arg in "$@"; do
  case "$arg" in
    --with-install) WITH_INSTALL=1 ;;
    --keep-temp) KEEP_TEMP=1 ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${REPO_ROOT}/logs/release_acceptance/${STAMP}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/fpdev-release-XXXXXX")"
DATA_ROOT="${TMP_ROOT}/fpdev-data"
LAZARUS_CONFIG_ROOT="${TMP_ROOT}/lazarus-config"
SUMMARY_FILE="${RUN_DIR}/summary.txt"
RELEASE_BIN_PATH_FILE="${RUN_DIR}/release-bin-path.txt"
RELEASE_BIN="${REPO_ROOT}/bin/fpdev"

mkdir -p "${RUN_DIR}" "${DATA_ROOT}" "${LAZARUS_CONFIG_ROOT}"

cleanup() {
  if [[ "${KEEP_TEMP}" == "1" ]]; then
    echo "[INFO] Keeping temp root: ${TMP_ROOT}"
    return 0
  fi
  rm -rf "${TMP_ROOT}" 2>/dev/null || true
}

trap cleanup EXIT

export TMPDIR="${TMP_ROOT}"
export TMP="${TMP_ROOT}"
export TEMP="${TMP_ROOT}"
export FPDEV_DATA_ROOT="${DATA_ROOT}"
export FPDEV_LAZARUS_CONFIG_ROOT="${LAZARUS_CONFIG_ROOT}"
export FPDEV_TEST_LOG_ROOT="${RUN_DIR}/pascal_regression_logs"
export FPDEV_SKIP_NETWORK_TESTS="${FPDEV_SKIP_NETWORK_TESTS:-1}"
export FPDEV_RELEASE_BUILD_ROOT="${TMP_ROOT}/release-build"
export FPDEV_RELEASE_BIN_PATH_FILE="${RELEASE_BIN_PATH_FILE}"
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

step() {
  echo
  echo "== $1 =="
}

assert_no_cjk() {
  local log_file="$1"
  python3 - "$log_file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8', errors='ignore')
if re.search(r'[\u3400-\u9fff\uF900-\uFAFF]', text):
    print(f'[FAIL] CJK characters detected in {path}', file=sys.stderr)
    sys.exit(1)
PY
}

run_logged() {
  local name="$1"
  shift
  local log_file="${RUN_DIR}/${name}.log"
  echo "+ $*" | tee "${log_file}"
  (
    cd "${REPO_ROOT}"
    "$@" 2>&1 | tee -a "${log_file}"
  )
}

run_repeated_focused_test() {
  local name="$1"
  local repeat_count="$2"
  local test_file="$3"
  local log_file="${RUN_DIR}/${name}.log"
  local attempt=0

  : >"${log_file}"

  for attempt in $(seq 1 "${repeat_count}"); do
    echo "+ attempt ${attempt}/${repeat_count}: bash scripts/run_single_test.sh ${test_file}" | tee -a "${log_file}"
    (
      cd "${REPO_ROOT}"
      bash scripts/run_single_test.sh "${test_file}" 2>&1 | tee -a "${log_file}"
    )
  done
}

run_cli_smoke() {
  local name="$1"
  local expected_exit="$2"
  shift 2

  local log_file="${RUN_DIR}/${name}.log"
  local status=0

  (
    cd "${REPO_ROOT}"
    "$@" >"${log_file}" 2>&1
  ) || status=$?

  if [[ "${status}" -ne "${expected_exit}" ]]; then
    echo "[FAIL] ${name} exited ${status}, expected ${expected_exit}" >&2
    cat "${log_file}" >&2
    return 1
  fi

  assert_no_cjk "${log_file}"
}

assert_log_contains() {
  local name="$1"
  local needle="$2"
  local log_file="${RUN_DIR}/${name}.log"

  if ! grep -Fq "${needle}" "${log_file}"; then
    echo "[FAIL] ${name} did not contain expected text: ${needle}" >&2
    cat "${log_file}" >&2
    return 1
  fi
}

append_summary() {
  cat <<EOF >>"${SUMMARY_FILE}"
$1
EOF
}

step "Environment"
cat <<EOF | tee "${SUMMARY_FILE}"
FPDev Linux Release Acceptance
timestamp: ${STAMP}
repo_root: ${REPO_ROOT}
run_dir: ${RUN_DIR}
temp_root: ${TMP_ROOT}
with_install: ${WITH_INSTALL}
EOF

step "Toolchain baseline"
run_logged toolchain_check bash scripts/check_toolchain.sh
append_summary "toolchain_check: pass"

step "Test inventory sync"
run_logged test_inventory_sync python3 scripts/update_test_stats.py --check
append_summary "test_inventory_sync: pass"

step "Python regression suite"
run_logged python_regression python3 -m unittest discover -s tests -p 'test_*.py'
append_summary "python_regression: pass"

step "IO bridge stability gate"
run_repeated_focused_test iobridge_stability 5 tests/test_fpc_installer_iobridge.lpr
append_summary "iobridge_stability: pass"

step "Full Pascal regression suite"
run_logged pascal_regression bash scripts/run_all_tests.sh
append_summary "pascal_regression: pass"

step "Release build"
run_logged release_build bash scripts/build_release.sh
if [[ -s "${RELEASE_BIN_PATH_FILE}" ]]; then
  RELEASE_BIN="$(head -n 1 "${RELEASE_BIN_PATH_FILE}")"
fi
if [[ ! -x "${RELEASE_BIN}" ]]; then
  echo "[FAIL] release binary missing or not executable: ${RELEASE_BIN}" >&2
  exit 1
fi
append_summary "release_build: pass"

step "CLI smoke"
run_cli_smoke system_help 0 "${RELEASE_BIN}" system help
assert_log_contains system_help "Available subcommands"
append_summary "system_help: pass"

run_cli_smoke system_version 0 "${RELEASE_BIN}" system version
assert_log_contains system_version "fpdev version 2.1.0"
append_summary "system_version: pass"

run_cli_smoke fpc_help 0 "${RELEASE_BIN}" fpc --help
assert_log_contains fpc_help "install"
assert_log_contains fpc_help "list"
append_summary "fpc_help: pass"

run_cli_smoke fpc_list_all 0 "${RELEASE_BIN}" fpc list --all
assert_log_contains fpc_list_all "3.2.2"
append_summary "fpc_list_all: pass"

run_cli_smoke system_toolchain_check 0 "${RELEASE_BIN}" system toolchain check
append_summary "system_toolchain_check: pass"

run_cli_smoke fpc_test 0 "${RELEASE_BIN}" fpc test
append_summary "fpc_test: pass"

if [[ "${WITH_INSTALL}" == "1" ]]; then
  step "Network-gated isolated install lane"
  unset FPDEV_SKIP_NETWORK_TESTS || true

  run_cli_smoke fpc_install_322 0 "${RELEASE_BIN}" fpc install 3.2.2
  run_cli_smoke fpc_use_322 0 "${RELEASE_BIN}" fpc use 3.2.2
  run_cli_smoke fpc_current_322 0 "${RELEASE_BIN}" fpc current
  assert_log_contains fpc_current_322 "3.2.2"
  run_cli_smoke fpc_verify_322 0 "${RELEASE_BIN}" fpc verify 3.2.2

  append_summary "fpc_install_322: pass"
  append_summary "fpc_use_322: pass"
  append_summary "fpc_current_322: pass"
  append_summary "fpc_verify_322: pass"
fi

step "Complete"
append_summary "status: pass"
echo "Release acceptance passed. Logs: ${RUN_DIR}"
