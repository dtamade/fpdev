#!/bin/bash
# Run all FPDev tests and collect results

set -e

# Isolated environment (avoid touching real user config)
TEST_TMP_ROOT="$(mktemp -d /tmp/fpdev-tests.XXXXXX 2>/dev/null || true)"
if [ -z "${TEST_TMP_ROOT}" ] || [ ! -d "${TEST_TMP_ROOT}" ]; then
  TEST_TMP_ROOT="/tmp/fpdev-tests.$$"
  mkdir -p "${TEST_TMP_ROOT}"
fi

TEST_DATA_ROOT="${TEST_TMP_ROOT}/fpdev-data"
TEST_LAZARUS_CONFIG_ROOT="${TEST_TMP_ROOT}/lazarus-config"
mkdir -p "${TEST_DATA_ROOT}" "${TEST_LAZARUS_CONFIG_ROOT}"

export FPDEV_DATA_ROOT="${TEST_DATA_ROOT}"
export FPDEV_LAZARUS_CONFIG_ROOT="${TEST_LAZARUS_CONFIG_ROOT}"

# Default: keep test suite offline/deterministic
export FPDEV_SKIP_NETWORK_TESTS="${FPDEV_SKIP_NETWORK_TESTS:-1}"

cleanup() {
  if [ "${FPDEV_TEST_KEEP_TEMP:-0}" = "1" ]; then
    echo "[INFO] Keeping test temp dir: ${TEST_TMP_ROOT}"
    return 0
  fi
  rm -rf "${TEST_TMP_ROOT}" 2>/dev/null || true
}
trap cleanup EXIT

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

# Arrays to store results
declare -a FAILED_TESTS
declare -a PASSED_TESTS

echo "========================================"
echo "Running All FPDev Tests"
echo "========================================"
echo ""

# Find all test files (including nested directories)
# Excluded directories and reasons:
#   fpdev.git2.adapter - Requires libgit2 native library (not available in CI)
#   fpdev.libgit2.base - Requires libgit2 native library (not available in CI)
#   fpdev.core.misc    - Legacy/experimental tests not part of main suite
#   migrated           - Old tests superseded by newer implementations
#   examples           - Example code, not test cases
TEST_FILES=$(find tests -name "test_*.lpr" \
    ! -path "*/examples/*" \
    ! -path "*/fpdev.git2.adapter/*" \
    ! -path "*/fpdev.libgit2.base/*" \
    ! -path "*/fpdev.core.misc/*" \
    ! -path "*/migrated/*" \
    | sort)

run_test_binary() {
  local bin_path="$1"
  local log_path="$2"

  # Many fpcunit console runners require --all to actually run tests.
  if "${bin_path}" --all >"${log_path}" 2>&1; then
    return 0
  fi

  # Legacy/simple tests often take no args.
  if "${bin_path}" >"${log_path}" 2>&1; then
    return 0
  fi

  return 1
}

for TEST_FILE in $TEST_FILES; do
    TOTAL=$((TOTAL + 1))
    TEST_NAME=$(basename "$TEST_FILE" .lpr)
    TEST_DIR=$(dirname "$TEST_FILE")
    TEST_LPI="${TEST_FILE%.lpr}.lpi"
    TEST_LOG="${TEST_TMP_ROOT}/${TEST_NAME}.log"

    # Determine binary path: check nested bin/ first, then top-level bin/
    if [ "$TEST_DIR" != "tests" ]; then
        TEST_BIN="${TEST_DIR}/bin/${TEST_NAME}"
        TEST_BIN_DIR="${TEST_DIR}/bin"
    else
        TEST_BIN="bin/${TEST_NAME}"
        TEST_BIN_DIR="bin"
    fi

    # Ensure output directory exists
    mkdir -p "$TEST_BIN_DIR"

    echo -n "[$TOTAL] Testing $TEST_NAME... "

    # Try to build the test
    BUILD_SUCCESS=false

    # First try lazbuild if .lpi exists
    if [ -f "$TEST_LPI" ]; then
        if lazbuild -B "$TEST_LPI" > /dev/null 2>&1; then
            BUILD_SUCCESS=true
        else
            # If lazbuild fails, try fpc as fallback
            if fpc -Fusrc -Fisrc -FE"$TEST_BIN_DIR" -FUlib "$TEST_FILE" > /dev/null 2>&1; then
                BUILD_SUCCESS=true
            fi
        fi
    else
        # Fall back to direct fpc compilation
        if fpc -Fusrc -Fisrc -FE"$TEST_BIN_DIR" -FUlib "$TEST_FILE" > /dev/null 2>&1; then
            BUILD_SUCCESS=true
        fi
    fi

    if [ "$BUILD_SUCCESS" = true ]; then
        # Run the test
        if [ -f "$TEST_BIN" ]; then
            if run_test_binary "./${TEST_BIN}" "${TEST_LOG}"; then
                echo -e "${GREEN}PASSED${NC}"
                PASSED=$((PASSED + 1))
                PASSED_TESTS+=("$TEST_NAME")
            else
                echo -e "${RED}FAILED${NC}"
                FAILED=$((FAILED + 1))
                FAILED_TESTS+=("$TEST_NAME")
                echo -e "${YELLOW}  log: ${TEST_LOG}${NC}"
            fi
        else
            echo -e "${YELLOW}SKIPPED (no binary)${NC}"
            SKIPPED=$((SKIPPED + 1))
        fi
    else
        echo -e "${RED}BUILD FAILED${NC}"
        FAILED=$((FAILED + 1))
        FAILED_TESTS+=("$TEST_NAME")
    fi
done

echo ""
echo "========================================"
echo "Test Results Summary"
echo "========================================"
echo "Total:   $TOTAL"
echo -e "${GREEN}Passed:  $PASSED${NC}"
echo -e "${RED}Failed:  $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed Tests:${NC}"
    for TEST in "${FAILED_TESTS[@]}"; do
        echo "  - $TEST"
    done
    echo ""
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
