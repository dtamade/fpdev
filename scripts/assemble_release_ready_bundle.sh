#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/assemble_release_ready_bundle.sh [--help]

Assemble the FPDev release-ready bundle from downloaded CI artifacts.

Environment overrides:
  FPDEV_BUNDLE_DOWNLOADS_DIR      Override the artifact download root
  FPDEV_RELEASE_READY_BUNDLE_DIR  Override the output bundle directory
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
DOWNLOAD_ROOT="${FPDEV_BUNDLE_DOWNLOADS_DIR:-${REPO_ROOT}/bundle/downloads}"
OUTPUT_ROOT="${FPDEV_RELEASE_READY_BUNDLE_DIR:-${REPO_ROOT}/release-ready-bundle}"
ASSET_DIR="${OUTPUT_ROOT}/release-assets"
OWNER_PROOF_DIR="${OUTPUT_ROOT}/owner-proof"
LOG_DIR="${OUTPUT_ROOT}/release-acceptance-logs"

require_file() {
  local path="$1"

  if [[ ! -f "${path}" ]]; then
    echo "[FAIL] Missing required file: ${path}" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1"

  if [[ ! -d "${path}" ]]; then
    echo "[FAIL] Missing required directory: ${path}" >&2
    exit 1
  fi
}

copy_asset() {
  local artifact_name="$1"
  local filename="$2"

  local source_path="${DOWNLOAD_ROOT}/${artifact_name}/${filename}"
  require_file "${source_path}"
  cp "${source_path}" "${ASSET_DIR}/"
}

copy_tree_contents() {
  local artifact_name="$1"
  local destination_dir="$2"

  local source_dir="${DOWNLOAD_ROOT}/${artifact_name}"
  require_dir "${source_dir}"
  cp -R "${source_dir}/." "${destination_dir}/"
}

find_baseline_summary() {
  find "${LOG_DIR}" -name summary.txt -print | while read -r path; do
    grep -q '^with_install: 0$' "$path" && printf '%s\n' "$path" && break
  done
}

find_install_summary() {
  find "${LOG_DIR}" -name summary.txt -print | while read -r path; do
    grep -q '^with_install: 1$' "$path" && printf '%s\n' "$path" && break
  done
}

rm -rf "${OUTPUT_ROOT}"
mkdir -p "${ASSET_DIR}" "${OWNER_PROOF_DIR}" "${LOG_DIR}"

copy_asset release-asset-linux-x64 fpdev-linux-x64.tar.gz
copy_asset release-asset-windows-x64 fpdev-windows-x64.zip
copy_asset release-asset-macos-x64 fpdev-macos-x64.tar.gz
copy_asset release-asset-macos-arm64 fpdev-macos-arm64.tar.gz

copy_tree_contents release-acceptance-logs "${LOG_DIR}"
copy_tree_contents owner-proof-windows-x64 "${OWNER_PROOF_DIR}"
copy_tree_contents owner-proof-macos-x64 "${OWNER_PROOF_DIR}"
copy_tree_contents owner-proof-macos-arm64 "${OWNER_PROOF_DIR}"

(
  cd "${REPO_ROOT}"
  python3 scripts/generate_release_checksums.py "${ASSET_DIR}" --require-planned-assets
)

BASELINE_SUMMARY="$(find_baseline_summary)" || true
INSTALL_SUMMARY="$(find_install_summary)" || true

if [[ -z "${BASELINE_SUMMARY}" ]]; then
  echo "::error::Missing baseline summary in release acceptance logs" >&2
  exit 1
fi

evidence_args=(
  --baseline-summary "${BASELINE_SUMMARY}"
  --asset-dir "${ASSET_DIR}"
  --owner-proof-dir "${OWNER_PROOF_DIR}"
  --output "${ASSET_DIR}/RELEASE_EVIDENCE.md"
)

if [[ -n "${INSTALL_SUMMARY}" ]]; then
  evidence_args+=(--install-summary "${INSTALL_SUMMARY}")
fi

(
  cd "${REPO_ROOT}"
  python3 scripts/generate_release_evidence.py "${evidence_args[@]}"
)

echo "[INFO] Release-ready bundle assembled at ${OUTPUT_ROOT}"
