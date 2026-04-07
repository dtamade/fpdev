# FPDev Development Roadmap & Acceptance Criteria

> Historical document: this snapshot reflects the 2026-01-13 gap analysis and is no longer the current execution truth.
> For current public status use `docs/ROADMAP.md`; for release close-out use `docs/MVP_ACCEPTANCE_CRITERIA.md` and `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`.
> 当前工作树补充说明：本文提到的 `src/fpdev.cmd.fpc.pas` 现已不是当前实现中心，而是兼容层；当前 worktree 的实现重心与发布状态应以 `docs/ROADMAP.md` 和相关 manager/action 单元为准。

## Project Status Analysis

### Current State (2026-01-13)

Based on comprehensive code analysis, FPDev has the following completion status:

| Module | Status | Completion |
|--------|--------|------------|
| CLI Framework | Working | 95% |
| Command Registry | Working | 100% |
| Configuration System | Working | 90% |
| FPC Version Management | Partial | 60% |
| FPC Source Installation | Broken | 30% |
| FPC Binary Installation | Not Implemented | 10% |
| Lazarus Management | Skeleton | 20% |
| Cross-Compilation | Framework Only | 40% |
| Package Management | Skeleton | 15% |

### Critical Issues Identified

#### Issue #1: FPC Install Shows Success But Doesn't Execute (P0)

**Location**: `src/fpdev.cmd.fpc.pas:702-706`

```pascal
// If already installed and not forcing reinstall, skip
if IsVersionInstalled(AVersion) and (APrefix = '') and (not AEnsure) then
begin
  FOut.WriteLn(_Fmt(ERR_ALREADY_INSTALLED, ['FPC ' + AVersion]));
  Result := True;  // Returns success without doing anything!
  Exit;
end;
```

**Problem**: `IsVersionInstalled` checks for `fpc.exe` in install path, but the path doesn't exist. The function returns `False`, but subsequent steps fail silently.

**Root Cause Chain**:
1. `DownloadSource` calls `TGitOperations.Clone`
2. Git clone may fail silently if no git backend available
3. `BuildFromSource` checks `DirectoryExists(ASourceDir)` - fails if clone failed
4. Error messages are written but `Result := False` doesn't propagate properly

#### Issue #2: No Binary Installation Path (P1)

**Location**: `src/fpdev.cmd.fpc.pas:779-782`

```pascal
// Binary installation
FOut.WriteLn(_(MSG_FPC_STEP_DOWNLOAD_BIN));
Result := InstallFromBinary(AVersion, APrefix);
```

`InstallFromBinary` is not implemented - it's a stub that returns `False`.

#### Issue #3: Bootstrap Compiler Chicken-Egg Problem (P1)

To build FPC 3.2.2 from source, you need FPC 3.2.0.
To build FPC 3.2.0 from source, you need FPC 3.0.4.

The bootstrap download from SourceForge is implemented but untested.

---

## MVP Definition (Minimum Viable Product)

### MVP Scope: "Install and Use FPC"

A user should be able to:
1. Install FPDev
2. Run `fpdev fpc install 3.2.2` (binary or source)
3. Run `fpdev fpc use 3.2.2`
4. Compile a Pascal program with the installed FPC

### MVP Acceptance Criteria

#### AC-1: Binary Installation (Primary Path)
```bash
# User runs:
fpdev fpc install 3.2.2

# Expected behavior:
# 1. Downloads FPC 3.2.2 binary from official mirror
# 2. Extracts to ~/.fpdev/fpc/3.2.2/
# 3. Registers in config.json
# 4. Verifies installation with smoke test

# Verification:
fpdev fpc list
# Output: 3.2.2 [installed]

fpdev fpc current
# Output: 3.2.2

~/.fpdev/fpc/3.2.2/bin/fpc -v
# Output: Free Pascal Compiler version 3.2.2
```

#### AC-2: Source Installation (Secondary Path)
```bash
# User runs:
fpdev fpc install 3.2.2 --from-source

# Expected behavior:
# 1. Ensures bootstrap compiler (downloads if needed)
# 2. Clones FPC source from GitLab
# 3. Builds FPC with make
# 4. Installs to ~/.fpdev/fpc/3.2.2/
# 5. Registers in config.json

# Verification:
ls ~/.fpdev/fpc/3.2.2/bin/fpc
# File exists

fpdev fpc doctor
# All checks pass
```

#### AC-3: Version Switching
```bash
fpdev fpc use 3.2.2
# Sets active version

fpdev fpc current
# Output: 3.2.2

# PATH should include ~/.fpdev/fpc/3.2.2/bin
```

#### AC-4: Error Handling
```bash
fpdev fpc install 9.9.9
# Output: Error: Unknown FPC version '9.9.9'
# Exit code: 1

fpdev fpc install 3.2.2 --from-source
# (when no git available)
# Output: Error: Git is required for source installation
# Suggestion: Install git or use binary installation
```

---

## Development Phases

### Phase 1: Fix Critical Installation Path (P0)

**Goal**: Make `fpdev fpc install 3.2.2` actually work

**Tasks**:
1. [ ] Implement `InstallFromBinary` function
   - Download from SourceForge/official mirrors
   - Extract tar.gz/zip based on platform
   - Verify extracted files

2. [ ] Fix error propagation in `InstallVersion`
   - Ensure failures in sub-steps return `False`
   - Add detailed error messages with suggestions

3. [ ] Add installation verification
   - Run `fpc -v` after install
   - Verify expected files exist

**Files to modify**:
- `src/fpdev.cmd.fpc.pas` - InstallFromBinary implementation
- `src/fpdev.fpc.builder.pas` - Error handling improvements
- `src/fpdev.utils.fs.pas` - Add tar.gz extraction

### Phase 2: Robust Source Build (P1)

**Goal**: Make `--from-source` reliable

**Tasks**:
1. [ ] Fix Git backend detection and fallback
   - Prefer libgit2, fallback to CLI git
   - Clear error when neither available

2. [ ] Implement bootstrap compiler download
   - Test SourceForge download path
   - Add checksum verification

3. [ ] Add build progress reporting
   - Stream make output to console
   - Show percentage/stage indicators

**Files to modify**:
- `src/fpdev.utils.git.pas` - Backend detection
- `src/fpdev.fpc.builder.pas` - Bootstrap download
- `src/fpdev.build.manager.pas` - Progress reporting

### Phase 3: Version Management (P2)

**Goal**: Reliable version switching and listing

**Tasks**:
1. [ ] Fix `fpdev fpc list` to show installed versions
2. [ ] Implement `fpdev fpc use <version>` properly
3. [ ] Add `fpdev fpc uninstall <version>`
4. [ ] Add `fpdev fpc update` for source builds

**Files to modify**:
- `src/fpdev.cmd.fpc.pas` - Version management
- `src/fpdev.fpc.version.pas` - Version detection
- `src/fpdev.config.managers.pas` - Toolchain registration

### Phase 4: Cross-Platform Polish (P3)

**Goal**: Work reliably on Windows, Linux, macOS

**Tasks**:
1. [ ] Test and fix Windows-specific paths
2. [ ] Test and fix macOS-specific issues
3. [ ] Add platform-specific binary URLs
4. [ ] Handle platform-specific make variants

### Phase 5: Lazarus Integration (P4)

**Goal**: Basic Lazarus installation

**Tasks**:
1. [ ] Implement `fpdev lazarus install`
2. [ ] Implement `fpdev lazarus use`
3. [ ] Link Lazarus to installed FPC version

---

## Test Plan

### Unit Tests Required

```
tests/
├── test_fpc_install_binary.lpr      # Binary installation
├── test_fpc_install_source.lpr      # Source installation
├── test_fpc_version_switch.lpr      # Version switching
├── test_bootstrap_download.lpr      # Bootstrap compiler
├── test_git_operations.lpr          # Git clone/checkout
└── test_config_toolchain.lpr        # Config management
```

### Integration Tests

> 历史示例：下面的 `scripts/test_mvp.sh` 只反映 2026-01-13 规划时的验证设想，当前工作树未跟踪这个脚本。
> 当前可用的发布/验收入口请以 `docs/MVP_ACCEPTANCE_CRITERIA.md` 和现行 release verification 流程为准。

```bash
# Test script: scripts/test_mvp.sh

#!/bin/bash
set -e

# Clean state
rm -rf ~/.fpdev/fpc/3.2.2

# Test binary install
./bin/fpdev fpc install 3.2.2
test -f ~/.fpdev/fpc/3.2.2/bin/fpc

# Test version listing
./bin/fpdev fpc list | grep "3.2.2"

# Test version switching
./bin/fpdev fpc use 3.2.2
./bin/fpdev fpc current | grep "3.2.2"

# Test compilation
echo "program test; begin writeln('Hello'); end." > /tmp/test.pas
~/.fpdev/fpc/3.2.2/bin/fpc /tmp/test.pas
/tmp/test | grep "Hello"

echo "MVP tests passed!"
```

---

## Comparison with rustup

| Feature | rustup | fpdev | Gap |
|---------|--------|-------|-----|
| Install toolchain | `rustup install stable` | `fpdev fpc install 3.2.2` | Needs implementation |
| Switch version | `rustup default stable` | `fpdev fpc use 3.2.2` | Partial |
| List installed | `rustup show` | `fpdev fpc list` | Working |
| Update | `rustup update` | `fpdev fpc update` | Not implemented |
| Cross-compile | `rustup target add` | `fpdev cross install` | Framework only |
| Component add | `rustup component add` | N/A | Not planned for MVP |
| Self-update | `rustup self update` | N/A | Not planned for MVP |

---

## Success Metrics

### MVP Success Criteria

1. **Installation Success Rate**: >95% on supported platforms
2. **Time to First Compile**: <5 minutes (binary), <30 minutes (source)
3. **Error Message Quality**: Every failure has actionable suggestion
4. **Documentation**: README covers all MVP commands

### Quality Gates

Before declaring MVP complete:
- [ ] All unit tests pass
- [ ] Integration test script passes on Linux
- [ ] Integration test script passes on Windows
- [ ] `fpdev fpc doctor` reports no issues after install
- [ ] No Chinese characters in terminal output (Windows compatibility)

---

## Timeline-Free Priority Order

1. **Immediate**: Fix `InstallFromBinary` - this unblocks all users
2. **Next**: Fix error propagation - users need clear feedback
3. **Then**: Source build reliability - for advanced users
4. **After**: Version management polish
5. **Finally**: Cross-platform testing

---

*Document created: 2026-01-13*
*Last updated: 2026-01-13*
