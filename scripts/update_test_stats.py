#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TEST_ROOT = REPO_ROOT / 'tests'
EXCLUDED_PARTS = (
    '/examples/',
    '/fpdev.git2.adapter/',
    '/fpdev.libgit2.base/',
    '/fpdev.core.misc/',
    '/migrated/',
)

README_MD = REPO_ROOT / 'README.md'
README_EN = REPO_ROOT / 'README.en.md'
TESTING_MD = REPO_ROOT / 'docs' / 'testing.md'
ROADMAP_MD = REPO_ROOT / 'docs' / 'ROADMAP.md'
MVP_ACCEPTANCE_MD = REPO_ROOT / 'docs' / 'MVP_ACCEPTANCE_CRITERIA.md'
MVP_ACCEPTANCE_EN = REPO_ROOT / 'docs' / 'MVP_ACCEPTANCE_CRITERIA.en.md'
CI_YML = REPO_ROOT / '.github' / 'workflows' / 'ci.yml'
RUN_ALL_TESTS = REPO_ROOT / 'scripts' / 'run_all_tests.sh'

TEST_INVENTORY_BADGE = 'TEST-INVENTORY-BADGE'
TEST_INVENTORY_SUMMARY = 'TEST-INVENTORY-SUMMARY'
TEST_INVENTORY_COVERAGE = 'TEST-INVENTORY-COVERAGE'
TEST_INVENTORY_FOOTER = 'TEST-INVENTORY-FOOTER'


def discover_tests() -> list[Path]:
    tests: list[Path] = []
    for path in sorted(TEST_ROOT.rglob('test_*.lpr')):
        normalized = '/' + path.relative_to(REPO_ROOT).as_posix() + '/'
        if any(excluded in normalized for excluded in EXCLUDED_PARTS):
            continue
        tests.append(path.relative_to(REPO_ROOT))
    return tests


def replace_once(text: str, pattern: str, repl: str, path: Path) -> str:
    updated, count = re.subn(pattern, repl, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f'pattern not found exactly once in {path}: {pattern}')
    return updated


def replace_marker_block(text: str, marker: str, body: str, path: Path) -> str:
    pattern = re.compile(
        rf'<!-- {re.escape(marker)}:BEGIN -->\n.*?\n<!-- {re.escape(marker)}:END -->',
        flags=re.DOTALL,
    )
    replacement = f'<!-- {marker}:BEGIN -->\n{body}\n<!-- {marker}:END -->'
    updated, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise RuntimeError(f'marker block not found exactly once in {path}: {marker}')
    return updated


def render_readme_md(text: str, count: int) -> str:
    text = replace_marker_block(
        text,
        TEST_INVENTORY_BADGE,
        f'[![Tests](https://img.shields.io/badge/tests-{count}%20discoverable-brightgreen.svg)](#testing)',
        README_MD,
    )
    text = replace_once(
        text,
        r'^(?:\[OK\]|\[INFO\]) (?:Test coverage: .*|Discoverable test programs: .*)$',
        f'[INFO] Discoverable test programs: {count} (same inventory rules as CI)',
        README_MD,
    )
    text = replace_marker_block(
        text,
        TEST_INVENTORY_SUMMARY,
        f'总计: {count} 个可发现的 test_*.lpr 测试程序（与 CI 使用同一发现规则）',
        README_MD,
    )
    return text


def render_readme_en(text: str, count: int) -> str:
    text = replace_marker_block(
        text,
        TEST_INVENTORY_BADGE,
        f'[![Tests](https://img.shields.io/badge/tests-{count}%20discoverable-brightgreen.svg)](#testing)',
        README_EN,
    )
    text = replace_once(
        text,
        r'^(?:✅|\[INFO\]) (?:Test Coverage: .*|Discoverable test programs: .*)$',
        f'[INFO] Discoverable test programs: {count} (same inventory rules as CI)',
        README_EN,
    )
    text = replace_marker_block(
        text,
        TEST_INVENTORY_SUMMARY,
        f'✅ {count} discoverable test_*.lpr programs (same rules as CI)',
        README_EN,
    )
    return text


def render_testing_md(text: str, count: int) -> str:
    text = replace_marker_block(
        text,
        TEST_INVENTORY_COVERAGE,
        (
            'Current discoverable test-program inventory:\n\n'
            f'- Discoverable `test_*.lpr` programs: {count}\n'
            '- Shared discovery rules: CI and `scripts/run_all_tests.sh` use the same inventory source\n'
            '- Default exclusions: `examples`, `fpdev.git2.adapter`, `fpdev.libgit2.base`, `fpdev.core.misc`, `migrated`\n'
            '- Sync command: `python3 scripts/update_test_stats.py --write`\n'
            '- Verification command: `python3 scripts/update_test_stats.py --check`'
        ),
        TESTING_MD,
    )
    text = replace_marker_block(
        text,
        TEST_INVENTORY_FOOTER,
        f'**Test Inventory**: {count} discoverable test programs (same rules as CI)',
        TESTING_MD,
    )
    return text


def render_roadmap_md(text: str, count: int) -> str:
    text = replace_once(
        text,
        r'^- ✅ \*\*Test Coverage\*\*: .*$',
        f'- ✅ **Test Coverage**: {count} discoverable tests (same inventory rules as CI), latest full-run evidence recorded separately',
        ROADMAP_MD,
    )
    text = replace_once(
        text,
        r'^- Test Coverage: .*$',
        f'- Test Coverage: {count} discoverable tests (same inventory rules as CI), latest full-run evidence recorded separately',
        ROADMAP_MD,
    )
    return text


def render_mvp_acceptance_md(text: str, count: int) -> str:
    return replace_once(
        text,
        r'^- \[x\] Test inventory is synchronized at `\d+` discoverable `test_\*\.lpr` programs$',
        f'- [x] Test inventory is synchronized at `{count}` discoverable `test_*.lpr` programs',
        MVP_ACCEPTANCE_MD,
    )


def render_ci_yml(text: str) -> str:
    pattern = (
        r'    - name: Verify test(?: count| inventory sync)\n'
        r'      run: \|\n'
        r'[\s\S]*?'
        r'        echo "(?:Test count check passed\.|Discoverable test programs: \$\{TEST_COUNT\})"\n'
    )
    replacement = (
        '    - name: Verify test inventory sync\n'
        '      run: |\n'
        '        python3 scripts/update_test_stats.py --check\n'
        '        TEST_COUNT=$(python3 scripts/update_test_stats.py --count)\n'
        '        echo "Discoverable test programs: ${TEST_COUNT}"\n'
    )
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        return text
    if count == 1:
        return updated
    raise RuntimeError(f'pattern not found exactly once in {CI_YML}: {pattern}')


def render_run_all_tests(text: str) -> str:
    patterns = (
        r'TEST_FILES=(?:\$\(find tests -name "test_\*\.lpr" \
[\s\S]*?    \| sort\)|"\$\(python3 scripts/update_test_stats.py --list\)"|\$\(python3 scripts/update_test_stats.py --list\))',
        r'mapfile -t TEST_FILES < <\(python3 "\$\{SCRIPT_DIR\}/[^"]+" --list\)',
    )
    replacement = 'mapfile -t TEST_FILES < <(python3 "${SCRIPT_DIR}/update_test_stats.py" --list)'
    for pattern in patterns:
        updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
        if count == 1:
            return updated
    raise RuntimeError(f'pattern not found exactly once in {RUN_ALL_TESTS}: {patterns[0]}')


def render_updates(count: int) -> dict[Path, str]:
    return {
        README_MD: render_readme_md(README_MD.read_text(), count),
        README_EN: render_readme_en(README_EN.read_text(), count),
        TESTING_MD: render_testing_md(TESTING_MD.read_text(), count),
        ROADMAP_MD: render_roadmap_md(ROADMAP_MD.read_text(), count),
        MVP_ACCEPTANCE_MD: render_mvp_acceptance_md(MVP_ACCEPTANCE_MD.read_text(), count),
        MVP_ACCEPTANCE_EN: render_mvp_acceptance_md(MVP_ACCEPTANCE_EN.read_text(), count),
        CI_YML: render_ci_yml(CI_YML.read_text()),
        RUN_ALL_TESTS: render_run_all_tests(RUN_ALL_TESTS.read_text()),
    }


def write_updates(updates: dict[Path, str]) -> None:
    for path, content in updates.items():
        path.write_text(content)


def main() -> int:
    parser = argparse.ArgumentParser(description='Sync FPDev test inventory text with actual discoverable tests.')
    parser.add_argument('--count', action='store_true', help='Print discoverable test count')
    parser.add_argument('--list', action='store_true', help='Print discoverable test paths')
    parser.add_argument('--write', action='store_true', help='Write synchronized updates to tracked files')
    parser.add_argument('--check', action='store_true', help='Fail if tracked files are out of sync')
    args = parser.parse_args()

    tests = discover_tests()
    count = len(tests)

    if args.count:
        print(count)
        return 0

    if args.list:
        for test in tests:
            print(test.as_posix())
        return 0

    updates = render_updates(count)

    if args.write:
        write_updates(updates)
        return 0

    if args.check:
        mismatches = []
        for path, expected in updates.items():
            current = path.read_text()
            if current != expected:
                mismatches.append(path.relative_to(REPO_ROOT).as_posix())
        if mismatches:
            print('Out-of-sync files:')
            for mismatch in mismatches:
                print(f'  - {mismatch}')
            return 1
        return 0

    parser.print_help()
    return 0


if __name__ == '__main__':
    sys.exit(main())
