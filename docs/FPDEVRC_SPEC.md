# .fpdevrc 项目配置文件规范 v1.0

## 概述

`.fpdevrc` 是 fpdev 的项目级配置文件，用于锁定项目所需的工具链版本，实现团队协作和 CI 环境的一致性。

**设计目标**：
- 类似 `rust-toolchain.toml` 和 `.nvmrc` 的体验
- 支持自动版本切换（cd 时检测）
- 支持版本别名（stable/lts/trunk）
- 最小化配置，合理默认值

## 文件位置

fpdev 按以下顺序查找配置文件（优先级从高到低）：

1. 当前目录的 `.fpdevrc`
2. 当前目录的 `fpdev.toml`
3. 父目录递归查找 `.fpdevrc` 或 `fpdev.toml`（最多向上 10 级）
4. 全局配置 `~/.fpdev/config.json`

## 文件格式

### 简单格式（仅版本号）

最简单的 `.fpdevrc` 只需要一行版本号：

```
3.2.2
```

这等价于：
```toml
[toolchain]
fpc = "3.2.2"
```

### TOML 格式（完整配置）

```toml
# fpdev.toml 或 .fpdevrc (TOML 格式)

[toolchain]
# FPC 版本（必需）
fpc = "3.2.2"

# Lazarus 版本（可选）
lazarus = "3.8"

# 版本通道（可选，覆盖具体版本）
# 可选值: stable, lts, trunk
channel = "stable"

[cross]
# 交叉编译目标（可选）
targets = ["aarch64-linux", "x86_64-win64"]

[settings]
# 镜像源（可选）
# 可选值: auto, github, gitee, <custom-url>
mirror = "auto"

# 是否自动安装缺失版本（可选，默认 false）
auto_install = false
```

## 版本别名

支持以下版本别名：

| 别名 | 说明 |
|------|------|
| `stable` | 最新稳定版（当前 3.2.2） |
| `lts` | 长期支持版（当前 3.2.0） |
| `trunk` | 开发版（main 分支） |
| `latest` | 等同于 stable |

示例：
```toml
[toolchain]
fpc = "stable"
lazarus = "lts"
```

## 配置优先级

fpdev 当前按以下优先级解析配置（从高到低）：

1. **环境变量** - `FPDEV_FPC_VERSION`, `FPDEV_LAZARUS_VERSION`
2. **项目配置** - `.fpdevrc` 或 `fpdev.toml`
3. **全局默认** - `~/.fpdev/config.json` 中的 `default_toolchain`
4. **系统默认** - 硬编码的 `DEFAULT_FPC_VERSION`

当前 CLI 还没有公开 `--fpc-version`、`--lazarus-version` 这样的全局参数，所以这里不把它们算进实际优先级。

## Shell 集成

### 自动版本切换

启用 shell hook 后，进入包含 `.fpdevrc` 的目录时自动切换版本：

**Bash** (`~/.bashrc`):
```bash
eval "$(fpdev system env hook bash)"
```

**Zsh** (`~/.zshrc`):
```zsh
eval "$(fpdev system env hook zsh)"
```

**Fish** (`~/.config/fish/config.fish`):
```fish
fpdev system env hook fish | source
```

### 手动切换

```bash
# 设置当前 FPC 版本
fpdev fpc use 3.2.2

# 确保版本存在后再切换
fpdev fpc use 3.2.2 --ensure

# 设置当前 Lazarus 版本
fpdev lazarus use 3.8
```

当前 CLI 没有公开顶层 `fpdev use` 或 `fpdev override` 命令。如果你需要临时覆盖，优先使用环境变量或显式的 `fpc` / `lazarus` 子命令。

## 示例场景

### 场景 1：简单项目

```
# .fpdevrc
3.2.2
```

### 场景 2：Lazarus GUI 项目

```toml
# fpdev.toml
[toolchain]
fpc = "3.2.2"
lazarus = "3.8"
```

### 场景 3：交叉编译项目

```toml
# fpdev.toml
[toolchain]
fpc = "3.2.2"

[cross]
targets = ["aarch64-linux", "arm-linux"]

[settings]
auto_install = true
```

### 场景 4：CI 环境

```toml
# fpdev.toml
[toolchain]
channel = "stable"

[settings]
mirror = "gitee"
auto_install = true
```

## 与 config.json 的关系

| 配置项 | .fpdevrc | config.json |
|--------|----------|-------------|
| 作用域 | 项目级 | 用户级/全局 |
| 版本锁定 | ✅ | ❌ |
| 默认版本 | ❌ | ✅ |
| 镜像设置 | ✅ | ✅ |
| 已安装版本 | ❌ | ✅ |
| 仓库配置 | ❌ | ✅ |

## 错误处理

当 `.fpdevrc` 指定的版本未安装时：

1. **auto_install = true**: 自动下载安装
2. **auto_install = false**: 提示用户安装
   ```
   Error: FPC 3.2.2 is not installed.

   To install it, run:
     fpdev fpc install 3.2.2

   Or enable auto-install in .fpdevrc:
     [settings]
     auto_install = true
   ```

## 版本历史

- v1.0 (2026-01-15): 初始版本

---

*文档版本: 1.0*
*创建日期: 2026-01-15*
