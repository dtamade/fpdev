# FPDev MVP Acceptance Criteria

## Definition of MVP

**MVP Goal**: A user can install FPC and compile Pascal programs using fpdev.

**Target User**: Pascal developer who wants to manage FPC versions without manual installation.

---

## Acceptance Criteria Checklist

### AC-1: Binary Installation (MUST HAVE)

| ID | Criterion | Test Command | Expected Result |
|----|-----------|--------------|-----------------|
| AC-1.1 | Install FPC 3.2.2 binary | `fpdev fpc install 3.2.2` | Downloads and extracts FPC binary |
| AC-1.2 | Installation creates correct directory | `ls ~/.fpdev/fpc/3.2.2/bin/` | Contains `fpc`, `ppcx64` (or platform equivalent) |
| AC-1.3 | Installation registers in config | `cat ~/.fpdev/config.json` | Contains toolchain entry for 3.2.2 |
| AC-1.4 | Installed FPC is functional | `~/.fpdev/fpc/3.2.2/bin/fpc -v` | Outputs "Free Pascal Compiler version 3.2.2" |
| AC-1.5 | List shows installed version | `fpdev fpc list` | Shows "3.2.2 [installed]" |

### AC-2: Source Installation (SHOULD HAVE)

| ID | Criterion | Test Command | Expected Result |
|----|-----------|--------------|-----------------|
| AC-2.1 | Source install with flag | `fpdev fpc install 3.2.2 --from-source` | Clones, builds, and installs FPC |
| AC-2.2 | Bootstrap compiler acquired | (internal) | Downloads or uses system FPC |
| AC-2.3 | Git clone succeeds | `ls ~/.fpdev/sources/fpc/fpc-3.2.2/` | Contains `compiler/`, `rtl/`, `Makefile` |
| AC-2.4 | Build produces artifacts | `ls ~/.fpdev/fpc/3.2.2/bin/` | Contains compiled FPC binaries |

### AC-3: Version Management (MUST HAVE)

| ID | Criterion | Test Command | Expected Result |
|----|-----------|--------------|-----------------|
| AC-3.1 | Switch active version | `fpdev fpc use 3.2.2` | Sets 3.2.2 as active |
| AC-3.2 | Show current version | `fpdev fpc current` | Outputs "3.2.2" |
| AC-3.3 | List available versions | `fpdev fpc list --all` | Shows all known FPC versions |
| AC-3.4 | Uninstall version | `fpdev fpc uninstall 3.2.2` | Removes installation directory |

### AC-4: Error Handling (MUST HAVE)

| ID | Criterion | Test Command | Expected Result |
|----|-----------|--------------|-----------------|
| AC-4.1 | Unknown version error | `fpdev fpc install 9.9.9` | Error with suggestion |
| AC-4.2 | Already installed notice | `fpdev fpc install 3.2.2` (twice) | "FPC 3.2.2 is already installed" |
| AC-4.3 | Missing git error | (no git) `fpdev fpc install 3.2.2 --from-source` | Clear error with alternative |
| AC-4.4 | Command suggestion | `fpdev fpc instal` | "Did you mean 'install'?" |

### AC-5: Cross-Platform (SHOULD HAVE)

| ID | Criterion | Platform | Expected Result |
|----|-----------|----------|-----------------|
| AC-5.1 | Linux x86_64 | Linux | All AC-1 tests pass |
| AC-5.2 | Windows x64 | Windows | All AC-1 tests pass |
| AC-5.3 | macOS x64/ARM | macOS | All AC-1 tests pass |

### AC-6: Doctor Command (MUST HAVE)

| ID | Criterion | Test Command | Expected Result |
|----|-----------|--------------|-----------------|
| AC-6.1 | Doctor reports status | `fpdev fpc doctor` | Shows system status |
| AC-6.2 | Doctor detects issues | (misconfigured) `fpdev fpc doctor` | Reports specific problems |
| AC-6.3 | Doctor suggests fixes | (misconfigured) `fpdev fpc doctor` | Provides actionable suggestions |

---

## Test Scenarios

### Scenario 1: Fresh Install (Happy Path)

```bash
# Prerequisites: fpdev binary available, no prior installation

# Step 1: Install FPC
fpdev fpc install 3.2.2
# Expected: Downloads binary, extracts, configures

# Step 2: Verify installation
fpdev fpc list
# Expected: Shows "3.2.2 [installed]"

# Step 3: Set as active
fpdev fpc use 3.2.2
# Expected: Success message

# Step 4: Compile test program
echo "program test; begin writeln('Hello FPDev'); end." > /tmp/test.pas
~/.fpdev/fpc/3.2.2/bin/fpc /tmp/test.pas -o/tmp/test
/tmp/test
# Expected: Outputs "Hello FPDev"
```

### Scenario 2: Source Build (Advanced Path)

```bash
# Prerequisites: git available, system FPC or bootstrap available

# Step 1: Install from source
fpdev fpc install 3.2.2 --from-source
# Expected: Clones source, builds, installs

# Step 2: Verify build artifacts
ls ~/.fpdev/fpc/3.2.2/lib/fpc/3.2.2/
# Expected: Contains ppcx64 (or platform equivalent)

# Step 3: Test compilation
fpdev fpc doctor
# Expected: All checks pass
```

### Scenario 3: Error Recovery

```bash
# Test 1: Invalid version
fpdev fpc install 99.99.99
# Expected: "Error: Unknown FPC version '99.99.99'"
# Expected: "Available versions: 3.2.2, 3.2.0, 3.0.4, ..."

# Test 2: Typo in command
fpdev fpc instal 3.2.2
# Expected: "Unknown command 'instal'. Did you mean 'install'?"

# Test 3: Network failure (simulated)
# Expected: Clear error message with retry suggestion
```

---

## Quality Gates

### Before MVP Release

- [ ] All AC-1.x tests pass on Linux
- [ ] All AC-3.x tests pass on Linux
- [ ] All AC-4.x tests pass on Linux
- [ ] AC-6.x tests pass on Linux
- [ ] No Chinese characters in terminal output
- [ ] Exit codes are correct (0 for success, non-zero for failure)
- [ ] `fpdev --help` shows all commands
- [ ] `fpdev fpc --help` shows all subcommands

### Stretch Goals (Post-MVP)

- [ ] AC-2.x source installation works
- [ ] AC-5.x cross-platform support
- [ ] Lazarus integration
- [ ] Cross-compilation support

---

## Non-Functional Requirements

### Performance

| Metric | Target |
|--------|--------|
| Binary install time | < 5 minutes |
| Source build time | < 30 minutes |
| Command startup time | < 500ms |
| `fpdev fpc list` response | < 1 second |

### Reliability

| Metric | Target |
|--------|--------|
| Installation success rate | > 95% |
| No data loss on failure | 100% |
| Graceful degradation | Required |

### Usability

| Metric | Target |
|--------|--------|
| Error messages have suggestions | 100% |
| Commands have --help | 100% |
| Progress indication for long ops | Required |

---

## Comparison with rustup

| Feature | rustup | fpdev MVP | fpdev Future |
|---------|--------|-----------|--------------|
| Install toolchain | Yes | Yes | - |
| Switch version | Yes | Yes | - |
| List versions | Yes | Yes | - |
| Update toolchain | Yes | No | Yes |
| Cross-compile | Yes | No | Yes |
| Component management | Yes | No | Maybe |
| Self-update | Yes | No | Maybe |
| Proxy commands | Yes | No | Maybe |

---

## Sign-off Criteria

MVP is considered complete when:

1. **Functional**: All MUST HAVE acceptance criteria pass
2. **Stable**: No crashes during normal operation
3. **Documented**: README covers installation and basic usage
4. **Tested**: Integration test script passes

---

*Document Version: 1.0*
*Created: 2026-01-13*
