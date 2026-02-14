# Remote Registry HTTP Methods Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make remote registry upload/publish paths use real HTTP POST/PUT/DELETE flows instead of hardcoded "not yet implemented" failures.

**Architecture:** Keep existing `TRemoteRegistryClient` API unchanged and implement request dispatch only inside `ExecuteWithRetry`. Use `TFPHTTPClient.RequestBody` + `HTTPMethod` for non-GET requests, preserving retry/error behavior and status handling.

**Tech Stack:** Object Pascal (FPC), `fphttpclient`, existing custom test harness (`tests/test_*.lpr`).

---

### Task 1: Add Failing Tests For Remote POST Paths

**Files:**
- Create: `tests/test_registry_client_remote.lpr`
- Modify: none
- Test: `tests/test_registry_client_remote.lpr`

**Step 1: Write the failing test**

Add tests that call:
- `TRemoteRegistryClient.PublishMetadata`
- `TRemoteRegistryClient.UploadPackage`

Expected behavior after fix:
- Calls should fail due unreachable test endpoint, but error text must **not** contain `not yet implemented`.

**Step 2: Run test to verify it fails**

Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_registry_client_remote.lpr && ./bin/test_registry_client_remote`
Expected: FAIL with `not yet implemented` still present in error message.

**Step 3: Commit**

```bash
git add tests/test_registry_client_remote.lpr
git commit -m "test(registry): add failing tests for remote post flows"
```

### Task 2: Implement Minimal POST/PUT/DELETE Support

**Files:**
- Modify: `src/fpdev.registry.client.pas`
- Test: `tests/test_registry_client_remote.lpr`

**Step 1: Write minimal implementation**

In `TRemoteRegistryClient.ExecuteWithRetry`:
- Keep GET path as-is.
- Replace POST/PUT stub with real HTTP invocation using:
  - `FHTTPClient.RequestBody := ABody` (when assigned, reset stream position)
  - `FHTTPClient.HTTPMethod(AMethod, AURL, AResponse, [200, 201, 202, 204])`
  - clear `RequestBody` in `finally`.
- Add DELETE support with `HTTPMethod('DELETE', ...)`.
- Keep unsupported-method guard for unknown verbs.

**Step 2: Run test to verify it passes**

Run: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_registry_client_remote.lpr && ./bin/test_registry_client_remote`
Expected: PASS, and no assertion sees `not yet implemented`.

**Step 3: Commit**

```bash
git add src/fpdev.registry.client.pas tests/test_registry_client_remote.lpr
git commit -m "feat(registry): implement non-get remote request flow"
```

### Task 3: Verify No Regression In Package Workflows

**Files:**
- Test: `tests/test_package_registry.lpr`
- Test: `tests/test_package_publish.lpr`

**Step 1: Run targeted regression tests**

Run:
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_registry.lpr && ./bin/test_package_registry`
- `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_publish.lpr && ./bin/test_package_publish`

Expected: PASS for both suites.

**Step 2: Optional full suite check**

Run: `scripts/run_all_tests.sh`
Expected: pass; if environment limitations exist, capture exact failure context.

**Step 3: Commit**

```bash
git add src/fpdev.registry.client.pas tests/test_registry_client_remote.lpr
git commit -m "test(registry): verify remote client change has no local registry regression"
```
