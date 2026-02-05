#!/usr/bin/env bash
set -euo pipefail

TOOLS=( make gmake mingw32-make fpc lazbuild git openssl ppc386 ppcx64 ppcarm )
OK=0; MISS=0

check() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "[ OK ] $1"
    return 0
  else
    echo "[MISS] $1"
    return 1
  fi
}

for t in "${TOOLS[@]}"; do
  if check "$t"; then OK=$((OK+1)); else MISS=$((MISS+1)); fi
done

TS=$(date +%Y%m%d_%H%M%S)
OUTDIR=logs/check
mkdir -p "$OUTDIR"
OUT="$OUTDIR/toolchain_$TS.txt"
{
  echo "Toolchain Check @ $(date)"
  echo "=================================="
  for t in "${TOOLS[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      case "$t" in
        git) echo -n "$t : "; git --version ;;
        openssl) echo -n "$t : "; openssl version ;;
        fpc) echo -n "$t : "; fpc -iV ;;
        lazbuild) echo -n "$t : "; lazbuild --version 2>/dev/null | head -n1 ;;
        *) echo "$t : found" ;;
      esac
    else
      echo "$t : MISSING"
    fi
  done
} | tee "$OUT"

if (( MISS > 0 )); then
  echo "Missing tools: $MISS"
  exit 1
else
  echo "All required tools seem available."
  exit 0
fi

