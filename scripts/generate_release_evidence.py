#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path


DEFAULT_OUTPUT_NAME = 'RELEASE_EVIDENCE.md'
CHECKSUM_FILE_NAME = 'SHA256SUMS.txt'
OWNER_EVIDENCE_FILES = [
    ('Windows x64 asset smoke', 'windows-x64-owner-smoke.txt'),
    ('macOS x64 asset smoke', 'macos-x64-owner-smoke.txt'),
    ('macOS arm64 asset smoke', 'macos-arm64-owner-smoke.txt'),
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


def collect_owner_evidence(owner_proof_dir: Path) -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    for lane, filename in OWNER_EVIDENCE_FILES:
        evidence_path = owner_proof_dir / filename
        status = 'found' if evidence_path.is_file() else 'missing'
        rows.append((lane, filename, status))
    return rows


def render_lane(title: str, summary_path: Path | None, summary: dict[str, str] | None) -> list[str]:
    if summary_path is None or summary is None:
        return [
            f'### {title}',
            '',
            '- status: not provided',
            '- summary: not provided',
            '- timestamp: not provided',
            '- run_dir: not provided',
            '- note: Pass --install-summary if the network-gated lane was executed.',
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
    owner_evidence_rows: list[tuple[str, str, str]],
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
        '| Windows x64 asset smoke | pending | command transcript + asset checksum |',
        '| macOS x64 asset smoke | pending | command transcript + asset checksum |',
        '| macOS arm64 asset smoke | pending | command transcript + asset checksum |',
        '',
        '## Owner Evidence Files',
        '',
        f'- owner_proof_dir: `{owner_proof_dir}`',
        '',
        '| Lane | Transcript | Status |',
        '|------|------------|--------|',
    ])

    for lane, filename, status in owner_evidence_rows:
        lines.append(f'| {lane} | `{filename}` | {status} |')

    lines.append('')
    return '\n'.join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Generate a markdown release evidence summary from acceptance logs and packaged assets.'
    )
    parser.add_argument('--baseline-summary', required=True, help='Path to the Linux baseline summary.txt')
    parser.add_argument(
        '--install-summary',
        help='Path to the Linux isolated install summary.txt (optional when the network-gated lane was not run)',
    )
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
        if summary_path is None:
            continue
        if not summary_path.is_file():
            print(f'Summary file does not exist: {summary_path}', file=sys.stderr)
            return 2

    if not asset_dir.is_dir():
        print(f'Asset directory does not exist: {asset_dir}', file=sys.stderr)
        return 2

    baseline_summary = parse_summary(baseline_path)
    install_summary = parse_summary(install_path) if install_path else None
    checksum_lines = read_checksum_lines(asset_dir)
    owner_evidence_rows = collect_owner_evidence(owner_proof_dir)
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
