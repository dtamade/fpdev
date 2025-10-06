#!/usr/bin/env bash
set -euo pipefail

EXDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$EXDIR"
mkdir -p bin lib

FPC=fpc
INCLUDES="-Fu../../src -Fu../../lib -Fu."
OUTUNIT="-FUlib"
OPTS="-gl -gh"

for f in example_preflight.lpr example_build_dryrun.lpr example_install_sandbox.lpr example_strict_validate.lpr; do
  echo "Building $f ..."
  $FPC $INCLUDES $OUTUNIT -obin/"${f%.lpr}" $OPTS "$f"
done

MODE=${REAL:-0}
if [[ "$MODE" == "1" ]]; then
  RUN_MODE=REAL
else
  RUN_MODE=DRY
fi

echo "Running examples (MODE=$RUN_MODE) ..."
for e in example_preflight example_build_dryrun example_install_sandbox example_strict_validate; do
  echo "=== Running $e (MODE=$RUN_MODE) ==="
  ./bin/$e
done

echo "Done."

