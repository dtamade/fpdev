# Build Cache Binaryartifactflow Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** Extract the binary artifact lifecycle orchestration from `src/fpdev.build.cache.pas` into a helper without reopening the mixed `HasArtifacts(...)` compatibility surface or the existing SHA256 / TTL / index helpers.

**Architecture:** Add `src/fpdev.build.cache.binaryartifactflow.pas` to own binary artifact save/restore/info orchestration. `src/fpdev.build.cache.pas` keeps cache directory ownership, `HasArtifacts(...)`, `CalculateSHA256(...)`, `VerifyArtifact(...)`, `FCacheHits` / `FCacheMisses`, and the higher-level TTL / cleanup / index surface. Reuse existing low-level helpers such as `binarysave`, `binaryrestore`, `binaryinfo`, and `verify` instead of inventing a second binary metadata stack.

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: Confirm the binary-artifact-only seam

**Files:**
- Inspect: `src/fpdev.build.cache.pas`
- Reuse: `src/fpdev.build.cache.binarysave.pas`
- Reuse: `src/fpdev.build.cache.binaryrestore.pas`
- Reuse: `src/fpdev.build.cache.binaryinfo.pas`
- Reuse: `src/fpdev.build.cache.verify.pas`
- Reuse: `tests/test_build_cache_binary.lpr`
- Reuse: `tests/test_cache_verification.lpr`
- Reuse: `tests/test_fpc_binaryflow.lpr`

**Step 1: Lock the helper-owned methods**

- `SaveBinaryArtifact(...)`
- `RestoreBinaryArtifact(...)`
- `GetBinaryArtifactInfo(...)`

**Step 2: Lock what stays in `TBuildCache`**

- `HasArtifacts(...)` mixed source/binary compatibility surface
- `FCacheDir` / `FCacheDirWithDelim`
- `FCacheHits` / `FCacheMisses`
- `FVerifyOnRestore`
- `CalculateSHA256(...)`
- `VerifyArtifact(...)`
- TTL / cleanup / index / stats methods

**Step 3: Record the stop condition**

- If extraction would force changes to `fpdev.fpc.binaryflow` callback contracts, `TArtifactInfo` shape, or binary metadata file format, stop and record a no-go checkpoint instead of widening the wave.

### Task 2: Write RED for boundary and helper behavior

**Files:**
- Create: `tests/test_build_cache_binary_boundary.py`
- Create: `tests/test_build_cache_binaryartifactflow.lpr`
- Create: `tests/test_build_cache_binaryartifactflow.lpi`
- Modify: `tests/test_temp_hygiene.py`

**Step 1: Extend Python boundary RED**

- Require `src/fpdev.build.cache.pas` to import `fpdev.build.cache.binaryartifactflow`.
- Require `SaveBinaryArtifact(...)`, `RestoreBinaryArtifact(...)`, and `GetBinaryArtifactInfo(...)` to delegate to helper calls.
- Require inline binary meta load/save, archive restore, and verification-failure text to leave those class methods.
- Keep `HasArtifacts(...)`, `CalculateSHA256(...)`, and `VerifyArtifact(...)` in the class unit.

**Step 2: Add focused Pascal RED**

- helper save copies the downloaded archive and writes binary metadata.
- helper info rebuilds `TArtifactInfo` from binary metadata and stored file extension.
- helper restore uses verify callback before tar extraction.
- helper restore reports verification failure as a miss-worthy failure without invoking extraction.

**Step 3: Run RED evidence**

Run:
```bash
python3 -m unittest tests.test_build_cache_binary_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_build_cache_binaryartifactflow.lpr
```

Expected: FAIL because the helper unit does not exist yet and binary artifact lifecycle logic is still inline in `TBuildCache`.

### Task 3: Implement the minimal helper

**Files:**
- Create: `src/fpdev.build.cache.binaryartifactflow.pas`
- Modify: `src/fpdev.build.cache.pas`

**Step 1: Move only binary artifact lifecycle orchestration**

- Add helper-owned save/restore/info functions.
- Reuse existing `binarysave` / `binaryrestore` / `binaryinfo` / `verify` building blocks.
- Keep `TBuildCache` as the public entrypoint and state owner.

**Step 2: Preserve behavior**

- Preserve binary metadata format and `-binary` suffix naming.
- Preserve `VerifyArtifact(...)` usage when `FVerifyOnRestore` is enabled.
- Preserve `FCacheHits` / `FCacheMisses` semantics.
- Preserve `fpdev.fpc.binaryflow` callback expectations for cache restore/info/save.

### Task 4: Focused verification

Run:
```bash
python3 -m unittest tests.test_build_cache_binary_boundary tests.test_temp_hygiene -v
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_build_cache_binaryartifactflow.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_build_cache_binary.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_cache_verification.lpr
```

Run:
```bash
bash scripts/run_single_test.sh tests/test_fpc_binaryflow.lpr
```

Expected: all pass, and `src/fpdev.build.cache.pas` remains a thin state owner for the binary cache surface.
