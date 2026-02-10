# Toolchain Health Check and Policy (fpdev.toolchain)

This module provides "pure code, zero side-effect" toolchain health checks and FPC version policy validation. It supports external policy JSON overrides and is integrated with BuildManager's strict Preflight mode.

## Quick Start

- Direct health check (JSON):
  - `fpdev --check-toolchain`
- Policy validation (check if FPC version meets source version requirements):
  - `fpdev --check-policy main`
  - `fpdev --check-policy 3.2.2`

- Examples:
  - `examples/fpdev.toolchain/buildOrTest.bat` (Windows)
  - `bash examples/fpdev.toolchain/buildOrTest.sh` (Unix)

## Main API (For Code Usage)

- `function BuildToolchainReportJSON: string;`
  - Builds a HostReady health check report (fpc/make/lazbuild/git/openssl), returns a JSON string; no disk writes, no system modifications

- `function CheckFPCVersionPolicy(const ASourceVersion: string;
  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;`
  - Reads the current FPC version (`fpc -iV`) and checks it against the policy to determine if it meets source version requirements
  - Returns True if >= min (can proceed); AStatus=OK|WARN|FAIL, Reason explains why, and outputs threshold values and current version

- `function LoadPolicyAuto: boolean;`
  - Loads external policy JSON in order (first match wins):
    1) Environment variable `FPDEV_POLICY_FILE`
    2) `src/fpdev.toolchain.policy.json`
    3) `plays/fpdev.toolchain.policy.json`
    4) `./fpdev.toolchain.policy.json`
  - Falls back to built-in conservative policy if none are loaded

## BuildManager Integration (Strict Mode)

- After `TBuildManager.SetToolchainStrict(True)`, Preflight sequence:
  1) Calls `CheckFPCVersionPolicy(AVersion, ...)` (fails immediately if not satisfied)
  2) Health check JSON `BuildToolchainReportJSON` (fails immediately if level=FAIL)
- Relaxed mode: only checks for `make` presence

## Health Check JSON Structure (HostReady)

Example:
```json
{
  "hostOS": "Windows",
  "hostCPU": "x86_64",
  "pathHead": ["C:\\Windows\\system32", "C:\\Windows", "..."],
  "tools": [
    {"name":"fpc","found":true,"version":"3.2.2","path":"C:\\...\\fpc.exe","notes":""},
    {"name":"mingw32-make","found":true,"version":"GNU Make 4.4","path":"C:\\...\\mingw32-make.exe","notes":""},
    {"name":"lazbuild","found":false,"version":"","path":"","notes":"optional"},
    {"name":"git","found":true,"version":"git version 2.x","path":"C:\\...\\git.exe","notes":""},
    {"name":"openssl","found":false,"version":"","path":"","notes":"optional for HTTPS"}
  ],
  "issues": [],
  "level": "OK"
}
```

Field descriptions:
- hostOS/hostCPU: Host system information
- pathHead: First few segments of PATH (for diagnostics)
- tools: Detection results for key tools
- issues: List of missing items (e.g., missing fpc/make)
- level: OK/WARN/FAIL (missing fpc/make -> FAIL; missing optional items -> WARN)

## Policy JSON (External Override)

Minimal format (FPC policy only):
```json
{
  "fpc": {
    "trunk": { "min": "3.2.2", "rec": "3.2.2" },
    "main":  { "min": "3.2.2", "rec": "3.2.2" },
    "3.3.":  { "min": "3.2.2", "rec": "3.2.2" },
    "3.2.2": { "min": "3.0.4", "rec": "3.2.0" },
    "3.2.":  { "min": "3.0.4", "rec": "3.2.2" },
    "3.0.":  { "min": "2.6.4", "rec": "3.0.4" }
  }
}
```
Notes:
- Keys support aliases/prefixes: `trunk`, `main`, `3.3.`, `3.2.2`, `3.2.`, `3.0.`
- Match priority: exact version > prefix > alias; falls back to built-in conservative policy if no match

## Version Comparison Rules

- Only compares digits and dots (ignores trailing tags)
- `CmpVersion(A,B)` returns -1/0/1 (A<B/A=B/A>B)

## Common Issues and Recommendations

- On Windows, prefer `mingw32-make`; on Unix/BSD, prefer `gmake`
- HTTPS downloads should include OpenSSL dynamic libraries; a warning or degraded mode is triggered if missing
- The health check JSON is not written to disk; if persistence is needed, the calling program can write it to a file

## Future Plans

- Expand health check scope: binutils (as/ld/ar/strip/nm/objdump)
- Merge policy results into health check JSON (policy section)
- On-demand fetch framework: manifest/mirror/fetcher design and implementation (GitHub/GitLab/Gitee mirrors)

## Offline Mode and Local Sources (.fpdev Data Root)

- Data root: Defaults to `.fpdev/` under the repository root; can be overridden to any path via the `FPDEV_DATA_ROOT` environment variable.
  - Cache: `.fpdev/cache/`
  - Sandbox: `.fpdev/sandbox/`
  - Logs: `.fpdev/logs/`
  - Lock files: `.fpdev/locks/`

- Local directory as source
  - `fpdev --ensure-source fpc-src 3.2.2 --local D:\\kits\\fpc-3.2.2-src --strict`
  - Behavior: structure validation -> copy to `.fpdev/sandbox/sources/fpc-src/3.2.2/` -> write lock file

- Local zip as source
  - `fpdev --ensure-source lazarus-src 3.4.0 --local D:\\kits\\lazarus-3.4.0.zip --sha256 <64hex> --strict`
  - Behavior: SHA-256 verification -> extract -> strict structure validation -> write lock file

- Import offline bundle directory
  - `fpdev --import-bundle D:\\kits\\fpdev-bundle-2025-08-18\\`
  - Behavior: scans the directory for `*.zip + .sha256`, verifies checksums, then imports to `.fpdev/cache/toolchain/`

Notes:
- In strict mode (`--strict`), directories only undergo structure validation; zip files must provide sha256.
- Recommended to use offline bundles (containing manifest.json and sha256) for team/intranet distribution to ensure reproducibility.
