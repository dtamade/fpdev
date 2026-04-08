#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build_release.sh [--help]

Build FPDev in Release mode using a shared maintainer entrypoint.

Environment overrides:
  FPDEV_LAZBUILD_BIN          Override the lazbuild executable path
  FPDEV_LAZARUSDIR            Override the Lazarus root directory (must contain lcl/)
  FPDEV_RELEASE_BUILD_ROOT    Override the writable fallback build workspace root
  FPDEV_RELEASE_BIN_PATH_FILE Write the resolved release binary path to this file
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

write_release_bin_path() {
  local bin_path="$1"

  if [[ -z "${FPDEV_RELEASE_BIN_PATH_FILE:-}" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "${FPDEV_RELEASE_BIN_PATH_FILE}")"
  printf '%s\n' "${bin_path}" > "${FPDEV_RELEASE_BIN_PATH_FILE}"
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

dir_is_writable() {
  local dir_path="$1"

  mkdir -p "${dir_path}" 2>/dev/null || true
  [[ -d "${dir_path}" && -w "${dir_path}" ]]
}

prepare_fallback_build_workspace() {
  local workspace_root="${FPDEV_RELEASE_BUILD_ROOT:-}"

  if [[ -z "${workspace_root}" ]]; then
    workspace_root="$(mktemp -d "${TMPDIR:-/tmp}/fpdev-release-build-XXXXXX")"
  else
    mkdir -p "${workspace_root}"
  fi

  rm -rf "${workspace_root}/src" 2>/dev/null || true
  mkdir -p "${workspace_root}/bin" "${workspace_root}/lib"
  ln -s "${REPO_ROOT}/src" "${workspace_root}/src"
  cp "${REPO_ROOT}/fpdev.lpi" "${workspace_root}/fpdev.lpi"
  printf '%s\n' "${workspace_root}"
}

BUILD_CMD=("${LAZBUILD_BIN}")
BUILD_ROOT="${REPO_ROOT}"
RELEASE_BIN_PATH="${REPO_ROOT}/bin/fpdev"

if LAZARUS_DIR="$(detect_lazarus_dir)"; then
  echo "[INFO] Using Lazarus directory: ${LAZARUS_DIR}"
  BUILD_CMD+=("--lazarusdir=${LAZARUS_DIR}")
else
  echo "[INFO] Using lazbuild default Lazarus discovery"
fi

if ! dir_is_writable "${REPO_ROOT}/bin" || ! dir_is_writable "${REPO_ROOT}/lib"; then
  BUILD_ROOT="$(prepare_fallback_build_workspace)"
  RELEASE_BIN_PATH="${BUILD_ROOT}/bin/fpdev"
  echo "[INFO] Using writable fallback build root: ${BUILD_ROOT}"
fi

BUILD_CMD+=("-B" "--build-mode=Release" "fpdev.lpi")

echo "+ ${BUILD_CMD[*]}"
(
  cd "${BUILD_ROOT}"
  "${BUILD_CMD[@]}"
)

write_release_bin_path "${RELEASE_BIN_PATH}"
echo "[INFO] Release binary: ${RELEASE_BIN_PATH}"
