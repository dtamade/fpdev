# FPC Installation Enhancement - Implementation Plan

**Version**: 1.0
**Date**: 2026-01-18
**Status**: Pending Approval
**Priority**: P0 (Highest)

---

## Executive Summary

Implement fast, reliable FPC installation with binary/source dual-mode support, automatic fallback, and comprehensive verification system.

**User Value**:
- 🚀 Binary install < 5 minutes (vs 30-60 min source build)
- 🔄 Auto-fallback to source build on binary failure
- ✅ Smoke tests ensure installation works
- 📦 Offline support via existing cache system

**Technical Approach**:
- Leverage existing cache system (Phase 4.3)
- Integrate with BuildManager for source builds
- Follow TDD methodology (test-first)
- Maintain cross-platform compatibility

---

## Architecture Design

### Component Breakdown

#### 1. Binary Installation Manager (`fpdev.fpc.binary.pas`)

**Responsibilities**:
- Platform detection (OS + CPU architecture)
- Mirror source management (official + backup)
- Binary download with progress tracking
- Archive extraction and validation
- Integration with cache system

**Key Classes**:
```pascal
TBinaryInstaller = class
  - DetectPlatform(): TPlatformInfo
  - GetDownloadURL(version, platform): string
  - DownloadBinary(url, dest): Boolean
  - ExtractArchive(archive, dest): Boolean
  - ValidateInstallation(path): Boolean
end;

TMirrorManager = class
  - GetMirrors(): TStringList
  - SelectBestMirror(): string
  - TestMirrorAvailability(url): Boolean
end;
```

#### 2. Verification System (`fpdev.fpc.verify.pas`)

**Responsibilities**:
- Version check (`fpc -version`)
- Hello world compilation test
- Metadata generation (`.fpdev-meta.json`)
- Installation integrity validation

**Key Classes**:
```pascal
TFPCVerifier = class
  - VerifyVersion(path, expectedVersion): Boolean
  - CompileHelloWorld(fpcPath): Boolean
  - GenerateMetadata(installPath, version): Boolean
  - ValidateIntegrity(installPath): TVerifyResult
end;
```

#### 3. Unified Install Command (`fpdev.cmd.fpc.install.pas` - Enhanced)

**Responsibilities**:
- Command-line option parsing
- Installation mode selection (auto/binary/source)
- Progress reporting
- Error handling and fallback logic

**Command Options**:
```
fpdev fpc install <version> [options]

Options:
  --binary          Force binary installation
  --source          Force source build
  --offline         Use cache only (no network)
  --no-cache        Skip cache, force fresh download
  --prefix <path>   Custom installation path
  --scope <scope>   Installation scope (project/user/system)
  --verify          Run verification after install (default: true)
  --no-verify       Skip verification
```

---

## Implementation Plan

### Week 1-2: Binary Installation Core

**Tasks**:
1. **Platform Detection** (2 days)
   - Implement `TPlatformInfo` record (OS, CPU, ABI)
   - Add detection logic for Windows/Linux/macOS
   - Support x86_64, i386, ARM64, ARM32
   - Write tests: `test_platform_detection.lpr`

2. **Mirror Management** (2 days)
   - Define mirror configuration format (JSON)
   - Implement `TMirrorManager` class
   - Add official FPC mirrors + backup sources
   - Write tests: `test_mirror_manager.lpr`

3. **Download Engine** (3 days)
   - Implement HTTP download with progress callback
   - Add resume support for interrupted downloads
   - Integrate with cache system (check before download)
   - Write tests: `test_binary_download.lpr`

4. **Archive Extraction** (2 days)
   - Support .tar.gz, .tar.bz2, .zip formats
   - Cross-platform extraction (use libarchive or native tools)
   - Validate extracted files
   - Write tests: `test_archive_extraction.lpr`

5. **Integration** (1 day)
   - Wire up `TBinaryInstaller` components
   - Add to `fpdev fpc install` command
   - End-to-end test: `test_binary_install_e2e.lpr`

**Deliverables**:
- `src/fpdev.fpc.binary.pas` (new)
- `src/fpdev.fpc.mirrors.pas` (new)
- `src/fpdev.http.download.pas` (new, or enhance existing)
- `tests/test_binary_install_*.lpr` (5 test files)
- Updated `src/fpdev.cmd.fpc.install.pas`

---

### Week 3: Verification System

**Tasks**:
1. **Version Check** (1 day)
   - Execute `fpc -version` and parse output
   - Validate version matches expected
   - Write tests: `test_fpc_version_check.lpr`

2. **Hello World Test** (2 days)
   - Generate minimal `hello.pas` program
   - Compile using installed FPC
   - Execute and verify output
   - Clean up temporary files
   - Write tests: `test_hello_world_compile.lpr`

3. **Metadata Generation** (1 day)
   - Define `.fpdev-meta.json` schema
   - Implement `TFPCVerifier.GenerateMetadata()`
   - Include: version, install_date, source_type, platform
   - Write tests: `test_metadata_generation.lpr`

4. **Verify Command** (1 day)
   - Implement `fpdev fpc verify <version>` command
   - Run all verification checks
   - Report results with color-coded output
   - Write tests: `test_verify_command.lpr`

**Deliverables**:
- `src/fpdev.fpc.verify.pas` (new)
- `src/fpdev.cmd.fpc.verify.pas` (new)
- `tests/test_fpc_verify_*.lpr` (4 test files)
- Updated documentation

---

### Week 4: Source Install Fix & Integration

**Tasks**:
1. **Fix Issue #1** (2 days)
   - Debug "shows success but doesn't execute" issue
   - Enhance error logging in BuildManager
   - Add validation checks after build
   - Write regression tests: `test_source_install_fix.lpr`

2. **Unified Install Logic** (2 days)
   - Implement auto-mode (try binary → fallback source)
   - Add progress reporting for both modes
   - Integrate verification into install flow
   - Write tests: `test_install_auto_fallback.lpr`

3. **Error Handling** (1 day)
   - Improve error messages (user-friendly)
   - Add troubleshooting hints
   - Log detailed errors to file
   - Write tests: `test_install_error_handling.lpr`

4. **Documentation** (2 days)
   - Update `README.md` with new install options
   - Add `docs/INSTALLATION.md` guide
   - Document mirror configuration
   - Add troubleshooting section

5. **Integration Testing** (1 day)
   - Full workflow tests (binary + source + verify)
   - Cross-platform testing (Windows/Linux)
   - Performance benchmarks
   - Write tests: `test_install_integration.lpr`

**Deliverables**:
- Fixed `src/fpdev.build.manager.pas`
- Enhanced `src/fpdev.cmd.fpc.install.pas`
- `tests/test_install_*.lpr` (3 test files)
- Updated documentation (README, INSTALLATION)

---

## Data Flow

```
User Command: fpdev fpc install 3.2.2
         ↓
[TFPCInstallCommand] Parse options, determine mode
         ↓
    ┌────┴────┐
    │  Auto?  │ (default)
    └────┬────┘
         ↓
    Try Binary First
         ↓
[TBinaryInstaller]
    ├─ DetectPlatform()
    ├─ SelectMirror()
    ├─ CheckCache() ──→ Cache Hit? → Extract from cache
    ├─ DownloadBinary() ──→ Save to cache
    └─ ExtractArchive()
         ↓
    Binary Success? ──No──→ Fallback to Source Build
         │                        ↓
         Yes                [TBuildManager]
         ↓                   ├─ Clone/Update repo
         │                   ├─ BuildCompiler()
         │                   ├─ BuildRTL()
         │                   └─ Install()
         │                        ↓
         └────────────────────────┘
                  ↓
         [TFPCVerifier]
         ├─ VerifyVersion()
         ├─ CompileHelloWorld()
         └─ GenerateMetadata()
                  ↓
         Installation Complete ✅
```

---

## Risk Assessment

### Risk 1: Mirror Source Availability
**Severity**: 🔴 High
**Impact**: Binary install fails if mirrors are down
**Mitigation**:
- Configure multiple backup mirrors (official + GitHub releases + Gitee)
- Implement automatic mirror failover
- Cache successful downloads for offline use
- Fallback to source build as last resort

### Risk 2: Platform Compatibility
**Severity**: 🟡 Medium
**Impact**: Binary may not work on all platforms/architectures
**Mitigation**:
- Prioritize common platforms (Windows x64, Linux x64, macOS x64)
- Test on real hardware/VMs before release
- Document supported platforms clearly
- Provide source build as alternative

### Risk 3: Archive Format Variations
**Severity**: 🟡 Medium
**Impact**: Extraction may fail for unexpected archive formats
**Mitigation**:
- Support common formats (.tar.gz, .tar.bz2, .zip)
- Validate archive integrity before extraction
- Provide clear error messages on failure
- Test with actual FPC release archives

### Risk 4: Verification False Positives/Negatives
**Severity**: 🟡 Medium
**Impact**: May incorrectly report success/failure
**Mitigation**:
- Use multiple verification methods (version + compile test)
- Allow users to skip verification (`--no-verify`)
- Log detailed verification results
- Test verification on known-good installations

---

## File Changes

### New Files
- `src/fpdev.fpc.binary.pas` - Binary installer core
- `src/fpdev.fpc.mirrors.pas` - Mirror management
- `src/fpdev.fpc.verify.pas` - Verification system
- `src/fpdev.http.download.pas` - HTTP download utility
- `src/fpdev.cmd.fpc.verify.pas` - Verify command
- `tests/test_platform_detection.lpr`
- `tests/test_mirror_manager.lpr`
- `tests/test_binary_download.lpr`
- `tests/test_archive_extraction.lpr`
- `tests/test_binary_install_e2e.lpr`
- `tests/test_fpc_version_check.lpr`
- `tests/test_hello_world_compile.lpr`
- `tests/test_metadata_generation.lpr`
- `tests/test_verify_command.lpr`
- `tests/test_source_install_fix.lpr`
- `tests/test_install_auto_fallback.lpr`
- `tests/test_install_error_handling.lpr`
- `tests/test_install_integration.lpr`

### Modified Files
- `src/fpdev.cmd.fpc.install.pas` - Add binary mode + options
- `src/fpdev.build.manager.pas` - Fix Issue #1, enhance logging
- `src/fpdev.build.cache.pas` - Ensure binary cache integration
- `src/fpdev.lpr` - Import new command units
- `README.md` - Update installation instructions
- `docs/INSTALLATION.md` - Comprehensive install guide
- `CLAUDE.md` - Document new components

---

## Test Strategy

### Unit Tests (13 files)
- Platform detection logic
- Mirror selection algorithm
- Download progress tracking
- Archive extraction
- Version parsing
- Metadata generation

### Integration Tests (3 files)
- Binary install end-to-end
- Source install fallback
- Verification workflow

### Manual Testing
- Windows 10/11 (x64)
- Ubuntu 22.04/24.04 (x64)
- macOS 13+ (x64, ARM64)
- Offline mode (no network)
- Slow network (throttled)

### Performance Benchmarks
- Binary install time (target: < 5 min)
- Source build time (baseline: 30-60 min)
- Cache hit time (target: < 1 min)

---

## Success Criteria

1. ✅ Binary installation completes in < 5 minutes on common platforms
2. ✅ Automatic fallback to source build works reliably
3. ✅ Verification system catches broken installations
4. ✅ Offline mode works with cached binaries
5. ✅ All 16 new tests pass (100% pass rate)
6. ✅ No regression in existing functionality
7. ✅ Documentation is clear and comprehensive
8. ✅ Cross-platform support (Windows/Linux/macOS)

---

## Dependencies

- Existing cache system (`fpdev.build.cache.pas`) ✅ Ready
- BuildManager (`fpdev.build.manager.pas`) ✅ Ready
- Config system (`fpdev.config.interfaces.pas`) ✅ Ready
- HTTP library (Synapse or Indy) ⚠️ Need to verify availability
- Archive library (libarchive or native tools) ⚠️ Need to verify

---

## Rollback Plan

If critical issues arise:
1. Revert changes to `fpdev.cmd.fpc.install.pas`
2. Keep new files but don't register commands
3. Document issues in GitHub issue tracker
4. Plan fixes for next iteration

---

## Next Steps After Approval

1. Create feature branch: `feature/fpc-binary-install`
2. Set up test infrastructure (Week 1, Day 1)
3. Begin TDD cycle: Write first test for platform detection
4. Daily progress updates in todo list
5. Weekly review with user

---

**Estimated Effort**: 4 weeks (80-100 hours)
**Risk Level**: 🟡 Medium (mitigated by fallback strategy)
**User Impact**: ⭐⭐⭐⭐⭐ Very High

---

*This plan follows FPDev's TDD methodology and interface-driven design principles.*
