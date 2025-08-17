#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: buildOrTest.sh [--strict] [--no-install] [--verbose]
  --strict        Enable strict checks
  --no-install    Skip Install() stage
  --verbose       Enable verbose logs
Env vars:
  STRICT=1        Append --strict
  NO_INSTALL=1    Append --no-install
  VERBOSE=1       Append --verbose
Examples:
  ./buildOrTest.sh --strict --verbose
  STRICT=1 VERBOSE=1 bash ./buildOrTest.sh
USAGE
  exit 0
fi


mkdir -p lib bin logs
if [[ "${TEST_ONLY:-}" == "1" ]]; then DEMO_ARGS+=" --test-only"; fi
if [[ "${DRY_RUN:-}" == "1" ]]; then DEMO_ARGS+=" --dry-run"; fi
if [[ "${PREFLIGHT:-}" == "1" ]]; then DEMO_ARGS+=" --preflight"; fi



# Build demo (Unix paths)
fpc -Fu../../src -obin/demo demo.lpr

# Resolve args from env vars (append)
DEMO_ARGS="${*:-}"
if [[ "${STRICT:-}" == "1" ]]; then DEMO_ARGS+=" --strict"; fi
if [[ "${VERBOSE:-}" == "1" ]]; then DEMO_ARGS+=" --verbose"; fi
if [[ "${NO_INSTALL:-}" == "1" ]]; then DEMO_ARGS+=" --no-install"; fi

echo "Running: ./bin/demo ${DEMO_ARGS}"
./bin/demo ${DEMO_ARGS}

echo "=== latest log ==="
LATEST_LOG=$(ls -1t logs/build_*.log 2>/dev/null | head -n1 || true)
if [[ -n "${LATEST_LOG}" ]]; then
  cat "${LATEST_LOG}"
else
  echo "(no log found)"
fi

