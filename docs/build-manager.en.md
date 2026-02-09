# BuildManager Design and Usage

## Objectives
- Decouple build/install/configure responsibilities from TFPCSourceManager
- Maintain default safety, offline capability, and rollback support: no writes to system directories, no downloads, no external dependencies
- Provide replaceable implementations (placeholder -> gradual integration with actual make builds)

## Key Points
- Minimal execution: Call make in source directory (if system lacks make, gracefully skip and return True)
- Parallel strategy: -jN (limited to 1..16)
- Check: TestResults only checks if directory exists (placeholder)
- Configure: Currently placeholder, does not write to system fpc.cfg

## Interface
- Unit: src/fpdev.build.manager.pas
- Class: TBuildManager
  - Create(ASourceRoot, AParallelJobs, AVerbose)
  - SetSandboxRoot(Path)
  - SetAllowInstall(Enable)
  - property LogFileName: string (generates independent log per run)
  - BuildCompiler(Version): Boolean
  - BuildRTL(Version): Boolean
  - Install(Version): Boolean
  - Configure(Version): Boolean
  - TestResults(Version): Boolean

## Usage Examples

### In TFPCSourceManager
- BuildFPCCompiler/BuildFPCRTL/InstallFPCBinaries/ConfigureFPCEnvironment/TestBuildResults
- Now delegated to TBuildManager with consistent log output

### Direct Usage (Demo)
- plays/fpdev.build.manager.demo/buildOrTest.bat
- Key code:
  - SetSandboxRoot('sandbox_demo'): Set sandbox output root directory
  - SetAllowInstall(True): Allow installation (disabled by default for safety)
  - SetLogVerbosity(1): Enable verbose logging (records make command lines, etc.)
  - Optional: SetStrictResults(True) to enable strict validation
  - Optional: --no-install (or NO_INSTALL=1 environment variable) to skip installation
  - BuildCompiler/BuildRTL/Install/Configure/TestResults executed in sequence

### Example: Sandbox Installation + Verbose Logging

```pascal
LBM.SetSandboxRoot('sandbox_demo');
LBM.SetAllowInstall(True);
LBM.SetLogVerbosity(1);
if LBM.BuildCompiler(LVer) then WriteLn('BuildCompiler OK');
if LBM.BuildRTL(LVer) then WriteLn('BuildRTL OK');
if LBM.Install(LVer) then WriteLn('Install OK');
if LBM.Configure(LVer) then WriteLn('Configure OK');
WriteLn('Log file: ', LBM.LogFileName);
if LBM.TestResults(LVer) then WriteLn('TestResults OK');
```

### Parameters and Environment Variables (buildOrTest.bat)
- Parameters: strict/-s → equivalent to --strict --verbose; also supports --no-install / --verbose / --preflight / --dry-run
- Environment variables: DEMO_STRICT=1, DEMO_VERBOSE=1, NO_INSTALL=1, PREFLIGHT=1, DRY_RUN=1 (equivalent to corresponding parameters)

## Safe Defaults
- No make available: Print notice and return True (does not block workflow)
- No writes to system directories, no global configuration modifications
- No network downloads triggered

## Log Files and Location
- Independent log generated per run: logs/build_yyyymmdd_hhnnss_zzz.log
- Code and demos will print LogFileName for easy location

## Sandbox Validation
- When SetAllowInstall(True), Install directs installation output to sandbox/fpc-<version>
- TestResults prioritizes sandbox validation when installation is allowed: passes if at least bin/ or lib/ exists
- When installation is not allowed, falls back to checking if compiler/ and rtl/ exist in source directory

### Strict Mode (Optional)
- Enable: SetStrictResults(True)
- Validation rules (FAIL if not met):
  - bin/ or lib/ directory is empty
  - lib/ has no subdirectories (should typically contain fpc/<version>, etc.)
  - bin/ contains no compiler-like executable (prefix fpc/ppc, extension .exe/.sh/none)
- Still only validates within sandbox scope, does not touch system directories

## Cross-Platform Notes (Linux/macOS)
- PATH separator:
  - Windows uses semicolon `;`
  - Linux/macOS uses colon `:`
  - BuildManager parses PATH by platform in verbose log mode and prints only first few items
- make behavior differences:
  - `-jN` parallel parameter works cross-platform, but upstream Makefile support for DESTDIR/PREFIX may vary
  - If installation phase shows prefix not taking effect, check upstream Makefile installation variable naming (INSTALL_*, PREFIX, etc.)
- Recommendations:
  - On non-Windows platforms, use `sh -lc` script environment to run demos, ensuring consistent environment variables and PATH
  - For more detailed platform-specific diagnostics, set log level to 1 and add more environment output

### Linux/macOS FPC Installation Reference
- Official download and instructions: https://www.freepascal.org/download.html
- Common package managers (examples):
  - Debian/Ubuntu: `sudo apt-get update && sudo apt-get install -y fpc`
  - Fedora/RHEL: `sudo dnf install -y fpc`
  - Arch/Manjaro: `sudo pacman -S --noconfirm fpc`
  - openSUSE: `sudo zypper install -y fpc`
  - macOS (Homebrew): `brew install fpc`
- Verify installation:
  - Check version: `fpc -iV`
  - Check path: `which fpc` (Linux/macOS) or `command -v fpc`
- Notes:
  - macOS's `make` is BSD make; if upstream Makefile requires GNU make, install `gmake` and ensure it's available in environment
  - If build/install depends on external tools, pre-install on CI/Runner and add to PATH

## API Reference and Advanced Configuration

### Core Methods

**SetMakeCmd(const ACmd: string)** - Customize make command
- Parameter: `ACmd` - make command name (e.g., `mingw32-make`, `gmake`, `make`)
- Purpose: Override default make command detection
- Example:
  ```pascal
  BM.SetMakeCmd('mingw32-make');  // Windows MinGW
  BM.SetMakeCmd('gmake');         // macOS GNU make
  ```

**SetTarget(const ACPU, AOS: string)** - Set cross-compilation target
- Parameters:
  - `ACPU` - Target CPU architecture (e.g., `x86_64`, `aarch64`, `i386`)
  - `AOS` - Target operating system (e.g., `linux`, `win64`, `darwin`)
- Purpose: Configure cross-compilation target platform
- Example:
  ```pascal
  BM.SetTarget('x86_64', 'linux');   // Linux x86_64
  BM.SetTarget('aarch64', 'linux');  // Linux ARM64
  BM.SetTarget('x86_64', 'win64');   // Windows 64-bit
  ```

**SetPrefix(const APrefix, AInstallPrefix: string)** - Set installation prefix
- Parameters:
  - `APrefix` - Compile-time prefix path
  - `AInstallPrefix` - Install-time prefix path
- Purpose: Control installation directory structure
- Example:
  ```pascal
  BM.SetPrefix('/usr/local', '/usr/local');
  BM.SetPrefix('C:\FPC', 'C:\FPC');
  ```

### Cross-Compilation Examples

#### Example 1: Windows → Linux (x86_64)

```pascal
program CrossCompileWinToLinux;

uses
  fpdev.build.manager;

var
  BM: TBuildManager;
begin
  BM := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
  try
    BM.SetSandboxRoot('sandbox_linux');
    BM.SetAllowInstall(True);
    BM.SetLogVerbosity(1);
    BM.SetMakeCmd('mingw32-make');

    // Set cross-compilation target
    BM.SetTarget('x86_64', 'linux');
    BM.SetPrefix('/usr/local', '/usr/local');

    WriteLn('Building cross-compiler for Linux x86_64...');
    if not BM.Preflight('main') then Exit;
    if not BM.BuildCompiler('main') then Exit;
    if not BM.BuildRTL('main') then Exit;
    if not BM.Install('main') then Exit;

    WriteLn('Cross-compiler built successfully!');
    WriteLn('Log: ', BM.LogFileName);
  finally
    BM.Free;
  end;
end.
```

#### Example 2: Linux → ARM (aarch64)

```pascal
program CrossCompileLinuxToARM;

uses
  fpdev.build.manager;

var
  BM: TBuildManager;
begin
  BM := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
  try
    BM.SetSandboxRoot('sandbox_arm');
    BM.SetAllowInstall(True);
    BM.SetLogVerbosity(1);

    // Set cross-compilation target
    BM.SetTarget('aarch64', 'linux');
    BM.SetPrefix('/opt/fpc-arm', '/opt/fpc-arm');

    WriteLn('Building cross-compiler for ARM aarch64...');
    if not BM.Preflight('main') then Exit;
    if not BM.BuildCompiler('main') then Exit;
    if not BM.BuildRTL('main') then Exit;
    if not BM.Install('main') then Exit;

    WriteLn('Cross-compiler built successfully!');
    WriteLn('Sandbox: sandbox_arm/fpc-main');
  finally
    BM.Free;
  end;
end.
```

### Common Configuration Combinations

| Scenario | SetMakeCmd | SetTarget | SetPrefix | Description |
|----------|-----------|-----------|-----------|-------------|
| Windows local | `mingw32-make` | - | - | MinGW environment |
| Linux local | `make` | - | - | System make |
| macOS local | `gmake` | - | - | GNU make |
| Win→Linux | `mingw32-make` | `x86_64, linux` | `/usr/local` | Cross-compile |
| Linux→ARM | `make` | `aarch64, linux` | `/opt/fpc-arm` | Cross-compile |
| macOS→Win | `gmake` | `x86_64, win64` | `C:\FPC` | Cross-compile |

## Preflight and Dry-run Modes

### Preflight
- Does not execute build, quickly checks if environment and paths are ready
- Checks: make availability, source path existence, sandbox and logs writability, install root writable when installation allowed
- Log: `== Preflight START/END`, outputs `issue: ...` for each failure
- Returns: True if all checks pass, otherwise False

### Dry-run
- Does not execute make, only prints commands that would be executed
- Behavior: `RunMake` only logs `make ...` line and outputs `dry-run: skipped make execution`, returns True
- Use: Review commands and variables (DESTDIR/PREFIX, etc.) in CI or locally before execution to avoid mistakes

## Running Local Tests (Optional)
- Windows: `tests\fpdev.build.manager\run_tests.bat`
- Linux/macOS: `bash tests/fpdev.build.manager/run_tests.sh`

These scripts will:
- Compile and run three minimal tests:
  - `test_build_manager.lpr` (source fallback + sandbox)
  - `test_build_manager_strict_fail.lpr` (strict mode, expects FAIL)
  - `test_build_manager_strict_pass.lpr` (strict mode, expects PASS)
- Print latest log (logs/build_*.log) showing Summary/hints/samples

## Future Roadmap
- Record Start/End markers at Build/Install/Configure key steps for improved readability
- Gradually refine sandbox structure checklist (share/, fpc.cfg, etc.)
- Optional: Introduce configuration to enable real builds (when explicitly allowed by user)

---

**Last Updated**: 2026-02-10
