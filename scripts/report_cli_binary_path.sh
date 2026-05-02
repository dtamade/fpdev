#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/report_cli_binary_path.sh <binary-path> <output-file>

Write the resolved CLI binary path to an output file.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 2
fi

BINARY_PATH="$1"
OUTPUT_FILE="$2"

if [[ -z "${BINARY_PATH}" ]]; then
  echo "[FAIL] binary path must not be empty" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"
printf '%s\n' "${BINARY_PATH}" > "${OUTPUT_FILE}"
echo "[INFO] Reported CLI binary path: ${BINARY_PATH}"
