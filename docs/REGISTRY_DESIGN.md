# FPDev Registry 设计文档

**版本**: 1.2 (Audited)
**日期**: 2026-05-19
**状态**: 已审查定稿 + 严格审计通过

> **实现状态说明**：本文档描述的是最终目标架构。当前实现状态：
> - ✅ 已实现：registry 数据加载、版本元数据、二进制 manifest、包索引、cross targets、bootstrap URL、update-registry 命令、源码单仓库、overrides.json 合并、镜像偏好选择、Build Steps 引擎（post-install 接入）
> - 🔲 待实现：Build Steps 引擎接入源码编译流程、schema 版本验证、镜像延迟自动测试

---

## 1. 概述

### 1.1 目标

将 fpdev 中所有硬编码的元数据（版本列表、镜像 URL、构建步骤、bootstrap 依赖、交叉编译目标、包索引）迁移到一个独立的 git 仓库（`fpdev-registry`），实现数据与代码分离。

### 1.2 核心原则

- **数据告诉 fpdev "做什么"，代码负责"怎么做"**
- 新版本发布、新镜像添加、新交叉目标支持——只需更新 registry，不需要改 fpdev 代码
- 简单优先：一个 git 仓库 + 一个 overrides 文件 + 内嵌 fallback

### 1.3 设计约束

- 单人维护项目，不依赖服务器基础设施
- 支持中国用户（gitee 镜像）
- 支持离线/气隔环境
- FPC/Lazarus 更新频率低（一年 1-2 次）
- fpdev 已内置 libgit2，git 操作成本低

---

## 2. 架构总览

### 2.1 分发模型

```
fpdev-registry (独立 git 仓库)
  ├── 镜像到 github / gitee / gitlab
  └── 用户通过 fpdev update-registry 拉取

fpdev 二进制
  └── 内嵌一份 fallback 元数据（编译时快照）

用户本地
  ~/.fpdev/
  ├── registry/          ← git clone --depth=1 of fpdev-registry
  └── overrides.json     ← 用户自定义覆盖（gitignored）
```

### 2.2 数据加载优先级

```
1. overrides.json（用户自定义，最高优先级）
2. ~/.fpdev/registry/（git 仓库，正常数据源）
3. 内嵌 fallback（编译时快照，兜底）
```

### 2.3 更新策略

- **手动更新**：只在用户执行 `fpdev update-registry` 时拉取
- **不自动更新**：避免离线环境报错、避免用户失去控制感
- **智能提示**：当用户请求安装一个本地 registry 不存在的版本时，提示运行 update-registry

---

## 3. Registry 仓库结构

```
fpdev-registry/
├── index.json                    入口文件，schema 版本声明
│
├── sources.json                  git 仓库镜像列表（FPC + Lazarus）
│
├── fpc/
│   ├── versions.json             FPC 版本定义（ref、bootstrap、build steps）
│   └── binary.json               各平台二进制包 URL + hash
│
├── lazarus/
│   ├── versions.json             Lazarus 版本定义（ref、FPC 兼容性）
│   └── binary.json               各平台二进制包 URL + hash
│
├── cross/
│   └── targets.json              交叉编译目标定义
│
├── bootstrap/
│   └── compilers.json            Bootstrap 编译器下载 URL + hash
│
├── packages/
│   └── index.json                包索引
│
├── patches/                      版本特定补丁文件
│   └── fpc-3.2.2-aarch64.patch
│
└── build-steps/                  构建步骤模板
    ├── fpc-source.json           FPC 源码编译默认步骤
    ├── fpc-post-install.json     FPC 安装后配置步骤
    ├── lazarus-source.json       Lazarus 源码编译步骤
    └── cross-build.json          交叉编译器构建步骤
```

---

## 4. Schema 定义

### 4.1 index.json

```json
{
  "schema_version": 1,
  "minimum_fpdev": "2.2.0",
  "updated_at": "2026-05-19T00:00:00Z"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| schema_version | integer | Schema 版本号，不兼容变更时递增 |
| minimum_fpdev | string | 能解析此 schema 的最低 fpdev 版本 |
| updated_at | string | 最后更新时间（ISO 8601） |

### 4.2 sources.json

```json
{
  "fpc": {
    "gitlab": {
      "url": "https://gitlab.com/freepascal.org/fpc/source.git",
      "region": "eu"
    },
    "github": {
      "url": "https://github.com/fpc/FPCSource.git",
      "region": "us"
    },
    "gitee": {
      "url": "https://gitee.com/freepascal/fpc-source.git",
      "region": "cn"
    }
  },
  "lazarus": {
    "gitlab": {
      "url": "https://gitlab.com/freepascal.org/lazarus/lazarus.git",
      "region": "eu"
    },
    "github": {
      "url": "https://github.com/fpc/Lazarus.git",
      "region": "us"
    },
    "gitee": {
      "url": "https://gitee.com/freepascal/lazarus.git",
      "region": "cn"
    }
  }
}
```

### 4.3 fpc/versions.json

```json
{
  "default_version": "3.2.2",
  "versions": {
    "3.2.2": {
      "channel": "stable",
      "status": "active",
      "release_date": "2021-05-19",
      "ref": "release_3_2_2",

      "bootstrap": {
        "known_good": ["3.2.2", "3.2.0"],
        "minimum": "3.2.0"
      },

      "build": {
        "steps": [
          {
            "action": "make",
            "targets": ["all"],
            "env": {
              "PP": "{{bootstrap_compiler}}",
              "OVERRIDEVERSIONCHECK": "1"
            }
          },
          {
            "action": "make",
            "targets": ["install"],
            "env": {
              "PREFIX": "{{install_path}}",
              "PP": "{{build_dir}}/compiler/ppcx64"
            }
          }
        ],
        "platform_overrides": {
          "darwin-aarch64": {
            "steps_prepend": [
              {"action": "patch", "file": "patches/fpc-3.2.2-aarch64.patch"}
            ],
            "env_merge": {
              "MACOSX_DEPLOYMENT_TARGET": "11.0"
            }
          }
        }
      },

      "post_install": [
        {"action": "symlink-compiler"},
        {"action": "create-wrapper"},
        {"action": "generate-cfg"}
      ]
    },

    "3.3.1": {
      "channel": "development",
      "status": "active",
      "ref": "main",
      "tracking": true,

      "bootstrap": {
        "known_good": ["3.2.2"],
        "minimum": "3.2.2"
      },

      "build": {
        "inherit": "3.2.2",
        "env_override": {
          "OVERRIDEVERSIONCHECK": null
        }
      }
    }
  },

  "channels": {
    "stable": {
      "current": "3.2.2",
      "description": "Latest stable release"
    },
    "development": {
      "current": "3.3.1",
      "description": "Development trunk"
    }
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| versions.{ver}.channel | string | stable / development / legacy |
| versions.{ver}.status | string | active / eol（end of life） |
| versions.{ver}.ref | string | git tag 或 branch 名 |
| versions.{ver}.tracking | boolean | true 表示跟踪分支 HEAD（rolling） |
| versions.{ver}.bootstrap.known_good | string[] | 经过测试可用的 bootstrap 版本 |
| versions.{ver}.bootstrap.minimum | string | 最低 bootstrap 版本 |
| versions.{ver}.build.steps | object[] | 结构化构建步骤 |
| versions.{ver}.build.inherit | string | 继承另一个版本的 build 配置 |
| versions.{ver}.build.platform_overrides | object | 平台特定覆盖 |
| versions.{ver}.post_install | object[] | 安装后步骤 |

### 4.4 fpc/binary.json

```json
{
  "3.2.2": {
    "linux-x86_64": {
      "mirrors": {
        "github": "https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.2/fpc-3.2.2-linux-x86_64.tar.gz",
        "gitee": "https://gitee.com/dtamade/fpdev-fpc/releases/download/v3.2.2/fpc-3.2.2-linux-x86_64.tar.gz"
      },
      "hash": {
        "sha256": "46c083c7308a6fb978f0244c0e2e7c4217210200232923f777fc4f0483ca1caf"
      },
      "size": 85384375,
      "install_method": "nested-tar"
    },
    "windows-x86_64": {
      "mirrors": {
        "github": "https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.2/fpc-3.2.2-windows-x86_64.zip",
        "gitee": "https://gitee.com/dtamade/fpdev-fpc/releases/download/v3.2.2/fpc-3.2.2-windows-x86_64.zip"
      },
      "hash": {
        "sha256": "7182b02643594b082997f1c3af25171ffb85e89c57af1d036b26a1339f749c98"
      },
      "size": 86963689,
      "install_method": "unzip"
    },
    "darwin-x86_64": {
      "mirrors": {
        "github": "https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.2/fpc-3.2.2-darwin-x86_64.tar.gz"
      },
      "hash": {
        "sha256": "d0fab36b784273c8c5d79f03c0b5ca29ba282386e3c54a4161fbebf9796659e3"
      },
      "size": 134990974,
      "install_method": "nested-tar"
    }
  },
  "3.0.4": {
    "linux-x86_64": {
      "mirrors": {
        "github": "https://github.com/dtamade/fpdev-fpc/releases/download/v3.0.4/fpc-3.0.4.x86_64-linux.tar"
      },
      "hash": {
        "sha256": "7e965baf13c9822a0ff39e7bbfa040bd5599e94d0f3338f1ac4efa989081fd77"
      },
      "size": 56842240,
      "install_method": "nested-tar"
    }
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| install_method | string | nested-tar / unzip / untar-flat / dmg |
| mirrors | object | 镜像名 → URL 的映射 |
| hash | object | 算法 → 摘要值 |
| size | integer | 文件大小（字节），用于进度显示 |

### 4.5 cross/targets.json

```json
{
  "targets": {
    "arm-linux": {
      "cpu": "arm",
      "os": "linux",
      "subarch": "armv7a",
      "fpc_target": "arm-linux",
      "cross_options": "-CpARMV7A -CfVFPV3",
      "requires_fpc": ">=3.2.0",
      "binutils": {
        "prefix": "arm-linux-gnueabihf-",
        "acquisition": "system-package",
        "package_hint": {
          "debian": "gcc-arm-linux-gnueabihf",
          "fedora": "arm-linux-gnueabihf-gcc",
          "brew": "arm-linux-gnueabihf-binutils"
        }
      },
      "build": {
        "steps": [
          {
            "action": "make",
            "targets": ["crossall"],
            "env": {
              "CPU_TARGET": "arm",
              "OS_TARGET": "linux",
              "CROSSOPT": "{{cross_options}}",
              "PP": "{{host_compiler}}"
            }
          },
          {
            "action": "make",
            "targets": ["crossinstall"],
            "env": {
              "CPU_TARGET": "arm",
              "OS_TARGET": "linux",
              "PREFIX": "{{install_path}}"
            }
          }
        ]
      }
    },
    "aarch64-linux": {
      "cpu": "aarch64",
      "os": "linux",
      "fpc_target": "aarch64-linux",
      "cross_options": "",
      "requires_fpc": ">=3.2.0",
      "binutils": {
        "prefix": "aarch64-linux-gnu-",
        "acquisition": "system-package",
        "package_hint": {
          "debian": "gcc-aarch64-linux-gnu"
        }
      },
      "build": {
        "inherit": "arm-linux"
      }
    },
    "x86_64-win64": {
      "cpu": "x86_64",
      "os": "win64",
      "fpc_target": "x86_64-win64",
      "cross_options": "",
      "requires_fpc": ">=3.2.0",
      "binutils": {
        "prefix": "x86_64-w64-mingw32-",
        "acquisition": "system-package",
        "package_hint": {
          "debian": "mingw-w64",
          "brew": "mingw-w64"
        }
      },
      "build": {
        "inherit": "arm-linux"
      }
    }
  }
}
```

### 4.6 bootstrap/compilers.json

```json
{
  "compilers": {
    "3.2.2": {
      "linux-x86_64": {
        "mirrors": {
          "github": "https://github.com/dtamade/fpdev-bootstrap/releases/download/v3.2.2/fpc-3.2.2-bootstrap-linux-x86_64.tar.gz",
          "gitee": "https://gitee.com/dtamade/fpdev-bootstrap/releases/download/v3.2.2/fpc-3.2.2-bootstrap-linux-x86_64.tar.gz"
        },
        "hash": {"sha256": "..."},
        "size": 5800000
      },
      "darwin-aarch64": {
        "mirrors": {
          "github": "https://github.com/dtamade/fpdev-bootstrap/releases/download/v3.2.2/fpc-3.2.2-bootstrap-darwin-aarch64.tar.gz"
        },
        "hash": {"sha256": "..."}
      }
    },
    "3.2.0": {
      "linux-x86_64": {
        "mirrors": {
          "github": "https://github.com/dtamade/fpdev-bootstrap/releases/download/v3.2.0/fpc-3.2.0-bootstrap-linux-x86_64.tar.gz"
        },
        "hash": {"sha256": "..."}
      }
    }
  },

  "fallback_chain": ["3.2.2", "3.2.0", "3.0.4", "3.0.2", "3.0.0", "2.6.4"]
}
```

### 4.7 packages/index.json

```json
{
  "packages": [
    {
      "name": "synapse",
      "version": "40.1",
      "description": "TCP/IP library for Delphi and FreePascal",
      "author": "Lukas Gebauer",
      "license": "BSD",
      "homepage": "http://www.ararat.cz/synapse/",
      "mirrors": {
        "github": "https://github.com/geby/synapse/archive/refs/heads/master.zip"
      }
    },
    {
      "name": "mormot2",
      "version": "2.2",
      "description": "Server-side framework for Delphi and FPC",
      "author": "Synopse",
      "license": "MPL/LGPL",
      "homepage": "https://synopse.info",
      "mirrors": {
        "github": "https://github.com/synopse/mORMot2/archive/refs/heads/master.zip"
      },
      "dependencies": ["synapse"]
    }
  ]
}
```

### 4.8 build-steps/fpc-source.json

```json
{
  "description": "Default FPC source build steps",
  "steps": [
    {
      "action": "make",
      "targets": ["all"],
      "env": {
        "PP": "{{bootstrap_compiler}}",
        "OVERRIDEVERSIONCHECK": "1"
      },
      "parallel": true
    },
    {
      "action": "make",
      "targets": ["install"],
      "env": {
        "PREFIX": "{{install_path}}",
        "PP": "{{build_dir}}/compiler/{{native_compiler}}"
      }
    }
  ],
  "template_vars": {
    "bootstrap_compiler": "Bootstrap FPC 编译器路径",
    "install_path": "安装目标目录",
    "build_dir": "源码目录",
    "native_compiler": "本机编译器名（ppcx64/ppcarm 等）"
  }
}
```

### 4.9 build-steps/fpc-post-install.json

```json
{
  "description": "FPC post-install configuration steps",
  "steps": [
    {
      "action": "symlink-compiler",
      "description": "Create symlink from lib/fpc/VERSION/ppcx64 to bin/ppcx64",
      "platforms": ["linux", "darwin"]
    },
    {
      "action": "create-wrapper",
      "description": "Create bin/fpc wrapper script that calls native compiler with fpc.cfg",
      "platforms": ["linux", "darwin"],
      "template": "#!/bin/sh\n{{bin_path}}/{{native_compiler}} -n @{{bin_path}}/fpc.cfg \"$@\""
    },
    {
      "action": "generate-cfg",
      "description": "Generate fpc.cfg with unit and library search paths",
      "platforms": ["linux", "darwin", "windows"],
      "template_file": "templates/fpc.cfg.tmpl"
    }
  ]
}
```

---

## 5. 客户端行为

### 5.1 首次运行

```
用户安装 fpdev → 执行任何命令
  ├─ ~/.fpdev/registry/ 存在? → 使用 registry 数据
  └─ 不存在 → 使用内嵌 fallback 数据
       └─ 提示: "Run 'fpdev update-registry' to get latest version data"
```

内嵌 fallback 是编译时从 registry 仓库快照生成的资源文件，保证 fpdev 开箱即用。

### 5.2 update-registry 命令

```bash
fpdev update-registry [--mirror=gitee|github|gitlab]
```

行为：
1. 读取用户配置的 preferred_mirror（或命令行指定）
2. 确定 registry 仓库 URL
3. 如果 `~/.fpdev/registry/` 不存在：`git clone --depth=1 <url>`
4. 如果已存在：`git pull --ff-only`
5. 如果 pull 失败（网络问题）：保留现有数据，报告错误
6. 输出更新摘要

### 5.3 overrides.json

位置：`~/.fpdev/overrides.json`

用途：用户自定义覆盖，不受 git pull 影响。

```json
{
  "mirror": {
    "preferred": "gitee",
    "fallback_order": ["gitee", "github", "gitlab"],
    "latency_cache": {
      "best": "gitee",
      "tested_at": "2026-05-18T10:00:00Z",
      "ttl_hours": 168
    }
  },
  "local_sources": {
    "fpc": "/home/user/src/fpc",
    "lazarus": "/home/user/src/lazarus"
  },
  "fpc": {
    "versions": {
      "3.2.2-patched": {
        "ref": "my-fork/custom-branch",
        "note": "my patched build"
      }
    }
  }
}
```

合并规则：
- overrides.json 中的字段**覆盖** registry 中的同名字段
- 数组字段：overrides 完全替换（不合并）
- 对象字段：深度合并（overrides 的 key 覆盖 registry 的同名 key）

### 5.4 离线/气隔环境

无需任何特殊代码。操作方式：

1. 在有网络的机器上：`git clone --depth=1 <registry-url>`
2. 把 clone 的目录拷贝到目标机器的 `~/.fpdev/registry/`
3. 完事。fpdev 检测到目录存在就直接读取。

如果还需要二进制包/源码：
- 把下载好的 tar.gz 放到 `~/.fpdev/cache/downloads/`
- 或者把 FPC 源码仓库放到 overrides.json 的 `local_sources.fpc`

### 5.5 镜像选择逻辑

```
1. overrides.json 有 mirror.preferred? → 用它
2. 首次使用且未配置? → 自动检测区域（时区/LANG）
   ├─ 中国区域 → 默认 gitee
   └─ 其他 → 默认 github
3. auto 模式 → 测试延迟，缓存结果（TTL 168 小时）
```

### 5.6 源码获取逻辑

当执行 `fpdev fpc install <version> --from-source` 时：

```
1. --source-path=/path 指定了? → 直接用本地路径
2. overrides.json 有 local_sources.fpc? → 用本地路径
3. ~/.fpdev/sources/fpc/.git 存在?
   ├─ 是 → git fetch + git checkout <ref>
   └─ 否 → git clone <mirror-url> ~/.fpdev/sources/fpc/
            → git checkout <ref>
4. 源码目录就是单一仓库，用 checkout 切换版本
```

### 5.7 二进制获取逻辑

当执行 `fpdev fpc install <version> --from-binary` 时：

```
1. --archive=/path 指定了? → 直接用本地文件
2. ~/.fpdev/cache/downloads/ 有缓存? → 校验 hash，匹配则使用
3. 从 binary.json 获取当前平台的 mirrors
4. 按 preferred_mirror 选择 URL
5. 下载 → 校验 hash → 按 install_method 解压
6. 缓存到 ~/.fpdev/cache/downloads/
```

---

## 6. 目录结构（最终状态）

```
~/.fpdev/
├── registry/                       git clone of fpdev-registry（只读）
│   ├── index.json
│   ├── sources.json
│   ├── fpc/
│   ├── lazarus/
│   ├── cross/
│   ├── bootstrap/
│   ├── packages/
│   ├── patches/
│   └── build-steps/
│
├── overrides.json                  用户自定义覆盖
│
├── sources/                        源码仓库（单仓库 per 项目）
│   ├── fpc/                           单一 git repo，checkout 切换版本
│   └── lazarus/                       单一 git repo
│
├── toolchains/                     安装产物（干净，无中间文件）
│   ├── fpc/
│   │   ├── 3.0.4/
│   │   │   ├── bin/
│   │   │   ├── lib/
│   │   │   └── share/
│   │   └── 3.2.2/
│   └── lazarus/
│       └── 3.6/
│
├── bootstrap/                      Bootstrap 编译器
│   └── fpc-3.2.0/
│
├── cache/                          所有缓存（可安全删除）
│   ├── downloads/                     下载的原始包
│   └── builds/                        编译产物打包缓存
│
├── packages/                       已安装的包
│
└── config.json                     fpdev 运行时配置
```

---

## 7. Build Steps 执行引擎

### 7.1 Action 类型

| Action | 说明 | 参数 |
|--------|------|------|
| make | 执行 make 命令 | targets, env, parallel |
| patch | 应用补丁文件 | file |
| symlink-compiler | 创建编译器 symlink | （自动推导路径） |
| create-wrapper | 创建 fpc wrapper 脚本 | template |
| generate-cfg | 生成 fpc.cfg | template_file |
| copy | 复制文件/目录 | from, to |
| delete | 删除文件/目录 | path, pattern |

### 7.2 模板变量

| 变量 | 说明 |
|------|------|
| `{{install_path}}` | 安装目标目录 |
| `{{bootstrap_compiler}}` | Bootstrap 编译器路径 |
| `{{build_dir}}` | 源码/构建目录 |
| `{{version}}` | 目标版本号 |
| `{{native_compiler}}` | 本机编译器名（ppcx64/ppca64/...） |
| `{{bin_path}}` | 安装目录下的 bin/ 路径 |
| `{{host_compiler}}` | 宿主编译器路径（交叉编译用） |
| `{{cross_options}}` | 交叉编译选项 |
| `{{cpu_target}}` | 目标 CPU |
| `{{os_target}}` | 目标 OS |

### 7.3 平台覆盖机制

```json
"build": {
  "steps": [ ... ],                    // 基础步骤
  "platform_overrides": {
    "darwin-aarch64": {
      "steps_prepend": [ ... ],        // 在基础步骤前插入
      "steps_append": [ ... ],         // 在基础步骤后追加
      "steps_replace": [ ... ],        // 完全替换基础步骤
      "env_merge": { ... }             // 合并到所有步骤的 env
    }
  }
}
```

### 7.4 继承机制

```json
"3.3.1": {
  "build": {
    "inherit": "3.2.2",                // 继承 3.2.2 的 build 配置
    "env_override": {                  // 覆盖特定环境变量
      "OVERRIDEVERSIONCHECK": null     // null = 删除该变量
    }
  }
}
```

---

## 8. 迁移计划

### Phase 1：创建 registry 仓库

1. 创建 `fpdev-registry` 仓库
2. 从当前硬编码数据生成初始 JSON 文件
3. 镜像到 github / gitee / gitlab

### Phase 2：实现 registry 加载层

1. 实现 `TRegistryLoader` — 读取 registry 目录 + overrides 合并
2. 实现内嵌 fallback 资源生成（编译时脚本）
3. 实现 `fpdev update-registry` 命令

### Phase 3：迁移版本元数据

1. 替换 `fpdev.version.registry.loadflow.pas` 中的硬编码数据
2. 替换 `fpdev.constants.pas` 中的仓库 URL 常量
3. 替换 manifest 加载逻辑，改为读取 `fpc/binary.json`

### Phase 4：迁移构建流程

1. 实现 Build Steps 执行引擎
2. 替换 `fpdev.fpc.builderflow.pas` 中的硬编码 make 命令
3. 替换 `fpdev.fpc.installer.config.pas` 中的 post_install 逻辑

### Phase 5：迁移源码管理

1. 改为单仓库模式（`sources/fpc/` 单一 git repo）
2. 实现 `git checkout` 切换版本逻辑
3. 支持 `local_sources` 配置

### Phase 6：迁移其他元数据

1. 交叉编译目标 → 读取 `cross/targets.json`
2. Bootstrap 编译器 → 读取 `bootstrap/compilers.json`
3. 包索引 → 读取 `packages/index.json`

### Phase 7：清理

1. 删除所有硬编码的版本数据
2. 删除旧的 manifest 加载代码
3. 更新文档和测试

---

## 9. 与当前代码的映射

| 当前代码位置 | 迁移到 |
|-------------|--------|
| `fpdev.version.registry.loadflow.pas` (FPCReleases) | `registry/fpc/versions.json` |
| `fpdev.version.registry.loadflow.pas` (LazarusReleases) | `registry/lazarus/versions.json` |
| `fpdev.version.registry.loadflow.pas` (BootstrapMap) | `registry/fpc/versions.json` 的 bootstrap 字段 |
| `fpdev.constants.pas` (FPC_OFFICIAL_REPO) | `registry/sources.json` |
| `fpdev.constants.pas` (FPC_MIRROR_*) | `registry/fpc/binary.json` |
| `~/.fpdev/cache/manifests/*.json` | `registry/fpc/binary.json` |
| `~/.fpdev/packages/index.json` | `registry/packages/index.json` |
| `fpdev.fpc.mirrors.pas` | 删除，由 registry 镜像选择逻辑替代 |
| `fpdev.fpc.installer.config.pas` (post_install) | `registry/build-steps/fpc-post-install.json` + executor |
| `fpdev.fpc.builderflow.pas` (make 命令) | `registry/build-steps/fpc-source.json` + executor |

---

## 10. 设计决策记录

| 决策 | 选择 | 理由 |
|------|------|------|
| 分发方式 | Git 仓库 | fpdev 已有 libgit2；天然支持多镜像、离线、版本历史 |
| 用户自定义 | overrides.json（gitignored） | 比 overlay 双目录简单；git pull 永远不冲突 |
| 更新策略 | 手动 update-registry | 更新频率低；避免离线报错；用户保持控制 |
| 首次运行 | 内嵌 fallback | 开箱即用，不强制联网 |
| 源码管理 | 单仓库 + git checkout | 节省 1.2GB 磁盘；新版本只需 fetch + checkout |
| 构建步骤 | 结构化 action（非模板字符串） | 类型安全；跨平台；可做错误恢复 |
| Bootstrap | known_good 列表（非 semver range） | FPC 版本兼容性不遵循 semver |
| 文件拆分 | 按职责拆分多文件 | diff 清晰；可独立更新；离线可取子集 |
| 平台标识符 | 宿主用 {os}-{cpu}，交叉目标用 {cpu}-{os} | 宿主与 binary.json 一致；交叉目标遵循 FPC 惯例 |
| Registry URL | 硬编码在 fpdev 中 | 鸡生蛋问题——没 clone 前无法从 registry 读取 |

---

## 11. 补充规范（审查后增补）

以下内容基于 Codex 审查反馈补充，解决了设计中的关键缺陷。

### 11.1 继承机制规则

适用于 `fpc/versions.json` 的 `build.inherit` 和 `cross/targets.json` 的 `build.inherit`。

规则：
- 最大继承深度：**2 层**（A→B→C 允许，A→B→C→D 禁止）
- 加载时检测循环引用，发现则报错并中止
- 继承目标不存在时视为配置错误，报错并中止
- 继承行为：深拷贝父级 build 配置，然后应用子级的 override 字段

### 11.2 Cross Target 的模板变量自动填充

`cross/targets.json` 中的 build steps 应使用模板变量而非硬编码值：

```json
"build": {
  "steps": [
    {
      "action": "make",
      "targets": ["crossall"],
      "env": {
        "CPU_TARGET": "{{cpu}}",
        "OS_TARGET": "{{os}}",
        "CROSSOPT": "{{cross_options}}",
        "PP": "{{host_compiler}}"
      }
    },
    {
      "action": "make",
      "targets": ["crossinstall"],
      "env": {
        "CPU_TARGET": "{{cpu}}",
        "OS_TARGET": "{{os}}",
        "PREFIX": "{{install_path}}"
      }
    }
  ]
}
```

`{{cpu}}`、`{{os}}`、`{{cross_options}}` 由 target 定义中的 `cpu`、`os`、`cross_options` 字段自动填充。这样继承才有意义——步骤结构相同，变量由各 target 自动提供。

### 11.3 overrides.json 中 build 字段的合并语义

overrides.json 中的 build 字段遵循与 `platform_overrides` 相同的合并协议：

```json
{
  "fpc": {
    "versions": {
      "3.2.2": {
        "build": {
          "steps_prepend": [{"action": "patch", "file": "my-local.patch"}],
          "env_override": {"CUSTOM_FLAG": "1"}
        }
      }
    }
  }
}
```

支持的合并操作：
- `steps_prepend`：在基础步骤前插入
- `steps_append`：在基础步骤后追加
- `steps_replace`：完全替换基础步骤
- `env_override`：合并到所有步骤的 env（null 值表示删除）

**不支持**直接写 `"steps": [...]`（数组完全替换），必须使用上述语义化操作。

### 11.4 native_compiler 解析规则

`{{native_compiler}}` 由 fpdev 运行时根据宿主平台自动填充：

| 宿主平台 | native_compiler |
|----------|----------------|
| linux-x86_64 | ppcx64 |
| linux-aarch64 | ppca64 |
| linux-i386 | ppc386 |
| darwin-x86_64 | ppcx64 |
| darwin-aarch64 | ppca64 |
| windows-x86_64 | ppcx64.exe |
| windows-i386 | ppc386.exe |

此映射表硬编码在 fpdev 中（不在 registry 中），因为这是"怎么做"的执行逻辑。

### 11.5 Action 通用可选字段

适用于所有 action 类型的可选字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| platforms | string[] | 仅在列出的平台上执行，其他平台静默跳过 |
| description | string | 人类可读的步骤说明（用于日志输出） |

### 11.6 Bootstrap 解析算法

当需要 bootstrap 编译器时，按以下顺序解析：

```
1. 检查系统 FPC 版本是否在目标版本的 bootstrap.known_good 列表中
   → 是：使用系统 FPC
2. 检查 fpdev 已安装的版本是否在 known_good 列表中
   → 是：使用已安装版本
3. 按 known_good 列表顺序，查找 bootstrap/compilers.json 中
   有当前平台下载链接的第一个版本
   → 找到：下载并使用
4. 回退到 fallback_chain 中 >= bootstrap.minimum 的第一个
   在 compilers.json 中有当前平台条目的版本
   → 找到：下载并使用
5. 全部不可用 → 报错，提示：
   - 手动安装系统 FPC
   - 或使用 --from-binary 安装
```

### 11.7 Lazarus versions.json Schema

```json
{
  "default_version": "3.6",
  "versions": {
    "3.6": {
      "channel": "stable",
      "status": "active",
      "release_date": "2024-10-14",
      "ref": "lazarus_3_6",

      "fpc_compatible": ["3.2.2", "3.2.0"],
      "fpc_minimum": "3.2.0",

      "build": {
        "steps": [
          {
            "action": "make",
            "targets": ["all"],
            "env": {
              "PP": "{{fpc_compiler}}",
              "PREFIX": "{{install_path}}"
            },
            "parallel": true
          },
          {
            "action": "make",
            "targets": ["install"],
            "env": {
              "PREFIX": "{{install_path}}"
            }
          }
        ]
      },

      "post_install": [
        {"action": "generate-lazarus-cfg"}
      ]
    },

    "main": {
      "channel": "development",
      "status": "active",
      "ref": "main",
      "tracking": true,
      "fpc_compatible": ["3.2.2", "3.3.1", "main"],
      "fpc_minimum": "3.2.2",
      "build": {
        "inherit": "3.6"
      }
    }
  },

  "channels": {
    "stable": {"current": "3.6"},
    "development": {"current": "main"}
  }
}
```

Lazarus 特有的模板变量：

| 变量 | 说明 |
|------|------|
| `{{fpc_compiler}}` | 兼容的 FPC 编译器路径 |
| `{{install_path}}` | Lazarus 安装目标目录 |

### 11.8 install_method 行为定义

| Method | 输入格式 | 行为 |
|--------|---------|------|
| nested-tar | .tar / .tar.gz | 解压外层后，内部有 binary.*.tar，再解压内层到目标目录，逐个解压 units-*.tar.gz |
| unzip | .zip | 直接解压到目标目录 |
| untar-flat | .tar.gz | 直接解压到目标目录（无嵌套） |
| dmg | .dmg | 挂载 DMG，提取内容到目标目录 |
| inno-extract | .exe | 使用 innoextract 解压 Inno Setup 安装包 |

### 11.9 平台标识符规范

- **宿主平台**（binary.json, platform_overrides）：`{os}-{cpu}` 格式
  - 示例：`linux-x86_64`, `darwin-aarch64`, `windows-x86_64`
- **交叉目标**（cross/targets.json）：`{cpu}-{os}` 格式
  - 示例：`arm-linux`, `aarch64-darwin`, `x86_64-win64`
  - 遵循 FPC 的 `CPU_TARGET-OS_TARGET` 惯例

### 11.10 Registry 仓库 URL（鸡生蛋问题）

Registry 仓库自身的 URL 是唯一允许硬编码在 fpdev 代码中的 URL：

```pascal
const
  FPDEV_REGISTRY_GITHUB = 'https://github.com/dtamade/fpdev-registry.git';
  FPDEV_REGISTRY_GITEE  = 'https://gitee.com/dtamade/fpdev-registry.git';
  FPDEV_REGISTRY_GITLAB = 'https://gitlab.com/dtamade/fpdev-registry.git';
```

`update-registry` 根据用户的 `preferred_mirror` 配置选择使用哪个 URL。

`sources.json` 中也包含 registry 条目，用于已有 clone 后切换镜像源。

### 11.11 Fallback 快照生成

编译时脚本将 registry 的以下文件合并为单个 JSON 资源嵌入 fpdev 二进制：

包含内容：
- `sources.json`（完整）
- `fpc/versions.json`（仅 stable channel 的版本）
- `fpc/binary.json`（仅最新 stable 版本的当前平台）
- `bootstrap/compilers.json`（仅最新 stable 对应的 bootstrap）

嵌入方式：使用 FPC 的 `{$R}` 资源机制或编译时 `{$I}` include。

运行时使用 fallback 时显示警告：
```
Warning: Using embedded registry data (generated 2026-05-19).
Run 'fpdev update-registry' to get the latest version information.
```

### 11.12 包索引完整 Schema

```json
{
  "packages": [
    {
      "name": "synapse",
      "version": "40.1",
      "description": "TCP/IP library for Delphi and FreePascal",
      "author": "Lukas Gebauer",
      "license": "BSD",
      "homepage": "http://www.ararat.cz/synapse/",
      "fpc_compatible": ">=3.0.0",
      "type": "source",
      "unit_paths": ["source/lib"],
      "mirrors": {
        "github": "https://github.com/geby/synapse/archive/refs/heads/master.zip"
      },
      "hash": {"sha256": "..."},
      "dependencies": []
    }
  ]
}
```

| 字段 | 类型 | 必须 | 说明 |
|------|------|------|------|
| name | string | 是 | 包名 |
| version | string | 是 | 版本号 |
| description | string | 是 | 简短描述 |
| author | string | 否 | 作者 |
| license | string | 否 | 许可证 |
| homepage | string | 否 | 主页 URL |
| fpc_compatible | string | 否 | 兼容的 FPC 版本范围 |
| type | string | 否 | source / binary（默认 source） |
| unit_paths | string[] | 否 | 安装后的单元搜索路径（相对于包根目录） |
| mirrors | object | 是 | 镜像名 → 下载 URL |
| hash | object | 否 | 算法 → 摘要值 |
| dependencies | string[] | 否 | 依赖的其他包名 |

### 11.13 镜像区域自动检测规则

```
区域检测（按优先级）：
1. TZ 包含 "Asia/Shanghai" 或 "Asia/Chongqing" 或 "Asia/Urumqi" → cn
2. LANG 以 "zh_CN" 开头 → cn
3. 其他所有情况 → 默认 github

注：不尝试做完美的地理检测。用户可通过 overrides.json 手动设置 preferred mirror。
```

### 11.14 Schema 版本兼容性策略

- fpdev 支持当前 `schema_version` 和前一个版本（向后兼容 1 代）
- 遇到未来 `schema_version`（高于支持范围）时：回退到内嵌 fallback 并警告升级 fpdev
- `minimum_fpdev` 检查失败时：警告但继续使用 fallback，提示升级

### 11.15 运行时缓存与用户配置分离

`overrides.json` 只保留用户意图性配置。运行时缓存数据存放在：

```
~/.fpdev/cache/
├── mirror-latency.json          镜像延迟测试缓存
└── ...
```

`mirror-latency.json` 格式：
```json
{
  "best": "gitee",
  "tested_at": "2026-05-18T10:00:00Z",
  "ttl_hours": 168,
  "results": {
    "github": 230,
    "gitee": 45,
    "gitlab": 180
  }
}
```

### 11.16 迁移计划修订

基于审查反馈，调整 Phase 顺序：

| Phase | 内容 | 依赖 |
|-------|------|------|
| 1 | 创建 fpdev-registry 仓库，生成初始数据 | 无 |
| 2 | 实现 registry 加载层 + fallback + update-registry 命令 | Phase 1 |
| 3 | **源码管理改为单仓库**（提前，因为后续 phase 依赖路径假设） | Phase 2 |
| 4 | 迁移版本元数据（替换硬编码） | Phase 2 |
| 5 | 实现 Build Steps 执行引擎 + 迁移构建流程 | Phase 4 |
| 6 | 迁移其他元数据（cross targets, bootstrap, packages） | Phase 4 |
| 7 | 清理旧代码 + 更新测试 | Phase 5, 6 |

### 11.17 build-steps/ 目录定位

`build-steps/` 目录下的文件是**默认模板**，可被 `versions.json` 中的内联 build 配置引用：

```json
"build": {
  "template": "build-steps/fpc-source.json",
  "env_override": {"CUSTOM": "1"}
}
```

或者版本可以完全内联 build steps（不引用模板）。两种方式等价，选择取决于是否需要复用。

引用模板时的合并规则：加载模板内容，然后应用 `env_override`、`steps_prepend`、`steps_append` 等覆盖字段。
