# Cache System Completion - Implementation Plan

**Version**: v2.0.4
**Date**: 2026-01-16
**Status**: Planning Phase
**Priority**: HIGH (Foundation for future features)

---

## Executive Summary

Complete the FPDev cache system by implementing cache invalidation strategies, storage format optimizations, and enhanced statistics. This builds upon the existing Binary Cache and Offline Mode features (v2.0.3) to provide a production-ready caching solution.

**Key Goals**:
1. Implement intelligent cache invalidation (TTL, version dependencies, content verification)
2. Optimize storage format and metadata structure
3. Enhance cache statistics and user feedback
4. Maintain backward compatibility with existing cache

**Expected Impact**:
- Faster version switching (instant cache hits)
- Reduced disk space usage (smart cleanup)
- Better user experience (clear feedback, offline reliability)
- Solid foundation for dependency resolution and cross-compilation features

---

## Current State Analysis

### Completed Features (v2.0.3)
✅ Binary artifact cache (SaveBinaryArtifact, RestoreBinaryArtifact)
✅ Source artifact cache (SaveArtifacts, RestoreArtifacts)
✅ Cache management commands (list, stats, clean, path)
✅ Offline mode (--offline flag)
✅ Cache bypass (--no-cache flag)
✅ Platform-aware cache keys (fpc-{version}-{cpu}-{os}.tar.gz)
✅ Basic metadata tracking (.meta files)
✅ Cache statistics (hits/misses)

### Current Implementation
- **File**: `src/fpdev.build.cache.pas` (815 lines)
- **Cache Structure**:
  ```
  ~/.fpdev/cache/builds/
  ├── fpc-3.2.2-x86_64-linux.tar.gz          # Source build
  ├── fpc-3.2.2-x86_64-linux.meta            # Metadata
  ├── fpc-3.2.2-x86_64-linux-binary.tar.gz   # Binary download
  ├── fpc-3.2.2-x86_64-linux-binary.meta     # Binary metadata
  └── build-cache.txt                         # Index file
  ```

### Pending Features (ROADMAP Phase 4.1)
❌ Cache invalidation strategy
❌ Storage format improvements
❌ Statistics enhancements

---

## Architecture Decisions

### 1. Cache Invalidation Strategy

**Decision**: Multi-layered invalidation with configurable policies

**Rationale**:
- **Time-based (TTL)**: Prevent stale caches from accumulating
- **Content-based (SHA256)**: Verify integrity on restore
- **Version-based**: Detect FPC source updates
- **Space-based**: Auto-cleanup when disk space is low

**Implementation**:
```pascal
type
  TCacheInvalidationPolicy = (
    cipNone,           // Never invalidate (manual only)
    cipTTL,            // Time-to-live based
    cipContentHash,    // SHA256 verification
    cipVersionCheck,   // Git revision check
    cipSpaceLimit      // Disk space threshold
  );

  TCacheInvalidationConfig = record
    Policies: set of TCacheInvalidationPolicy;
    TTLDays: Integer;              // Default: 30 days
    MaxCacheSizeGB: Integer;       // Default: 10 GB
    VerifyOnRestore: Boolean;      // Default: True
  end;
```

**Trade-offs**:
- ✅ Flexible: Users can configure policies
- ✅ Safe: Default to conservative settings
- ⚠️ Complexity: More code to maintain
- ⚠️ Performance: SHA256 verification adds overhead

### 2. Storage Format Optimization

**Decision**: Enhanced metadata with JSON format + index optimization

**Rationale**:
- Current `.meta` files use simple key=value format
- JSON provides better structure and extensibility
- Add index file for fast lookups without scanning all .meta files

**New Metadata Structure**:
```json
{
  "version": "3.2.2",
  "cpu": "x86_64",
  "os": "linux",
  "source_type": "binary",
  "archive_path": "fpc-3.2.2-x86_64-linux-binary.tar.gz",
  "archive_size": 87654321,
  "sha256": "abc123...",
  "created_at": "2026-01-16T05:40:00Z",
  "last_accessed": "2026-01-16T05:40:00Z",
  "access_count": 5,
  "git_revision": "a1b2c3d4",
  "download_url": "https://sourceforge.net/...",
  "invalidation": {
    "ttl_expires": "2026-02-15T05:40:00Z",
    "verified": true,
    "last_verification": "2026-01-16T05:40:00Z"
  }
}
```

**Index File** (`cache-index.json`):
```json
{
  "version": "1.0",
  "last_updated": "2026-01-16T05:40:00Z",
  "entries": [
    {
      "key": "fpc-3.2.2-x86_64-linux-binary",
      "version": "3.2.2",
      "size": 87654321,
      "created": "2026-01-16T05:40:00Z",
      "accessed": "2026-01-16T05:40:00Z",
      "hits": 5
    }
  ],
  "statistics": {
    "total_entries": 1,
    "total_size": 87654321,
    "total_hits": 5,
    "total_misses": 2
  }
}
```

**Trade-offs**:
- ✅ Extensible: Easy to add new fields
- ✅ Fast: Index enables O(1) lookups
- ✅ Compatible: Can migrate old .meta files
- ⚠️ Migration: Need to convert existing caches

### 3. Statistics Enhancement

**Decision**: Comprehensive metrics with CLI visualization

**Rationale**:
- Current stats are basic (hits/misses only)
- Users need visibility into cache health
- Help users make informed cleanup decisions

**New Statistics**:
```
Cache Statistics:
  Cached versions:     3
  Total size:          245.67 MB
  Cache directory:     ~/.fpdev/cache/builds/

Performance:
  Cache hits:          15 (75.0%)
  Cache misses:        5 (25.0%)
  Avg restore time:    2.3s

Storage:
  Oldest entry:        fpc-3.2.0 (45 days ago)
  Largest entry:       fpc-3.2.2-binary (87.5 MB)
  Space available:     15.2 GB

Recommendations:
  ⚠ fpc-3.2.0 is 45 days old (consider cleaning)
  ✓ Cache is healthy (75% hit rate)
```

**Trade-offs**:
- ✅ Actionable: Users know what to clean
- ✅ Transparent: Clear cache health status
- ⚠️ Overhead: More data to track

---

## Implementation Plan (TDD Methodology)

### Phase 1: Cache Invalidation (Week 1)

#### Task 1.1: TTL-based Invalidation
**Test First** (`tests/test_cache_ttl.lpr`):
```pascal
procedure TestTTLExpiration;
// Create cache entry with TTL
// Advance system time (mock)
// Verify entry is marked as expired
// Verify expired entry is not restored

procedure TestTTLConfiguration;
// Test default TTL (30 days)
// Test custom TTL configuration
// Test TTL=0 (never expire)
```

**Implementation** (`src/fpdev.build.cache.pas`):
- Add `TTLDays` field to `TArtifactInfo`
- Add `IsExpired()` method
- Modify `RestoreArtifacts()` to check TTL
- Add `CleanExpired()` method

**Acceptance Criteria**:
- ✅ Expired entries are not restored
- ✅ TTL is configurable via config file
- ✅ Default TTL is 30 days
- ✅ All tests pass (100%)

#### Task 1.2: Content Hash Verification
**Test First** (`tests/test_cache_verification.lpr`):
```pascal
procedure TestSHA256Verification;
// Create cache with known SHA256
// Restore and verify hash matches
// Corrupt archive and verify detection
// Test verification skip flag

procedure TestVerificationPerformance;
// Measure verification overhead
// Ensure < 500ms for 100MB archive
```

**Implementation**:
- Add SHA256 calculation on save
- Add SHA256 verification on restore
- Add `--skip-verify` flag for fast restore
- Use FPC's built-in hash functions

**Acceptance Criteria**:
- ✅ Corrupted archives are detected
- ✅ Verification is optional (--skip-verify)
- ✅ Performance overhead < 500ms
- ✅ All tests pass (100%)

#### Task 1.3: Space-based Cleanup
**Test First** (`tests/test_cache_space.lpr`):
```pascal
procedure TestSpaceLimitCleanup;
// Fill cache to limit
// Add new entry
// Verify LRU entry is removed
// Verify space is under limit

procedure TestSpaceLimitConfiguration;
// Test default limit (10 GB)
// Test custom limit
// Test limit=0 (unlimited)
```

**Implementation**:
- Add `MaxCacheSizeGB` configuration
- Add `GetTotalCacheSize()` method (already exists)
- Add `CleanupLRU()` method (Least Recently Used)
- Integrate into `SaveArtifacts()`

**Acceptance Criteria**:
- ✅ Cache respects size limit
- ✅ LRU entries are removed first
- ✅ Limit is configurable
- ✅ All tests pass (100%)

### Phase 2: Storage Format Migration (Week 2)

#### Task 2.1: JSON Metadata Format
**Test First** (`tests/test_cache_metadata.lpr`):
```pascal
procedure TestJSONMetadataWrite;
// Create artifact with JSON metadata
// Verify JSON structure
// Verify all fields present

procedure TestJSONMetadataRead;
// Read JSON metadata
// Verify parsing
// Test backward compatibility with old .meta

procedure TestMetadataMigration;
// Create old-format .meta
// Migrate to JSON
// Verify data integrity
```

**Implementation**:
- Add `fpjson` unit dependency
- Create `SaveMetadataJSON()` method
- Create `LoadMetadataJSON()` method
- Add migration logic in constructor

**Acceptance Criteria**:
- ✅ New caches use JSON format
- ✅ Old .meta files are migrated automatically
- ✅ No data loss during migration
- ✅ All tests pass (100%)

#### Task 2.2: Cache Index
**Test First** (`tests/test_cache_index.lpr`):
```pascal
procedure TestIndexCreation;
// Create multiple cache entries
// Verify index is generated
// Verify index contains all entries

procedure TestIndexLookup;
// Lookup entry by version
// Measure lookup performance (< 10ms)
// Test index rebuild

procedure TestIndexUpdate;
// Add new entry
// Verify index is updated
// Remove entry
// Verify index is updated
```

**Implementation**:
- Create `cache-index.json` structure
- Add `RebuildIndex()` method
- Add `UpdateIndex()` method
- Integrate into save/delete operations

**Acceptance Criteria**:
- ✅ Index enables fast lookups (< 10ms)
- ✅ Index is automatically maintained
- ✅ Index can be rebuilt if corrupted
- ✅ All tests pass (100%)

### Phase 3: Statistics Enhancement (Week 3)

#### Task 3.1: Enhanced Statistics
**Test First** (`tests/test_cache_stats.lpr`):
```pascal
procedure TestStatisticsTracking;
// Track hits/misses
// Track access times
// Track entry ages
// Verify statistics accuracy

procedure TestStatisticsDisplay;
// Generate statistics report
// Verify formatting
// Test recommendations
```

**Implementation**:
- Add `access_count` to metadata
- Add `last_accessed` to metadata
- Enhance `GetCacheStats()` method
- Add `GetRecommendations()` method

**Acceptance Criteria**:
- ✅ Statistics are accurate
- ✅ Recommendations are actionable
- ✅ CLI output is clear and helpful
- ✅ All tests pass (100%)

#### Task 3.2: CLI Improvements
**Test First** (`tests/test_cache_cli.lpr`):
```pascal
procedure TestCacheStatsCommand;
// Run `fpdev fpc cache stats`
// Verify output format
// Verify recommendations

procedure TestCacheListCommand;
// Run `fpdev fpc cache list`
// Verify sorting (by date/size)
// Verify filtering options
```

**Implementation**:
- Enhance `fpdev.cmd.fpc.cache.stats.pas`
- Add sorting options to `fpdev.cmd.fpc.cache.list.pas`
- Add `--verbose` flag for detailed output
- Add color coding for recommendations

**Acceptance Criteria**:
- ✅ Output is user-friendly
- ✅ Sorting and filtering work
- ✅ Recommendations are highlighted
- ✅ All tests pass (100%)

---

## Testing Strategy

### Test Coverage Goals
- **Unit Tests**: 100% coverage of new methods
- **Integration Tests**: End-to-end cache workflows
- **Performance Tests**: Verify overhead < 500ms
- **Compatibility Tests**: Old cache migration

### Test Files
1. `tests/test_cache_ttl.lpr` (6 tests)
2. `tests/test_cache_verification.lpr` (4 tests)
3. `tests/test_cache_space.lpr` (5 tests)
4. `tests/test_cache_metadata.lpr` (6 tests)
5. `tests/test_cache_index.lpr` (6 tests)
6. `tests/test_cache_stats.lpr` (4 tests)
7. `tests/test_cache_cli.lpr` (4 tests)

**Total**: 35 new tests (100% pass rate required)

---

## Risk Assessment

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| SHA256 performance overhead | Medium | Low | Make verification optional (--skip-verify) |
| Metadata migration failures | High | Low | Extensive testing, backup old .meta files |
| Index corruption | Medium | Low | Auto-rebuild on corruption detection |
| Backward compatibility breaks | High | Low | Maintain old .meta support for 2 versions |
| Disk space calculation errors | Medium | Medium | Use platform-specific APIs, add safety margin |

### User Experience Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Confusing cache statistics | Medium | Medium | User testing, clear documentation |
| Unexpected cache cleanup | High | Low | Dry-run mode, confirmation prompts |
| Slow cache operations | Medium | Low | Performance benchmarks, optimization |

---

## Backward Compatibility

### Migration Strategy
1. **Detect old format**: Check for `.meta` files without JSON structure
2. **Auto-migrate**: Convert to JSON on first access
3. **Preserve old files**: Keep `.meta.bak` for rollback
4. **Deprecation timeline**: Support old format for 2 versions (v2.0.4 → v2.0.6)

### Configuration Compatibility
- New config fields have sensible defaults
- Old configs continue to work without changes
- Config migration is automatic and transparent

---

## Documentation Updates

### Files to Update
1. `README.md`: Add cache invalidation and statistics sections
2. `CHANGELOG.md`: Document v2.0.4 changes
3. `CLAUDE.md`: Update cache system documentation
4. `docs/CACHE_SYSTEM.md`: New comprehensive cache guide

### User-Facing Documentation
- Cache invalidation policies and configuration
- Cache statistics interpretation
- Cache cleanup best practices
- Troubleshooting guide

---

## Success Criteria

### Functional Requirements
✅ Cache invalidation works (TTL, content hash, space limit)
✅ Metadata format is JSON-based and extensible
✅ Cache index enables fast lookups (< 10ms)
✅ Statistics provide actionable insights
✅ CLI commands are user-friendly
✅ Backward compatibility is maintained

### Non-Functional Requirements
✅ All 35 tests pass (100% pass rate)
✅ Performance overhead < 500ms for verification
✅ Cache operations are atomic (no partial states)
✅ Error messages are clear and actionable
✅ Documentation is complete and accurate

### Quality Gates
- ✅ Code review by maintainer
- ✅ TDD methodology followed (test-first)
- ✅ No regressions in existing tests
- ✅ Performance benchmarks met
- ✅ User acceptance testing passed

---

## Next Steps

1. **User Approval**: Review and approve this plan
2. **Phase 1 Execution**: Implement cache invalidation (Week 1)
3. **Phase 2 Execution**: Implement storage format migration (Week 2)
4. **Phase 3 Execution**: Implement statistics enhancement (Week 3)
5. **Integration Testing**: End-to-end validation
6. **Documentation**: Update all docs
7. **Release**: v2.0.4 with cache system completion

---

## Appendix: Code Examples

### Example 1: TTL Check
```pascal
function TBuildCache.IsExpired(const AInfo: TArtifactInfo): Boolean;
var
  ExpiryDate: TDateTime;
begin
  if FConfig.TTLDays = 0 then
    Exit(False); // Never expire

  ExpiryDate := AInfo.CreatedAt + FConfig.TTLDays;
  Result := Now > ExpiryDate;
end;
```

### Example 2: SHA256 Verification
```pascal
function TBuildCache.VerifyArtifact(const AArchivePath, AExpectedHash: string): Boolean;
var
  ActualHash: string;
begin
  if not FConfig.VerifyOnRestore then
    Exit(True); // Skip verification

  ActualHash := CalculateSHA256(AArchivePath);
  Result := SameText(ActualHash, AExpectedHash);

  if not Result then
    WriteLn('Warning: Cache verification failed for ', AArchivePath);
end;
```

### Example 3: LRU Cleanup
```pascal
procedure TBuildCache.CleanupLRU;
var
  Entries: TList<TArtifactInfo>;
  TotalSize, MaxSize: Int64;
  I: Integer;
begin
  Entries := GetAllArtifacts;
  try
    // Sort by last accessed (oldest first)
    Entries.Sort(@CompareByLastAccessed);

    TotalSize := GetTotalCacheSize;
    MaxSize := FConfig.MaxCacheSizeGB * 1024 * 1024 * 1024;

    // Remove oldest entries until under limit
    I := 0;
    while (TotalSize > MaxSize) and (I < Entries.Count) do
    begin
      DeleteArtifacts(Entries[I].Version);
      TotalSize := TotalSize - Entries[I].ArchiveSize;
      Inc(I);
    end;
  finally
    Entries.Free;
  end;
end;
```

---

**Plan Status**: Ready for Review
**Estimated Effort**: 3 weeks (TDD methodology)
**Risk Level**: Low (incremental, well-tested)
**Impact**: High (foundation for future features)
