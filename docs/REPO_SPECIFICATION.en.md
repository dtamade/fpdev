# FPDev Resource Repository Specification (fpdev-repo)

## Overview

fpdev-repo is the official resource repository for fpdev, providing downloads of FPC/Lazarus binary packages, bootstrap compilers, cross-compilation toolchains, and other resources.

**Design Principles**:
- Download only from fpdev-repo; no fallback to external sources such as SourceForge
- Chinese users default to the Gitee mirror
- Support for user-hosted mirror repositories

**Storage Model (Recommended Option A: Git Repository + External Storage)**:
- **manifest.json is required** (resource manifest/metadata)
- **Keep the Git repository lightweight** (only store manifest.json and README)
- **Host binary files externally** (GitHub Releases, Gitee Releases, CDN, object storage, etc.)
- **Each file supports multiple mirror URLs** (automatic failover)

> **Why is Option A recommended?**
> - GitHub/Gitee have single file size limits (GitHub 100MB, Gitee 50MB)
> - FPC binary packages are typically 50-100MB, which may exceed limits
> - Storing large files in a Git repository causes repository bloat
> - External storage is more flexible and can leverage CDN acceleration

---

## Official Repository URLs

| Region | Platform | Git Repository URL | Binary Storage |
|--------|----------|--------------------|----------------|
| International | GitHub | `https://github.com/dtamade/fpdev-repo` | GitHub Releases |
| China | Gitee | `https://gitee.com/dtamade/fpdev-repo` | Gitee Releases |

---

## Repository Directory Structure

**Option A (Recommended): Lightweight Git Repository**

```
fpdev-repo/
├── manifest.json                    # Resource manifest (required, contains download URLs)
└── README.md                        # Repository description
```

Binary files are stored in GitHub/Gitee Releases or other external storage.

**Option B (Optional): Full Git Repository**

If files are small or Git LFS is used, files can also be stored directly in the repository:

```
fpdev-repo/
├── manifest.json                    # Resource manifest (required)
├── README.md                        # Repository description
├── releases/fpc/3.2.2/              # FPC binaries (optional)
├── bootstrap/3.2.2/                 # Bootstrap compilers (optional)
└── cross/arm-linux/                 # Cross-compilation toolchains (optional)
```

---

## manifest.json Specification v2.0

### Complete Example

```json
{
  "version": "2.0.0",
  "updated_at": "2026-01-13T00:00:00Z",

  "repository": {
    "name": "fpdev-repo",
    "description": "Official FPDev resource repository",
    "mirrors": [
      {
        "name": "GitHub",
        "url": "https://github.com/dtamade/fpdev-repo",
        "region": "global",
        "priority": 1
      },
      {
        "name": "Gitee",
        "url": "https://gitee.com/dtamade/fpdev-repo",
        "region": "china",
        "priority": 1
      }
    ]
  },

  "fpc_releases": {
    "3.2.2": {
      "release_date": "2021-05-20",
      "platforms": {
        "linux-x86_64": {
          "url": "https://github.com/dtamade/fpdev-repo/releases/download/fpc-3.2.2/fpc-3.2.2-linux-x86_64.tar.gz",
          "mirrors": [
            "https://gitee.com/dtamade/fpdev-repo/releases/download/fpc-3.2.2/fpc-3.2.2-linux-x86_64.tar.gz",
            "https://mirror.ghproxy.com/https://github.com/dtamade/fpdev-repo/releases/download/fpc-3.2.2/fpc-3.2.2-linux-x86_64.tar.gz"
          ],
          "sha256": "abc123def456...",
          "size": 52428800,
          "tested": true
        },
        "windows-x86_64": {
          "url": "https://github.com/dtamade/fpdev-repo/releases/download/fpc-3.2.2/fpc-3.2.2-windows-x86_64.zip",
          "mirrors": [
            "https://gitee.com/dtamade/fpdev-repo/releases/download/fpc-3.2.2/fpc-3.2.2-windows-x86_64.zip"
          ],
          "sha256": "def456ghi789...",
          "size": 61865984,
          "tested": true
        },
        "darwin-x86_64": {
          "url": "https://github.com/dtamade/fpdev-repo/releases/download/fpc-3.2.2/fpc-3.2.2-darwin-x86_64.tar.gz",
          "mirrors": [],
          "sha256": "ghi789jkl012...",
          "size": 48234496,
          "tested": true
        },
        "darwin-aarch64": {
          "url": "https://github.com/dtamade/fpdev-repo/releases/download/fpc-3.2.2/fpc-3.2.2-darwin-aarch64.tar.gz",
          "mirrors": [],
          "sha256": "jkl012mno345...",
          "size": 47185920,
          "tested": true
        }
      }
    },
    "3.2.0": {
      "release_date": "2020-06-19",
      "platforms": {
        "linux-x86_64": {
          "url": "https://github.com/dtamade/fpdev-repo/releases/download/fpc-3.2.0/fpc-3.2.0-linux-x86_64.tar.gz",
          "mirrors": [],
          "sha256": "...",
          "size": 51380224,
          "tested": true
        }
      }
    }
  },

  "bootstrap_compilers": {
    "3.2.2": {
      "platforms": {
        "linux-x86_64": {
          "url": "https://github.com/dtamade/fpdev-repo/releases/download/bootstrap-3.2.2/bootstrap-3.2.2-linux-x86_64.tar.gz",
          "mirrors": [
            "https://gitee.com/dtamade/fpdev-repo/releases/download/bootstrap-3.2.2/bootstrap-3.2.2-linux-x86_64.tar.gz"
          ],
          "executable": "bin/ppcx64",
          "sha256": "...",
          "size": 15728640,
          "tested": true
        },
        "windows-x86_64": {
          "url": "https://github.com/dtamade/fpdev-repo/releases/download/bootstrap-3.2.2/bootstrap-3.2.2-windows-x86_64.zip",
          "mirrors": [],
          "executable": "bin/ppcx64.exe",
          "sha256": "...",
          "size": 16777216,
          "tested": true
        }
      }
    },
    "3.2.0": {
      "platforms": {}
    },
    "3.0.4": {
      "platforms": {}
    }
  },

  "bootstrap_version_map": {
    "main": "3.2.2",
    "3.3.1": "3.2.2",
    "3.2.4": "3.2.2",
    "3.2.2": "3.2.0",
    "3.2.0": "3.0.4",
    "3.0.4": "3.0.2"
  },

  "cross_toolchains": {
    "arm-linux": {
      "display_name": "ARM Linux (32-bit)",
      "cpu": "arm",
      "os": "linux",
      "binutils_prefix": "arm-linux-gnueabihf-",
      "host_platforms": {
        "linux-x86_64": {
          "binutils_url": "https://github.com/dtamade/fpdev-repo/releases/download/cross-arm-linux/binutils-arm-linux-gnueabihf.tar.gz",
          "binutils_mirrors": [],
          "binutils_sha256": "...",
          "libs_url": "https://github.com/dtamade/fpdev-repo/releases/download/cross-arm-linux/libs-arm-linux.tar.gz",
          "libs_mirrors": [],
          "libs_sha256": "..."
        }
      }
    },
    "aarch64-linux": {
      "display_name": "ARM64 Linux",
      "cpu": "aarch64",
      "os": "linux",
      "binutils_prefix": "aarch64-linux-gnu-",
      "host_platforms": {}
    },
    "win64": {
      "display_name": "Windows 64-bit",
      "cpu": "x86_64",
      "os": "win64",
      "binutils_prefix": "x86_64-w64-mingw32-",
      "host_platforms": {}
    }
  },

  "lazarus_releases": {
    "3.6": {
      "release_date": "2024-09-01",
      "fpc_compatibility": ["3.2.2", "3.2.0"],
      "platforms": {}
    }
  }
}
```

### Field Descriptions

#### repository Node
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | string | Yes | Repository name |
| description | string | No | Repository description |
| mirrors | array | Yes | List of Git repository mirrors |
| mirrors[].name | string | Yes | Mirror name |
| mirrors[].url | string | Yes | Mirror Git URL |
| mirrors[].region | string | Yes | Region: global, china, europe, us |
| mirrors[].priority | int | Yes | Priority (lower value = higher priority) |

#### fpc_releases / bootstrap_compilers Node
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| [version].release_date | string | Yes | Release date (YYYY-MM-DD) |
| [version].platforms | object | Yes | Platform mappings |
| platforms[].url | string | Yes | **Primary download URL** (full HTTP/HTTPS URL) |
| platforms[].mirrors | array | No | **Fallback mirror URL list** (failover) |
| platforms[].sha256 | string | Yes | SHA256 checksum |
| platforms[].size | int | Yes | File size (bytes) |
| platforms[].tested | bool | No | Whether the file has been tested |
| platforms[].executable | string | No | Relative path to executable (bootstrap only) |

#### Backward Compatibility: archive Field
For backward compatibility, the `archive` field (relative path) is still supported:
```json
{
  "archive": "releases/fpc/3.2.2/fpc-3.2.2-linux-x86_64.tar.gz",
  "sha256": "..."
}
```
When the `url` field is not present, fpdev concatenates `archive` with the repository root URL.

#### Platform Identifiers
| Identifier | Description |
|------------|-------------|
| linux-x86_64 | Linux 64-bit (x86_64) |
| linux-i386 | Linux 32-bit (i386) |
| linux-aarch64 | Linux ARM64 |
| windows-x86_64 | Windows 64-bit |
| windows-i386 | Windows 32-bit |
| darwin-x86_64 | macOS Intel |
| darwin-aarch64 | macOS Apple Silicon |

---

## Download Workflow

The workflow fpdev uses to download binary files:

1. **Read manifest.json** - Fetch the resource manifest from the Git repository
2. **Locate resource** - Find the matching entry by version and platform
3. **Try primary URL** - First attempt the address specified in the `url` field
4. **Failover** - If the primary URL fails, try addresses in the `mirrors` list sequentially
5. **Verify file** - After download completes, verify the SHA256 checksum
6. **Extract and install** - Extract to the target directory after verification passes

```
┌─────────────────┐
│  manifest.json  │
└────────┬────────┘
         │
         v
┌─────────────────┐     Failed     ┌─────────────────┐
│  Try primary URL│ ────────────> │  Try mirror[0]  │
└────────┬────────┘               └────────┬────────┘
         │ Success                         │ Failed
         v                                 v
┌─────────────────┐               ┌─────────────────┐
│  SHA256 verify  │               │  Try mirror[1]  │
└────────┬────────┘               └────────┬────────┘
         │                                 │
         v                                ...
┌─────────────────┐
│  Extract/Install│
└─────────────────┘
```

---

## Mirror Selection Mechanism

### Automatic Selection Algorithm

1. **Region Detection**
   - Check the `TZ` environment variable
   - Check the `LANG` environment variable
   - Read `/etc/timezone` (Linux)
   - Identify region: china, europe, us, global

2. **Mirror Filtering**
   - Prefer mirrors in the same region
   - Fall back to global mirrors if no same-region mirror is available

3. **Latency Testing**
   - Perform latency tests on candidate mirrors
   - Select the mirror with the lowest latency
   - Cache results for 1 hour

### User Configuration

Users can configure mirror sources in `~/.fpdev/config.json`:

```json
{
  "settings": {
    "mirror": "gitee",
    "custom_repo_url": "https://my-company.com/fpdev-repo"
  }
}
```

Configuration options:
- `mirror`: Preset mirror (`github`, `gitee`, `auto`)
- `custom_repo_url`: Custom repository URL (highest priority)

Command-line configuration:
```bash
# Chinese users
fpdev config set mirror gitee

# International users
fpdev config set mirror github

# Custom repository
fpdev config set custom_repo_url https://my-company.com/fpdev-repo
```

---

## Self-Hosted Mirror Repository

### Steps

1. Create a Git repository (GitHub/Gitee/GitLab/self-hosted)
2. Create `manifest.json` with your download URLs
3. Upload binary files to your storage (Releases, CDN, object storage, etc.)
4. Configure fpdev to use the custom repository

### Minimal Repository Example

```
my-fpdev-repo/
└── manifest.json
```

manifest.json:
```json
{
  "version": "2.0.0",
  "updated_at": "2026-01-13T00:00:00Z",
  "repository": {
    "name": "my-fpdev-repo",
    "mirrors": []
  },
  "fpc_releases": {
    "3.2.2": {
      "release_date": "2021-05-20",
      "platforms": {
        "linux-x86_64": {
          "url": "https://my-cdn.com/fpc/fpc-3.2.2-linux-x86_64.tar.gz",
          "mirrors": [],
          "sha256": "abc123...",
          "size": 52428800
        }
      }
    }
  }
}
```

---

## Binary Package Format Requirements

### FPC Binary Packages

The extracted directory structure must conform to:

```
fpc-3.2.2/
├── bin/
│   ├── fpc                    # or fpc.exe (Windows)
│   ├── ppcx64                 # or ppcx64.exe
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

### Bootstrap Compilers

Minimal package, only the compiler executable is needed:

```
bootstrap-3.2.2/
└── bin/
    └── ppcx64                 # or ppcx64.exe
```

---

## Versioning

- manifest.json version: Semantic versioning
  - `1.x.x`: Uses the `archive` field (relative path)
  - `2.x.x`: Uses the `url` + `mirrors` fields (full URL)
- Update the `updated_at` field when adding new resources
- Increment the major version number when modifying the manifest structure

---

## Update Workflow

1. Prepare binary packages for the new version
2. Calculate SHA256 checksums
3. Upload to storage (GitHub Releases, CDN, etc.)
4. Update manifest.json (add URLs and checksums)
5. Commit and push the Git repository
6. Sync to all Git mirrors

---

*Document version: 2.0*
*Created: 2026-01-13*
