# FPDev 资源仓库架构设计 v2.0

## 概述

fpdev 采用 **主索引 + 子仓库** 的分布式架构，实现资源的模块化管理和按需下载。

## 架构图

```
                    ┌─────────────────────────────────────┐
                    │           fpdev-index               │
                    │  (主索引仓库 - 用户配置的唯一入口)    │
                    │                                     │
                    │  index.json                         │
                    │  ├── repositories (子仓库注册)       │
                    │  ├── channels (stable/edge)         │
                    │  └── mirrors (GitHub/Gitee)         │
                    └──────────────┬──────────────────────┘
                                   │
           ┌───────────────────────┼───────────────────────┐
           │                       │                       │
           ▼                       ▼                       ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  fpdev-bootstrap │    │    fpdev-fpc     │    │  fpdev-lazarus   │
│                  │    │                  │    │                  │
│  manifest.json   │    │  manifest.json   │    │  manifest.json   │
│  └── 3.3.1       │    │  └── 3.2.2       │    │  └── 3.6         │
│  └── 3.2.2       │    │  └── 3.2.0       │    │  └── 3.4         │
│  └── 3.2.0       │    │  └── 3.0.4       │    │                  │
└────────┬─────────┘    └────────┬─────────┘    └────────┬─────────┘
         │                       │                       │
         ▼                       ▼                       ▼
   GitHub Releases         GitHub Releases         GitHub Releases
   (二进制文件)             (二进制文件)             (二进制文件)
```

## 仓库清单

| 仓库名 | 用途 | 内容 |
|--------|------|------|
| `fpdev-index` | 主索引 | index.json + README |
| `fpdev-bootstrap` | 引导编译器 | manifest.json + README |
| `fpdev-fpc` | FPC 完整包 | manifest.json + README |
| `fpdev-lazarus` | Lazarus IDE | manifest.json + README |
| `fpdev-cross` | 交叉编译工具链 | manifest.json + README |

## 文件格式规范

### 1. index.json (主索引)

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

### 2. manifest.json (子仓库 - 通用结构)

所有子仓库的 manifest.json 使用统一结构：

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

### 3. 平台标识符

| 标识符 | 说明 |
|--------|------|
| `linux-x86_64` | Linux 64-bit (x86_64) |
| `linux-i386` | Linux 32-bit (i386) |
| `linux-aarch64` | Linux ARM64 |
| `windows-x86_64` | Windows 64-bit |
| `windows-i386` | Windows 32-bit |
| `darwin-x86_64` | macOS Intel |
| `darwin-aarch64` | macOS Apple Silicon |

### 4. 打包格式

| 平台 | 格式 | 原因 |
|------|------|------|
| Linux/macOS | `.tar.gz` | 原生支持，保留权限 |
| Windows | `.zip` | 原生支持，无需额外工具 |

### 5. 解压后目录结构

**Bootstrap (最小编译器)**:
```
bootstrap-3.3.1-linux-x86_64/
└── bin/
    ├── fpc          # 可选
    └── ppcx64       # 必需
```

**FPC Release (完整包)**:
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

## fpdev 下载流程

```
1. 读取 index.json (从 fpdev-index)
   ↓
2. 根据用户请求确定子仓库
   ↓
3. 读取子仓库的 manifest.json
   ↓
4. 查找版本和平台
   ↓
5. 下载二进制包 (url → mirrors 故障转移)
   ↓
6. 校验 SHA256
   ↓
7. 解压到目标目录
```

## 镜像策略

1. **Git 仓库镜像**: GitHub ↔ Gitee 双向同步
2. **二进制文件镜像**:
   - 主: GitHub Releases
   - 备: Gitee Releases
   - 可选: ghproxy.com 加速
3. **自动选择**:
   - 中国用户 → Gitee 优先
   - 国际用户 → GitHub 优先

## 版本管理

- `schema_version`: manifest 结构版本
- `updated_at`: 最后更新时间
- Git tags: 用于 channels 引用 (如 `v3.2.2`)
- `ref`: 可以是 tag、branch 或 commit hash

## 扩展性

添加新工具只需：
1. 创建新的子仓库 (如 `fpdev-newtools`)
2. 在 `fpdev-index/index.json` 注册
3. fpdev 代码无需修改

## 安全性

- 所有下载必须校验 SHA256
- 建议对 index.json 和 manifest.json 进行签名 (未来)
- 镜像 URL 必须在 manifest 中声明，不接受动态 URL

---

*文档版本: 2.0*
*创建日期: 2026-01-14*
*基于 Codex 架构分析*
