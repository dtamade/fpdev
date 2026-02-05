# FPDev Testing Guide

FPDev uses **fpcunit** for automated tests. Most tests are standalone Lazarus/FPC programs under `tests/` (commonly `tests/test_*.lpr`).

## Running Tests

### Run one test

If a `.lpi` exists, prefer `lazbuild`:
```bash
lazbuild -B tests/test_config_management.lpi
./bin/test_config_management
```

Fallback (or `.lpi` not present):
```bash
fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_config_management.lpr
./bin/test_config_management
```

### Run all top-level tests

```bash
scripts/run_all_tests.sh
```

Windows:
```bat
scripts\run_all_tests.bat
```

### BuildManager test suite

```bash
cd tests/fpdev.build.manager
./run_tests.sh
```

## Offline By Default

Tests should be deterministic and avoid network dependencies.

- Network-dependent tests are **disabled by default**.
- Enable them explicitly:
  - `FPDEV_RUN_NETWORK_TESTS=1`
- Force-skip (even if enabled):
  - `FPDEV_SKIP_NETWORK_TESTS=1`

## Writing Tests

- Follow TDD (Red → Green → Refactor).
- Prefer local fixtures under `tests/` and temporary directories (via `GetTempDir`) over writing into the repo root.
