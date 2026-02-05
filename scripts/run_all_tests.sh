#!/bin/bash
# Run all FPDev tests and collect results

set -e

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

# Find all test files (excluding examples subdirectory and non-existent files)
TEST_FILES=$(find tests -maxdepth 1 -name "test_*.lpr" | sort)

for TEST_FILE in $TEST_FILES; do
    TOTAL=$((TOTAL + 1))
    TEST_NAME=$(basename "$TEST_FILE" .lpr)
    TEST_BIN="bin/$TEST_NAME"
    TEST_LPI="${TEST_FILE%.lpr}.lpi"

    echo -n "[$TOTAL] Testing $TEST_NAME... "

    # Try to build the test
    BUILD_SUCCESS=false

    # First try lazbuild if .lpi exists
    if [ -f "$TEST_LPI" ]; then
        if lazbuild -B "$TEST_LPI" > /dev/null 2>&1; then
            BUILD_SUCCESS=true
        else
            # If lazbuild fails, try fpc as fallback
            if fpc -Fusrc -Fisrc -FEbin -FUlib "$TEST_FILE" > /dev/null 2>&1; then
                BUILD_SUCCESS=true
            fi
        fi
    else
        # Fall back to direct fpc compilation
        if fpc -Fusrc -Fisrc -FEbin -FUlib "$TEST_FILE" > /dev/null 2>&1; then
            BUILD_SUCCESS=true
        fi
    fi

    if [ "$BUILD_SUCCESS" = true ]; then
        # Run the test
        if [ -f "$TEST_BIN" ]; then
            if ./"$TEST_BIN" > /dev/null 2>&1; then
                echo -e "${GREEN}PASSED${NC}"
                PASSED=$((PASSED + 1))
                PASSED_TESTS+=("$TEST_NAME")
            else
                echo -e "${RED}FAILED${NC}"
                FAILED=$((FAILED + 1))
                FAILED_TESTS+=("$TEST_NAME")
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
