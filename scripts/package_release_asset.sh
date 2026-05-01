#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/package_release_asset.sh [package_release_assets.py options]

Shared shell entrypoint for packaging FPDev release assets.

This wrapper keeps the release-asset packaging step aligned across:
  - CI Linux release packaging
  - CI cross-platform packaging matrix
  - local Linux release acceptance reruns

Environment overrides:
  FPDEV_PACKAGE_PYTHON_BIN  Override the Python executable used to run the packager

Common forwarded options:
  --output-dir <dir>
  --data-dir <dir>
  --linux-bin <path>
  --windows-bin <path>
  --macos-x64-bin <path>
  --macos-arm64-bin <path>
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PYTHON_BIN="${FPDEV_PACKAGE_PYTHON_BIN:-}"
OUTPUT_DIR=""

if [[ -z "${PYTHON_BIN}" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
  else
    echo "[FAIL] python3/python not found on PATH" >&2
    exit 1
  fi
fi

args=("$@")
index=0
while [[ "${index}" -lt "${#args[@]}" ]]; do
  arg="${args[$index]}"
  case "${arg}" in
    --output-dir)
      index=$((index + 1))
      if [[ "${index}" -ge "${#args[@]}" ]]; then
        echo "[FAIL] --output-dir requires a value" >&2
        exit 2
      fi
      OUTPUT_DIR="${args[$index]}"
      ;;
    --output-dir=*)
      OUTPUT_DIR="${arg#--output-dir=}"
      ;;
  esac
  index=$((index + 1))
done

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="dist"
fi

rm -rf "${OUTPUT_DIR}"

(
  cd "${REPO_ROOT}"
  "${PYTHON_BIN}" scripts/package_release_assets.py "$@"
)
