#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p bin logs

# build
fpc -Fu./src -obin/test_bm tests/fpdev.build.manager/test_build_manager.lpr
fpc -Fu./src -obin/test_bm_fail tests/fpdev.build.manager/test_build_manager_strict_fail.lpr
fpc -Fu./src -obin/test_bm_pass tests/fpdev.build.manager/test_build_manager_strict_pass.lpr

# run
./bin/test_bm
./bin/test_bm_fail || true
./bin/test_bm_pass

# show latest log
echo "=== latest log ==="
LATEST_LOG=$(ls -1t logs/build_*.log 2>/dev/null | head -n1 || true)
if [[ -n "$LATEST_LOG" ]]; then
  cat "$LATEST_LOG"
else
  echo "(no log found)"
fi

