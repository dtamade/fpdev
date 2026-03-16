#!/bin/bash
# Run all FPDev tests and collect results

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
TEST_TMP_ROOT=""
TEST_DATA_ROOT=""
TEST_LAZARUS_CONFIG_ROOT=""

# Arrays to store results
declare -a FAILED_TESTS
declare -a PASSED_TESTS
declare -a TEST_FILES

create_test_tmp_root() {
  local tmp_root=""
  tmp_root="$(mktemp -d /tmp/fpdev-tests.XXXXXX 2>/dev/null || true)"
  if [ -z "${tmp_root}" ] || [ ! -d "${tmp_root}" ]; then
    tmp_root="/tmp/fpdev-tests.$$"
    mkdir -p "${tmp_root}"
  fi
  printf '%s\n' "${tmp_root}"
}

init_test_environment() {
  TEST_TMP_ROOT="$(create_test_tmp_root)"
  TEST_DATA_ROOT="${TEST_TMP_ROOT}/fpdev-data"
  TEST_LAZARUS_CONFIG_ROOT="${TEST_TMP_ROOT}/lazarus-config"
  mkdir -p "${TEST_DATA_ROOT}" "${TEST_LAZARUS_CONFIG_ROOT}"

  export FPDEV_DATA_ROOT="${TEST_DATA_ROOT}"
  export FPDEV_LAZARUS_CONFIG_ROOT="${TEST_LAZARUS_CONFIG_ROOT}"
  export FPDEV_SKIP_NETWORK_TESTS="${FPDEV_SKIP_NETWORK_TESTS:-1}"
}

cleanup() {
  if [ -z "${TEST_TMP_ROOT}" ]; then
    return 0
  fi
  if [ "${FPDEV_TEST_KEEP_TEMP:-0}" = "1" ]; then
    echo "[INFO] Keeping test temp dir: ${TEST_TMP_ROOT}"
    return 0
  fi
  rm -rf "${TEST_TMP_ROOT}" 2>/dev/null || true
}

print_banner() {
  echo "========================================"
  echo "Running All FPDev Tests"
  echo "========================================"
  echo ""
}

load_test_inventory() {
  mapfile -t TEST_FILES < <(python3 "${SCRIPT_DIR}/update_test_stats.py" --list)
}

run_test_binary() {
  local bin_path="$1"
  local log_path="$2"

  if "${bin_path}" --all >"${log_path}" 2>&1; then
    return 0
  fi

  if "${bin_path}" >"${log_path}" 2>&1; then
    return 0
  fi

  return 1
}

cleanup_compiled_state_files() {
  find lib -type f -name "*.compiled" -delete 2>/dev/null || true
}

cleanup_compiler_artifact_files() {
  find lib -type f \( \
    -name "*.o" -o \
    -name "*.ppu" -o \
    -name "*.a" -o \
    -name "*.or" -o \
    -name "*.rst" \
  \) -delete 2>/dev/null || true
}

is_compiled_state_corruption() {
  local build_log="$1"
  grep -Eq \
    "Root element is missing|Error reading file|Invalid header size|\\.compiled" \
    "$build_log"
}

is_transient_build_failure() {
  local build_log="$1"
  grep -Eq \
    "Can't call the linker|Failed to execute \"/usr/bin/ld|Resource temporarily unavailable|Text file busy|No space left on device|Disk quota exceeded|bad reloc symbol index|failed to set dynamic section sizes: bad value" \
    "$build_log"
}

build_test_with_fallback() {
  local test_lpi="$1"
  local test_file="$2"
  local test_bin_dir="$3"
  local build_log="$4"
  local test_unit_dir=""

  test_unit_dir="${test_bin_dir}/lib"

  if [ -f "$test_lpi" ]; then
    if lazbuild -B "$test_lpi" >>"$build_log" 2>&1; then
      return 0
    fi

    if is_compiled_state_corruption "$build_log"; then
      echo "[run_all_tests] detected compiled-state corruption, cleaning and retrying lazbuild once" >>"$build_log"
      cleanup_compiled_state_files
      if lazbuild -B "$test_lpi" >>"$build_log" 2>&1; then
        return 0
      fi
    elif is_transient_build_failure "$build_log"; then
      echo "[run_all_tests] detected transient build failure, retrying lazbuild once" >>"$build_log"
      if lazbuild -B "$test_lpi" >>"$build_log" 2>&1; then
        return 0
      fi
    fi
  fi

  echo "[run_all_tests] lazbuild failed, trying direct fpc fallback" >>"$build_log"
  mkdir -p "$test_unit_dir"
  if fpc -Fusrc -Fisrc -FE"$test_bin_dir" -FU"$test_unit_dir" "$test_file" >>"$build_log" 2>&1; then
    return 0
  fi

  return 1
}

extract_lpi_target_binary() {
  local lpi_path="$1"

  awk '
    /<Target>/ { in_target=1; next }
    /<\/Target>/ { in_target=0 }
    in_target && match($0, /Filename Value="([^"]+)"/, m) {
      print m[1]
      exit
    }
  ' "$lpi_path"
}

get_test_binary_candidates() {
  local preferred_bin="$1"
  local test_dir="$2"
  local test_name="$3"
  local test_lpi="$4"
  local lpi_target=""

  printf '%s\n' "$preferred_bin"
  printf '%s\n' "${preferred_bin}.exe"
  printf '%s\n' "bin/${test_name}"
  printf '%s\n' "bin/${test_name}.exe"

  if [ -f "$test_lpi" ]; then
    lpi_target="$(extract_lpi_target_binary "$test_lpi")"
    if [ -n "$lpi_target" ]; then
      case "$lpi_target" in
        /*|[A-Za-z]:[\\/]* )
          printf '%s\n' "$lpi_target"
          printf '%s\n' "${lpi_target}.exe"
          ;;
        *)
          printf '%s\n' "${test_dir}/${lpi_target}"
          printf '%s\n' "${test_dir}/${lpi_target}.exe"
          ;;
      esac
    fi
  fi
}

cleanup_test_binary_candidates() {
  local preferred_bin="$1"
  local test_dir="$2"
  local test_name="$3"
  local test_lpi="$4"
  local candidate=""

  while IFS= read -r candidate; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      rm -f "$candidate" 2>/dev/null || true
    fi
  done < <(get_test_binary_candidates "$preferred_bin" "$test_dir" "$test_name" "$test_lpi")
}

resolve_test_binary_path() {
  local preferred_bin="$1"
  local test_dir="$2"
  local test_name="$3"
  local test_lpi="$4"
  local candidate=""

  while IFS= read -r candidate; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(get_test_binary_candidates "$preferred_bin" "$test_dir" "$test_name" "$test_lpi")

  return 1
}

has_valid_test_binary() {
  local preferred_bin="$1"
  local test_dir="$2"
  local test_name="$3"
  local test_lpi="$4"
  local resolved_bin=""

  if ! resolved_bin="$(resolve_test_binary_path "$preferred_bin" "$test_dir" "$test_name" "$test_lpi")"; then
    return 1
  fi

  [ -s "$resolved_bin" ]
}

build_test_with_recovery() {
  local test_lpi="$1"
  local test_file="$2"
  local preferred_bin="$3"
  local test_dir="$4"
  local test_name="$5"
  local build_log="$6"
  local test_bin_dir=""
  local build_success=false

  test_bin_dir="$(dirname "$preferred_bin")"
  : >"$build_log"

  cleanup_test_binary_candidates "$preferred_bin" "$test_dir" "$test_name" "$test_lpi"
  if build_test_with_fallback "$test_lpi" "$test_file" "$test_bin_dir" "$build_log"; then
    build_success=true
  fi

  if [ "$build_success" = true ] && has_valid_test_binary "$preferred_bin" "$test_dir" "$test_name" "$test_lpi"; then
    return 0
  fi

  if [ "$build_success" != true ] && { is_compiled_state_corruption "$build_log" || is_transient_build_failure "$build_log"; }; then
    echo "[run_all_tests] build failed with recoverable compiler/linker noise, cleaning outputs and retrying once" >>"$build_log"
    cleanup_compiled_state_files
    cleanup_compiler_artifact_files
    cleanup_test_binary_candidates "$preferred_bin" "$test_dir" "$test_name" "$test_lpi"

    if build_test_with_fallback "$test_lpi" "$test_file" "$test_bin_dir" "$build_log" \
      && has_valid_test_binary "$preferred_bin" "$test_dir" "$test_name" "$test_lpi"; then
      return 0
    fi
  fi

  if [ "$build_success" = true ]; then
    echo "[run_all_tests] build completed without a runnable binary, cleaning outputs and retrying once" >>"$build_log"
    cleanup_compiled_state_files
    cleanup_compiler_artifact_files
    cleanup_test_binary_candidates "$preferred_bin" "$test_dir" "$test_name" "$test_lpi"

    if build_test_with_fallback "$test_lpi" "$test_file" "$test_bin_dir" "$build_log" \
      && has_valid_test_binary "$preferred_bin" "$test_dir" "$test_name" "$test_lpi"; then
      return 0
    fi
  fi

  if ! has_valid_test_binary "$preferred_bin" "$test_dir" "$test_name" "$test_lpi"; then
    echo "[run_all_tests] missing or zero-byte test binary after build" >>"$build_log"
  fi

  return 1
}

run_single_test() {
  local test_file="$1"
  local test_name=""
  local test_dir=""
  local test_lpi=""
  local test_log=""
  local build_log=""
  local test_bin=""
  local test_bin_dir=""
  local run_bin=""

  TOTAL=$((TOTAL + 1))
  test_name="$(basename "$test_file" .lpr)"
  test_dir="$(dirname "$test_file")"
  test_lpi="${test_file%.lpr}.lpi"
  test_log="${TEST_TMP_ROOT}/${test_name}.log"
  build_log="${TEST_TMP_ROOT}/${test_name}.build.log"

  if [ "$test_dir" != "tests" ]; then
    test_bin="${test_dir}/bin/${test_name}"
    test_bin_dir="${test_dir}/bin"
  else
    test_bin="bin/${test_name}"
    test_bin_dir="bin"
  fi

  mkdir -p "$test_bin_dir"

  echo -n "[$TOTAL] Testing $test_name... "

  if build_test_with_recovery "$test_lpi" "$test_file" "$test_bin" "$test_dir" "$test_name" "$build_log"; then
    if run_bin="$(resolve_test_binary_path "$test_bin" "$test_dir" "$test_name" "$test_lpi")" \
      && run_test_binary "$run_bin" "$test_log"; then
      echo -e "${GREEN}PASSED${NC}"
      PASSED=$((PASSED + 1))
      PASSED_TESTS+=("$test_name")
    else
      echo -e "${RED}FAILED${NC}"
      FAILED=$((FAILED + 1))
      FAILED_TESTS+=("$test_name")
      echo -e "${YELLOW}  log: ${test_log}${NC}"
    fi
  else
    echo -e "${RED}BUILD FAILED${NC}"
    FAILED=$((FAILED + 1))
    FAILED_TESTS+=("$test_name")
    echo -e "${YELLOW}  build log: ${build_log}${NC}"
  fi
}

print_summary() {
  local test_name=""

  echo ""
  echo "========================================"
  echo "Test Results Summary"
  echo "========================================"
  echo "Total:   $TOTAL"
  echo -e "${GREEN}Passed:  $PASSED${NC}"
  echo -e "${RED}Failed:  $FAILED${NC}"
  echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
  echo ""

  if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Failed Tests:${NC}"
    for test_name in "${FAILED_TESTS[@]}"; do
      echo "  - $test_name"
    done
    echo ""
    return 1
  fi

  echo -e "${GREEN}All tests passed!${NC}"
  return 0
}

main() {
  local test_file=""

  set -e
  cd "$REPO_ROOT"
  init_test_environment
  trap cleanup EXIT

  print_banner
  load_test_inventory

  for test_file in "${TEST_FILES[@]}"; do
    run_single_test "$test_file"
  done

  print_summary
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
