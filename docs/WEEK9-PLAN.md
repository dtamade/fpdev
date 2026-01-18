# Week 9 Plan: Package Authoring System

**Date**: 2026-01-19
**Status**: 📋 Planning
**Branch**: main → feature/package-authoring

## Overview

Week 9 focuses on implementing the **Package Authoring System** (Phase 3.3), completing the package management lifecycle. After Week 8's dependency resolution system (consumer side), Week 9 enables developers to create, validate, and publish their own packages (producer side).

## Context

### Completed Work (Week 1-8)
- ✅ Week 1-2: Core Workflow
- ✅ Week 3-4: Manifest System
- ✅ Week 5: Bootstrap Compiler Management
- ✅ Week 6: Multi-Mirror Fallback & Offline Mode
- ✅ Week 7: Binary Cache System (91.1% performance improvement)
- ✅ Week 8: Package Dependency Resolution System (93.7% test coverage)

### Current Project Status
- **Phase 1**: Core Workflow - ✅ 100% Complete
- **Phase 2**: Installation Flexibility - ✅ 100% Complete
- **Phase 3**: Advanced Features - 🔄 In Progress
  - 3.4 Lazarus IDE Integration - ✅ Complete
  - 3.1 Package Dependency Resolution - ✅ Complete (Week 8)
  - **3.3 Package Authoring - ⏳ Week 9 Target**
  - 3.2 Cross-Compilation Support - 🔜 Future
- **Phase 4**: Polish and Optimization - 🔄 In Progress
  - 4.2 Bootstrap Compiler Management - ✅ Complete
  - 4.3 FPC Packages Build - ✅ Complete

### Why Package Authoring?

**User Pain Point**:
```bash
# Current: No way to create packages
$ # User has to manually create package.json, tar.gz, etc.
$ # No validation, no standardization, error-prone
```

**Desired behavior**:
```bash
# Week 9: Automated package creation
$ fpdev package create mylib
Creating package 'mylib'...
  ✓ Generated package.json
  ✓ Detected source files (src/*.pas)
  ✓ Validated package structure
  ✓ Created mylib-1.0.0.tar.gz

Package created successfully!
Next steps:
  - Test: fpdev package test mylib-1.0.0.tar.gz
  - Publish: fpdev package publish mylib-1.0.0.tar.gz
```

## Week 9 Objectives

### Primary Goals

1. **Package Creation Command** (Day 1-2)
   - Implement `fpdev package create` command
   - Interactive package metadata generation
   - Automatic source file detection
   - Package structure validation

2. **Package Archiving** (Day 3-4)
   - Create tar.gz archives with proper structure
   - Include source files, metadata, and dependencies
   - Generate checksums (SHA256)
   - Validate archive integrity

3. **Package Testing** (Day 5-6)
   - Implement `fpdev package test` command
   - Install package in isolated environment
   - Run package tests
   - Validate dependencies

4. **Documentation and Polish** (Day 7)
   - Write comprehensive test suite
   - Update user documentation
   - Create package authoring guide
   - Week 9 summary

### Secondary Goals (If Time Permits)

- Add `fpdev package init` for interactive package creation
- Implement `fpdev package validate` for pre-publish checks
- Add `fpdev package publish` stub (local registry)
- Package templates for common use cases

## Technical Design

### 1. Package Structure

**Standard Package Layout**:
```
mylib/
├── package.json          # Package metadata (Week 8 format)
├── src/                  # Source files
│   ├── mylib.pas
│   └── mylib.utils.pas
├── tests/                # Test files (optional)
│   └── test_mylib.lpr
├── README.md             # Package documentation
├── LICENSE               # License file
└── .fpdevignore          # Files to exclude from package
```

**Package Archive Structure** (mylib-1.0.0.tar.gz):
```
mylib-1.0.0/
├── package.json
├── src/
│   ├── mylib.pas
│   └── mylib.utils.pas
├── tests/
│   └── test_mylib.lpr
├── README.md
└── LICENSE
```

### 2. Package Metadata (package.json)

**Format** (extends Week 8 format):
```json
{
  "name": "mylib",
  "version": "1.0.0",
  "description": "My awesome library",
  "author": "John Doe <john@example.com>",
  "license": "MIT",
  "homepage": "https://github.com/user/mylib",
  "repository": {
    "type": "git",
    "url": "https://github.com/user/mylib.git"
  },
  "keywords": ["library", "utility", "fpc"],
  "dependencies": {
    "libfoo": ">=1.2.0",
    "libbar": "^2.0.0"
  },
  "optionalDependencies": {
    "liboptional": "~1.0.0"
  },
  "fpc": {
    "minVersion": "3.2.0",
    "maxVersion": "3.2.2"
  },
  "files": [
    "src/**/*.pas",
    "src/**/*.inc",
    "README.md",
    "LICENSE"
  ],
  "scripts": {
    "test": "lazbuild -B tests/test_mylib.lpi && ./bin/test_mylib",
    "build": "fpc -Fusrc -FEbin src/mylib.pas"
  }
}
```

### 3. Core Commands

#### 3.1 fpdev package create

**Usage**:
```bash
# Interactive mode
fpdev package create

# Non-interactive mode
fpdev package create mylib --version 1.0.0 --author "John Doe"

# From existing directory
fpdev package create --from-dir ./mylib
```

**Implementation**:
```pascal
type
  TPackageCreateCommand = class(TInterfacedObject, ICommand)
  private
    function DetectSourceFiles(const ADir: string): TStringList;
    function GenerateMetadata(const AName, AVersion: string): TPackageMetadata;
    function ValidatePackageStructure(const ADir: string): Boolean;
    function CreateArchive(const ADir, AOutputFile: string): Boolean;
  public
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;
```

**Workflow**:
1. Prompt for package name, version, description, author
2. Detect source files in current directory
3. Generate package.json with detected files
4. Validate package structure
5. Create tar.gz archive
6. Generate SHA256 checksum

#### 3.2 fpdev package test

**Usage**:
```bash
# Test package archive
fpdev package test mylib-1.0.0.tar.gz

# Test package in directory
fpdev package test ./mylib

# Run specific test script
fpdev package test mylib-1.0.0.tar.gz --script test
```

**Implementation**:
```pascal
type
  TPackageTestCommand = class(TInterfacedObject, ICommand)
  private
    function ExtractToTempDir(const AArchive: string): string;
    function InstallDependencies(const APackageDir: string): Boolean;
    function RunTests(const APackageDir: string): Boolean;
    function CleanupTempDir(const ATempDir: string): Boolean;
  public
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;
```

**Workflow**:
1. Extract package to temporary directory
2. Load package.json
3. Install dependencies (using Week 8 resolver)
4. Run test script from package.json
5. Report test results
6. Cleanup temporary directory

#### 3.3 fpdev package validate

**Usage**:
```bash
# Validate package directory
fpdev package validate ./mylib

# Validate package archive
fpdev package validate mylib-1.0.0.tar.gz

# Strict validation (all checks)
fpdev package validate ./mylib --strict
```

**Implementation**:
```pascal
type
  TPackageValidateCommand = class(TInterfacedObject, ICommand)
  private
    function ValidateMetadata(const AMeta: TPackageMetadata): TValidationResult;
    function ValidateFiles(const ADir: string; const AMeta: TPackageMetadata): TValidationResult;
    function ValidateDependencies(const AMeta: TPackageMetadata): TValidationResult;
    function ValidateLicense(const ADir: string): TValidationResult;
  public
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;
```

**Validation Checks**:
- ✅ package.json exists and is valid JSON
- ✅ Required fields present (name, version, description, author, license)
- ✅ Version follows semantic versioning
- ✅ All files in "files" array exist
- ✅ Dependencies are valid (format and availability)
- ✅ LICENSE file exists
- ✅ README.md exists
- ✅ No sensitive files included (.git, .env, etc.)

### 4. Package Archiving

**Archive Format**: tar.gz (gzip-compressed tar)

**Implementation**:
```pascal
type
  TPackageArchiver = class
  private
    FSourceDir: string;
    FOutputFile: string;
    FMetadata: TPackageMetadata;

    function CollectFiles: TStringList;
    function CreateTarArchive(const AFiles: TStringList): Boolean;
    function CompressArchive(const ATarFile: string): Boolean;
    function GenerateChecksum(const AArchive: string): string;
  public
    constructor Create(const ASourceDir, AOutputFile: string);
    function CreateArchive: Boolean;
    function GetChecksum: string;
  end;
```

**Archive Process**:
1. Read package.json
2. Collect files based on "files" patterns
3. Exclude files in .fpdevignore
4. Create tar archive with package-version/ prefix
5. Compress with gzip
6. Generate SHA256 checksum
7. Save checksum to .sha256 file

### 5. .fpdevignore Format

**Similar to .gitignore**:
```
# Build artifacts
bin/
lib/
*.o
*.ppu

# IDE files
*.lps
*.compiled

# Test data
test_data/
*.tmp

# Sensitive files
.env
*.key
*.pem
```

## Implementation Plan (TDD Approach)

### Day 1-2: Package Creation Command

**🔴 Red Phase**:
```bash
# Create test file
tests/test_package_create.lpr

# Test cases:
- TestCreatePackageInteractive
- TestCreatePackageNonInteractive
- TestDetectSourceFiles
- TestGenerateMetadata
- TestValidatePackageStructure
- TestCreateArchive
```

**🟢 Green Phase**:
```bash
# Implement
src/fpdev.cmd.package.create.pas
src/fpdev.package.archiver.pas

# Key functions:
- DetectSourceFiles(dir): TStringList
- GenerateMetadata(name, version): TPackageMetadata
- ValidatePackageStructure(dir): Boolean
- CreateArchive(dir, output): Boolean
```

**🔵 Refactor Phase**:
- Extract file detection logic
- Add progress reporting
- Improve error messages

### Day 3-4: Package Testing Command

**🔴 Red Phase**:
```bash
# Create test file
tests/test_package_test.lpr

# Test cases:
- TestExtractPackage
- TestInstallDependencies
- TestRunTests
- TestCleanupTempDir
- TestTestFailureHandling
```

**🟢 Green Phase**:
```bash
# Implement
src/fpdev.cmd.package.test.pas

# Key functions:
- ExtractToTempDir(archive): string
- InstallDependencies(packageDir): Boolean
- RunTests(packageDir): Boolean
- CleanupTempDir(tempDir): Boolean
```

**🔵 Refactor Phase**:
- Improve temp directory management
- Add test output formatting
- Handle test failures gracefully

### Day 5-6: Package Validation Command

**🔴 Red Phase**:
```bash
# Create test file
tests/test_package_validate.lpr

# Test cases:
- TestValidateMetadata
- TestValidateFiles
- TestValidateDependencies
- TestValidateLicense
- TestValidateSensitiveFiles
```

**🟢 Green Phase**:
```bash
# Implement
src/fpdev.cmd.package.validate.pas
src/fpdev.package.validator.pas

# Key functions:
- ValidateMetadata(meta): TValidationResult
- ValidateFiles(dir, meta): TValidationResult
- ValidateDependencies(meta): TValidationResult
- ValidateLicense(dir): TValidationResult
```

**🔵 Refactor Phase**:
- Extract validation rules
- Add detailed error messages
- Improve validation reporting

### Day 7: Testing & Documentation

**Testing**:
```bash
# Run all tests
lazbuild -B tests/test_package_create.lpi && ./bin/test_package_create
lazbuild -B tests/test_package_test.lpi && ./bin/test_package_test
lazbuild -B tests/test_package_validate.lpi && ./bin/test_package_validate

# Integration test
./scripts/test_package_authoring.sh
```

**Documentation**:
```bash
# Create/update files
docs/PACKAGE-AUTHORING-GUIDE.md  # New: Package authoring guide
docs/PACKAGE-MANAGEMENT.md        # Update: Add authoring section
README.md                          # Update: Add package create examples
CLAUDE.md                          # Document new modules
docs/WEEK9-SUMMARY.md              # Week 9 summary
```

## Test Scenarios

### Scenario 1: Create Simple Package

```bash
$ cd mylib
$ fpdev package create
Package name: mylib
Version (1.0.0):
Description: My utility library
Author: John Doe <john@example.com>
License (MIT):

Detected source files:
  - src/mylib.pas
  - src/mylib.utils.pas

Create package? (y/n): y

✓ Generated package.json
✓ Created mylib-1.0.0.tar.gz
✓ Generated SHA256 checksum

Package created successfully!
```

### Scenario 2: Test Package

```bash
$ fpdev package test mylib-1.0.0.tar.gz
Testing package mylib-1.0.0...
  ✓ Extracted to /tmp/fpdev-test-12345
  ✓ Loaded package.json
  ✓ Installing dependencies...
    - libfoo 1.2.3
    - libbar 2.1.0
  ✓ Running tests...
    - test_mylib: 10/10 passed

All tests passed!
```

### Scenario 3: Validate Package

```bash
$ fpdev package validate ./mylib
Validating package...
  ✓ package.json exists and is valid
  ✓ Required fields present
  ✓ Version follows semver (1.0.0)
  ✓ All files exist
  ✓ Dependencies are valid
  ✓ LICENSE file exists
  ✓ README.md exists
  ⚠ Warning: No test files found

Validation passed with 1 warning.
```

### Scenario 4: Create Package with Dependencies

```bash
$ fpdev package create myapp --from-dir ./myapp
Creating package 'myapp'...
  ✓ Detected source files (5 files)
  ✓ Detected dependencies:
    - libfoo (found in package.json)
    - libbar (found in package.json)
  ✓ Validated package structure
  ✓ Created myapp-1.0.0.tar.gz

Package created successfully!
Size: 45.2 KB
Checksum: d19252e6cfe52f1217f4822a548ee699eaa7e044807aaf8429a0532cb7e4cb3d
```

## Success Criteria

### Functional Requirements
- ✅ Create package from directory
- ✅ Generate package.json interactively
- ✅ Detect source files automatically
- ✅ Create tar.gz archives
- ✅ Generate SHA256 checksums
- ✅ Test packages in isolated environment
- ✅ Validate package structure and metadata
- ✅ Support .fpdevignore for file exclusion

### Non-Functional Requirements
- ✅ All tests passing (>95% coverage)
- ✅ Archive creation <5 seconds for typical packages
- ✅ Validation <1 second for typical packages
- ✅ Clear error messages for all failure cases
- ✅ Documentation is complete and accurate

### Quality Gates
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code review completed
- [ ] Documentation updated
- [ ] No regressions in existing functionality

## Risk Management

### Technical Risks

1. **Archive Format Compatibility**
   - **Risk**: tar.gz format may not work on all platforms
   - **Mitigation**: Use cross-platform tar library (fparchive)
   - **Fallback**: Support zip format as alternative

2. **File Detection Accuracy**
   - **Risk**: May miss or include wrong files
   - **Mitigation**: Use glob patterns, allow manual override
   - **Fallback**: Require explicit file list in package.json

3. **Test Isolation**
   - **Risk**: Package tests may interfere with system
   - **Mitigation**: Use temporary directories, cleanup after tests
   - **Fallback**: Add --no-cleanup flag for debugging

### Process Risks

1. **Scope Creep**
   - **Risk**: Feature may expand beyond Week 9
   - **Mitigation**: Focus on core functionality, defer advanced features
   - **Fallback**: Move package publishing to Week 10

2. **Integration with Week 8**
   - **Risk**: May need changes to Week 8 dependency resolver
   - **Mitigation**: Design for compatibility, add tests
   - **Fallback**: Keep systems loosely coupled

## Timeline (Flexible)

| Day | Focus | Deliverables |
|-----|-------|--------------|
| 1-2 | Package Creation | create command, archiver, tests |
| 3-4 | Package Testing | test command, isolation, tests |
| 5-6 | Package Validation | validate command, rules, tests |
| 7 | Testing & Documentation | All tests passing, docs updated |

**Note**: This is a flexible timeline. Focus on quality over speed.

## Next Steps After Week 9

### Week 10 Options

**Option 1: Package Publishing (Phase 3.3 continuation)**
- Implement package registry (local/remote)
- Add `fpdev package publish` command
- Package search and discovery
- Version management

**Option 2: Cross-Compilation Support (Phase 3.2)**
- Binutils download and management
- Cross-compilation target setup
- Cross-compile test builds
- Platform-specific packaging

**Option 3: Enhanced Package Features**
- Package templates
- Package scaffolding
- Automated testing
- CI/CD integration

## References

### Similar Systems
- **npm**: Node.js package manager (npm pack, npm publish)
- **cargo**: Rust package manager (cargo package, cargo publish)
- **pip**: Python package manager (setup.py, twine)

### File Formats
- **tar.gz**: Standard Unix archive format
- **package.json**: JSON metadata format (Week 8)
- **.fpdevignore**: Gitignore-style exclusion patterns

### Documentation
- [Semantic Versioning](https://semver.org/)
- [tar Format](https://www.gnu.org/software/tar/manual/)
- [Package Management Best Practices](https://packaging.python.org/guides/)

---

**Created**: 2026-01-19
**Author**: Claude Code (Sonnet 4.5)
**Status**: 📋 Planning Phase
**Next Action**: Review plan with user, get approval, start Day 1
