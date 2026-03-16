# FPC and Lazarus Cross-Platform Build Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the FPC and Lazarus source-build paths choose the correct make-family command and compiler executable path for Windows/Linux/macOS, with focused tests that lock those platform branches.

**Architecture:** Reuse the existing `fpdev.build.toolchain` responsibility for make-family detection instead of letting FPC and Lazarus source builders hardcode `make`. Add a pure Lazarus build-plan helper so Windows and Unix executable/path behavior can be tested on any host without needing real cross-platform runners.

**Tech Stack:** Object Pascal, Free Pascal, Lazarus, existing `fpdev.build.toolchain`, `fpdev.lazarus.commandflow`, focused `test_*.lpr` suites.

---

### Task 1: Lock make-family detection semantics

**Files:**
- Modify: `src/fpdev.build.toolchain.pas`
- Create or modify: `tests/test_build_toolchain_makecmd.lpr` (preferred) or `tests/test_toolchain.lpr`

**Step 1: Write the failing test**

Add focused cases that prove:
- Windows host prefers `mingw32-make`, then `make`, then `gmake`
- Unix/macOS host prefers `gmake`, then `make`
- `IsMakeAvailable` reflects the same make-family resolution logic

**Step 2: Run test to verify it fails**

Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_toolchain_makecmd.lpr`

Expected: FAIL because the pure helper for host-aware make selection does not exist yet.

**Step 3: Write minimal implementation**

- Add a pure helper in `src/fpdev.build.toolchain.pas` that accepts host/platform intent plus a tool-availability callback and returns the selected make command.
- Refactor `ResolveMakeCmd` and `IsMakeAvailable` to delegate to that helper.

**Step 4: Run test to verify it passes**

Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_toolchain_makecmd.lpr && ./bin/test_build_toolchain_makecmd`

Expected: PASS.

### Task 2: Lock Lazarus source-build plan semantics

**Files:**
- Modify: `src/fpdev.lazarus.commandflow.pas`
- Modify: `tests/test_lazarus_flow.lpr`

**Step 1: Write the failing test**

Add focused tests for a new pure Lazarus build-plan helper that prove:
- Windows build plan uses `mingw32-make` when requested and appends `.exe` to the `FPC=` executable path
- Unix/macOS build plan keeps plain `fpc` and preserves the selected `gmake`/`make`
- PATH env prepends the chosen FPC bin directory

**Step 2: Run test to verify it fails**

Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_lazarus_flow.lpr && ./bin/test_lazarus_flow`

Expected: FAIL because the build-plan helper does not exist yet and/or the expected platform-specific fields are wrong.

**Step 3: Write minimal implementation**

- Add a `TLazarusBuildPlan` record and `CreateLazarusBuildPlanCore` in `src/fpdev.lazarus.commandflow.pas`.
- Make `TLazarusManager.BuildFromSource` use that helper instead of hardcoded `make` and `.../bin/fpc`.

**Step 4: Run test to verify it passes**

Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_lazarus_flow.lpr && ./bin/test_lazarus_flow`

Expected: PASS.

### Task 3: Align FPC source builder to shared make detection

**Files:**
- Modify: `src/fpdev.fpc.builder.pas`
- Reuse test coverage from Task 1, plus compile smoke

**Step 1: Add the minimal failing coverage**

Use the Task 1 make-resolution tests as the contract for shared behavior; no separate behavior-specific FPC test is required unless wiring proves risky.

**Step 2: Run the relevant tests before changing code**

Run:
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_toolchain_makecmd.lpr && ./bin/test_build_toolchain_makecmd`

Expected: PASS, establishing the shared helper contract before wiring.

**Step 3: Write minimal implementation**

- Replace the hardcoded `MakeCmd := 'make'` in `src/fpdev.fpc.builder.pas` with the shared toolchain resolution path.
- Keep current bootstrap compiler selection behavior unchanged in this batch.

**Step 4: Run targeted verification**

Run:
- `lazbuild -B fpdev.lpi`
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_fpc_builder.lpr && ./bin/test_fpc_builder`

Expected: PASS.

### Task 4: Regression verification

**Files:**
- Verify only

**Step 1: Focused Lazarus regression**

Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_lazarus_update.lpr && ./bin/test_lazarus_update`

Expected: PASS.

**Step 2: Focused FPC/Lazarus flow regression**

Run:
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_lazarus_flow.lpr && ./bin/test_lazarus_flow`
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_fpc_builder.lpr && ./bin/test_fpc_builder`

Expected: PASS.

**Step 3: Broader regression**

Run: `bash scripts/run_all_tests.sh`

Expected: PASS.

### Task 5: Document residual cross-platform risks

**Files:**
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Record what this batch fixed**

Capture:
- shared make-family resolution now used by FPC/Lazarus source builds
- Windows Lazarus `FPC=` path now uses `.exe`

**Step 2: Record what remains out of scope**

Capture:
- bootstrap compiler binary naming in `src/fpdev.fpc.builder.pas` may still need a dedicated Windows/ARM review
- no real Windows/macOS runtime execution happened in this Linux session; confidence comes from code-path tests and shared helper coverage
