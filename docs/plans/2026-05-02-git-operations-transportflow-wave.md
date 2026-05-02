# Git Operations Transportflow Wave

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan test-first.

**Goal:** Extract the shared libgit2 transport credential payload/callback/options-init wiring from `src/fpdev.git.operations.impl.pas` into an internal helper, without changing push refspec resolution, pull merge behavior, or backend fallback semantics.

**Architecture:** Add `src/fpdev.git.operations.transportflow.pas` to own transport credential payload loading, the libgit2 credential acquire callback, and the clone/fetch/push transport-option initialization helpers. Keep `src/fpdev.git.operations.impl.pas` owning repository open/lookup, branch/refspec resolution, ahead-behind logic, merge execution, and checkout/update behavior. `src/fpdev.git.operations.pas` remains the only public facade and must not expose the helper.

**Tech Stack:** Object Pascal, Python unittest, focused Pascal test runner

---

### Task 1: Lock the seam with RED

**Files:**
- Modify: `tests/test_git_runtime_boundary.py`
- Create: `tests/test_git_operations_transportflow.lpr`
- Create: `tests/test_git_operations_transportflow.lpi`

**Step 1: Boundary RED**

- Require `src/fpdev.git.operations.transportflow.pas` to exist.
- Require `fpdev.git.operations.impl.pas` to import the helper.
- Require clone/fetch/pull/push to delegate transport setup through helper functions.
- Forbid inline `LoadCredentialPayloadFromEnv(...)` and `CredentialAcquireCb(...)` inside `fpdev.git.operations.impl.pas`.
- Require `fpdev.git.operations.pas` to stay free of transportflow imports.

**Step 2: Focused Pascal RED**

- Cover shared env payload loading.
- Cover clone/fetch/push options wiring to the shared callback and payload.
- Cover passthrough behavior when payload is absent or plaintext password is unavailable.

### Task 2: Implement the helper

**Files:**
- Create: `src/fpdev.git.operations.transportflow.pas`
- Modify: `src/fpdev.git.operations.impl.pas`

**Step 1: Move only the helper-owned transport glue**

- credential payload type
- env-based payload loading
- credential acquire callback
- clone/fetch/push option initialization helpers

**Step 2: Keep core git behavior in the implementation unit**

Do not move:
- push refspec/branch resolution
- fetch/pull remote lookup and repo open
- pull ahead/behind and merge logic
- checkout behavior
- public facade exports

### Task 3: Verify

Run:

```bash
python3 -m unittest tests.test_git_runtime_boundary -v
bash scripts/run_single_test.sh tests/test_git_operations_transportflow.lpr
bash scripts/run_single_test.sh tests/test_git_operations_identityflow.lpr
bash scripts/run_single_test.sh tests/test_git_operations.lpr
lazbuild -B --build-mode=Release fpdev.lpi
```

Expected:
- boundary test passes
- transportflow focused runner passes
- existing identityflow and default git operations runners remain green
- release build succeeds
