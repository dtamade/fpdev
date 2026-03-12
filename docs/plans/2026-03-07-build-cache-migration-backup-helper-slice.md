# Build Cache Migration Backup Helper Slice Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract low-risk old `.meta` backup finalization from `TBuildCache.MigrateMetadataToJSON` into a helper without changing migration behavior.

**Architecture:** Keep `MigrateMetadataToJSON` responsible for old-meta existence checks, reading legacy metadata, writing JSON metadata, and verifying JSON output. Move the backup-path construction and old-meta rename/overwrite behavior into `fpdev.build.cache.migrationbackup`.

**Tech Stack:** Object Pascal (FPC/Lazarus), small filesystem helper, focused Pascal regression tests.

---

### Task 1: Add focused failing test for migration backup helper

**Files:**
- Create: `tests/test_build_cache_migrationbackup.lpr`

**Step 1: Write the failing test**
- Add tests that verify:
  - backup path appends `.bak`
  - existing old meta is renamed to backup
  - existing backup is overwritten by the new old-meta contents

**Step 2: Run test to verify it fails**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_migrationbackup.lpr`
Expected: FAIL because `fpdev.build.cache.migrationbackup` does not exist yet.

### Task 2: Extract migration backup helper and thin the wrapper

**Files:**
- Create: `src/fpdev.build.cache.migrationbackup.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Write minimal implementation**
- Add `BuildCacheGetMetaBackupPath`.
- Add `BuildCacheFinalizeMetaMigration`.
- Keep `MigrateMetadataToJSON` as read/save/verify orchestration plus helper delegation.

**Step 2: Run focused test to verify it passes**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_migrationbackup.lpr && ./bin/test_build_cache_migrationbackup`
Expected: PASS.

### Task 3: Regression verification

**Files:**
- Verify only

**Step 1: Metadata regression**
Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cache_metadata.lpr && ./bin/test_cache_metadata`
Expected: PASS.

**Step 2: Main build and full suite verification**
Run: `lazbuild -B fpdev.lpi && bash scripts/run_all_tests.sh`
Expected: build succeeds and the full suite remains green.
