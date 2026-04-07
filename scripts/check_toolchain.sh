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
