# FPDev 资源仓库规范 (fpdev-repo)

## 概述

fpdev-repo 是 fpdev 的官方资源仓库，提供 FPC/Lazarus 二进制包、引导编译器、交叉编译工具链等资源的下载。

**设计原则**：
- 只从 fpdev-repo 下载，不回退到 SourceForge 等外部源
- 中国用户默认使用 Gitee 镜像
- 支持用户自建镜像仓库

**存储模式（推荐方案 A：Git 仓库 + 外部存储）**：
- **manifest.json 是必须的**（资源清单/元数据）
- **Git 仓库保持轻量**（只存储 manifest.json 和 README）
- **二进制文件托管在外部**（GitHub Releases、Gitee Releases、CDN、对象存储等）
- **每个文件支持多个镜像 URL**（自动故障转移）

> **为什么推荐方案 A？**
> - GitHub/Gitee 对单文件大小有限制（GitHub 100MB，Gitee 50MB）
> - FPC 二进制包通常 50-100MB，可能超限
> - Git 仓库存储大文件会导致体积膨胀
> - 外部存储更灵活，可以使用 CDN 加速

---

## 官方仓库地址

| 区域 | 平台 | Git 仓库 URL | 二进制存储 |
|------|------|-------------|-----------|
| 国际 | GitHub | `https://github.com/dtamade/fpdev-repo` | GitHub Releases |
| 中国 | Gitee | `https://gitee.com/dtamade/fpdev-repo` | Gitee Releases |

---

## 仓库目录结构

**方案 A（推荐）：轻量 Git 仓库**

```
fpdev-repo/
├── manifest.json                    # 资源清单（必需，包含下载 URL）
└── README.md                        # 仓库说明
```

二进制文件存储在 GitHub/Gitee Releases 或其他外部存储中。

**方案 B（可选）：完整 Git 仓库**

如果文件较小或使用 Git LFS，也可以直接存储在仓库中：

```
fpdev-repo/
├── manifest.json                    # 资源清单（必需）
├── README.md                        # 仓库说明
├── releases/fpc/3.2.2/              # FPC 二进制（可选）
├── bootstrap/3.2.2/                 # 引导编译器（可选）
└── cross/arm-linux/                 # 交叉编译工具链（可选）
```

---

## manifest.json 规范 v2.0

### 完整示例

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

### 字段说明

#### repository 节点
| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| name | string | 是 | 仓库名称 |
| description | string | 否 | 仓库描述 |
| mirrors | array | 是 | Git 仓库镜像列表 |
| mirrors[].name | string | 是 | 镜像名称 |
| mirrors[].url | string | 是 | 镜像 Git URL |
| mirrors[].region | string | 是 | 区域: global, china, europe, us |
| mirrors[].priority | int | 是 | 优先级（越小越优先） |

#### fpc_releases / bootstrap_compilers 节点
| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| [version].release_date | string | 是 | 发布日期 (YYYY-MM-DD) |
| [version].platforms | object | 是 | 平台映射 |
| platforms[].url | string | 是 | **主下载 URL**（完整 HTTP/HTTPS URL） |
| platforms[].mirrors | array | 否 | **备用镜像 URL 列表**（故障转移） |
| platforms[].sha256 | string | 是 | SHA256 校验和 |
| platforms[].size | int | 是 | 文件大小（字节） |
| platforms[].tested | bool | 否 | 是否经过测试 |
| platforms[].executable | string | 否 | 可执行文件相对路径（仅 bootstrap） |

#### 向后兼容：archive 字段
为了向后兼容，仍然支持 `archive` 字段（相对路径）：
```json
{
  "archive": "releases/fpc/3.2.2/fpc-3.2.2-linux-x86_64.tar.gz",
  "sha256": "..."
}
```
当 `url` 字段不存在时，fpdev 会将 `archive` 拼接到仓库根 URL。

#### 平台标识符
| 标识符 | 说明 |
|--------|------|
| linux-x86_64 | Linux 64位 (x86_64) |
| linux-i386 | Linux 32位 (i386) |
| linux-aarch64 | Linux ARM64 |
| windows-x86_64 | Windows 64位 |
| windows-i386 | Windows 32位 |
| darwin-x86_64 | macOS Intel |
| darwin-aarch64 | macOS Apple Silicon |

---

## 下载流程

fpdev 下载二进制文件的流程：

1. **读取 manifest.json** - 从 Git 仓库获取资源清单
2. **查找资源** - 根据版本和平台查找对应条目
3. **尝试主 URL** - 首先尝试 `url` 字段指定的地址
4. **故障转移** - 如果主 URL 失败，依次尝试 `mirrors` 列表中的地址
5. **校验文件** - 下载完成后验证 SHA256 校验和
6. **解压安装** - 校验通过后解压到目标目录

```
┌─────────────────┐
│  manifest.json  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     失败      ┌─────────────────┐
│   尝试主 URL    │ ───────────▶ │  尝试 mirror[0] │
└────────┬────────┘              └────────┬────────┘
         │ 成功                           │ 失败
         ▼                               ▼
┌─────────────────┐              ┌─────────────────┐
│   SHA256 校验   │              │  尝试 mirror[1] │
└────────┬────────┘              └────────┬────────┘
         │                                │
         ▼                               ...
┌─────────────────┐
│   解压安装      │
└─────────────────┘
```

---

## 镜像源选择机制

### 自动选择算法

1. **区域检测**
   - 检查 `TZ` 环境变量
   - 检查 `LANG` 环境变量
   - 读取 `/etc/timezone` (Linux)
   - 识别区域: china, europe, us, global

2. **镜像筛选**
   - 优先选择同区域镜像
   - 如果没有同区域镜像，使用 global 镜像

3. **延迟测试**
   - 对候选镜像进行延迟测试
   - 选择延迟最低的镜像
   - 缓存结果 1 小时

### 用户配置

用户可以在当前活动数据根中的 `config.json` 里配置镜像源：

- portable release 默认位置：`<install-dir>/data/config.json`
- 如果显式设置了 `FPDEV_DATA_ROOT`：`$FPDEV_DATA_ROOT/config.json`
- Linux/macOS 非 portable 模式：`$XDG_DATA_HOME/fpdev/config.json`；若未设置 `XDG_DATA_HOME`，则回退到 `~/.fpdev/config.json`
- Windows 非 portable 模式：`%APPDATA%\fpdev\config.json`

```json
{
  "settings": {
    "mirror": "gitee",
    "custom_repo_url": "https://my-company.com/fpdev-repo"
  }
}
```

配置选项：
- `mirror`: 预设镜像 (`github`, `gitee`, `auto`)
- `custom_repo_url`: 自定义仓库 URL（优先级最高）

命令行配置：
```bash
# 中国用户
fpdev system config set mirror gitee

# 国际用户
fpdev system config set mirror github

# 自定义仓库
fpdev system config set custom_repo_url https://my-company.com/fpdev-repo
```

---

## 自建镜像仓库

### 步骤

1. 创建 Git 仓库（GitHub/Gitee/GitLab/自建）
2. 创建 `manifest.json`，填写你的下载 URL
3. 上传二进制文件到你的存储（Releases、CDN、对象存储等）
4. 配置 fpdev 使用自定义仓库

### 最小化仓库示例

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

## 二进制包格式要求

### FPC 二进制包

解压后的目录结构必须符合：

```
fpc-3.2.2/
├── bin/
│   ├── fpc                    # 或 fpc.exe (Windows)
│   ├── ppcx64                 # 或 ppcx64.exe
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

### 引导编译器

最小化包，只需要编译器可执行文件：

```
bootstrap-3.2.2/
└── bin/
    └── ppcx64                 # 或 ppcx64.exe
```

---

## 版本号

- manifest.json 版本: 语义化版本
  - `1.x.x`: 使用 `archive` 字段（相对路径）
  - `2.x.x`: 使用 `url` + `mirrors` 字段（完整 URL）
- 当添加新资源时，更新 `updated_at` 字段
- 当修改 manifest 结构时，增加主版本号

---

## 更新流程

1. 准备新版本的二进制包
2. 计算 SHA256 校验和
3. 上传到存储（GitHub Releases、CDN 等）
4. 更新 manifest.json（添加 URL 和校验和）
5. 提交并推送 Git 仓库
6. 同步到所有 Git 镜像

---

*文档版本: 2.0*
*创建日期: 2026-01-13*
