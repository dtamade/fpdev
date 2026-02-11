# Deprecated Code Audit Report

**Date**: 2026-02-11
**Status**: Round 4 Analysis

## Summary

| Unit | Status | Production Usage | Recommended Action |
|------|--------|------------------|-------------------|
| fpdev.git2.pas | DEPRECATED | 0 callers in src/ | Keep for tests; document migration |
| fpdev.http.download.pas | DEPRECATED | 0 callers in src/ | Keep for tests; already cleaned |
| fpdev.fpc.installer.pas (2 methods) | DEPRECATED | Internal only | Document; low priority |
| fpdev.fpc.source.pas (1 method) | DEPRECATED | Internal only | Document; low priority |
| fpdev.fpc.bootstrap.pas (1 function) | DEPRECATED comment | N/A | Comment only; no action |

## Detailed Analysis

### 1. fpdev.git2.pas (Entire Unit)

**Status**: DEPRECATED (replaced by git2.api + git2.impl)

**Current State**:
- Unit header marked as DEPRECATED
- Recommends using interface-based IGitManager pattern
- `GitManager()` singleton function was removed in Round 2

**Usage**:
- 0 production source files use this unit
- Test files still reference it (backward compatibility)

**Recommendation**:
- Keep unit for test compatibility
- Update CLAUDE.md documentation (already done)
- No code changes needed

### 2. fpdev.http.download.pas (Entire Unit)

**Status**: DEPRECATED (replaced by fpdev.toolchain.fetcher)

**Current State**:
- Unit header marked as DEPRECATED
- Migration guide to fpdev.toolchain.fetcher provided
- THTTPDownloader usage removed from fpdev.fpc.binary.pas (Round 3)

**Usage**:
- 0 production source files use this unit
- Test file exists: test_http_download.lpr

**Recommendation**:
- Keep unit for test compatibility
- Consider removing in future major version
- No code changes needed

### 3. fpdev.fpc.installer.pas (2 Methods)

**Deprecated Methods**:
- `GetPackageURL()` - Gets download URL for binary FPC package
- `DownloadPackage()` - Downloads binary FPC package from legacy sources

**Current State**:
- Both methods marked with `{ DEPRECATED: ... }` comment
- Internal implementation detail, not public API

**Recommendation**:
- Low priority for cleanup
- Document in method comments (already done)
- No immediate action needed

### 4. fpdev.fpc.source.pas (1 Method)

**Deprecated Method**:
- `GetBootstrapCompilerURL()` - Use fpdev-repo for bootstrap compilers instead

**Current State**:
- Method marked with `{ DEPRECATED: ... }` comment
- Internal implementation detail

**Recommendation**:
- Low priority for cleanup
- Document in method comments (already done)
- No immediate action needed

### 5. fpdev.fpc.bootstrap.pas (1 Comment)

**Deprecated Code**:
- Function with SourceForge URLs (no longer supported)

**Current State**:
- Comment-only deprecation marker
- Code still exists but shouldn't be called

**Recommendation**:
- No action needed
- Comment serves as documentation

## Migration Completed

The following migrations have been completed:

1. **SharedGitManager → Instance Field** (Round 3, Task #11)
   - Migrated global singleton to TGitOperations.FGitManager
   - Each instance now manages its own IGitManager lifetime

2. **THTTPDownloader → fpdev.toolchain.fetcher** (Round 3, Task #12)
   - Removed dead THTTPDownloader usage from fpdev.fpc.binary.pas
   - Production code now uses EnsureDownloadedCached()

3. **GitManager() singleton → Direct TGitManager.Create** (Round 2)
   - Removed FGitManager global and GitManager() function
   - Code now uses direct instantiation or IGitManager interface

## Conclusion

No critical deprecated code remains in production paths. All deprecated units/methods are:
- Properly documented with deprecation notices
- Unused in production source files
- Retained for test compatibility only

**Next Steps**:
- Consider removing deprecated units in next major version
- Update ROADMAP.md with deprecation timeline
- Monitor test dependencies on deprecated code
