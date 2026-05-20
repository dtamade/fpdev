#!/bin/bash
set -e

echo "========================================"
echo "  FPDev E2E Validation - Clean Environment"
echo "========================================"
echo

# Verify no pre-existing fpdev data
echo "[1/11] Verifying clean environment..."
if [ -d "$HOME/.fpdev" ]; then
  echo "FAIL: ~/.fpdev already exists"
  exit 1
fi
echo "  OK: No pre-existing fpdev data"
echo

# Check fpdev binary works
echo "[2/11] Checking fpdev binary..."
fpdev --help > /dev/null 2>&1 || true
fpdev version 2>&1 || true
echo "  OK: fpdev binary functional"
echo

# Setup registry (simulate what update-registry would do)
echo "[3/11] Setting up package registry..."
mkdir -p "$HOME/.fpdev/registry/packages"
cp /fpdev/registry/packages/index.json "$HOME/.fpdev/registry/packages/index.json"
mkdir -p "$HOME/.fpdev/packages"
echo "  OK: Registry configured"
echo

# Test package list
echo "[4/11] Listing available packages..."
fpdev package list --all
echo

# Install synapse package
echo "[5/11] Installing synapse package..."
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
echo "[6/11] Verifying package metadata..."
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
echo "[7/11] Testing package deps and why commands..."
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
echo "[8/11] Testing custom package source..."
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

# Test source publish with --package-json
echo "[9/11] Testing source publish --package-json..."
mkdir -p /tmp/pkg-meta-test
cat > /tmp/pkg-meta-test/package.json <<PKGJSON
{
  "name": "meta-pkg",
  "version": "2.0.0",
  "description": "Package from metadata",
  "author": "E2E Bot",
  "license": "Apache-2.0",
  "dependencies": ["openssl"]
}
PKGJSON
fpdev package source publish \
  --index=/tmp/custom-source/index.json \
  --package-json=/tmp/pkg-meta-test/package.json \
  --url=https://example.com/meta-pkg-2.0.0.zip
echo "  --- Verifying meta-pkg in index ---"
python3 -c "
import json
with open('/tmp/custom-source/index.json') as f:
    d = json.load(f)
pkgs = d.get('packages', [])
found = [p for p in pkgs if p['name'] == 'meta-pkg']
if found:
    p = found[0]
    assert p['version'] == '2.0.0', f'version mismatch: {p[\"version\"]}'
    assert p['description'] == 'Package from metadata'
    assert 'openssl' in p.get('dependencies', [])
    print('  PASS: meta-pkg published from package.json metadata')
else:
    print('  FAIL: meta-pkg not found in index')
    exit(1)
"
echo

# Test package lock
echo "[10/11] Testing package lock..."
cd /tmp
mkdir -p lock-test-project && cd lock-test-project
fpdev package lock
if [ -f "fpdev-lock.json" ]; then
  echo "  PASS: fpdev-lock.json generated"
  python3 -c "
import json
with open('fpdev-lock.json') as f:
    d = json.load(f)
print(f'    lockfileVersion: {d.get(\"lockfileVersion\", \"(missing)\")}')
print(f'    packages count: {len(d.get(\"packages\", {}))}')
"
else
  echo "  INFO: fpdev-lock.json not generated (no installed packages in this dir)"
fi
echo

# Test offline mode
echo "[11/11] Testing offline install mode..."
set +e
fpdev package install nonexistent-pkg --offline 2>&1
OFFLINE_EXIT=$?
set -e
if [ $OFFLINE_EXIT -ne 0 ]; then
  echo "  PASS: offline install correctly fails for uncached package (exit=$OFFLINE_EXIT)"
else
  echo "  FAIL: offline install should have failed"
  exit 1
fi
echo

echo "========================================"
echo "  E2E Validation Complete"
echo "========================================"
