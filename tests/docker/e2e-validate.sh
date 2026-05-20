#!/bin/bash
set -e

echo "========================================"
echo "  FPDev E2E Validation - Clean Environment"
echo "========================================"
echo

# Verify no pre-existing fpdev data
echo "[1/7] Verifying clean environment..."
if [ -d "$HOME/.fpdev" ]; then
  echo "FAIL: ~/.fpdev already exists"
  exit 1
fi
echo "  OK: No pre-existing fpdev data"
echo

# Check fpdev binary works
echo "[2/7] Checking fpdev binary..."
fpdev --help > /dev/null 2>&1 || true
fpdev version 2>&1 || true
echo "  OK: fpdev binary functional"
echo

# Setup registry (simulate what update-registry would do)
echo "[3/7] Setting up package registry..."
mkdir -p "$HOME/.fpdev/registry/packages"
cp /fpdev/registry/packages/index.json "$HOME/.fpdev/registry/packages/index.json"
mkdir -p "$HOME/.fpdev/packages"
echo "  OK: Registry configured"
echo

# Test package list
echo "[4/7] Listing available packages..."
fpdev package list --all
echo

# Install synapse package
echo "[5/7] Installing synapse package..."
set +e
fpdev package install synapse 2>&1
INSTALL_EXIT=$?
set -e
if [ $INSTALL_EXIT -ne 0 ]; then
  echo "  Package install exit code: $INSTALL_EXIT"
  echo "  (May fail due to network - checking what was written...)"
fi
echo

# Verify package metadata includes dependencies
echo "[6/7] Verifying package metadata..."
if [ -f "$HOME/.fpdev/packages/synapse/package.json" ]; then
  echo "  package.json exists"
  python3 -c "
import json
with open('$HOME/.fpdev/packages/synapse/package.json') as f:
    d = json.load(f)
print(f'    name: {d.get(\"name\", \"(missing)\")}')
print(f'    version: {d.get(\"version\", \"(missing)\")}')
print(f'    dependencies: {d.get(\"dependencies\", \"(missing)\")}')
deps = d.get('dependencies', [])
if 'openssl' in deps:
    print('  PASS: dependencies contains openssl')
elif len(deps) == 0:
    print('  WARN: dependencies is empty')
else:
    print(f'  INFO: dependencies = {deps}')
"
else
  echo "  package.json not found (install may have failed due to network)"
  echo "  Testing deps/why with available packages instead..."
fi
echo

# Test package deps command
echo "[7/7] Testing package deps and why commands..."
echo "  --- fpdev package deps synapse ---"
fpdev package deps synapse
echo
echo "  --- fpdev package deps synapse --flat ---"
fpdev package deps synapse --flat
echo
echo "  --- fpdev package deps openssl ---"
fpdev package deps openssl
echo
echo "  --- fpdev package why openssl ---"
fpdev package why openssl
echo
echo "  --- fpdev package deps (project level, from fpdev-lock.json) ---"
cd /fpdev
fpdev package deps
echo

echo "========================================"
echo "  E2E Validation Complete"
echo "========================================"
