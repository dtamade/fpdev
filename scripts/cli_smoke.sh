#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/cli_smoke.sh [executable-path]

Run the bounded FPDev CLI smoke suite against a built executable.

Arguments:
  executable-path  Optional path to the FPDev binary.
                   Default: ./bin/fpdev
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

EXE="${1:-./bin/fpdev}"

if [[ ! -f "${EXE}" ]]; then
  echo "[FAIL] executable not found: ${EXE}" >&2
  exit 2
fi

if [[ ! -x "${EXE}" ]]; then
  chmod +x "${EXE}"
fi

run_smoke() {
  local label="$1"
  shift
  echo "[SMOKE] ${label}: $*"
  "$@"
}

run_smoke "system version" "${EXE}" system version
run_smoke "system help" "${EXE}" system help
run_smoke "fpc help" "${EXE}" fpc --help
run_smoke "fpc list all" "${EXE}" fpc list --all

echo "[ OK ] CLI smoke passed for ${EXE}"
