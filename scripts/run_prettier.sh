#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run_prettier.sh [prettier-args...]

Run Prettier without relying on a parent yarn workspace wrapper.

Examples:
  scripts/run_prettier.sh --check docs/ARCHITECTURE.md
  scripts/run_prettier.sh --write docs/ARCHITECTURE.md docs/ARCHITECTURE.en.md
EOF
}

resolve_prettier_bin() {
  local candidate=""

  if candidate="$(command -v prettier 2>/dev/null)"; then
    printf '%s\n' "${candidate}"
    return 0
  fi

  if [[ -n "${HOME:-}" && -x "${HOME}/node_modules/.bin/prettier" ]]; then
    printf '%s\n' "${HOME}/node_modules/.bin/prettier"
    return 0
  fi

  if command -v node >/dev/null 2>&1; then
    candidate="$(
      node -e "process.stdout.write(require.resolve('prettier/bin/prettier.cjs'))" 2>/dev/null || true
    )"
    if [[ -n "${candidate}" && -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  return 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -eq 0 ]]; then
  usage >&2
  exit 2
fi

PRETTIER_BIN="$(resolve_prettier_bin || true)"
if [[ -z "${PRETTIER_BIN}" ]]; then
  echo "[FAIL] prettier binary not found. Install prettier or expose it on PATH." >&2
  exit 127
fi

exec "${PRETTIER_BIN}" "$@"
