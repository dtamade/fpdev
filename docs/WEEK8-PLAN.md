# Week 8 Plan: Package Dependency Resolution System

**Date**: 2026-01-19
**Status**: 📋 Planning
**Branch**: main → feature/package-dependency-resolution

## Overview

Week 8 focuses on implementing the **Package Dependency Resolution System** (Phase 3.1), a critical feature for FPDev's package management capabilities. This will enable automatic dependency handling, making FPDev more user-friendly and closer to rustup's functionality.

## Context

### Completed Work (Week 1-7)
- ✅ Week 1-2: Core Workflow (project clean/run/test, fpc clean/update)
- ✅ Week 3-4: Manifest System (JSON-based package metadata)
- ✅ Week 5: Bootstrap Compiler Management
- ✅ Week 6: Multi-Mirror Fallback & Offline Mode
- ✅ Week 7: Binary Cache System (91.1% performance improvement)

### Current Project Status
- **Phase 1**: Core Workflow - ✅ 100% Complete
- **Phase 2**: Installation Flexibility - ✅ 100% Complete
- **Phase 3**: Advanced Features - 🔄 In Progress
  - 3.4 Lazarus IDE Integration - ✅ Complete
  - **3.1 Package Dependency Resolution - ⏳ Week 8 Target**
- **Phase 4**: Polish and Optimization - 🔄 In Progress
  - 4.2 Bootstrap Compiler Management - ✅ Complete
  - 4.3 FPC Packages Build - ✅ Complete

### Why Package Dependency Resolution?

**User Pain Point**:
```bash
# Current behavior (manual dependency management)
$ fpdev package install mylib
Error: Missing dependency: libfoo >= 1.2.0

$ fpdev package install libfoo
Error: Missing dependency: libbar >= 2.0.0

$ fpdev package install libbar
$ fpdev package install libfoo
$ fpdev package install mylib
# 😫 Tedious and error-prone!
```

**Desired behavior (automatic dependency resolution)**:
```bash
$ fpdev package install mylib
Resolving dependencies...
  mylib 1.0.0 requires:
    - libfoo >= 1.2.0
    - libbar >= 2.0.0
  libfoo 1.2.3 requires:
    - libbar >= 2.0.0
  libbar 2.1.0 (no dependencies)

Installing 3 packages:
  1. libbar 2.1.0
  2. libfoo 1.2.3
  3. mylib 1.0.0

✓ All packages installed successfully!
# 😊 Just works!
```

## Week 8 Objectives

### Primary Goals

1. **Design Dependency Metadata Format** (Day 1-2)
   - Define package metadata schema with dependencies
   - Support version constraints (>=, <=, ~, ^)
   - Handle optional dependencies
   - Document metadata format

2. **Implement Dependency Graph Algorithm** (Day 3-4)
   - Build dependency graph from package metadata
   - Topological sort for installation order
   - Detect circular dependencies
   - Handle version conflicts

3. **Integrate with Package Manager** (Day 5-6)
   - Update `fpdev package install` to resolve dependencies
   - Add `--no-deps` flag to skip dependency resolution
   - Show dependency tree before installation
   - Implement dry-run mode

4. **Testing and Documentation** (Day 7)
   - Write comprehensive test suite
   - Test circular dependency detection
   - Test version conflict resolution
   - Update user documentation

### Secondary Goals (If Time Permits)

- Add `fpdev package deps <package>` command to show dependencies
- Implement dependency caching for faster resolution
- Add `fpdev package why <package>` to show why a package is installed

## Technical Design

### 1. Package Metadata Format

**File**: `package.json` (in package root)

```json
{
  "name": "mylib",
  "version": "1.0.0",
  "description": "My awesome library",
  "author": "John Doe <john@example.com>",
  "license": "MIT",
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
  }
}
```

**Version Constraint Syntax**:
- `>=1.2.0` - Greater than or equal to 1.2.0
- `<=2.0.0` - Less than or equal to 2.0.0
- `^1.2.0` - Compatible with 1.2.0 (1.2.x, 1.3.x, but not 2.0.0)
- `~1.2.0` - Approximately 1.2.0 (1.2.x only)
- `1.2.0` - Exact version

### 2. Dependency Graph Algorithm

**Algorithm**: Topological Sort with Cycle Detection

```pascal
type
  TPackageNode = record
    Name: string;
    Version: string;
    Dependencies: TStringList;  // List of dependency names
    Visited: Boolean;
    InStack: Boolean;  // For cycle detection
  end;

  TDependencyGraph = class
  private
    FNodes: TFPHashObjectList;  // Name -> TPackageNode
    FInstallOrder: TStringList;  // Topologically sorted list

    function BuildGraph(const ARootPackage: string): Boolean;
    function TopologicalSort: Boolean;
    function DetectCycle(const ANode: TPackageNode): Boolean;
    function ResolveVersion(const APackage, AConstraint: string): string;

  public
    function Resolve(const APackage: string): TStringList;
    function HasCircularDependency: Boolean;
    function GetInstallOrder: TStringList;
  end;
```

**Key Steps**:
1. **Build Graph**: Parse package metadata and build dependency graph
2. **Resolve Versions**: For each dependency, find compatible version
3. **Detect Cycles**: Use DFS with stack to detect circular dependencies
4. **Topological Sort**: Generate installation order (dependencies first)

### 3. Integration Points

**Files to Modify**:
- `src/fpdev.cmd.package.pas` - Add dependency resolution to install command
- `src/fpdev.package.metadata.pas` - NEW: Package metadata parser
- `src/fpdev.package.resolver.pas` - NEW: Dependency resolver
- `src/fpdev.package.version.pas` - NEW: Version constraint parser

**Command Flow**:
```
fpdev package install mylib
  ↓
TPackageInstallCommand.Execute
  ↓
TDependencyResolver.Resolve("mylib")
  ↓
BuildGraph → ResolveVersions → DetectCycles → TopologicalSort
  ↓
[libbar 2.1.0, libfoo 1.2.3, mylib 1.0.0]
  ↓
For each package in order:
  DownloadPackage → ExtractPackage → InstallPackage
  ↓
Success!
```

## Implementation Plan (TDD Approach)

### Day 1-2: Metadata Format & Parser

**🔴 Red Phase**:
```bash
# Create test file
tests/test_package_metadata.lpr

# Test cases:
- TestParseBasicMetadata
- TestParseDependencies
- TestParseVersionConstraints
- TestParseOptionalDependencies
- TestValidateMetadata
```

**🟢 Green Phase**:
```bash
# Implement
src/fpdev.package.metadata.pas

# Key functions:
- LoadMetadata(const APackagePath: string): TPackageMetadata
- ParseDependencies(const AJson: TJSONObject): TDependencyList
- ValidateMetadata(const AMeta: TPackageMetadata): Boolean
```

**🔵 Refactor Phase**:
- Extract common JSON parsing logic
- Add error handling for malformed metadata
- Optimize memory usage

### Day 3-4: Dependency Resolver

**🔴 Red Phase**:
```bash
# Create test file
tests/test_dependency_resolver.lpr

# Test cases:
- TestResolveSimpleDependency
- TestResolveChainedDependencies
- TestDetectCircularDependency
- TestResolveVersionConflict
- TestHandleOptionalDependencies
- TestTopologicalSort
```

**🟢 Green Phase**:
```bash
# Implement
src/fpdev.package.resolver.pas

# Key classes:
- TDependencyGraph
- TDependencyResolver
- TVersionConstraint

# Key algorithms:
- BuildGraph (DFS)
- DetectCycle (DFS with stack)
- TopologicalSort (Kahn's algorithm)
- ResolveVersion (version constraint matching)
```

**🔵 Refactor Phase**:
- Optimize graph traversal
- Add caching for resolved versions
- Improve error messages

### Day 5-6: Integration with Package Manager

**🔴 Red Phase**:
```bash
# Create test file
tests/test_package_install_deps.lpr

# Test cases:
- TestInstallWithDependencies
- TestInstallNoDepsFlag
- TestDryRunMode
- TestShowDependencyTree
- TestHandleInstallationFailure
```

**🟢 Green Phase**:
```bash
# Modify existing files
src/fpdev.cmd.package.pas

# Add to TPackageInstallCommand:
- ResolveDependencies(const APackage: string): TStringList
- ShowDependencyTree(const ADeps: TStringList)
- InstallPackages(const APackages: TStringList): Boolean

# Add command flags:
- --no-deps: Skip dependency resolution
- --dry-run: Show what would be installed
- --show-tree: Show dependency tree
```

**🔵 Refactor Phase**:
- Extract installation logic to separate class
- Add progress reporting
- Improve error recovery

### Day 7: Testing & Documentation

**Testing**:
```bash
# Run all tests
lazbuild -B tests/test_package_metadata.lpi && ./bin/test_package_metadata
lazbuild -B tests/test_dependency_resolver.lpi && ./bin/test_dependency_resolver
lazbuild -B tests/test_package_install_deps.lpi && ./bin/test_package_install_deps

# Integration test
./scripts/test_package_deps.sh
```

**Documentation**:
```bash
# Update files
docs/PACKAGE-MANAGEMENT.md  # Add dependency resolution section
README.md                    # Update package install examples
CLAUDE.md                    # Document new modules
```

## Test Scenarios

### Scenario 1: Simple Dependency Chain

```
mylib 1.0.0
  └── libfoo 1.2.3
        └── libbar 2.1.0
```

**Expected**: Install order: [libbar, libfoo, mylib]

### Scenario 2: Diamond Dependency

```
mylib 1.0.0
  ├── libfoo 1.2.3
  │     └── libcommon 1.0.0
  └── libbar 2.1.0
        └── libcommon 1.0.0
```

**Expected**: Install order: [libcommon, libfoo, libbar, mylib]

### Scenario 3: Circular Dependency

```
mylib 1.0.0
  └── libfoo 1.2.3
        └── libbar 2.1.0
              └── mylib 1.0.0  ← Circular!
```

**Expected**: Error: Circular dependency detected: mylib → libfoo → libbar → mylib

### Scenario 4: Version Conflict

```
mylib 1.0.0
  ├── libfoo 1.2.3 (requires libcommon >=1.0.0)
  └── libbar 2.1.0 (requires libcommon >=2.0.0)
```

**Expected**: Error: Version conflict for libcommon: >=1.0.0 vs >=2.0.0

### Scenario 5: Optional Dependencies

```
mylib 1.0.0
  ├── libfoo 1.2.3 (required)
  └── liboptional 1.0.0 (optional)
```

**Expected**: Install libfoo, skip liboptional if not available

## Success Criteria

### Functional Requirements
- ✅ Parse package metadata with dependencies
- ✅ Resolve dependency graph correctly
- ✅ Detect circular dependencies
- ✅ Handle version conflicts gracefully
- ✅ Generate correct installation order
- ✅ Install packages in dependency order
- ✅ Support `--no-deps` flag
- ✅ Support `--dry-run` mode
- ✅ Show dependency tree before installation

### Non-Functional Requirements
- ✅ All tests passing (>95% coverage)
- ✅ Performance: Resolve <100 packages in <1 second
- ✅ Memory: Handle graphs with >1000 nodes
- ✅ Error messages are clear and actionable
- ✅ Documentation is complete and accurate

### Quality Gates
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code review completed
- [ ] Documentation updated
- [ ] No regressions in existing functionality

## Risk Management

### Technical Risks

1. **Complexity of Version Constraint Matching**
   - **Risk**: Version constraint syntax is complex (^, ~, >=, etc.)
   - **Mitigation**: Start with simple constraints (>=, <=), add complex ones later
   - **Fallback**: Use exact version matching only

2. **Performance with Large Dependency Graphs**
   - **Risk**: Topological sort may be slow for large graphs
   - **Mitigation**: Use efficient algorithms (Kahn's algorithm O(V+E))
   - **Fallback**: Add caching and memoization

3. **Handling Version Conflicts**
   - **Risk**: Multiple packages may require incompatible versions
   - **Mitigation**: Clear error messages with suggestions
   - **Fallback**: Allow user to manually resolve conflicts

### Process Risks

1. **Scope Creep**
   - **Risk**: Feature may expand beyond Week 8
   - **Mitigation**: Stick to core functionality, defer advanced features
   - **Fallback**: Move optional features to Week 9

2. **Integration Issues**
   - **Risk**: May break existing package installation
   - **Mitigation**: Comprehensive testing, feature flag
   - **Fallback**: Make dependency resolution opt-in initially

## Timeline (Flexible)

| Day | Focus | Deliverables |
|-----|-------|--------------|
| 1-2 | Metadata Format & Parser | Package metadata parser, tests |
| 3-4 | Dependency Resolver | Graph algorithm, cycle detection, tests |
| 5-6 | Integration | Updated package install command, tests |
| 7 | Testing & Documentation | All tests passing, docs updated |

**Note**: This is a flexible timeline. Focus on quality over speed.

## Next Steps After Week 8

### Week 9 Options

**Option 1: Package Authoring (Phase 3.3)**
- Implement `fpdev package create`
- Package metadata generation
- Archive creation

**Option 2: Cross-Compilation Support (Phase 3.2)**
- Binutils download
- Libraries download
- Cross-compile test build

**Option 3: Build Cache System (Phase 4.1)**
- Source build caching
- Cache invalidation strategy
- Performance optimization

## References

### Similar Systems
- **npm**: Node.js package manager (semver, dependency resolution)
- **cargo**: Rust package manager (Cargo.toml, dependency graph)
- **pip**: Python package manager (requirements.txt, dependency resolution)

### Algorithms
- **Topological Sort**: Kahn's algorithm, DFS-based
- **Cycle Detection**: DFS with stack
- **Version Matching**: Semantic versioning (semver)

### Documentation
- [Semantic Versioning](https://semver.org/)
- [Topological Sorting](https://en.wikipedia.org/wiki/Topological_sorting)
- [Dependency Resolution](https://research.swtch.com/version-sat)

---

**Created**: 2026-01-19
**Author**: Claude Code (Sonnet 4.5)
**Status**: 📋 Planning Phase
**Next Action**: Review plan with user, get approval, start Day 1
