#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
LOGDIR="logs/examples/real"
mkdir -p "$LOGDIR"

scripts/check_toolchain.sh || { echo "Toolchain check failed. See logs/check."; exit 1; }

export REAL=1
for d in examples/*; do
  if [[ -x "$d/buildOrTest.sh" ]]; then
    echo "Running REAL examples in $d ..."
    (cd "$d" && ./buildOrTest.sh) > "$LOGDIR/$(basename "$d")_$(date +%Y%m%d_%H%M%S).log" 2>&1 || true
  fi
done

echo "All REAL examples executed. Logs in $LOGDIR"

