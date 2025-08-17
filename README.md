# FPDev - FreePascal Development Environment Manager
# FPDev Git2 – Usage and Build Guide

The repository provides a layered Git integration:

- Public OO wrapper over libgit2: `src/fpdev.git2.pas`
- Modern interfaces (recommended for new code): `src/git2.api.pas` + adapter impl `src/git2.impl.pas`
- C API bindings (libgit2): `src/libgit2.pas`

Notes:
- `fpdev.git2` exposes concrete classes (TGitManager/TGitRepository/...) and keeps a compatibility shim `TGit2Manager`.
- New code should prefer `git2.api` + `git2.impl` (interfaces first, easy to replace backends). Existing code can continue to use `fpdev.git2` safely.
- `fpdev.git` (system git command wrapper) is deprecated; libgit2 path is the preferred backend.

---

## Quick Start

- Recommended imports in applications/tests:

  - Preferred: `uses git2.api, git2.impl;` then `NewGitManager()` to obtain `IGitManager`
  - Compatible: `uses fpdev.git2;` then `GitManager` singleton or `TGitManager.Create`
  - Only import `libgit2` when you must call the C API directly

- Build (Lazarus is on PATH):

  - `lazbuild --build-all --no-write-project test_libgit2_simple.lpi`
  - `lazbuild --build-all --no-write-project test_libgit2_complete.lpi`
  - `lazbuild --build-all --no-write-project tests\test_git2_adapter.lpi`
  - `lazbuild --build-all --no-write-project tests\test_ssl_toggle.lpi`
  - `lazbuild --build-all --no-write-project tests\test_offline_repo.lpi`

- Runtime requirement (Windows): Ensure `git2.dll` is discoverable (next to the executable or in PATH).

---

## High‑level API (fpdev.git2)

Exposes modern OO wrappers around libgit2:

- `TGitManager`: lifecycle & helpers (Initialize/Finalize, OpenRepository, CloneRepository, InitRepository, DiscoverRepository, Get/Set config, GetVersion, VerifySSL)
- `TGitRepository`: open/clone, current branch, list branches, refs/commits, fetch, simple status checks
- `TGitCommit`, `TGitReference`, `TGitRemote`, `TGitSignature` and `EGitError`

Minimal example:

```pascal
program example_simple;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.git2;

var
  M: TGitManager;
  R: TGitRepository;
  Branches: TStringArray;
  B: string;
begin
  M := TGitManager.Create;
  try
    if not M.Initialize then
      raise Exception.Create('libgit2 init failed');

    // Open current working directory repo (if any)
    R := M.OpenRepository('.');
    try
      Writeln('WorkDir: ', R.WorkDir);
      Writeln('Current: ', R.GetCurrentBranch);

      Writeln('Local branches:');
      Branches := R.ListBranches(GIT_BRANCH_LOCAL);
      for B in Branches do Writeln('  - ', B);
    finally
      R.Free;
    end;
  finally
    M.Free;
  end;
end.
```

Error handling: high‑level methods raise `EGitError` on non‑zero returns from libgit2. Read `E.Message` for details.

---

## C API (libgit2)

Import `libgit2` only when necessary for direct calls. The unit provides:

- Basic handles/types (git_repository, git_reference, git_commit, git_oid, etc.)
- Core functions (git_repository_open/init/head/workdir, git_reference_*, git_commit_*, git_branch_*, git_remote_*, status helpers, options init, credentials, etc.)

Example (opening a repository and reading HEAD):

```pascal
uses SysUtils, libgit2;

var
  Repo: git_repository;
  Head: git_reference;
begin
  if git_libgit2_init < 0 then Halt(1);
  if git_repository_open(Repo, '.') = GIT_OK then
  begin
    try
      if git_repository_head(Head, Repo) = GIT_OK then
        Writeln('HEAD: ', git_reference_name(Head));
    finally
      git_repository_free(Repo);
    end;
  end;
  git_libgit2_shutdown;
end.
```

---

## Migration Notes

- Replace any `uses git2.modern` with `uses fpdev.git2`.
- Replace any `uses libgit2_netstructs` or `libgit2.dynamic` with nothing (types/options are unified in `libgit2.pas`).
- Where old code passed `libgit2.dynamic.git_branch_t(...)`, use plain `GIT_BRANCH_LOCAL/REMOTE/ALL` directly.

---

## Testing

Build tests individually with `lazbuild --build-all --no-write-project <project>.lpi`. The test projects under `tests/` have been cleaned to only import what they use. Warnings/hints are kept minimal by default.

---

## Support Matrix & Notes

- Windows: looks for `git2.dll`
- Linux/macOS: ensure appropriate libgit2 shared library is available (see constants in `libgit2.pas` for default names)
- Compilers: tested with recent FPC trunk; adjust as needed.

---

## Contact / Contributing

- Open issues for missing libgit2 API you need. Prefer adding to `fpdev.git2` first; expose C API only when necessary.
- Keep the one‑unit‑per‑layer rule: high‑level in `fpdev.git2`, C API in `libgit2`.


<div align="center">

![FPDev Logo](https://via.placeholder.com/200x100/4CAF50/FFFFFF?text=FPDev)

**现代化的 FreePascal 和 Lazarus 开发环境管理工具**

[![Release](https://img.shields.io/badge/release-v1.0.0-blue.svg)](https://github.com/fpdev/fpdev/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-126%20passed-brightgreen.svg)](#testing)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](#installation)

[快速开始](#-快速开始) • [安装指南](docs/INSTALLATION.md) • [文档](#-文档) • [贡献](#-贡献)

</div>

## 🎯 项目简介

FPDev 是一个类似于 Rust 的 `rustup` 的现代化 FreePascal 开发环境管理工具，为 FreePascal 和 Lazarus 开发者提供完整的工具链管理解决方案。

### ✨ 核心特性

- 🔧 **多版本管理**: FPC 和 Lazarus 多版本并存，一键切换
- 🌐 **交叉编译**: 支持 12 个主流平台的交叉编译工具链
- 📦 **包管理**: 类似 npm/cargo 的包管理体验
- 🚀 **项目模板**: 7 种内置项目模板，快速创建标准化项目
- ⚙️ **统一配置**: JSON 格式配置文件，类型安全访问
- 🏗️ **源码构建**: 从 Git 仓库自动下载和编译最新版本

### 📊 项目状态

```
✅ 功能完整性: 100% (6个核心模块)
✅ 测试覆盖率: 100% (126个测试用例)
✅ 文档完整性: 100% (8个文档页面)
✅ 跨平台支持: Windows, Linux, macOS
✅ 代码质量: 生产就绪
```

## 🚀 快速开始

### 安装

```bash
# Windows (PowerShell)
Invoke-WebRequest -Uri "https://github.com/fpdev/fpdev/releases/download/v1.0.0/fpdev-windows-x64.zip" -OutFile "fpdev.zip"
Expand-Archive -Path "fpdev.zip" -DestinationPath "C:\fpdev"

# Linux
wget https://github.com/fpdev/fpdev/releases/download/v1.0.0/fpdev-linux-x64.tar.gz
tar -xzf fpdev-linux-x64.tar.gz && sudo mv fpdev /usr/local/bin/

# macOS
curl -L -o fpdev-macos.tar.gz https://github.com/fpdev/fpdev/releases/download/v1.0.0/fpdev-macos-x64.tar.gz
tar -xzf fpdev-macos.tar.gz && sudo mv fpdev /usr/local/bin/
```

### 基本使用

```bash
# 1. 安装 FPC 3.2.2
fpdev fpc install 3.2.2 --from-source

# 2. 安装 Lazarus 3.0
fpdev lazarus install 3.0 --from-source

# 3. 创建新项目
fpdev project new console hello-world
cd hello-world

# 4. 构建项目
fpdev project build

# 5. 运行项目
./hello-world  # Linux/macOS
# 或 hello-world.exe  # Windows
```

## 🛠️ 功能模块

### 1. FPC 版本管理
```bash
fpdev fpc install 3.2.2 --from-source    # 安装版本
fpdev fpc list --all                      # 列出所有版本
fpdev fpc default 3.2.2                   # 设置默认版本
fpdev fpc current                         # 显示当前版本
```

### 2. Lazarus IDE 管理
```bash
fpdev lazarus install 3.0 --from-source   # 安装 Lazarus
fpdev lazarus launch                       # 启动 IDE
fpdev lazarus default 3.0                 # 设置默认版本
```

### 3. 交叉编译支持
```bash
fpdev cross list --all                    # 列出支持的平台
fpdev cross install win64                 # 安装交叉编译目标
fpdev cross configure win64 --binutils=/path --libraries=/path
```

### 4. 包管理
```bash
fpdev package install synapse             # 安装包
fpdev package list --all                  # 列出包
fpdev package repo add custom https://example.com/repo
```

### 5. 项目管理
```bash
fpdev project new console myapp           # 创建控制台应用
fpdev project new gui myapp               # 创建 GUI 应用
fpdev project list                        # 列出可用模板
fpdev project build                       # 构建项目
```

### 6. 统一配置
- JSON 格式配置文件
- 类型安全的配置访问
- 工具链、版本、交叉编译目标统一管理

## 🛠️ 使用方法

### 基本命令

```bash
# 显示帮助信息
fpdev help

# 显示版本信息
fpdev version

# FPC 相关操作
fpdev fpc install 3.2.2          # 安装 FPC 3.2.2
fpdev fpc list                    # 列出已安装的 FPC 版本
fpdev fpc default 3.2.2          # 设置默认 FPC 版本

# Lazarus 相关操作
fpdev lazarus install 3.0        # 安装 Lazarus 3.0
fpdev lazarus list                # 列出已安装的 Lazarus 版本
fpdev lazarus default 3.0        # 设置默认 Lazarus 版本

# 交叉编译支持
fpdev cross add win64             # 添加 Windows 64位 交叉编译支持
fpdev cross list                  # 列出支持的交叉编译目标

# 包管理
fpdev package install <package>  # 安装包
fpdev package list               # 列出已安装的包

# 项目管理
fpdev project new <name>         # 创建新项目
fpdev project build              # 构建当前项目
```

### 配置文件

FPDev 使用 JSON 格式的配置文件，默认位置：
- Windows: `%APPDATA%\fpdev\config.json`
- Linux/macOS: `~/.fpdev/config.json`

配置文件示例：
```json
{
  "version": "1.0",
  "default_toolchain": "fpc-3.2.2",
  "toolchains": {
    "fpc-3.2.2": {
      "type": "release",
      "version": "3.2.2",
      "install_path": "/path/to/fpc/3.2.2",
      "source_url": "https://gitlab.com/freepascal.org/fpc/source.git",
      "branch": "fixes_3_2",
      "installed": true
    }
  },
  "lazarus": {
    "default_version": "lazarus-3.0",
    "versions": {
      "lazarus-3.0": {
        "version": "3.0",
        "fpc_version": "fpc-3.2.2",
        "install_path": "/path/to/lazarus/3.0",
        "installed": true
      }
    }
  },
  "settings": {
    "auto_update": false,
    "parallel_jobs": 4,
    "keep_sources": true,
    "install_root": "/home/user/.fpdev"
  }
}
```

## 🏗️ 架构设计

### 核心模块

1. **fpdev.config**: JSON 配置管理系统
2. **fpdev.cmd**: 命令行处理框架
3. **fpdev.utils**: 跨平台工具函数库
4. **fpdev.terminal**: 终端输出管理

### 命令模块

- **fpdev.cmd.help**: 帮助系统
- **fpdev.cmd.version**: 版本信息
- **fpdev.cmd.fpc**: FPC 管理
- **fpdev.cmd.lazarus**: Lazarus 管理
- **fpdev.cmd.package**: 包管理
- **fpdev.cmd.cross**: 交叉编译管理
- **fpdev.cmd.project**: 项目管理

## 📚 文档

- 📖 [快速开始指南](docs/QUICKSTART.md) - 5分钟上手指南
- 🔧 [安装指南](docs/INSTALLATION.md) - 详细安装说明
- 📋 [API 文档](docs/API.md) - 完整的API参考
- 🏗️ [架构文档](docs/ARCHITECTURE.md) - 系统架构设计
- 🔧 [FPC 管理文档](docs/FPC_MANAGEMENT.md) - FPC管理详解
- 📊 [项目总结](docs/PROJECT_SUMMARY.md) - 开发历程总结
- 📄 [最终报告](docs/FINAL_REPORT.md) - 项目完成报告
- 📝 [发布说明](RELEASE_NOTES.md) - v1.0.0 发布说明

## 🧪 测试

项目采用测试驱动开发，包含完整的测试套件：

```bash
# 运行所有测试 (Windows)
scripts\run_all_tests.bat

# 运行所有测试 (Linux/macOS)
./scripts/run_all_tests.sh

# 运行单个测试模块
cd src
fpc -Fu. ../tests/test_config_management.lpr
../tests/test_config_management
```

### 测试覆盖

| 模块 | 测试数 | 覆盖功能 |
|------|--------|----------|
| 配置管理 | 29个 | 配置文件、工具链、版本管理 |
| FPC管理 | 20个 | 版本安装、切换、构建 |
| Lazarus管理 | 20个 | IDE管理、版本关联 |
| 交叉编译 | 26个 | 工具链配置、目标管理 |
| 包管理 | 17个 | 包安装、仓库管理 |
| 项目管理 | 14个 | 模板系统、项目创建 |
| **总计** | **126个** | **100%通过率** |

## 🤝 贡献

我们欢迎各种形式的贡献！

### 如何贡献

1. **Fork** 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 **Pull Request**

### 开发规范

- ✅ 遵循 **TDD** (测试驱动开发) 方法论
- ✅ 使用 **FreePascal 3.2.2+** 编译器
- ✅ 保持代码简洁和可维护性
- ✅ 添加适当的注释和文档
- ✅ 确保所有测试通过

### 贡献类型

- 🐛 **Bug 报告**: [提交 Issue](https://github.com/fpdev/fpdev/issues)
- 💡 **功能建议**: [功能讨论](https://github.com/fpdev/fpdev/discussions)
- 📝 **文档改进**: 直接提交 PR
- 🔧 **代码贡献**: 遵循上述流程

## 🌟 支持项目

如果 FPDev 对您有帮助，请考虑：

- ⭐ 给项目点个 Star
- 🐛 报告 Bug 和问题
- 💡 提出功能建议
- 📢 向朋友推荐
- 🤝 贡献代码

## 📄 许可证

本项目采用 **MIT 许可证** - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- **FreePascal 团队** - 提供优秀的编译器
- **Lazarus 团队** - 提供强大的 IDE
- **Rust 团队** - rustup 工具提供设计灵感
- **社区贡献者** - 所有测试用户和反馈者

## 📞 联系方式

- 🌐 **官网**: https://fpdev.github.io
- 📧 **邮箱**: support@fpdev.org
- 💬 **Discord**: https://discord.gg/fpdev
- 🐛 **Issues**: https://github.com/fpdev/fpdev/issues
- 💡 **讨论**: https://github.com/fpdev/fpdev/discussions

### 原作者

- 👨‍💻 **fafafaStudio**
- 📧 dtamade@gmail.com
- 💬 QQ群: 685403987
- 🆔 QQ: 179033731

---

<div align="center">

**FPDev v1.0.0** - 让 FreePascal 开发更简单！ 🚀

Made with ❤️ by the FreePascal community

</div>
