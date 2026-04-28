#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/check_toolchain.sh [--strict]

Checks the local toolchain prerequisites for building/running FPDev.

Exit codes:
  0  OK (required tools present; optional tools may be missing)
  1  Missing required tools (or missing optional tools in --strict mode)
  2  Usage error

Options:
  --strict    Treat missing optional tools as errors (exit 1)
  --help,-h   Show this help

Notes:
  - For cross-compilation readiness, prefer: fpdev cross doctor
  - Set FPDEV_LAZARUSDIR to override the Lazarus root used by release builds
EOF
}

STRICT="${FPDEV_TOOLCHAIN_STRICT:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${FPDEV_TOOLCHAIN_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
REPO_BUILD_OUTPUTS_ENABLED=0
REPO_OUTPUT_LAST_STATUS=""
REPO_OUTPUT_LAST_NOTES=""
REPO_BIN_PATH="${REPO_ROOT}/bin"
REPO_BIN_STATUS="SKIPPED"
REPO_BIN_NOTES=""
REPO_LIB_PATH="${REPO_ROOT}/lib"
REPO_LIB_STATUS="SKIPPED"
REPO_LIB_NOTES=""

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

REQUIRED_TOOLS=(fpc lazbuild git openssl)
# Optional: only needed for certain cross/toolchain workflows.
OPTIONAL_TOOLS=(mingw32-make ppcx64 ppc386 ppcarm)

OK=0
REQ_MISS=0
OPT_MISS=0
LAZARUS_ROOT_STATUS="MISSING"
LAZARUS_ROOT_PATH=""

check() {
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    echo "[ OK ] $tool"
    return 0
  fi
  echo "[MISS] $tool"
  return 1
}

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

detect_lazarus_root() {
  local candidate=""
  local lazbuild_bin=""

  if [[ -n "${FPDEV_LAZARUSDIR:-}" ]]; then
    candidate="${FPDEV_LAZARUSDIR}"
    if [[ -d "${candidate}/lcl" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
    return 1
  fi

  lazbuild_bin="$(command -v lazbuild || true)"
  if [[ -z "${lazbuild_bin}" ]]; then
    return 1
  fi

  candidate="$(dirname "$(resolve_realpath "${lazbuild_bin}")")"
  if [[ -d "${candidate}/lcl" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi

  return 1
}

probe_repo_build_output() {
  local name="$1"
  local path="$2"
  local parent_dir=""

  REPO_OUTPUT_LAST_STATUS="MISSING"
  REPO_OUTPUT_LAST_NOTES=""

  if [[ -d "${path}" ]]; then
    if [[ -w "${path}" ]]; then
      REPO_OUTPUT_LAST_STATUS="found"
      echo "[ OK ] ${name}: ${path}"
      return 0
    fi

    REPO_OUTPUT_LAST_NOTES="directory exists but is not writable"
    echo "[MISS] ${name}: ${path} (${REPO_OUTPUT_LAST_NOTES})"
    return 1
  fi

  parent_dir="$(dirname "${path}")"
  if [[ -d "${parent_dir}" && -w "${parent_dir}" ]]; then
    REPO_OUTPUT_LAST_STATUS="found"
    REPO_OUTPUT_LAST_NOTES="creatable"
    echo "[ OK ] ${name}: ${path} (${REPO_OUTPUT_LAST_NOTES})"
    return 0
  fi

  REPO_OUTPUT_LAST_NOTES="parent directory is not writable"
  echo "[MISS] ${name}: ${path} (${REPO_OUTPUT_LAST_NOTES})"
  return 1
}

echo "=================================="
echo "Toolchain Check @ $(date)"
echo "=================================="

# Make: accept either make or gmake.
if command -v make >/dev/null 2>&1; then
  echo "[ OK ] make"
  OK=$((OK + 1))
elif command -v gmake >/dev/null 2>&1; then
  echo "[ OK ] gmake (as make)"
  OK=$((OK + 1))
else
  echo "[MISS] make (make or gmake)"
  REQ_MISS=$((REQ_MISS + 1))
fi

for t in "${REQUIRED_TOOLS[@]}"; do
  if check "$t"; then OK=$((OK + 1)); else REQ_MISS=$((REQ_MISS + 1)); fi
done

if LAZARUS_ROOT_PATH="$(detect_lazarus_root)"; then
  LAZARUS_ROOT_STATUS="found"
  echo "[ OK ] lazarus_root: ${LAZARUS_ROOT_PATH}"
  OK=$((OK + 1))
else
  if [[ -n "${FPDEV_LAZARUSDIR:-}" ]]; then
    echo "[MISS] lazarus_root (FPDEV_LAZARUSDIR does not contain lcl/)"
  else
    echo "[MISS] lazarus_root (set FPDEV_LAZARUSDIR to a Lazarus root containing lcl/)"
  fi
  REQ_MISS=$((REQ_MISS + 1))
fi

if [[ -f "${REPO_ROOT}/fpdev.lpi" ]]; then
  REPO_BUILD_OUTPUTS_ENABLED=1

  if probe_repo_build_output "repo_bin_writable" "${REPO_BIN_PATH}"; then
    OK=$((OK + 1))
  else
    REQ_MISS=$((REQ_MISS + 1))
  fi
  REPO_BIN_STATUS="${REPO_OUTPUT_LAST_STATUS}"
  REPO_BIN_NOTES="${REPO_OUTPUT_LAST_NOTES}"

  if probe_repo_build_output "repo_lib_writable" "${REPO_LIB_PATH}"; then
    OK=$((OK + 1))
  else
    REQ_MISS=$((REQ_MISS + 1))
  fi
  REPO_LIB_STATUS="${REPO_OUTPUT_LAST_STATUS}"
  REPO_LIB_NOTES="${REPO_OUTPUT_LAST_NOTES}"
fi

for t in "${OPTIONAL_TOOLS[@]}"; do
  if check "$t"; then OK=$((OK + 1)); else OPT_MISS=$((OPT_MISS + 1)); fi
done

TS=$(date +%Y%m%d_%H%M%S)
OUTDIR=logs/check
mkdir -p "$OUTDIR"
OUT="$OUTDIR/toolchain_$TS.txt"

{
  echo "Toolchain Check @ $(date)"
  echo "=================================="
  echo "strict: $STRICT"
  echo ""

  echo "Required:"
  echo "  make|gmake : $(command -v make >/dev/null 2>&1 && echo found || (command -v gmake >/dev/null 2>&1 && echo found || echo MISSING))"
  for t in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      case "$t" in
        git) echo -n "  $t : "; git --version ;;
        openssl) echo -n "  $t : "; openssl version ;;
        fpc) echo -n "  $t : "; fpc -iV ;;
        lazbuild) echo -n "  $t : "; lazbuild --version 2>/dev/null | head -n1 ;;
        *) echo "  $t : found" ;;
      esac
    else
      echo "  $t : MISSING"
    fi
  done
  if [[ "${LAZARUS_ROOT_STATUS}" == "found" ]]; then
    echo "  lazarus_root : ${LAZARUS_ROOT_PATH}"
  elif [[ -n "${FPDEV_LAZARUSDIR:-}" ]]; then
    echo "  lazarus_root : MISSING (FPDEV_LAZARUSDIR does not contain lcl/)"
  else
    echo "  lazarus_root : MISSING (set FPDEV_LAZARUSDIR to a Lazarus root containing lcl/)"
  fi
  echo ""

  echo "Build outputs:"
  if (( REPO_BUILD_OUTPUTS_ENABLED == 1 )); then
    echo "  repo_root : ${REPO_ROOT}"
    echo "  repo_bin_writable : ${REPO_BIN_STATUS} ${REPO_BIN_PATH} ${REPO_BIN_NOTES}"
    echo "  repo_lib_writable : ${REPO_LIB_STATUS} ${REPO_LIB_PATH} ${REPO_LIB_NOTES}"
  else
    echo "  skipped : repo root not detected (${REPO_ROOT}/fpdev.lpi missing)"
  fi
  echo ""

  echo "Optional:"
  for t in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      echo "  $t : found"
    else
      echo "  $t : MISSING"
    fi
  done
} | tee "$OUT"

echo ""
echo "Summary:"
echo "  ok: $OK"
echo "  missing_required: $REQ_MISS"
echo "  missing_optional: $OPT_MISS"

if (( REQ_MISS > 0 )); then
  exit 1
fi
if (( STRICT == 1 && OPT_MISS > 0 )); then
  exit 1
fi
exit 0
