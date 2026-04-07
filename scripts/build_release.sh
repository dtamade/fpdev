#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build_release.sh [--help]

Build FPDev in Release mode using a shared maintainer entrypoint.

Environment overrides:
  FPDEV_LAZBUILD_BIN  Override the lazbuild executable path
  FPDEV_LAZARUSDIR    Override the Lazarus root directory (must contain lcl/)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAZBUILD_BIN="${FPDEV_LAZBUILD_BIN:-$(command -v lazbuild || true)}"

if [[ -z "${LAZBUILD_BIN}" ]]; then
  echo "[FAIL] lazbuild not found on PATH" >&2
  exit 1
fi

resolve_realpath() {
  local input_path="$1"

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$input_path" <<'PY'
from pathlib import Path
import sys

print(Path(sys.argv[1]).resolve())
PY
    return 0
  fi

  printf '%s\n' "$input_path"
}

detect_lazarus_dir() {
  local candidate=""

  if [[ -n "${FPDEV_LAZARUSDIR:-}" ]]; then
    candidate="${FPDEV_LAZARUSDIR}"
    if [[ ! -d "${candidate}/lcl" ]]; then
      echo "[FAIL] FPDEV_LAZARUSDIR does not look like a Lazarus root: ${candidate}" >&2
      exit 1
    fi
    printf '%s\n' "${candidate}"
    return 0
  fi

  candidate="$(dirname "$(resolve_realpath "${LAZBUILD_BIN}")")"
  if [[ -d "${candidate}/lcl" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi

  return 1
}

BUILD_CMD=("${LAZBUILD_BIN}")

if LAZARUS_DIR="$(detect_lazarus_dir)"; then
  echo "[INFO] Using Lazarus directory: ${LAZARUS_DIR}"
  BUILD_CMD+=("--lazarusdir=${LAZARUS_DIR}")
else
  echo "[INFO] Using lazbuild default Lazarus discovery"
fi

BUILD_CMD+=("-B" "--build-mode=Release" "fpdev.lpi")

echo "+ ${BUILD_CMD[*]}"
(
  cd "${REPO_ROOT}"
  "${BUILD_CMD[@]}"
)
