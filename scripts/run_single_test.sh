#!/bin/bash
# Run one FPDev Pascal test with the same build recovery logic as run_all_tests.sh

FOCUSED_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./run_all_tests.sh
source "${FOCUSED_SCRIPT_DIR}/run_all_tests.sh"

print_focused_banner() {
  echo "========================================"
  echo "Running Focused FPDev Test"
  echo "========================================"
  echo ""
}

usage() {
  echo "Usage: $(basename "$0") <test_file.lpr>" >&2
}

main() {
  local test_file="${1:-}"

  if [ "$#" -ne 1 ]; then
    usage
    return 2
  fi

  set -e
  cd "$REPO_ROOT"

  if [ ! -f "$test_file" ]; then
    echo "[run_single_test] missing test file: $test_file" >&2
    return 2
  fi

  init_test_environment
  trap cleanup EXIT

  print_focused_banner
  run_single_test "$test_file"
  print_summary
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
