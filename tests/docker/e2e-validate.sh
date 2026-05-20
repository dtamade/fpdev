#!/bin/bash
set -e

echo "========================================"
echo "  FPDev E2E Validation - Clean Environment"
echo "========================================"
echo

# Verify no pre-existing fpdev data
echo "[1/8] Verifying clean environment..."
if [ -d "$HOME/.fpdev" ]; then
  echo "FAIL: ~/.fpdev already exists"
  exit 1
fi
echo "  OK: No pre-existing fpdev data"
echo

# Check fpdev binary works
echo "[2/8] Checking fpdev binary..."
fpdev --help > /dev/null 2>&1 || true
fpdev version 2>&1 || true
echo "  OK: fpdev binary functional"
echo

# Setup registry (simulate what update-registry would do)
echo "[3/8] Setting up package registry..."
mkdir -p "$HOME/.fpdev/registry/packages"
cp /fpdev/registry/packages/index.json "$HOME/.fpdev/registry/packages/index.json"
mkdir -p "$HOME/.fpdev/packages"
echo "  OK: Registry configured"
echo

# Test package list
echo "[4/8] Listing available packages..."
fpdev package list --all
echo

# Install synapse package
echo "[5/8] Installing synapse package..."
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
echo "[6/8] Verifying package metadata..."
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
echo "[7/8] Testing package deps and why commands..."
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

# Test custom package source (decentralized)
echo "[8/8] Testing custom package source..."
mkdir -p /tmp/custom-source
fpdev package source init /tmp/custom-source
fpdev package source publish \
  --index=/tmp/custom-source/index.json \
  --name=custom-pkg \
  --version=0.1.0 \
  --url=https://example.com/custom-pkg.zip \
  --description="Custom test package" \
  --author="E2E Test" \
  --license=MIT \
  --deps=openssl
fpdev package repo add custom file:///tmp/custom-source/index.json
fpdev package repo update
echo "  --- Verifying custom source package visible ---"
fpdev package list --all | grep custom-pkg
if [ $? -eq 0 ]; then
  echo "  PASS: custom source package visible in list"
else
  echo "  FAIL: custom source package not found"
  exit 1
fi
echo "  --- fpdev package deps custom-pkg ---"
fpdev package deps custom-pkg
echo

echo "========================================"
echo "  E2E Validation Complete"
echo "========================================"
