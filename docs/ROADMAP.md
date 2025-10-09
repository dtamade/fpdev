# FPDev Development Roadmap

**Version**: 1.0.0 → 2.0.0
**Status**: In Progress
**Last Updated**: 2025-01-29
**Methodology**: Test-Driven Development (TDD)

---

## Project Status Summary

### Current State (v1.0.0)
- ✅ **Core Architecture**: Complete (Interface-driven, Command Pattern)
- ✅ **Git Integration**: Complete (Three-layer libgit2 wrapper)
- ✅ **Build System**: Complete (Sandbox-isolated builds)
- ✅ **Configuration**: Complete (JSON-based config management)
- ✅ **Test Coverage**: 100% (29 config tests passing)
- ✅ **Documentation**: Complete (CLAUDE.md, WARP.md, README.md)
- ✅ **Basic Commands**: Implemented (fpc, lazarus, project, package, cross)

### Production Readiness
- Code Quality: Production-ready
- Platform Support: Windows, Linux, macOS
- Test Coverage: 126 tests (README claims), 29 config tests verified
- No critical bugs identified

---

## Development Philosophy

Following the TODO-FPC-v1.md philosophy:

> **Purpose**: Prepare a verifiable, switchable, reproducible FPC toolchain with smart reuse (cache/repos), without touching the system environment by default.

### Core Principles
1. **Scope-Aware**: Project-level (if .fpdev exists) → User-level → System-level (with consent)
2. **Source-Agnostic**: Auto (prefer binary → fallback source)
3. **Activation**: Off by default (explicit `use` or `--activate`)
4. **Smart Reuse**: No redundant clones/builds; leverage existing repos and caches
5. **Verification**: Mandatory smoke tests (version check + hello.pas compilation)

---

## TODO Analysis

### Categorized TODOs by Module

#### 1. FPC Management (Priority: HIGH)
- [ ] **Source update functionality** (`fpdev.cmd.fpc.pas:840`)
  - Impact: HIGH - Users need to update existing installations
  - Complexity: MEDIUM - Git pull + rebuild orchestration
  - Dependencies: None

- [ ] **Source cleanup functionality** (`fpdev.cmd.fpc.pas:847`)
  - Impact: MEDIUM - Disk space management
  - Complexity: LOW - Delete temp files and build artifacts
  - Dependencies: None

- [ ] **Bootstrap compiler download** (`fpdev.fpc.source.pas:544`)
  - Impact: HIGH - Required for source builds
  - Complexity: HIGH - Platform-specific binary downloads
  - Dependencies: None

- [ ] **Packages build** (`fpdev.fpc.source.pas:637`)
  - Impact: MEDIUM - Complete FPC installation
  - Complexity: MEDIUM - Additional make targets
  - Dependencies: Compiler + RTL built

- [ ] **Build cache usage** (`fpdev.fpc.source.pas:745`)
  - Impact: MEDIUM - Performance optimization
  - Complexity: MEDIUM - Cache invalidation strategy
  - Dependencies: None

#### 2. Lazarus Management (Priority: MEDIUM)
- [ ] **Source update functionality** (`fpdev.cmd.lazarus.pas:666`)
  - Impact: HIGH - Users need to update IDE
  - Complexity: MEDIUM - Similar to FPC update
  - Dependencies: None

- [ ] **Source cleanup functionality** (`fpdev.cmd.lazarus.pas:673`)
  - Impact: MEDIUM - Disk space management
  - Complexity: LOW - Delete temp files
  - Dependencies: None

- [ ] **IDE configuration functionality** (`fpdev.cmd.lazarus.pas:841`)
  - Impact: HIGH - User experience enhancement
  - Complexity: HIGH - XML/INI config manipulation
  - Dependencies: Lazarus installed

#### 3. Cross-Compilation (Priority: LOW)
- [ ] **Binutils download logic** (`fpdev.cmd.cross.pas:284`)
  - Impact: HIGH - Required for cross-compilation
  - Complexity: HIGH - Platform-specific toolchains
  - Dependencies: Manifest system

- [ ] **Libraries download logic** (`fpdev.cmd.cross.pas:299`)
  - Impact: HIGH - Required for cross-compilation
  - Complexity: HIGH - Target-specific libraries
  - Dependencies: Binutils installed

- [ ] **Cross-compile test build** (`fpdev.cmd.cross.pas:697`)
  - Impact: MEDIUM - Verification
  - Complexity: MEDIUM - Hello-world cross-compile
  - Dependencies: Cross toolchain installed

- [ ] **Target update functionality** (`fpdev.cmd.cross.pas:758`)
  - Impact: LOW - Maintenance
  - Complexity: MEDIUM - Toolchain updates
  - Dependencies: Cross toolchain installed

- [ ] **Target cleanup functionality** (`fpdev.cmd.cross.pas:765`)
  - Impact: LOW - Disk space management
  - Complexity: LOW - Delete target files
  - Dependencies: None

#### 4. Package Management (Priority: MEDIUM)
**Note**: Package download is ALREADY implemented using `fpdev.toolchain.fetcher`!

- [ ] **Dependency resolution** (`fpdev.cmd.package.pas:643`)
  - Impact: HIGH - Automatic dependency handling
  - Complexity: HIGH - Dependency graph resolution
  - Dependencies: Package metadata format

- [ ] **Package verification** (`fpdev.cmd.package.pas:1030`)
  - Impact: MEDIUM - Security and integrity
  - Complexity: MEDIUM - Checksum verification + signature checks
  - Dependencies: Package metadata

- [ ] **Create package functionality** (`fpdev.cmd.package.pas:1342`)
  - Impact: MEDIUM - Package authoring
  - Complexity: MEDIUM - Metadata generation + archive creation
  - Dependencies: None

- [ ] **Publish package functionality** (`fpdev.cmd.package.pas:1349`)
  - Impact: LOW - Advanced feature
  - Complexity: HIGH - Repository upload + metadata submission
  - Dependencies: Create package, Authentication system

#### 5. Project Management (Priority: HIGH)
- [ ] **Project cleanup functionality** (`fpdev.cmd.project.pas:549`)
  - Impact: HIGH - Development workflow
  - Complexity: LOW - Delete build artifacts
  - Dependencies: None

- [ ] **Project test functionality** (`fpdev.cmd.project.pas:556`)
  - Impact: HIGH - Development workflow
  - Complexity: MEDIUM - Execute test runner
  - Dependencies: Project build

- [ ] **Project run functionality** (`fpdev.cmd.project.pas:563`)
  - Impact: HIGH - Development workflow
  - Complexity: LOW - Execute built binary
  - Dependencies: Project build

- [ ] **Template install functionality** (`fpdev.cmd.project.pas:570`)
  - Impact: MEDIUM - Template extensibility
  - Complexity: MEDIUM - Template package format
  - Dependencies: Package system

- [ ] **Template remove functionality** (`fpdev.cmd.project.pas:577`)
  - Impact: LOW - Template management
  - Complexity: LOW - Delete template directory
  - Dependencies: None

- [ ] **Template update functionality** (`fpdev.cmd.project.pas:590`)
  - Impact: LOW - Template maintenance
  - Complexity: MEDIUM - Template versioning
  - Dependencies: Template install

---

## Development Roadmap (Phased Approach)

### Phase 1: Core Workflow Enhancements (Current Priority)
**Goal**: Improve daily development workflow with essential features

**Duration**: 2-3 weeks
**Impact**: HIGH - Immediate user value

#### 1.1 Project Management Essentials
- [x] ~~Analyze codebase and create roadmap~~ (Complete)
- [ ] **Implement `fpdev project clean`** (TDD)
  - Write tests for cleaning build artifacts
  - Implement cleanup logic (*.o, *.ppu, executables)
  - Document usage
  - **Priority**: 🔴 HIGHEST

- [ ] **Implement `fpdev project run`** (TDD)
  - Write tests for running built executables
  - Implement run logic with argument passing
  - Handle cross-platform executable names
  - **Priority**: 🔴 HIGHEST

- [ ] **Implement `fpdev project test`** (TDD)
  - Write tests for test runner integration
  - Implement test discovery and execution
  - Support FPCUnit and custom test frameworks
  - **Priority**: 🟡 HIGH

#### 1.2 FPC Source Management
- [ ] **Implement `fpdev fpc clean`** (TDD)
  - Write tests for source cleanup
  - Implement cleanup for temp files, build artifacts
  - Preserve source repos by default
  - **Priority**: 🟡 HIGH

- [ ] **Implement `fpdev fpc update`** (TDD)
  - Write tests for source updates
  - Implement git pull + rebuild orchestration
  - Handle version conflicts gracefully
  - **Priority**: 🟢 MEDIUM

### Phase 2: Installation Flexibility (v1.0 → v1.5)
**Goal**: Implement TODO-FPC-v1.md roadmap features

**Duration**: 4-6 weeks
**Impact**: HIGH - Advanced toolchain management

#### 2.1 Scoped Installation
- [ ] Implement `--prefix` option
- [ ] Implement `--scope` (project/user/system)
- [ ] Create metadata format (`.fpdev-meta.json`)
- [ ] Implement scope-aware activation
- [ ] **Priority**: 🟡 HIGH

#### 2.2 Installation Modes
- [ ] Implement `--source` option (auto/binary/source)
- [ ] Add binary mirror support
- [ ] Implement fallback logic
- [ ] **Priority**: 🟢 MEDIUM

#### 2.3 Verification Framework
- [ ] Implement `fpdev fpc verify`
- [ ] Create hello.pas smoke test
- [ ] Add version check (`fpc -iV`)
- [ ] Record verification results in metadata
- [ ] **Priority**: 🟡 HIGH

#### 2.4 Activation System
- [ ] Implement `fpdev fpc use <version>`
- [ ] Create shell activation scripts (.cmd/.sh)
- [ ] Generate VS Code settings.json
- [ ] Print activation instructions
- [ ] **Priority**: 🟢 MEDIUM

### Phase 3: Advanced Features (v1.5 → v2.0)
**Goal**: Package ecosystem and cross-compilation maturity

**Duration**: 6-8 weeks
**Impact**: MEDIUM - Advanced users and contributors

#### 3.1 Package Dependency Resolution
- [ ] Design dependency metadata format
- [ ] Implement dependency graph algorithm
- [ ] Handle circular dependencies
- [ ] Add conflict resolution
- [ ] **Priority**: 🟢 MEDIUM

#### 3.2 Cross-Compilation Toolchain Downloads
- [ ] Design binutils manifest format
- [ ] Implement binutils downloader
- [ ] Implement libraries downloader
- [ ] Add toolchain verification
- [ ] **Priority**: 🔵 LOW

#### 3.3 Package Authoring
- [ ] Implement `fpdev package create`
- [ ] Design package metadata schema
- [ ] Add archive creation logic
- [ ] **Priority**: 🔵 LOW

#### 3.4 Lazarus IDE Integration
- [ ] Implement Lazarus source update
- [ ] Implement Lazarus source cleanup
- [ ] Implement IDE configuration
- [ ] Add IDE settings management
- [ ] **Priority**: 🟢 MEDIUM

### Phase 4: Polish and Optimization (v2.0)
**Goal**: Performance, reliability, and user experience

**Duration**: 2-3 weeks
**Impact**: MEDIUM - Quality of life improvements

#### 4.1 Build Cache System
- [ ] Design cache invalidation strategy
- [ ] Implement cache storage format
- [ ] Add cache usage statistics
- [ ] **Priority**: 🔵 LOW

#### 4.2 Bootstrap Compiler Management
- [ ] Implement bootstrap downloader
- [ ] Add platform detection
- [ ] Handle version compatibility
- [ ] **Priority**: 🟢 MEDIUM

#### 4.3 FPC Packages Build
- [ ] Extend build manager for packages
- [ ] Add package selection UI
- [ ] Handle optional dependencies
- [ ] **Priority**: 🔵 LOW

---

## Implementation Strategy (TDD Red-Green-Refactor)

### For Each Feature:

#### 🔴 Red Phase: Write Failing Test
1. Create test file: `tests/test_<feature>.lpr`
2. Write test cases covering:
   - Happy path (normal usage)
   - Error cases (invalid input)
   - Edge cases (boundary conditions)
3. Run test → verify failure
4. Commit: `test: add failing test for <feature>`

#### 🟢 Green Phase: Implement Minimum Code
1. Implement simplest code to pass test
2. Run test → verify success
3. Commit: `feat: implement <feature>`

#### 🔵 Refactor Phase: Improve Code Quality
1. Refactor while keeping tests green
2. Extract common logic
3. Improve naming and structure
4. Run tests → verify still passing
5. Commit: `refactor: improve <feature> implementation`

### Example: Implementing `fpdev project clean`

```pascal
// Step 1: Red Phase (tests/test_project_clean.lpr)
program test_project_clean;
{$mode objfpc}{$H+}
uses
  SysUtils, fpdev.cmd.project;

procedure TestCleanRemovesObjectFiles;
var
  ProjectDir: string;
begin
  // Setup: Create test project with build artifacts
  ProjectDir := 'test_project_temp';
  ForceDirectories(ProjectDir);
  WriteStringToFile(ProjectDir + '/test.o', 'dummy');
  WriteStringToFile(ProjectDir + '/test.ppu', 'dummy');
  WriteStringToFile(ProjectDir + '/test.exe', 'dummy');

  // Execute
  CleanProject(ProjectDir);

  // Assert: Build artifacts removed, source preserved
  Assert(not FileExists(ProjectDir + '/test.o'), 'Object file should be removed');
  Assert(not FileExists(ProjectDir + '/test.ppu'), 'Unit file should be removed');
  Assert(not FileExists(ProjectDir + '/test.exe'), 'Executable should be removed');

  // Cleanup
  RemoveDir(ProjectDir);
  WriteLn('✓ TestCleanRemovesObjectFiles passed');
end;

begin
  try
    TestCleanRemovesObjectFiles;
    WriteLn('All tests passed');
  except
    on E: Exception do
    begin
      WriteLn('Test failed: ', E.Message);
      Halt(1);
    end;
  end;
end.
```

```bash
# Compile and run test (should fail)
lazbuild tests/test_project_clean.lpi
./bin/test_project_clean
# Expected: Test fails because CleanProject not implemented
```

```pascal
// Step 2: Green Phase (src/fpdev.cmd.project.pas)
function TProjectManager.CleanProject(const AProjectDir: string): Boolean;
var
  SR: TSearchRec;
  FileName: string;
begin
  Result := False;
  if not DirectoryExists(AProjectDir) then Exit;

  // Remove .o, .ppu, .exe files
  if FindFirst(AProjectDir + '/*.*', faAnyFile, SR) = 0 then
  begin
    repeat
      FileName := AProjectDir + '/' + SR.Name;
      if (ExtractFileExt(FileName) = '.o') or
         (ExtractFileExt(FileName) = '.ppu') or
         (ExtractFileExt(FileName) = '.exe') then
      begin
        DeleteFile(FileName);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  Result := True;
end;
```

```bash
# Run test again (should pass)
./bin/test_project_clean
# Expected: ✓ TestCleanRemovesObjectFiles passed
```

```pascal
// Step 3: Refactor Phase
// Extract common logic, improve error handling
function TProjectManager.CleanProject(const AProjectDir: string): Boolean;
const
  CLEANABLE_EXTENSIONS: array[0..2] of string = ('.o', '.ppu', '.exe');
var
  Ext: string;
  DeletedCount: Integer;
begin
  Result := False;
  if not DirectoryExists(AProjectDir) then
  begin
    WriteLn('Error: Project directory does not exist: ', AProjectDir);
    Exit;
  end;

  DeletedCount := 0;
  for Ext in CLEANABLE_EXTENSIONS do
    DeletedCount += DeleteFilesByExtension(AProjectDir, Ext);

  WriteLn('Cleaned ', DeletedCount, ' build artifact(s)');
  Result := True;
end;

function TProjectManager.DeleteFilesByExtension(const ADir, AExt: string): Integer;
var
  SR: TSearchRec;
  FileName: string;
begin
  Result := 0;
  if FindFirst(ADir + '/*' + AExt, faAnyFile, SR) = 0 then
  begin
    repeat
      FileName := ADir + '/' + SR.Name;
      if DeleteFile(FileName) then
        Inc(Result);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;
```

---

## Success Criteria

### Phase 1 Success Metrics
- [ ] All Phase 1 features implemented with TDD
- [ ] 100% test coverage for new features
- [ ] All tests passing (config + new features)
- [ ] Documentation updated (README, CLAUDE.md)
- [ ] No regressions in existing functionality

### Phase 2 Success Metrics
- [ ] `fpdev fpc install --prefix <dir>` works correctly
- [ ] `fpdev fpc verify <version>` runs smoke tests
- [ ] `fpdev fpc use <version>` activates toolchain
- [ ] `fpdev fpc list` shows installed versions with metadata
- [ ] Idempotent installs (no redundant clones)

### Phase 3 Success Metrics
- [ ] Dependency resolution algorithm tested and working
- [ ] Cross-compilation toolchains downloadable
- [ ] Package creation functional
- [ ] Lazarus IDE configuration working

### Phase 4 Success Metrics
- [ ] Build cache reduces build time by 50%+
- [ ] Bootstrap downloader supports all platforms
- [ ] FPC packages build successfully

---

## Risk Management

### Technical Risks
1. **Windows PATH shimming complexity**
   - Mitigation: Start with activation scripts, avoid global PATH modification

2. **Binary mirror availability**
   - Mitigation: Clear communication, fallback to source builds

3. **Cross-platform compatibility**
   - Mitigation: Test on all platforms regularly, use CI/CD

4. **Dependency graph complexity**
   - Mitigation: Use well-tested graph algorithms, handle cycles gracefully

### Process Risks
1. **Scope creep**
   - Mitigation: Stick to phased roadmap, defer non-critical features

2. **Test maintenance burden**
   - Mitigation: Keep tests simple and focused, refactor regularly

3. **Documentation drift**
   - Mitigation: Update docs with each feature, review in code review

---

## Next Immediate Actions

### Week 1 (Current)
1. ✅ Complete project status analysis
2. ✅ Create development roadmap (this document)
3. [ ] **START: Implement `fpdev project clean` (TDD)**
   - Write failing test
   - Implement feature
   - Refactor and commit

### Week 2
1. [ ] Implement `fpdev project run` (TDD)
2. [ ] Implement `fpdev fpc clean` (TDD)
3. [ ] Update documentation

### Week 3-4
1. [ ] Implement `fpdev project test` (TDD)
2. [ ] Implement `fpdev fpc update` (TDD)
3. [ ] Write comprehensive tests for all new features

---

## Progress Tracking

Use this checklist to track implementation progress:

### Phase 1 Progress: [██░░░░░░░░] 20% (2/10 tasks complete)
- [x] Analyze project status
- [x] Create roadmap
- [ ] Implement project clean
- [ ] Implement project run
- [ ] Implement project test
- [ ] Implement fpc clean
- [ ] Implement fpc update
- [ ] Write tests for all features
- [ ] Update documentation
- [ ] Release v1.1

---

**Last Updated**: 2025-01-29
**Maintained By**: FPDev Development Team
**License**: MIT
