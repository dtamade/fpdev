# FPDev 项目文档

**语言**: Object Pascal (Free Pascal / Lazarus)  
**主要用途**: Free Pascal 编译器与 Lazarus IDE 的开发环境管理工具  
**架构**: 模块化分层设计,命令模式 + Git 集成 + 沙箱构建系统

---

## 目录

1. [项目概述](#项目概述)
2. [核心开发范式:红-绿-重构(TDD)](#核心开发范式红-绿-重构tdd)
3. [构建与测试](#构建与测试)
4. [项目架构](#项目架构)
5. [核心实现细节](#核心实现细节)
6. [配置与源码管理](#配置与源码管理)
7. [重点提醒(Common Gotchas)](#重点提醒common-gotchas)
8. [文件命名规范](#文件命名规范)
9. [测试策略](#测试策略)
10. [外部依赖](#外部依赖)
11. [常用命令参考](#常用命令参考)
12. [仓库目录结构](#仓库目录结构)

---

## 项目概述

**FPDev** 是一个跨平台的命令行工具,用于管理 Free Pascal 编译器(FPC)和 Lazarus IDE 的安装、配置、构建和包管理。该项目采用 **模块化分层架构**,遵循 **命令模式(Command Pattern)** 和 **测试驱动开发(TDD)** 原则,确保代码的可维护性、可扩展性和可测试性。

### 核心特性

- **工具链管理**: 安装、列举、切换和删除 FPC/Lazarus 版本
- **交叉编译支持**: 添加和管理交叉编译目标
- **包管理**: 安装和管理 Lazarus 包
- **Git 集成**: 使用 libgit2 进行源码管理和版本控制
- **沙箱构建**: 默认安全构建,所有构建产物限制在沙箱内,不污染系统目录
- **模块化命令系统**: 基于命令模式的可扩展命令框架
- **跨平台**: Windows、Linux、macOS 支持

---

## 核心开发范式:红-绿-重构(TDD)

### 🔴 红阶段(Red Phase):编写失败的测试

在实现任何功能之前,**必须先编写测试**。测试应该:

1. **明确描述预期行为**: 测试用例名称应清晰表达意图(如 `test_git2_adapter_init_success`)
2. **覆盖边界情况**: 包括正常流程、异常输入、边界条件
3. **快速失败**: 测试应该立即失败,证明功能尚未实现

**示例**(参考 `tests/test_git2_adapter.lpr`):

```pascal
var
  Adapter: TGit2Manager;
  RepoDir: string;
  Repo: git_repository;
begin
  Adapter := TGit2Manager.Create;
  try
    if not Adapter.Initialize then
    begin
      WriteLn('INIT_FAIL');
      Halt(1);
    end;

    RepoDir := NewTempRepoDir('adapter_repo');
    // 初始化一个空仓库(离线)
    if git_repository_init(Repo, PChar(RepoDir), 0) <> GIT_OK then
    begin
      WriteLn('INIT_REPO_FAIL');
      Halt(1);
    end;
```

### 🟢 绿阶段(Green Phase):实现最小可用代码

编写**最简单**的代码使测试通过,不追求完美:

1. **快速实现**: 优先让测试变绿,不过度设计
2. **单一职责**: 每次只实现一个测试所需的功能
3. **可验证**: 确保测试能够稳定通过

**原则**:
- ✅ 先让测试通过(即使代码不优雅)
- ❌ 不在此阶段进行优化或重构

### 🔵 重构阶段(Refactor Phase):优化代码结构

测试通过后,在**保持测试绿色**的前提下改进代码:

1. **消除重复**: 提取公共逻辑到辅助函数或类
2. **改善命名**: 使变量、函数名更具表达力
3. **优化结构**: 分离关注点,提高模块内聚性
4. **持续验证**: 每次改动后立即运行测试确保功能不被破坏

**重构清单**:
- 消除魔法数字(使用常量或枚举)
- 简化复杂条件判断(提取为有意义的函数)
- 减少函数参数(使用对象封装相关参数)
- 移除僵尸代码(未使用的变量、函数)

---

### TDD 工作流程

```
1. 🔴 编写测试 → 测试失败
   ↓
2. 🟢 实现功能 → 测试通过
   ↓
3. 🔵 重构代码 → 测试仍然通过
   ↓
4. 重复 1-3 直到功能完成
```

### TDD 在 FPDev 项目中的应用

#### 示例 1: BuildManager 沙箱构建

**红阶段**:
```pascal
// tests/fpdev.build.manager/test_build_manager.lpr
// 期望:构建应限制在沙箱,不写系统目录
procedure TestSandboxBuildIsolation;
begin
  LBM := TBuildManager.Create('sources/fpc/fpc-main', 2, False);
  LBM.SetSandboxRoot('sandbox_test');
  LBM.SetAllowInstall(True);
  
  Assert(LBM.BuildCompiler('main'), 'Compiler build failed');
  Assert(LBM.Install('main'), 'Install failed');
  
  // 验证:系统目录未被修改,产物仅存在于沙箱
  Assert(DirectoryExists('sandbox_test/fpc-main'), 'Sandbox missing');
  Assert(not FileExists('C:\FPC\...'), 'System dir polluted!');
end;
```

**绿阶段**: 实现 `SetSandboxRoot` 和 `SetAllowInstall`,确保 `make` 命令使用 `DESTDIR` 指向沙箱。

**重构阶段**: 提取路径构建逻辑到 `BuildSandboxPath` 函数,统一日志记录格式。

#### 示例 2: Git 适配器初始化

**红阶段**:
```pascal
// tests/test_git2_adapter.lpr
// 期望:适配器初始化应成功,并能打开仓库
if not Adapter.Initialize then Halt(1);
Repo := Adapter.OpenRepository(RepoDir);
if Repo = nil then Halt(1);
```

**绿阶段**: 实现 `TGit2Manager.Initialize` 和 `OpenRepository`,调用 libgit2 API。

**重构阶段**: 将错误处理逻辑抽取为 `CheckGitError` 辅助函数。

---

### TDD 的优势

1. **设计驱动**: 先写测试强迫你思考接口设计和用户体验
2. **快速反馈**: 立即知道代码是否按预期工作
3. **回归保护**: 防止修改破坏现有功能
4. **文档作用**: 测试即活文档,展示如何使用 API
5. **重构信心**: 有测试覆盖,可以放心优化代码

---

## 构建与测试

### 前置条件

- **Free Pascal Compiler (FPC)**: 3.2.2 或更高版本
- **Lazarus IDE**: 2.2.0 或更高版本(可选,用于打开 `.lpi` 项目)
- **Git**: 用于克隆仓库和版本控制
- **Make**: 用于构建 FPC 源码(Windows 可用 MinGW/MSYS2 的 `mingw32-make`)

### 快速开始

```powershell
# 1. 克隆仓库
git clone <repository-url> fpdev
cd fpdev

# 2. 工具链体检(推荐)
scripts\check_toolchain.bat  # Windows
bash scripts/check_toolchain.sh  # Linux/macOS

# 3. 编译主程序
lazbuild -B fpdev.lpi
# 或使用 fpc 直接编译
fpc -Fusrc -Fisrc -FEbin -FUlib src/fpdev.lpr

# 4. 运行主程序
.\bin\fpdev.exe system help  # Windows
./bin/fpdev system help      # Linux/macOS

# 5. 查看版本信息
.\bin\fpdev.exe system version  # Windows
./bin/fpdev system version      # Linux/macOS
```

### 运行测试

```bash
# 顶层 Pascal 回归基线
bash scripts/run_all_tests.sh

# 聚焦单个 Pascal 测试
bash scripts/run_single_test.sh tests/test_config_management.lpr
```

顶层 runner 会在失败时输出对应的 build/test 日志路径,便于回溯具体失败项。

### 构建命令详解

| 命令 | 说明 |
|------|------|
| `lazbuild -B fpdev.lpi` | 使用 Lazarus clean rebuild 编译主程序 |
| `fpc -Fusrc -Fisrc -FEbin -FUlib src/fpdev.lpr` | 直接使用 FPC 编译主程序 |
| `lazbuild -B tests/test_config_management.lpi` | 编译指定测试程序 |
| `bash scripts/run_all_tests.sh` | 运行顶层 Pascal 回归基线 |
| `bash scripts/run_single_test.sh tests/test_config_management.lpr` | 运行单个 Pascal 测试 |
| `scripts\run_examples.bat` | 编译并运行示例(干跑模式) |
| `scripts\run_examples_real.bat` | 运行真实构建示例(仅写沙箱) |

### lazbuild 编译规范

`lazbuild` 是 Lazarus IDE 的命令行构建工具，用于编译 `.lpi` 项目文件，无需打开 IDE。这是 FPDev 项目的**标准构建方式**。

#### 基本语法

```bash
lazbuild [选项] <项目文件.lpi>
```

#### 常用选项

| 选项 | 说明 |
|------|------|
| `-B` 或 `--build-all` | 完全重新编译（清理构建） |
| `-r` 或 `--recursive` | 递归构建依赖包 |
| `--build-mode=<模式>` | 指定构建模式（Debug、Release 等） |
| `-q` 或 `--quiet` | 减少输出信息 |
| `-v` 或 `--verbose` | 增加详细输出 |
| `--os=<目标>` | 目标操作系统（win32、linux、darwin 等） |
| `--cpu=<目标>` | 目标 CPU 架构（x86_64、i386、aarch64 等） |
| `--widgetset=<组件集>` | 目标窗口组件集（win32、gtk2、qt5、cocoa 等） |
| `--build-mode-list` | 列出项目中定义的所有构建模式 |

#### 标准构建流程

```powershell
# 1. 检查可用的构建模式
lazbuild --build-mode-list fpdev.lpi

# 2. 简单编译（增量构建）
lazbuild fpdev.lpi

# 3. 完全重新编译（推荐用于测试重大更改）
lazbuild -B fpdev.lpi

# 4. 编译并构建依赖包
lazbuild -B -r fpdev.lpi

# 5. 指定构建模式（Release 模式，启用优化）
lazbuild -B --build-mode=Release fpdev.lpi

# 6. 安静模式（减少输出）
lazbuild -B -q fpdev.lpi

# 7. 交叉编译示例（Linux x86_64）
lazbuild --os=linux --cpu=x86_64 fpdev.lpi
```

#### FPDev 项目构建模式

项目中定义的构建模式（在 `fpdev.lpi` 中配置）：

- **Default** - 标准调试构建（默认）
- **Debug** - 完整调试符号，禁用优化
- **Release** - 启用优化，去除调试信息
- **Test** - 用于运行单元测试

#### 最佳实践

1. **重大更改时使用 `-B`**: 确保所有文件完全重新编译
2. **依赖更改时使用 `-r`**: 递归构建所有依赖包
3. **自动化脚本中明确指定构建模式**: 避免依赖默认值
4. **CI/CD 流程中检查退出码**: `lazbuild` 成功返回 `0`，失败返回非零值
5. **使用绝对路径**: 在脚本中使用绝对路径避免路径问题

#### 退出码

- `0` - 编译成功
- `1` - 编译错误（语法错误、链接失败等）
- `2` - 无效参数

#### 常见问题排查

**问题：包未找到**
```
错误: Package 'xxx' not found
解决: 使用 -r 标志递归构建依赖包
      lazbuild -B -r fpdev.lpi
```

**问题：单元文件未找到**
```
错误: Fatal: Can't find unit xxx
解决: 检查项目选项中的单元搜索路径，确保所有依赖已编译
```

**问题：编译期间访问冲突**
```
错误: Runtime error 216 (Access Violation)
解决: 使用 -B 清理构建，检查是否存在循环单元引用
      lazbuild -B fpdev.lpi
```

#### PowerShell 辅助函数

```powershell
# 定义构建辅助函数
function Build-FPDev {
    param(
        [switch]$Clean,
        [string]$Mode = "Default",
        [switch]$Recursive,
        [switch]$Quiet
    )
    
    $args = @()
    if ($Clean) { $args += "-B" }
    if ($Recursive) { $args += "-r" }
    if ($Quiet) { $args += "-q" }
    $args += "--build-mode=$Mode"
    $args += "fpdev.lpi"
    
    Write-Host "Building with: lazbuild $($args -join ' ')" -ForegroundColor Cyan
    lazbuild @args
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    } else {
        Write-Host "Build succeeded" -ForegroundColor Green
    }
}

# 使用示例
Build-FPDev -Clean -Mode Release -Recursive
```

#### 持续集成示例

```yaml
# GitHub Actions / GitLab CI 示例
steps:
  - name: Build FPDev (Release)
    run: |
      lazbuild -B -q --build-mode=Release fpdev.lpi
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    shell: pwsh

  - name: Build Tests
    run: |
      lazbuild -B --build-mode=Test tests/test_git2_adapter.lpi
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    shell: pwsh

  - name: Run Tests
    run: |
      .\bin\test_git2_adapter.exe
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    shell: pwsh
```

#### FPDev 项目快速命令

```powershell
# 构建主程序（标准）
lazbuild -B fpdev.lpi

# 构建主程序（Release，用于发布）
lazbuild -B --build-mode=Release fpdev.lpi

# 构建测试（Git 适配器测试）
lazbuild -B tests\test_git2_adapter.lpi

# 构建测试（构建管理器测试）
lazbuild -B tests\fpdev.build.manager\test_build_manager.lpi

# 构建所有测试（批处理）
foreach ($test in Get-ChildItem -Path tests -Filter *.lpi -Recurse) {
    Write-Host "Building $($test.FullName)"
    lazbuild -B $test.FullName
}
```

---

## 项目架构

### 分层设计

```
┌─────────────────────────────────────────────────────────────┐
│                    命令行界面层 (CLI)                        │
│  - 参数解析                                                  │
│  - 用户交互                                                  │
├─────────────────────────────────────────────────────────────┤
│                    命令处理层 (Command Layer)                │
│  ┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐ │
│  │  help   │ version │   fpc   │ lazarus │ package │  cross  │ │
│  └─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    核心服务层 (Service Layer)                │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│  │ 配置管理     │ 版本管理     │ 构建系统     │ Git 操作     │   │
│  │ (Config)    │ (Version)   │ (Build)     │ (Git2)      │   │
│  └─────────────┴─────────────┴─────────────┴─────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    基础设施层 (Infrastructure)               │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│  │ 文件系统     │ 进程管理     │ 网络操作     │ 系统信息     │   │
│  │ (FileSystem)│ (Process)   │ (Network)   │ (SysInfo)   │   │
│  └─────────────┴─────────────┴─────────────┴─────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 命令模式实现

FPDev 使用 **命令模式** 组织所有功能,核心接口 `ICommand` 提供统一的命令接口:

```pascal
ICommand = interface
  function Execute(Context: ICommandContext): Integer;
end;
```

**命令层次结构**:

```
fpdev (根命令)
├── fpc        (FPC 管理)
├── lazarus    (Lazarus 管理)
├── cross      (交叉编译)
├── package    (包管理)
├── project    (项目管理)
└── system     (系统维护与帮助)
    ├── help
    ├── version
    ├── doctor
    ├── env
    ├── config
    ├── cache
    ├── index
    ├── repo
    ├── toolchain
    └── perf
```

具体子命令以 `fpdev <namespace> help` 和 `fpdev system help` 的实时输出为准,避免维护静态大表产生漂移。

### 命令注册流程

1. `src/fpdev.command.imports*.pas` 聚合命令单元,触发命令注册
2. 每个模块的 `initialization` 部分调用 `GlobalCommandRegistry.RegisterPath(...)` 或 `RegisterSingletonPath(...)`
3. `src/fpdev.cli.bootstrap.pas` 负责加载 imports 并通过注册表分发命令
4. 工厂函数创建命令实例并调用 `Execute(..., IContext)`

**示例命令结构**:
```pascal
// fpdev.cmd.fpc.list.pas
type
  TFPCListCommand = class(TInterfacedObject, ICommand)
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','list'], @FPCListFactory, []);
end.
```

---

## 核心实现细节

### 1. Git 集成(三层适配器架构)

FPDev 使用 **libgit2** 进行 Git 操作,采用三层适配器模式隔离外部依赖:

#### 架构层次

```
应用层 (TFPCSourceManager)
    ↓ 调用高级接口
适配器层 (TGit2Manager / IGitManager) ← fpdev.git2.pas / git2.api.pas
    ↓ 封装 Git 操作
绑定层 (libgit2.pas) ← 3rd/libgit2
    ↓ FFI 调用
原生库 (git2.dll / libgit2.so / libgit2.dylib)
```

#### 关键组件

**高级面向对象接口** (`fpdev.git2.pas`):
- `TGitManager`: 单例管理器,通过 `GitManager` 访问
- `TGitRepository`: 仓库操作
- `TGitCommit`: 提交对象
- 抛出 `EGitError` 异常

**现代接口风格** (`git2.api.pas` + `git2.impl.pas`):
- `NewGitManager()`: 获取 `IGitManager` 接口
- 更易于测试和替换后端
- 推荐用于新代码

**C API 绑定** (`libgit2.pas`):
- 直接 libgit2 调用
- 仅在需要底层控制时使用
- 必须调用 `git_libgit2_init()` 和 `git_libgit2_shutdown()`

**运行时要求**: Windows 上 `git2.dll` 必须在 PATH 或可执行文件目录中

#### 为什么选择三层架构?

1. **隔离变更**: libgit2 API 变更不影响应用层
2. **可测试性**: 可 Mock `TGit2Manager` 或 `IGitManager` 进行单元测试
3. **跨平台**: 统一接口屏蔽平台差异(DLL 路径、调用约定)

---

### 2. 构建管理器(BuildManager)

**TBuildManager** (`src/fpdev.build.manager.pas`) 负责 FPC 源码的构建、安装和验证,核心设计原则:

#### 安全默认

- **无 make 时优雅降级**: 检测不到 `make` 时打印提示并返回成功,不阻塞流程
- **沙箱隔离**: 所有构建产物写入 `sandbox/<version>` 目录,不污染系统目录
- **不触发网络**: 不下载外部依赖
- **不修改全局配置**: 不写 `/etc/fpc.cfg` 或系统注册表

#### 核心接口

```pascal
TBuildManager = class
  // 构造函数
  constructor Create(ASourceRoot: string; AParallelJobs: Integer; AVerbose: Boolean);
  
  // 沙箱配置
  procedure SetSandboxRoot(const APath: string);
  procedure SetAllowInstall(AEnable: Boolean);
  
  // 构建流程
  function BuildCompiler(const AVersion: string): Boolean;
  function BuildRTL(const AVersion: string): Boolean;
  function Install(const AVersion: string): Boolean;
  function Configure(const AVersion: string): Boolean;
  
  // 验证与诊断
  function TestResults(const AVersion: string): Boolean;
  function Preflight(): Boolean;  // 预检环境
  
  // 日志控制
  procedure SetLogVerbosity(ALevel: Integer);  // 0=简洁, 1=详细
  property LogFileName: string read FLogFile;
end;
```

#### 工作流程

```
1. Preflight() → 检查 make/源码路径/沙箱可写性
2. BuildCompiler() → 编译编译器 (make compiler)
3. BuildRTL() → 编译运行时库 (make rtl)
4. Install() → 安装到沙箱 (make install DESTDIR=sandbox)
5. Configure() → 占位(不写系统配置)
6. TestResults() → 验证产物完整性
```

#### 严格模式(Strict Mode)

启用严格校验后(`SetStrictResults(True)`),`TestResults()` 会检查:

- `bin/` 目录是否包含编译器可执行文件(`fpc.exe`, `ppcx64.exe` 等)
- `lib/` 目录是否包含子目录(如 `fpc/<version>`)
- 可通过 `build-manager.strict.ini` 自定义清单

**配置示例** (`plays/fpdev.build.manager.demo/build-manager.strict.ini`):

```ini
[bin]
required_prefix=fpc,ppc
required_ext=.exe,.sh,
min_count=1

[lib]
require_subdir=true
min_count=1

[fpc]
require_cfg=true
cfg_relative_list=etc/fpc.cfg,lib/fpc/fpc.cfg
```

#### 日志系统

每次构建生成独立日志文件 `logs/build_yyyymmdd_hhnnss_zzz.log`,包含:

- **Start/End 标记**: 每个阶段的开始和结束时间
- **环境快照**: OS、PATH 前 N 项(详细模式)
- **命令行**: 完整的 `make` 命令及参数
- **产物样本**: `bin/`、`lib/` 目录的前 N 个文件
- **Summary**: 汇总信息(版本、阶段、结果、耗时)

---

### 3. 配置管理器(ConfigManager)

**TConfigManager** (`fpdev.config.pas`) 管理应用程序配置,支持:

- **工具链管理**: 添加、删除、切换 FPC/Lazarus 版本
- **交叉编译目标**: 管理 `target-cpu` 和 `target-os` 组合
- **持久化**: JSON 格式存储到当前活动数据根的 `config.json`
  - portable release 默认：`data/config.json`
  - 显式覆盖：`$FPDEV_DATA_ROOT/config.json`
  - Linux/macOS 非 portable：`$XDG_DATA_HOME/fpdev/config.json`，未设置时回退到 `~/.fpdev/config.json`
  - Windows 非 portable：`%APPDATA%\\fpdev\\config.json`

**配置文件结构**:

```json
{
  "version": "1.0",
  "toolchains": {
    "fpc-3.2.2": {
      "path": "C:\\FPC\\3.2.2\\bin\\i386-win32",
      "version": "3.2.2",
      "default": true
    }
  },
  "lazarus_installs": {
    "lazarus-2.2.0": {
      "path": "C:\\lazarus",
      "version": "2.2.0"
    }
  },
  "cross_targets": [
    {"cpu": "x86_64", "os": "linux"},
    {"cpu": "aarch64", "os": "darwin"}
  ],
  "settings": {
    "default_toolchain": "fpc-3.2.2",
    "parallel_jobs": 4
  }
}
```

---

## 配置与源码管理

### 源码目录结构

```
sources/
└── fpc/
    ├── fpc-main/          # 主分支源码
    ├── fpc-3.2.2/         # 稳定版本
    └── fpc-fixes/         # 修复分支
```

### 沙箱目录结构

```
sandbox/
└── fpc-<version>/
    ├── bin/               # 编译器可执行文件
    ├── lib/               # 运行时库和单元文件
    ├── etc/               # 配置文件
    ├── share/             # 文档和示例
    └── include/           # 头文件
```

### 日志目录

```
logs/
├── build_*.log           # 构建日志
├── check/                # 工具链检查日志
│   └── toolchain_*.txt
└── examples/             # 示例程序日志
    └── real/             # 真实构建日志
```

---

## 重点提醒(Common Gotchas)

### 1. 路径分隔符

- ✅ 使用 `PathDelim` 常量(跨平台)
- ❌ 硬编码 `\` 或 `/`

```pascal
// 正确
Result := Base + PathDelim + 'bin' + PathDelim + 'fpdev';

// 错误
Result := Base + '\bin\fpdev';  // Windows only!
```

### 2. libgit2 初始化

- ✅ 调用 `git_libgit2_init()` 后必须调用 `git_libgit2_shutdown()`
- ❌ 忘记释放资源会导致内存泄漏

```pascal
// 正确
Adapter := TGit2Manager.Create;
try
  if not Adapter.Initialize then Exit;
  // ... 使用 ...
finally
  Adapter.Free;  // 内部调用 shutdown
end;
```

### 3. BuildManager 安装权限

- ✅ 默认 `AllowInstall = False`,必须显式启用
- ❌ 未启用安装时调用 `Install()` 会返回 `False`

```pascal
// 正确
LBM := TBuildManager.Create('sources/fpc/fpc-main', 2, False);
LBM.SetSandboxRoot('sandbox');
LBM.SetAllowInstall(True);  // 必须显式启用
LBM.Install('main');
```

### 4. 命令注册

- ✅ 在命令单元 `initialization` 中注册命令路径
- ✅ 通过 `src/fpdev.command.imports.<domain>.pas` 聚合命令单元
- ❌ 不要再依赖在 `src/fpdev.lpr` 中手工导入命令模块

```pascal
// src/fpdev.command.imports.fpc.pas
uses
  fpdev.cmd.fpc.root,
  fpdev.cmd.fpc.install,
  fpdev.cmd.fpc.list,
  // ...其他命令模块
```

### 5. 日志文件时间戳

- ⚠️ Windows 日志时间戳可能包含空格(小时 < 10)
- 建议:使用零填充格式(如 `FormatDateTime('yyyymmdd_hhnnss', Now)`)

### 6. Make 命令可用性

- ✅ 构建前先运行 `Preflight()` 检查环境
- ❌ 假设 `make` 总是存在会导致运行时错误

### 7. 终端输出编码 (Windows 重要！)

- ❗ **绝对不要在终端输出中文！**
- ⚠️ Windows 终端输出中文会导致 "Disk Full" 错误
- ✅ 所有用户可见的输出必须使用英文
- ✅ 日志文件和配置文件可以使用 UTF-8 编码

```pascal
// 错误 - 会在 Windows 上导致 Disk Full
WriteLn('用法: fpdev system help');
WriteLn('错误: 未知命令');

// 正确 - 使用英文
WriteLn('Usage: fpdev system help');
WriteLn('Error: Unknown command');
```

**原因**: Windows 控制台的编码问题会导致 Pascal 的 WriteLn 在输出中文时触发 I/O 错误，表现为 "Disk Full" 异常。这是 **已知问题**，必须使用英文输出。

---

## 文件命名规范

### 单元文件(Unit Files)

- **格式**: `fpdev.<module>.pas`
- **示例**:
  - `fpdev.config.pas` - 配置管理
  - `fpdev.git2.pas` - Git 适配器
  - `fpdev.build.manager.pas` - 构建管理器
  - `fpdev.terminal.pas` - 终端输出
  - `fpdev.cmd.fpc.pas` - FPC 根命令
  - `fpdev.cmd.fpc.install.pas` - FPC 安装子命令

### 测试文件

- **格式**: `test_<module>.lpr`
- **示例**:
  - `test_git2_adapter.lpr`
  - `test_build_manager.lpr`
  - `test_build_manager_strict_pass.lpr`

### 项目文件

- **主程序**: `src/fpdev.lpr` (主项目源码) + `fpdev.lpi` (Lazarus 项目配置)
- **测试**: `tests/<test_name>/<test_name>.lpr` + `<test_name>.lpi`
- **示例**: `plays/<example_name>/<example_name>.lpr` + `<example_name>.lpi`

---

## 测试策略

### 测试分类

| 类型 | 位置 | 运行方式 | 目标覆盖率 |
|------|------|----------|------------|
| **单元测试** | `tests/` | `lazbuild <test>.lpi` | > 80% |
| **顶层回归** | `tests/` | `bash scripts/run_all_tests.sh` | 基线回归 |
| **单项回归** | `tests/` | `bash scripts/run_single_test.sh tests/test_config_management.lpr` | 聚焦验证 |
| **示例演示** | `plays/` | `run_examples.bat` | N/A |

### 测试原则

1. **隔离性**: 每个测试独立运行,不依赖其他测试
2. **可重复性**: 测试结果稳定,不受环境影响
3. **快速反馈**: 单元测试应在秒级完成
4. **清理资源**: 测试结束后清理临时文件和目录

### 测试命名约定

- **成功场景**: `test_<module>_<action>_success`
- **失败场景**: `test_<module>_<action>_fail`
- **边界条件**: `test_<module>_<action>_edge_case`

### 运行所有测试

```bash
# 顶层 Pascal 回归基线
bash scripts/run_all_tests.sh

# 聚焦单个 Pascal 测试
bash scripts/run_single_test.sh tests/test_config_management.lpr
```

---

## 外部依赖

### 核心依赖

| 依赖 | 版本 | 用途 | 许可证 |
|------|------|------|--------|
| **Free Pascal** | ≥ 3.2.2 | 编译器和运行时 | LGPL + 修改版 |
| **Lazarus** | ≥ 2.2.0 | IDE 和构建工具(可选) | GPL + LGPL |
| **libgit2** | ≥ 1.5.0 | Git 操作 | GPL v2 + GCC RE |
| **fpJSON** | 内置 | JSON 解析 | FPC RTL |

### 第三方库(包含在 `3rd/` 目录)

- **libgit2 绑定**: `3rd/libgit2/libgit2.pas`
- **静态链接库**: `3rd/libgit2/lib/`(Windows: `git2.dll`, Linux: `libgit2.so`, macOS: `libgit2.dylib`)

### 依赖安装

#### Windows

```powershell
# 安装 FPC + Lazarus
choco install fpc lazarus

# 或下载官方安装包
# https://www.lazarus-ide.org/index.php?page=downloads

# libgit2 已包含在 3rd/ 目录,无需额外安装
```

#### Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y fpc lazarus libgit2-dev
```

#### macOS

```bash
brew install fpc lazarus libgit2
```

---

## 常用命令参考

### 编译与构建

```powershell
# 编译主程序
lazbuild -B fpdev.lpi

# 编译并输出详细信息
lazbuild -B fpdev.lpi

# 直接使用 FPC 编译
fpc -Fusrc -Fisrc -FEbin -FUlib src/fpdev.lpr

# 清理构建产物
del /Q bin\*.exe bin\*.o bin\*.ppu  # Windows
rm -f bin/*.exe bin/*.o bin/*.ppu   # Linux/macOS
```

### 测试

```bash
# 顶层 Pascal 回归基线
bash scripts/run_all_tests.sh

# 聚焦单个 Pascal 测试
bash scripts/run_single_test.sh tests/test_config_management.lpr

# 若需要手动编译并执行单个测试
lazbuild -B tests/test_config_management.lpi
./bin/test_config_management

# 查看最新测试日志
tail -f logs/build_*.log | grep -E "FAIL|ERROR"  # 查看失败日志
```

### 示例演示

```powershell
# 干跑模式(不执行 make)
scripts\run_examples.bat  # Windows
bash scripts/run_examples.sh  # Linux/macOS

# 真实构建(仅写沙箱)
scripts\run_examples_real.bat  # Windows
bash scripts/run_examples_real.sh  # Linux/macOS

# 严格模式 + 详细日志
cd plays\fpdev.build.manager.demo
buildOrTest.bat strict  # Windows
STRICT=1 VERBOSE=1 bash buildOrTest.sh  # Linux/macOS
```

### 系统与仓库命令

```powershell
# 查看根帮助
.\bin\fpdev.exe system help

# 查看版本信息
.\bin\fpdev.exe system version

# 查看仓库管理帮助
.\bin\fpdev.exe system repo help
```

---

## 仓库目录结构

```
fpdev/
├── bin/                      # 编译产物(可执行文件、.o、.ppu)
├── lib/                      # 中间构建产物
├── src/                      # 源代码
│   ├── fpdev.lpr            # 主程序入口
│   ├── fpdev.config.pas     # 配置管理
│   ├── fpdev.git2.pas       # Git 适配器(高级 OO)
│   ├── git2.api.pas         # Git 接口(现代风格)
│   ├── git2.impl.pas        # Git 实现
│   ├── fpdev.build.manager.pas  # 构建管理器
│   ├── fpdev.terminal.pas   # 终端输出
│   ├── fpdev.utils.pas      # 工具函数
│   ├── fpdev.cmd.*.pas      # 根命令模块
│   ├── fpdev.cmd.*.<action>.pas  # 子命令模块
│   └── commands/            # 命令实现(按领域组织)
├── tests/                    # 测试程序
│   ├── test_git2_adapter.lpr
│   └── fpdev.build.manager/
│       ├── test_build_manager.lpr
│       ├── test_build_manager_strict_pass.lpr
│       ├── test_build_manager_strict_fail.lpr
│       └── run_tests.sh
├── plays/                    # 示例和演示
│   └── fpdev.build.manager.demo/
│       ├── demo.lpr
│       ├── buildOrTest.bat
│       └── build-manager.strict.ini
├── scripts/                  # 辅助脚本
│   ├── check_toolchain.bat
│   ├── run_examples.bat
│   └── run_examples_real.bat
├── docs/                     # 文档
│   ├── README.md
│   ├── fpdev.md             # 详细设计文档
│   ├── ARCHITECTURE.md      # 架构设计
│   └── build-manager.md     # BuildManager 文档
├── 3rd/                      # 第三方库
│   └── libgit2/
│       ├── libgit2.pas      # Pascal 绑定
│       └── lib/             # 原生库(.dll/.so/.dylib)
├── sources/                  # FPC/Lazarus 源码(构建时使用)
│   └── fpc/
│       ├── fpc-main/
│       └── fpc-3.2.2/
├── sandbox/                  # 沙箱构建产物
│   └── fpc-<version>/
│       ├── bin/
│       ├── lib/
│       └── etc/
├── logs/                     # 日志文件
│   ├── build_*.log
│   ├── check/
│   └── examples/
├── fpdev.lpi                 # Lazarus 项目文件
└── WARP.md                   # 本文档
```

---

## 附录:TDD 最佳实践清单

### ✅ 应该做的

- [ ] 每个新功能先写测试
- [ ] 测试应该简洁、清晰、易读
- [ ] 频繁运行测试(每次代码改动后)
- [ ] 保持测试独立(不依赖执行顺序)
- [ ] 测试失败时立即修复(不积累技术债)
- [ ] 重构时保持测试绿色
- [ ] 为边界条件和异常路径编写测试

### ❌ 不应该做的

- [ ] 跳过红阶段直接实现功能
- [ ] 在绿阶段过度设计
- [ ] 在测试失败时继续添加新功能
- [ ] 编写依赖外部服务的测试(应使用 Mock)
- [ ] 测试私有实现细节(应测试公开接口)
- [ ] 忽略失败的测试
- [ ] 注释掉失败的测试(应修复或删除)

---

## 参考资源

- **Free Pascal 官方文档**: https://www.freepascal.org/docs.html
- **Lazarus Wiki**: https://wiki.freepascal.org/
- **libgit2 文档**: https://libgit2.org/docs/
- **测试驱动开发(TDD)**: Kent Beck - "Test-Driven Development: By Example"
- **命令模式**: Gang of Four - "Design Patterns"

---

**最后更新**: 2026-04-02  
**维护者**: FPDev Team  
**许可证**: 见 LICENSE 文件
