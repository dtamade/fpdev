#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

PLANNED_RELEASE_ASSETS = [
    'fpdev-linux-x64.tar.gz',
    'fpdev-windows-x64.zip',
    'fpdev-macos-x64.tar.gz',
    'fpdev-macos-arm64.tar.gz',
]

DEFAULT_OUTPUT_NAME = 'SHA256SUMS.txt'


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def collect_assets(asset_dir: Path) -> list[Path]:
    return [asset_dir / name for name in PLANNED_RELEASE_ASSETS if (asset_dir / name).is_file()]


def require_assets(asset_dir: Path) -> None:
    missing = [name for name in PLANNED_RELEASE_ASSETS if not (asset_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(
            'Missing planned release assets: ' + ', '.join(missing)
        )


def render_checksums(asset_dir: Path) -> str:
    assets = collect_assets(asset_dir)
    if not assets:
        raise FileNotFoundError(
            f'No planned release assets found in {asset_dir}'
        )
    lines = [f'{sha256_file(path)}  {path.name}' for path in assets]
    return '\n'.join(lines) + '\n'


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Generate SHA256SUMS.txt for planned FPDev release assets.'
    )
    parser.add_argument(
        'asset_dir',
        nargs='?',
        default='.',
        help='Directory containing packaged release assets',
    )
    parser.add_argument(
        '--output',
        default=DEFAULT_OUTPUT_NAME,
        help='Output checksum file path (default: <asset_dir>/SHA256SUMS.txt)',
    )
    parser.add_argument(
        '--require-planned-assets',
        action='store_true',
        help='Fail unless all planned release assets are present',
    )
    args = parser.parse_args()

    asset_dir = Path(args.asset_dir).resolve()
    if not asset_dir.is_dir():
        print(f'Asset directory does not exist: {asset_dir}', file=sys.stderr)
        return 2

    try:
        if args.require_planned_assets:
            require_assets(asset_dir)
        output_path = Path(args.output)
        if not output_path.is_absolute():
            output_path = asset_dir / output_path
        output_path.write_text(render_checksums(asset_dir), encoding='utf-8')
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(f'Wrote {output_path}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
