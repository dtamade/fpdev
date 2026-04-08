#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path


DEFAULT_OUTPUT_NAME = 'RELEASE_EVIDENCE.md'
CHECKSUM_FILE_NAME = 'SHA256SUMS.txt'
OWNER_EVIDENCE_FILES = [
    ('Windows x64 asset smoke', 'windows-x64-owner-smoke.txt', 'fpdev-windows-x64.zip'),
    ('macOS x64 asset smoke', 'macos-x64-owner-smoke.txt', 'fpdev-macos-x64.tar.gz'),
    ('macOS arm64 asset smoke', 'macos-arm64-owner-smoke.txt', 'fpdev-macos-arm64.tar.gz'),
]


def parse_summary(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw_line in path.read_text(encoding='utf-8').splitlines():
        if ': ' not in raw_line:
            continue
        key, value = raw_line.split(': ', 1)
        data[key.strip()] = value.strip()
    return data


def rel_display_path(path: Path) -> str:
    parts = path.parts
    if 'logs' in parts:
        start = parts.index('logs')
        return '/'.join(parts[start:])
    return path.name


def read_checksum_lines(asset_dir: Path) -> list[str]:
    checksum_path = asset_dir / CHECKSUM_FILE_NAME
    if not checksum_path.is_file():
        return []
    return [line.strip() for line in checksum_path.read_text(encoding='utf-8').splitlines() if line.strip()]


def parse_checksum_assets(checksum_lines: list[str]) -> set[str]:
    assets: set[str] = set()
    for line in checksum_lines:
        parts = line.split()
        if len(parts) >= 2:
            assets.add(parts[-1].lstrip('*'))
    return assets


def collect_owner_evidence(
    owner_proof_dir: Path,
    checksum_lines: list[str],
) -> list[tuple[str, str, str, str, str]]:
    checksum_assets = parse_checksum_assets(checksum_lines)
    rows: list[tuple[str, str, str, str, str]] = []
    for lane, filename, asset_name in OWNER_EVIDENCE_FILES:
        evidence_path = owner_proof_dir / filename
        transcript_status = 'found' if evidence_path.is_file() else 'missing'
        ledger_status = 'pass' if transcript_status == 'found' and asset_name in checksum_assets else 'pending'
        rows.append((lane, filename, transcript_status, ledger_status, asset_name))
    return rows


def render_lane(
    title: str,
    summary_path: Path | None,
    summary: dict[str, str] | None,
) -> list[str]:
    if summary_path is None or summary is None:
        return [
            f'### {title}',
            '',
            '- status: not recorded (optional)',
            '- summary: `not provided`',
            '- timestamp: `not recorded`',
            '- run_dir: `not recorded`',
            '',
        ]

    return [
        f'### {title}',
        '',
        f'- status: {summary.get("status", "unknown")}',
        f'- summary: `{rel_display_path(summary_path)}`',
        f'- timestamp: `{summary.get("timestamp", "unknown")}`',
        f'- run_dir: `{summary.get("run_dir", "unknown")}`',
        '',
    ]


def render_markdown(
    baseline_path: Path,
    baseline_summary: dict[str, str],
    install_path: Path | None,
    install_summary: dict[str, str] | None,
    asset_dir: Path,
    checksum_lines: list[str],
    owner_proof_dir: Path,
    owner_evidence_rows: list[tuple[str, str, str, str, str]],
) -> str:
    lines = [
        '# FPDev Release Evidence',
        '',
        '## Automated Evidence',
        '',
        *render_lane('Linux automated acceptance', baseline_path, baseline_summary),
        *render_lane('Linux isolated install lane', install_path, install_summary),
        '## Release Assets',
        '',
        f'- asset_dir: `{asset_dir}`',
        f'- checksum_manifest: `{asset_dir / CHECKSUM_FILE_NAME}`',
    ]

    if checksum_lines:
        lines.extend([
            '',
            '```text',
            *checksum_lines,
            '```',
        ])
    else:
        lines.extend([
            '',
            '- `SHA256SUMS.txt` not found yet; generate it before publish.',
        ])

    lines.extend([
        '',
        '## Owner Ledger',
        '',
        '| Lane | Status | Evidence expectation |',
        '|------|--------|----------------------|',
    ])

    for lane, filename, _transcript_status, ledger_status, asset_name in owner_evidence_rows:
        lines.append(f'| {lane} | {ledger_status} | `{filename}` + `{asset_name}` checksum |')

    lines.extend([
        '',
        '## Owner Evidence Files',
        '',
        f'- owner_proof_dir: `{owner_proof_dir}`',
        '',
        '| Lane | Transcript | Status |',
        '|------|------------|--------|',
    ])

    for lane, filename, transcript_status, _ledger_status, _asset_name in owner_evidence_rows:
        lines.append(f'| {lane} | `{filename}` | {transcript_status} |')

    lines.append('')
    return '\n'.join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Generate a markdown release evidence summary from acceptance logs and packaged assets.'
    )
    parser.add_argument('--baseline-summary', required=True, help='Path to the Linux baseline summary.txt')
    parser.add_argument('--install-summary', help='Path to the optional Linux isolated install summary.txt')
    parser.add_argument('--asset-dir', required=True, help='Directory containing packaged release assets')
    parser.add_argument(
        '--owner-proof-dir',
        default='.',
        help='Directory containing owner smoke transcript files (default: current directory)',
    )
    parser.add_argument(
        '--output',
        default=DEFAULT_OUTPUT_NAME,
        help='Output markdown path (default: RELEASE_EVIDENCE.md in the current directory)',
    )
    args = parser.parse_args()

    baseline_path = Path(args.baseline_summary).resolve()
    install_path = Path(args.install_summary).resolve() if args.install_summary else None
    asset_dir = Path(args.asset_dir).resolve()
    owner_proof_dir = Path(args.owner_proof_dir).resolve()
    output_path = Path(args.output).resolve()

    for summary_path in (baseline_path, install_path):
        if summary_path is not None and not summary_path.is_file():
            print(f'Summary file does not exist: {summary_path}', file=sys.stderr)
            return 2

    if not asset_dir.is_dir():
        print(f'Asset directory does not exist: {asset_dir}', file=sys.stderr)
        return 2

    baseline_summary = parse_summary(baseline_path)
    install_summary = parse_summary(install_path) if install_path is not None else None
    checksum_lines = read_checksum_lines(asset_dir)
    owner_evidence_rows = collect_owner_evidence(owner_proof_dir, checksum_lines)
    markdown = render_markdown(
        baseline_path,
        baseline_summary,
        install_path,
        install_summary,
        asset_dir,
        checksum_lines,
        owner_proof_dir,
        owner_evidence_rows,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown, encoding='utf-8')

    checksum_path = asset_dir / CHECKSUM_FILE_NAME
    print(f'Wrote {output_path} using {checksum_path}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
