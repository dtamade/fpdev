#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bin lib

fpc -Fu../../src -Fu. -FUlib -obin/example_toolchain_check -gl -gh example_toolchain_check.lpr
fpc -Fu../../src -Fu. -FUlib -obin/example_policy_check -gl -gh example_policy_check.lpr
fpc -Fu../../src -Fu. -FUlib -obin/example_manifest_fetch -gl -gh example_manifest_fetch.lpr

echo "=== example_toolchain_check ==="
./bin/example_toolchain_check

echo "=== example_policy_check (main) ==="
./bin/example_policy_check main

echo "=== example_policy_check (3.2.2) ==="
./bin/example_policy_check 3.2.2

echo "=== example_manifest_fetch (mock) ==="
./bin/example_manifest_fetch

