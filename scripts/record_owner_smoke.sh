#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/record_owner_smoke.sh <lane> <executable-path> <output-dir>

Record a standardized owner smoke transcript by wrapping scripts/cli_smoke.sh.

Supported lanes:
  windows-x64
  macos-x64
  macos-arm64
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 3 ]]; then
  usage >&2
  exit 2
fi

LANE="$1"
EXE="$2"
OUTPUT_DIR="$3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${LANE}" in
  windows-x64|macos-x64|macos-arm64)
    ;;
  *)
    echo "[FAIL] unsupported lane: ${LANE}" >&2
    usage >&2
    exit 2
    ;;
esac

mkdir -p "${OUTPUT_DIR}"
TRANSCRIPT="${OUTPUT_DIR}/${LANE}-owner-smoke.txt"

if bash "${SCRIPT_DIR}/cli_smoke.sh" "${EXE}" 2>&1 | tee "${TRANSCRIPT}"; then
  echo "Recorded owner smoke transcript: ${TRANSCRIPT}"
else
  status=$?
  echo "[FAIL] owner smoke failed for ${LANE}; transcript preserved at ${TRANSCRIPT}" >&2
  exit "${status}"
fi
