# libgit2 Pascal Integration Documentation

## Overview

This document describes the current libgit2 integration state in FPDev, including native C API bindings, modern interface wrappers, active test paths, and runtime library layout expectations.

The current-worktree system-git facade is out of scope for this document; its default entrypoint is `fpdev.git.operations`, the concrete implementation lives in `src/fpdev.git.operations.impl.pas`, and `src/fpdev.utils.git.pas` has been removed and now appears only as a removed compatibility shim note.

## Architecture Design

### Layered Architecture

```
+-------------------------------------+
|      Application Layer (FPDev)      |
+-------------------------------------+
| Preferred modern interfaces         |
| (git2.api.pas + git2.impl.pas)      |
+-------------------------------------+
| Convenience wrapper (git2.modern)   |
+-------------------------------------+
| Legacy compatibility (fpdev.git2)   |
+-------------------------------------+
|  C API Binding Layer (libgit2.pas)  |
+-------------------------------------+
|  libgit2 Dynamic Library (git2.dll) |
+-------------------------------------+
```

### Core Components

1. **libgit2.pas** - Complete C API bindings
2. **git2.api.pas + git2.impl.pas** - Preferred modern interfaces (`IGitManager` / `IGitRepository` + `NewGitManager()`)
3. **git2.modern.pas** - Convenience wrapper built on the modern interfaces
4. **fpdev.git2.pas** - Legacy compatibility wrapper
5. **Runtime/build layout expectations** - documents where the current worktree expects libgit2 artifacts
6. **Test suite** - functional verification and historical manual samples

## File Structure

```
fpdev/
├── src/
│   ├── libgit2.pas           # C API bindings
│   ├── git2.api.pas          # Preferred modern interface definitions
│   ├── git2.impl.pas         # Preferred modern interface implementation
│   ├── git2.modern.pas       # Convenience wrapper built on the modern interfaces
│   ├── fpdev.git2.pas        # Legacy compatibility wrapper
│   └── fpdev.fpc.source.pas  # FPC source management
├── 3rd/
│   └── libgit2/              # libgit2 source and build
│       ├── build/            # Build directory
│       └── install/          # Installation directory
├── tests/
│   ├── fpdev.libgit2.base/
│   │   └── test_libgit2_complete.lpr   # libgit2 base/complete functionality tests
│   ├── fpdev.git2.adapter/
│   │   └── test_git_real.lpr           # Real Git operation tests
│   └── migrated/root-lpr/
│       └── test_fpc_source.lpr         # FPC source historical manual sample
└── docs/
    └── LIBGIT2_INTEGRATION.md      # This document
```

No dedicated libgit2 helper build scripts are tracked in the current worktree; use standard platform CMake or package-manager flows instead of relying on historical helper script names.

## API Binding Details

### libgit2.pas - C API Bindings

**Feature Coverage**:

- Basic library management (initialization/shutdown)
- Repository operations (open/create/clone)
- Reference management (branches/tags/HEAD)
- Commit operations (view/create/traverse)
- Remote operations (fetch/push/configuration)
- Object management (OID/blob/tree)
- Status queries (working directory/index status)
- Configuration management (global/local configuration)
- Error handling (exceptions/error codes)

**Type Definitions**:

```pascal
// Basic types
git_repository = Pointer;
git_commit = Pointer;
git_reference = Pointer;
git_remote = Pointer;

// OID structure
git_oid = record
  id: array[0..19] of Byte;
end;

// Time structure
git_time = record
  time: git_time_t;
  offset: cint;
  sign: cchar;
end;
```

**Core Functions**:

```pascal
// Library management
function git_libgit2_init: cint;
function git_libgit2_shutdown: cint;

// Repository operations
function git_repository_open(out repo: git_repository; const path: PChar): cint;
function git_clone(out repo: git_repository; const url, path: PChar; opts: Pointer): cint;

// Reference operations
function git_reference_lookup(out ref: git_reference; repo: git_repository; const name: PChar): cint;
function git_repository_head(out ref: git_reference; repo: git_repository): cint;
```

### git2.api.pas + git2.impl.pas - Preferred Modern Interfaces

**Design Principles**:

- Object-oriented design
- Automatic resource management
- Exception safety
- Type safety

**Core Classes**:

#### IGitManager - Git Manager Interface

```pascal
IGitManager = interface
  function Initialize: Boolean;
  function OpenRepository(const APath: string): IGitRepository;
  function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
  function IsRepository(const APath: string): Boolean;
end;
```

#### IGitRepository - Repository Interface

```pascal
IGitRepository = interface
  function CurrentBranch: string;
  function ListBranches: TStringArray;
  function HeadCommit: IGitCommit;
  function Remote(const AName: string = 'origin'): IGitRemote;
  function Fetch: Boolean;
end;
```

#### Convenience and legacy wrappers

```pascal
git2.modern.pas   // TGitManagerWrapper / TGitRepository on top of IGitManager
fpdev.git2.pas    // TGitManager / TGitRepository / TGit2Manager for legacy compatibility
```

## Build and Runtime Layout

If you need to build libgit2 locally, use the standard CMake or package-manager workflow for your platform and place the resulting artifacts into the layout expected by the current worktree. No dedicated libgit2 helper build scripts are tracked in the current worktree.

### Windows Artifact Layout

**Dependencies**:

- CMake 3.16+
- MinGW-w64 GCC
- Git

**Expected Artifacts**:

```bash
3rd\libgit2\install\bin\git2.dll         # Dynamic library (matches src/libgit2.pas on Windows)
3rd\libgit2\install\lib\git2.lib         # Import library
3rd\libgit2\install\include\git2.h       # Header file
```

### Linux Artifact Layout

**Dependencies**:

```bash
# Ubuntu/Debian
sudo apt install cmake build-essential libssl-dev zlib1g-dev

# CentOS/RHEL
sudo yum install cmake gcc gcc-c++ openssl-devel zlib-devel
```

**Expected Artifacts**:

```bash
3rd/libgit2/install/lib/libgit2.so       # Dynamic library
3rd/libgit2/install/lib/libgit2.a        # Static library
3rd/libgit2/install/include/git2.h       # Header file
```

### Runtime Loader Expectations

- Windows: `src/libgit2.pas` expects the runtime library name `git2.dll`
- Linux: `src/libgit2.pas` expects the runtime library name `libgit2.so`
- macOS: `src/libgit2.pas` expects the runtime library name `libgit2.1.dylib`
- If you build libgit2 yourself, place the matching artifact next to the executable or in a loader-visible location for your platform

## Test Suite

### Test Programs

1. **tests/fpdev.libgit2.base/test_libgit2_complete.lpr** - Complete functionality tests
   - libgit2 initialization tests
   - Repository operation tests
   - Commit information tests
   - Remote operation tests
   - OID operation tests
   - Excluded from the default discoverable test inventory; mainly used for manual compatibility checks

2. **tests/fpdev.git2.adapter/test_git_real.lpr** - Real Git operation tests
   - Git environment checks
   - Actual repository cloning
   - Network connectivity tests
   - Excluded from the default discoverable test inventory; mainly used for manual compatibility checks

3. **tests/migrated/root-lpr/test_fpc_source.lpr** - FPC source historical manual sample
   - FPC version management
   - Source path management
   - Branch information display
   - Not part of the current automated regression suite; kept only as a reference sample
   - excluded from the default discoverable test inventory

### Running Tests

```bash
# Manual verification samples (excluded from the default discoverable test inventory)
fpc -Fusrc -Fisrc -FEbin -FUlib tests/fpdev.libgit2.base/test_libgit2_complete.lpr
fpc -Fusrc -Fisrc -FEbin -FUlib tests/fpdev.git2.adapter/test_git_real.lpr
fpc -Fusrc -Fisrc -FEbin -FUlib tests/migrated/root-lpr/test_fpc_source.lpr
```

## Performance Characteristics

### Memory Management

- Automatic resource deallocation
- RAII pattern implementation
- Exception safety guarantees

### Network Optimization

- Shallow clone support (--depth 1)
- Progress callback support
- Interrupt and resume mechanism

### Cross-Platform Support

- Windows (MinGW/MSVC)
- Linux (GCC/Clang)
- macOS (Clang)

## Usage Examples

### Basic Repository Operations

```pascal
var
  Manager: IGitManager;
  Repo: IGitRepository;
  Commit: IGitCommit;
begin
  Manager := NewGitManager();
  if not Manager.Initialize then
    Halt(1);

  // Clone repository
  Repo := Manager.CloneRepository(
    'https://github.com/user/repo.git',
    'local-repo'
  );

  // Get current branch
  WriteLn('Current branch: ', Repo.CurrentBranch);

  // Get latest commit
  Commit := Repo.HeadCommit;
  WriteLn('Last commit: ', Commit.OIDString);
  WriteLn('Message: ', Commit.Message);
  WriteLn('Author: ', Commit.AuthorString);
end;
```

### FPC Source Management

```pascal
var
  FPCManager: TFPCSourceManager;
begin
  FPCManager := TFPCSourceManager.Create;
  try
    // Clone FPC 3.2.2 source code
    if FPCManager.CloneFPCSource('3.2.2') then
    begin
      WriteLn('FPC source cloned to: ', FPCManager.GetFPCSourcePath('3.2.2'));

      // List local versions
      var Versions := FPCManager.ListLocalVersions;
      for var Version in Versions do
        WriteLn('Local version: ', Version);
    end;
  finally
    FPCManager.Free;
  end;
end;
```

## Integration Example

### Modern interface integration sample

```pascal
uses
  git2.api, git2.impl, fpdev.fpc.source;

var
  GitManager: IGitManager;
  FPCManager: TFPCSourceManager;

begin
  GitManager := NewGitManager();
  FPCManager := TFPCSourceManager.Create;
  try
    GitManager.Initialize;

    // Handle command line arguments
    case ParamStr(1) of
      'fpc':
        HandleFPCCommand(FPCManager, ParamStr(2));
      'clone':
        HandleCloneCommand(GitManager, ParamStr(2), ParamStr(3));
    end;

  finally
    FPCManager.Free;
  end;
end;
```

## Future Extensions

### Planned Features

- [ ] Branch management (create/switch/merge)
- [ ] Commit creation and push
- [ ] Conflict resolution
- [ ] Submodule support
- [ ] LFS support
- [ ] SSH key management

### Performance Optimization

- [ ] Multi-threaded downloads
- [ ] Incremental updates
- [ ] Local caching
- [ ] Compressed transfer

## Troubleshooting

### Common Issues

1. **Failed to load the libgit2 shared library**
   - `src/libgit2.pas` expects different runtime library names on each platform:
     - Windows: `git2.dll`
     - Linux: `libgit2.so`
     - macOS: `libgit2.1.dylib`
   - Ensure the matching shared library is next to the executable or otherwise visible to the platform loader
   - Verify architecture match (32-bit/64-bit)

2. **Compilation errors**
   - Check FreePascal version (3.2.0+)
   - Ensure all dependency units are available

3. **Network connectivity issues**
   - Check firewall settings
   - Configure proxy (if needed)
   - Verify SSL certificates

### Debugging Tips

```pascal
// Enable detailed error messages
try
  // Git operations
except
  on E: EGitError do
  begin
    WriteLn('Git Error: ', E.Message);
    WriteLn('Error Code: ', E.ErrorCode);
  end;
end;
```

## License

This integration follows these licenses:

- **FPDev**: MIT License
- **libgit2**: GPL v2 with Linking Exception
- **FreePascal**: Modified LGPL

---

**Document Version**: 1.0.0  
**Last Updated**: 2026-04-06  
**Author**: FPDev Team
