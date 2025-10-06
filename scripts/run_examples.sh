#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
LOGDIR="logs/examples"
mkdir -p "$LOGDIR"

for d in examples/*; do
  if [[ -x "$d/buildOrTest.sh" ]]; then
    echo "Running $d/buildOrTest.sh ..."
    (cd "$d" && ./buildOrTest.sh) > "$LOGDIR/$(basename "$d")_$(date +%Y%m%d_%H%M%S).log" 2>&1 || true
  fi
done

echo "All examples executed. Logs in $LOGDIR"

