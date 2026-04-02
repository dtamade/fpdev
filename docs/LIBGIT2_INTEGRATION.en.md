# libgit2 Pascal Integration Documentation

## Overview

This document describes the complete libgit2 integration solution in the FPDev project, including native C API bindings, modern interface wrappers, the build system, and usage examples.

## Architecture Design

### Layered Architecture

```
+-------------------------------------+
|      Application Layer (FPDev)      |
+-------------------------------------+
|  Modern Interface Layer             |
|  (git2.modern.pas)                  |
+-------------------------------------+
|  C API Binding Layer (libgit2.pas)  |
+-------------------------------------+
|  libgit2 Dynamic Library (git2.dll) |
+-------------------------------------+
```

### Core Components

1. **src/libgit2.pas** - Complete C API bindings
2. **src/git2.modern.pas** - Modern Pascal interface wrappers
3. **3rd/libgit2/** - Upstream source tree used for manual CMake builds
4. **Test suite** - Functional verification and examples

## File Structure

```
fpdev/
├── src/
│   ├── libgit2.pas                    # C API bindings
│   ├── git2.modern.pas                # Modern interface wrappers
│   ├── fpdev.git2.pas                 # OO Git wrapper layer
│   └── fpdev.fpc.source.pas           # FPC source management
├── 3rd/
│   └── libgit2/                       # libgit2 source and manual build tree
│       ├── build/                    # CMake build directory
│       └── install/                  # Installation directory
├── tests/
│   ├── fpdev.libgit2.base/
│   │   └── test_libgit2_complete.lpr # Complete functionality tests
│   ├── fpdev.git2.adapter/
│   │   └── test_git_real.lpr         # Real Git operation tests
│   └── fpdev.core.misc/
│       └── test_dyn_loader.lpr       # Windows DLL discovery smoke test
└── docs/
    └── LIBGIT2_INTEGRATION.md      # This document
```

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

### git2.modern.pas - Modern Interface Wrappers

**Design Principles**:
- Object-oriented design
- Automatic resource management
- Exception safety
- Type safety

**Core Classes**:

#### TGitManager - Git Manager
```pascal
TGitManager = class
  function Initialize: Boolean;
  function OpenRepository(const APath: string): TGitRepository;
  function CloneRepository(const AURL, ALocalPath: string): TGitRepository;
  function IsRepository(const APath: string): Boolean;
end;
```

#### TGitRepository - Repository Wrapper
```pascal
TGitRepository = class
  function GetCurrentBranch: string;
  function ListBranches: TStringArray;
  function GetLastCommit: TGitCommit;
  function GetRemote(const AName: string = 'origin'): TGitRemote;
  function Fetch: Boolean;
end;
```

#### TGitCommit - Commit Wrapper
```pascal
TGitCommit = class
  property OID: TGitOID read FOID;
  property Message: string read GetMessage;
  property Author: TGitSignature read GetAuthor;
  property Time: TDateTime read GetTime;
end;
```

## Build System

### Windows Build (MinGW)

The current repository no longer maintains a dedicated libgit2 helper build script for Windows. If you need to rebuild the bundled copy, run CMake directly inside `3rd/libgit2/`.

**Dependencies**:
- CMake 3.16+
- MinGW-w64 GCC
- Git

**Build Steps**:
```bash
# 1. Clone source code
git clone https://github.com/libgit2/libgit2.git 3rd/libgit2

# 2. Run a manual CMake / MinGW build inside 3rd/libgit2

# 3. Output files
3rd\libgit2\install\bin\libgit2.dll      # Dynamic library
3rd\libgit2\install\lib\libgit2.dll.a    # Import library
3rd\libgit2\install\include\git2.h       # Header file
```

### Linux Build

The current repository no longer maintains a dedicated libgit2 helper build script for Linux. If you need to rebuild the bundled copy, run CMake directly inside `3rd/libgit2/`.

**Dependencies**:
```bash
# Ubuntu/Debian
sudo apt install cmake build-essential libssl-dev zlib1g-dev

# CentOS/RHEL
sudo yum install cmake gcc gcc-c++ openssl-devel zlib-devel
```

**Build Steps**:
```bash
# 1. Run a manual CMake build inside 3rd/libgit2

# 2. Output files
3rd/libgit2/install/lib/libgit2.so       # Dynamic library
3rd/libgit2/install/lib/libgit2.a        # Static library
3rd/libgit2/install/include/git2.h       # Header file
```

## Test Suite

### Test Programs

1. **tests/fpdev.libgit2.base/test_libgit2_complete.lpr** - Complete functionality tests
   - libgit2 initialization tests
   - Repository operation tests
   - Commit information tests
   - Remote operation tests
   - OID operation tests

2. **tests/fpdev.git2.adapter/test_git_real.lpr** - Real Git operation tests
   - Git environment checks
   - Actual repository cloning
   - Network connectivity tests

3. **tests/fpdev.core.misc/test_dyn_loader.lpr** - Dynamic library discovery smoke test
   - `TGitManager.Initialize` path
   - Windows `git2.dll` discovery and failure messaging
   - Minimal exception handling and exit-code behavior

### Running Tests

```bash
# Lazarus/FPC test projects
lazbuild --build-all --no-write-project tests/fpdev.libgit2.base/test_libgit2_complete.lpi
lazbuild --build-all --no-write-project tests/fpdev.git2.adapter/test_git_real.lpi
lazbuild -B tests/fpdev.core.misc/test_dyn_loader.lpi
fpc -Fusrc test_libgit2_complete.lpr
fpc -Fusrc test_git_real.lpr
fpc -Fusrc test_fpc_source.lpr

# Run tests
.\test_libgit2_complete.exe
.\test_git_real.exe
.\test_fpc_source.exe
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
  Manager: TGitManager;
  Repo: TGitRepository;
  Commit: TGitCommit;
begin
  Manager := TGitManager.Create;
  try
    Manager.Initialize;

    // Clone repository
    Repo := Manager.CloneRepository(
      'https://github.com/user/repo.git',
      'local-repo'
    );
    try
      // Get current branch
      WriteLn('Current branch: ', Repo.GetCurrentBranch);

      // Get latest commit
      Commit := Repo.GetLastCommit;
      try
        WriteLn('Last commit: ', GitOIDToString(Commit.OID));
        WriteLn('Message: ', Commit.Message);
        WriteLn('Author: ', Commit.Author.ToString);
      finally
        Commit.Free;
      end;

    finally
      Repo.Free;
    end;
  finally
    Manager.Free;
  end;
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

## Integration into FPDev

### Main Program Integration

```pascal
// fpdev.lpr
uses
  libgit2, git2.modern, fpdev.fpc.source;

var
  GitManager: TGitManager;
  FPCManager: TFPCSourceManager;

begin
  GitManager := TGitManager.Create;
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
    GitManager.Free;
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

1. **libgit2.dll not found**
   - Ensure git2.dll is in the program directory or in PATH
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
**Last Updated**: 2025-01-12
**Author**: FPDev Team
