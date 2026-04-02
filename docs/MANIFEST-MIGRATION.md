# Manifest Format Migration Guide

**Date**: 2026-01-18
**Version**: 1.0
**Status**: Completed

## Overview

This document describes the migration from the old manifest format to the new unified manifest format (v1) across all fpdev repositories.

## Migration Summary

**Affected Repositories**:
- `fpdev-fpc` - FPC binary releases
- `fpdev-lazarus` - Lazarus IDE releases
- `fpdev-bootstrap` - Bootstrap compilers
- `fpdev-cross` - Cross-compilation toolchains

**Migration Date**: 2026-01-18
**Parser Support**: `fpdev.manifest.pas` (57 tests passing)

---

## Format Comparison

### Old Format (fpdev-fpc example)

```json
{
  "schema_version": "1.0.0",
  "updated_at": "2026-01-15T12:00:00Z",
  "repository": {
    "name": "fpdev-fpc",
    "type": "fpc",
    "description": "Pre-built FPC binary releases"
  },
  "releases": {
    "3.2.2": {
      "release_date": "2021-05-20",
      "platforms": {
        "linux-x86_64": {
          "url": "https://github.com/.../fpc-3.2.2-linux-x86_64.tar.gz",
          "mirrors": [
            "https://gitee.com/.../fpc-3.2.2-linux-x86_64.tar.gz"
          ],
          "format": "tar.gz",
          "sha256": "46c083c7308a6fb978f0244c0e2e7c4217210200232923f777fc4f0483ca1caf",
          "size": 85384375,
          "components": ["compiler", "rtl", "units", "utils"]
        }
      }
    }
  }
}
```

### New Format (Unified v1)

```json
{
  "manifest-version": "1",
  "date": "2026-01-18",
  "pkg": {
    "fpc": {
      "version": "3.2.2",
      "targets": {
        "linux-x86_64": {
          "url": [
            "https://github.com/.../fpc-3.2.2-linux-x86_64.tar.gz",
            "https://gitee.com/.../fpc-3.2.2-linux-x86_64.tar.gz"
          ],
          "hash": "sha256:46c083c7308a6fb978f0244c0e2e7c4217210200232923f777fc4f0483ca1caf",
          "size": 85384375
        }
      }
    }
  }
}
```

---

## Key Changes

### 1. Top-Level Fields

| Old Format | New Format | Notes |
|------------|------------|-------|
| `schema_version` | `manifest-version` | Simplified version string |
| `updated_at` | `date` | ISO date format (YYYY-MM-DD) |
| `repository` | *(removed)* | Metadata moved to separate index |
| `releases` | `pkg` | Renamed for clarity |

### 2. Structure Hierarchy

**Old**: `releases → version → platforms → platform-name`
**New**: `pkg → package-name → targets → platform-name`

### 3. Hash Format

**Old**: Separate fields
```json
"sha256": "abc123..."
```

**New**: Unified format with algorithm prefix
```json
"hash": "sha256:abc123..."
```

**Supported algorithms**: `sha256`, `sha512`

### 4. URL and Mirrors

**Old**: Separate `url` and `mirrors` fields
```json
"url": "https://primary.com/file.tar.gz",
"mirrors": [
  "https://mirror1.com/file.tar.gz",
  "https://mirror2.com/file.tar.gz"
]
```

**New**: Unified `url` array
```json
"url": [
  "https://primary.com/file.tar.gz",
  "https://mirror1.com/file.tar.gz",
  "https://mirror2.com/file.tar.gz"
]
```

### 5. Removed Fields

The following fields were removed to simplify the format:
- `format` - Can be inferred from URL extension
- `components` - Not used by installer
- `release_date` - Metadata moved to index
- `repository` metadata - Moved to fpdev-index

---

## Benefits of New Format

### 1. **Parser Compatibility**
- Fully compatible with `fpdev.manifest.pas`
- 57 tests passing (100% coverage)
- Already integrated into `fpdev.fpc.installer.pas`

### 2. **Multi-Algorithm Support**
- Supports both SHA256 and SHA512
- Easy to add new algorithms (BLAKE3, etc.)
- Format: `"hash": "algorithm:digest"`

### 3. **Simplified Mirror Management**
- Single `url` array for all mirrors
- Automatic fallback in order
- Simpler download logic

### 4. **Cleaner Structure**
- Removed redundant metadata
- Smaller JSON files
- Faster parsing

### 5. **Version Control**
- `manifest-version` field for future upgrades
- Backward compatibility checking
- Smooth migration path to v2

### 6. **Multi-Repository Consistency**
- Same format across all fpdev-* repositories
- Unified tooling and validation
- Easier maintenance

---

## Migration Process

### Step 1: Backup Old Manifests

```bash
cd ~/projects/fpdev-fpc
cp manifest.json manifest.old.json

cd ~/projects/fpdev-lazarus
cp manifest.json manifest.old.json

cd ~/projects/fpdev-bootstrap
cp manifest.json manifest.old.json

cd ~/projects/fpdev-cross
cp manifest.json manifest.old.json
```

### Step 2: Convert to New Format

Use the conversion script or manual conversion:

```bash
# Manual conversion (already done)
# - fpdev-fpc/manifest-new.json
# - fpdev-lazarus/manifest-new.json
# - fpdev-bootstrap/manifest-new.json
# - fpdev-cross/manifest-new.json
```

### Step 3: Validate New Manifests

```bash
cd ~/projects/fpdev
./bin/test_manifest_parser

# Expected output:
# === Test Summary ===
# Passed: 57
# Failed: 0
```

### Step 4: Replace Old Manifests

```bash
cd ~/projects/fpdev-fpc
mv manifest-new.json manifest.json

cd ~/projects/fpdev-lazarus
mv manifest-new.json manifest.json

cd ~/projects/fpdev-bootstrap
mv manifest-new.json manifest.json

cd ~/projects/fpdev-cross
mv manifest-new.json manifest.json
```

### Step 5: Review Supported Integration Commands

```bash
cd ~/projects/fpdev

# Keep parser validation as the primary manifest contract
./bin/test_manifest_parser

# Review the supported install entrypoints before running networked installs
./bin/fpdev fpc install --help
./bin/fpdev lazarus install --help

# cross dry-run is supported on build planning, not install
./bin/fpdev cross build aarch64-linux --dry-run
```

### Step 6: Commit Changes

```bash
cd ~/projects/fpdev-fpc
git add manifest.json
git commit -m "feat: migrate to unified manifest format v1

- Convert from old schema_version format to manifest-version v1
- Unify url and mirrors into single url array
- Change hash format to algorithm:digest
- Remove redundant metadata fields (format, components, release_date)
- Fully compatible with fpdev.manifest.pas parser (57 tests passing)

BREAKING CHANGE: Old manifest format no longer supported"

cd ~/projects/fpdev-lazarus
git add manifest.json
git commit -m "feat: migrate to unified manifest format v1"

cd ~/projects/fpdev-bootstrap
git add manifest.json
git commit -m "feat: migrate to unified manifest format v1"

cd ~/projects/fpdev-cross
git add manifest.json
git commit -m "feat: migrate to unified manifest format v1"
```

---

## Conversion Examples

### Example 1: FPC Binary Package

**Before**:
```json
{
  "schema_version": "1.0.0",
  "releases": {
    "3.2.2": {
      "platforms": {
        "linux-x86_64": {
          "url": "https://github.com/.../fpc-3.2.2-linux-x86_64.tar.gz",
          "mirrors": ["https://gitee.com/.../fpc-3.2.2-linux-x86_64.tar.gz"],
          "sha256": "46c083c7...",
          "size": 85384375
        }
      }
    }
  }
}
```

**After**:
```json
{
  "manifest-version": "1",
  "date": "2026-01-18",
  "pkg": {
    "fpc": {
      "version": "3.2.2",
      "targets": {
        "linux-x86_64": {
          "url": [
            "https://github.com/.../fpc-3.2.2-linux-x86_64.tar.gz",
            "https://gitee.com/.../fpc-3.2.2-linux-x86_64.tar.gz"
          ],
          "hash": "sha256:46c083c7...",
          "size": 85384375
        }
      }
    }
  }
}
```

### Example 2: Multiple Versions

**Before**:
```json
{
  "releases": {
    "3.2.2": { ... },
    "3.2.0": { ... }
  }
}
```

**After**:
```json
{
  "pkg": {
    "fpc": {
      "version": "3.2.2",
      "targets": { ... }
    },
    "fpc-3.2.0": {
      "version": "3.2.0",
      "targets": { ... }
    }
  }
}
```

---

## Validation

### Parser Tests

All 57 tests in `test_manifest_parser.lpr` pass:

```
[PASS] Parse valid manifest
[PASS] Manifest version is 1
[PASS] Date is correct
[PASS] GetPackage returns true for valid package
[PASS] GetTarget returns true for valid platform
[PASS] Target has 2 mirror URLs
[PASS] Hash uses sha512
[PASS] ValidateHashFormat accepts sha256
[PASS] ValidateHashFormat accepts sha512
...
=== Test Summary ===
Passed: 57
Failed: 0
```

### Integration Checks

```bash
# Keep parser validation as the primary manifest contract
./bin/test_manifest_parser

# Review the real supported install command surfaces
./bin/fpdev fpc install --help
./bin/fpdev lazarus install --help

# cross dry-run is supported on build planning, not install
./bin/fpdev cross build aarch64-linux --dry-run
```

For networked end-to-end validation, run the install commands without the removed
`--dry-run` flag:

```bash
./bin/fpdev fpc install 3.2.2
./bin/fpdev lazarus install 3.8
./bin/fpdev cross install aarch64-linux
```

---

## Rollback Plan

If issues are discovered, rollback is simple:

```bash
cd ~/projects/fpdev-fpc
git revert HEAD
git push

cd ~/projects/fpdev-lazarus
git revert HEAD
git push

cd ~/projects/fpdev-bootstrap
git revert HEAD
git push

cd ~/projects/fpdev-cross
git revert HEAD
git push
```

---

## Future Enhancements (v2)

Potential improvements for manifest format v2:

1. **Incremental Updates**: Delta downloads for large packages
2. **Compression**: gzip-compressed manifests
3. **Component Selection**: Install only specific components
4. **Dependency Management**: Package dependency graphs
5. **Signature Verification**: minisign/GPG signatures
6. **Platform Detection**: Auto-detect platform from manifest

---

## References

- **Specification**: `docs/manifest-spec.md`
- **Parser Implementation**: `src/fpdev.manifest.pas`
- **Parser Tests**: `tests/test_manifest_parser.lpr`
- **Installer Integration**: `src/fpdev.fpc.installer.pas`
- **Rust rustup manifest**: https://rust-lang.github.io/rustup/concepts/channels.html

---

## Changelog

### 2026-01-18 - Initial Migration
- Migrated fpdev-fpc to v1 format
- Migrated fpdev-lazarus to v1 format
- Migrated fpdev-bootstrap to v1 format
- Migrated fpdev-cross to v1 format
- All 57 parser tests passing
- Documentation completed

---

**Maintainer**: FPDev Development Team
**Last Updated**: 2026-01-18
