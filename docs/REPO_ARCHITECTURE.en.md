# FPDev Resource Repository Architecture Design v2.0

## Overview

fpdev uses a **main index + sub-repository** distributed architecture to achieve modular resource management and on-demand downloads.

## Architecture Diagram

```
                    +-------------------------------------+
                    |           fpdev-index               |
                    |  (Main index repo - single entry    |
                    |   point for user configuration)     |
                    |                                     |
                    |  index.json                         |
                    |  +-- repositories (sub-repo registry)|
                    |  +-- channels (stable/edge)         |
                    |  +-- mirrors (GitHub/Gitee)         |
                    +----------------+--------------------+
                                     |
           +-------------------------+-------------------------+
           |                         |                         |
           v                         v                         v
+------------------+      +------------------+      +------------------+
|  fpdev-bootstrap |      |    fpdev-fpc     |      |  fpdev-lazarus   |
|                  |      |                  |      |                  |
|  manifest.json   |      |  manifest.json   |      |  manifest.json   |
|  +-- 3.3.1       |      |  +-- 3.2.2       |      |  +-- 3.6         |
|  +-- 3.2.2       |      |  +-- 3.2.0       |      |  +-- 3.4         |
|  +-- 3.2.0       |      |  +-- 3.0.4       |      |                  |
+--------+---------+      +--------+---------+      +--------+---------+
         |                         |                         |
         v                         v                         v
   GitHub Releases           GitHub Releases           GitHub Releases
   (binary files)            (binary files)            (binary files)
```

## Repository List

| Repository | Purpose | Contents |
|-----------|---------|----------|
| `fpdev-index` | Main index | index.json + README |
| `fpdev-bootstrap` | Bootstrap compiler | manifest.json + README |
| `fpdev-fpc` | FPC complete packages | manifest.json + README |
| `fpdev-lazarus` | Lazarus IDE | manifest.json + README |
| `fpdev-cross` | Cross-compilation toolchains | manifest.json + README |

## File Format Specifications

### 1. index.json (Main Index)

```json
{
  "schema_version": "1.0.0",
  "updated_at": "2026-01-14T00:00:00Z",

  "mirrors": {
    "github": "https://github.com/dtamade",
    "gitee": "https://gitee.com/dtamade"
  },

  "repositories": {
    "bootstrap": {
      "name": "fpdev-bootstrap",
      "description": "FPC bootstrap compilers for building from source",
      "github": "https://github.com/dtamade/fpdev-bootstrap",
      "gitee": "https://gitee.com/dtamade/fpdev-bootstrap"
    },
    "fpc": {
      "name": "fpdev-fpc",
      "description": "Pre-built FPC binary releases",
      "github": "https://github.com/dtamade/fpdev-fpc",
      "gitee": "https://gitee.com/dtamade/fpdev-fpc"
    },
    "lazarus": {
      "name": "fpdev-lazarus",
      "description": "Pre-built Lazarus IDE releases",
      "github": "https://github.com/dtamade/fpdev-lazarus",
      "gitee": "https://gitee.com/dtamade/fpdev-lazarus"
    },
    "cross": {
      "name": "fpdev-cross",
      "description": "Cross-compilation toolchains",
      "github": "https://github.com/dtamade/fpdev-cross",
      "gitee": "https://gitee.com/dtamade/fpdev-cross"
    }
  },

  "channels": {
    "stable": {
      "description": "Tested and verified combinations",
      "bootstrap": { "ref": "v1.0.0" },
      "fpc": { "ref": "v3.2.2" },
      "lazarus": { "ref": "v3.6" }
    },
    "edge": {
      "description": "Latest versions, may have issues",
      "bootstrap": { "ref": "main" },
      "fpc": { "ref": "main" },
      "lazarus": { "ref": "main" }
    }
  },

  "compatibility_matrix": {
    "fpc-3.2.2": {
      "bootstrap_required": "3.2.0",
      "lazarus_compatible": ["3.6", "3.4", "3.2"]
    },
    "fpc-3.2.0": {
      "bootstrap_required": "3.0.4",
      "lazarus_compatible": ["3.4", "3.2", "3.0"]
    }
  }
}
```

### 2. manifest.json (Sub-repository - Common Structure)

All sub-repositories use a unified manifest.json structure:

```json
{
  "schema_version": "1.0.0",
  "updated_at": "2026-01-14T00:00:00Z",
  "repository": {
    "name": "fpdev-bootstrap",
    "type": "bootstrap"
  },

  "releases": {
    "3.3.1": {
      "release_date": "2024-01-01",
      "platforms": {
        "linux-x86_64": {
          "url": "https://github.com/dtamade/fpdev-bootstrap/releases/download/v3.3.1/bootstrap-3.3.1-linux-x86_64.tar.gz",
          "mirrors": [
            "https://gitee.com/dtamade/fpdev-bootstrap/releases/download/v3.3.1/bootstrap-3.3.1-linux-x86_64.tar.gz"
          ],
          "format": "tar.gz",
          "sha256": "6927063b86a5cc0806ea17c9b749795c8e95c318e15edb87b46135bf510260eb",
          "size": 5981408,
          "components": ["compiler"],
          "layout": {
            "executable": "bin/ppcx64"
          }
        },
        "windows-x86_64": {
          "url": "https://github.com/dtamade/fpdev-bootstrap/releases/download/v3.3.1/bootstrap-3.3.1-windows-x86_64.zip",
          "mirrors": [],
          "format": "zip",
          "sha256": "...",
          "size": 6500000,
          "components": ["compiler"],
          "layout": {
            "executable": "bin/ppcx64.exe"
          }
        }
      }
    }
  }
}
```

### 3. Platform Identifiers

| Identifier | Description |
|-----------|-------------|
| `linux-x86_64` | Linux 64-bit (x86_64) |
| `linux-i386` | Linux 32-bit (i386) |
| `linux-aarch64` | Linux ARM64 |
| `windows-x86_64` | Windows 64-bit |
| `windows-i386` | Windows 32-bit |
| `darwin-x86_64` | macOS Intel |
| `darwin-aarch64` | macOS Apple Silicon |

### 4. Archive Formats

| Platform | Format | Reason |
|----------|--------|--------|
| Linux/macOS | `.tar.gz` | Native support, preserves permissions |
| Windows | `.zip` | Native support, no additional tools needed |

### 5. Extracted Directory Structure

**Bootstrap (Minimal Compiler)**:
```
bootstrap-3.3.1-linux-x86_64/
└── bin/
    ├── fpc          # Optional
    └── ppcx64       # Required
```

**FPC Release (Complete Package)**:
```
fpc-3.2.2-linux-x86_64/
├── bin/
│   ├── fpc
│   ├── ppcx64
│   └── ...
├── lib/
│   └── fpc/
│       └── 3.2.2/
│           ├── units/
│           │   └── x86_64-linux/
│           │       ├── rtl/
│           │       └── ...
│           └── ...
└── share/
    └── ...
```

## fpdev Download Workflow

```
1. Read index.json (from fpdev-index)
   |
2. Determine sub-repository based on user request
   |
3. Read the sub-repository's manifest.json
   |
4. Look up version and platform
   |
5. Download binary package (url -> mirrors failover)
   |
6. Verify SHA256
   |
7. Extract to target directory
```

## Mirror Strategy

1. **Git repository mirroring**: GitHub <-> Gitee bidirectional sync
2. **Binary file mirroring**:
   - Primary: GitHub Releases
   - Backup: Gitee Releases
   - Optional: ghproxy.com acceleration
3. **Automatic selection**:
   - Users in China -> Gitee preferred
   - International users -> GitHub preferred

## Version Management

- `schema_version`: manifest structure version
- `updated_at`: last update time
- Git tags: used for channel references (e.g., `v3.2.2`)
- `ref`: can be a tag, branch, or commit hash

## Extensibility

Adding a new tool only requires:
1. Create a new sub-repository (e.g., `fpdev-newtools`)
2. Register it in `fpdev-index/index.json`
3. No changes needed in fpdev code

## Security

- All downloads must verify SHA256 checksums
- Signing of index.json and manifest.json is recommended (future)
- Mirror URLs must be declared in the manifest; dynamic URLs are not accepted

---

*Document version: 2.0*
*Created: 2026-01-14*
*Based on Codex architecture analysis*
