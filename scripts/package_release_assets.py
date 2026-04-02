#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path

PLANNED_ASSETS = {
    'linux': ('fpdev-linux-x64.tar.gz', 'fpdev'),
    'windows': ('fpdev-windows-x64.zip', 'fpdev.exe'),
    'macos_x64': ('fpdev-macos-x64.tar.gz', 'fpdev'),
    'macos_arm64': ('fpdev-macos-arm64.tar.gz', 'fpdev'),
}


def copy_tree(src: Path, dst: Path) -> None:
    for path in src.rglob('*'):
        rel = path.relative_to(src)
        target = dst / rel
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)


def package_tar_gz(binary: Path, data_dir: Path, output_path: Path, binary_name: str) -> None:
    with tempfile.TemporaryDirectory(prefix='fpdev-package-') as tmp:
        staging = Path(tmp)
        staged_binary = staging / binary_name
        shutil.copy2(binary, staged_binary)
        staged_binary.chmod(staged_binary.stat().st_mode | 0o755)
        copy_tree(data_dir, staging / 'data')
        with tarfile.open(output_path, 'w:gz') as archive:
            archive.add(staged_binary, arcname=binary_name)
            archive.add(staging / 'data', arcname='data')


def package_zip(binary: Path, data_dir: Path, output_path: Path, binary_name: str) -> None:
    with zipfile.ZipFile(output_path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        archive.write(binary, arcname=binary_name)
        for path in sorted(data_dir.rglob('*')):
            if path.is_file():
                archive.write(path, arcname=str(Path('data') / path.relative_to(data_dir)))


def build_asset(binary: Path, data_dir: Path, output_dir: Path, asset_name: str, binary_name: str) -> Path:
    output_path = output_dir / asset_name
    output_dir.mkdir(parents=True, exist_ok=True)
    if asset_name.endswith('.zip'):
        package_zip(binary, data_dir, output_path, binary_name)
    else:
        package_tar_gz(binary, data_dir, output_path, binary_name)
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Package prepared FPDev binaries into planned release asset names.'
    )
    parser.add_argument('--output-dir', default='dist', help='Directory for packaged assets')
    parser.add_argument('--data-dir', required=True, help='Directory to include as ./data in each asset')
    parser.add_argument('--linux-bin', help='Linux x64 fpdev binary path')
    parser.add_argument('--windows-bin', help='Windows x64 fpdev.exe path')
    parser.add_argument('--macos-x64-bin', help='macOS x64 fpdev binary path')
    parser.add_argument('--macos-arm64-bin', help='macOS arm64 fpdev binary path')
    parser.add_argument(
        '--require-planned-assets',
        action='store_true',
        help='Fail unless binaries for all planned assets are provided',
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir).resolve()
    data_dir = Path(args.data_dir).resolve()
    if not data_dir.is_dir():
        print(f'Data directory does not exist: {data_dir}', file=sys.stderr)
        return 2

    binary_args = {
        'linux': args.linux_bin,
        'windows': args.windows_bin,
        'macos_x64': args.macos_x64_bin,
        'macos_arm64': args.macos_arm64_bin,
    }

    if args.require_planned_assets:
        missing = [key for key, value in binary_args.items() if not value]
        if missing:
            print(
                'Missing binaries for planned release assets: ' + ', '.join(missing),
                file=sys.stderr,
            )
            return 1

    built_assets: list[Path] = []
    for key, binary_path in binary_args.items():
        if not binary_path:
            continue
        binary = Path(binary_path).resolve()
        if not binary.is_file():
            print(f'Binary does not exist: {binary}', file=sys.stderr)
            return 2
        asset_name, binary_name = PLANNED_ASSETS[key]
        built_assets.append(build_asset(binary, data_dir, output_dir, asset_name, binary_name))

    if not built_assets:
        print('No binaries provided for packaging', file=sys.stderr)
        return 1

    for path in built_assets:
        print(path.name)
    return 0


if __name__ == '__main__':
    sys.exit(main())
