# libgit2 Pascal集成文档

## 📋 概述

本文档描述了 FPDev 项目中 libgit2 的集成现状，包括原生 C API 绑定、现代接口封装、当前测试路径和运行时库布局约定。

当前工作树里的 system-git facade 不在这份文档里展开；它的默认入口是 `fpdev.git.operations`，具体实现位于 `src/fpdev.git.operations.impl.pas`，而 `src/fpdev.utils.git.pas` 已删除，现在只作为 removed compatibility shim 的迁移说明出现。

## 🏗️ 架构设计

### 分层架构

```
┌─────────────────────────────────────┐
│        应用层 (FPDev)               │
├─────────────────────────────────────┤
│ 首选现代接口层                      │
│ (git2.api.pas + git2.impl.pas)      │
├─────────────────────────────────────┤
│ 便利 concrete wrapper (git2.modern) │
├─────────────────────────────────────┤
│ legacy 兼容包装 (fpdev.git2.pas)    │
├─────────────────────────────────────┤
│     C API绑定层 (libgit2.pas)       │
├─────────────────────────────────────┤
│      libgit2 共享库                  │
│   (git2.dll / libgit2.so /          │
│    libgit2.1.dylib)                 │
└─────────────────────────────────────┘
```

### 核心组件

1. **libgit2.pas** - 完整的C API绑定
2. **git2.api.pas + git2.impl.pas** - 首选现代接口（`IGitManager` / `IGitRepository` + `NewGitManager()`）
3. **git2.modern.pas** - 基于现代接口的便利包装
4. **fpdev.git2.pas** - legacy 兼容包装
5. **运行时/构建布局约定** - 说明当前工作树期望的 libgit2 产物位置
6. **测试套件** - 功能验证和历史手动样例

## 📁 文件结构

```
fpdev/
├── src/
│   ├── libgit2.pas           # C API绑定
│   ├── git2.api.pas          # 首选现代接口定义
│   ├── git2.impl.pas         # 首选现代接口实现
│   ├── git2.modern.pas       # 基于现代接口的便利包装
│   ├── fpdev.git2.pas        # legacy 兼容包装
│   └── fpdev.fpc.source.pas  # FPC源码管理
├── 3rd/
│   └── libgit2/              # libgit2源码和构建
│       ├── build/            # 构建目录
│       └── install/          # 安装目录
├── tests/
│   ├── fpdev.libgit2.base/
│   │   └── test_libgit2_complete.lpr   # libgit2 基础/完整功能测试
│   ├── fpdev.git2.adapter/
│   │   └── test_git_real.lpr           # 实际 Git 操作测试
│   └── migrated/root-lpr/
│       └── test_fpc_source.lpr         # FPC源码管理历史遗留手动样例
└── docs/
    └── LIBGIT2_INTEGRATION.md      # 本文档
```

当前工作树未跟踪专用的 libgit2 构建辅助脚本；请使用平台标准的 CMake / 包管理流程，而不要依赖历史 helper script 名称。

## 🔧 API绑定详情

### libgit2.pas - C API绑定

**功能覆盖**:

- ✅ 基本库管理 (初始化/关闭)
- ✅ 仓库操作 (打开/创建/克隆)
- ✅ 引用管理 (分支/标签/HEAD)
- ✅ 提交操作 (查看/创建/遍历)
- ✅ 远程操作 (fetch/push/配置)
- ✅ 对象管理 (OID/blob/tree)
- ✅ 状态查询 (工作区/索引状态)
- ✅ 配置管理 (全局/本地配置)
- ✅ 错误处理 (异常/错误码)

**类型定义**:

```pascal
// 基本类型
git_repository = Pointer;
git_commit = Pointer;
git_reference = Pointer;
git_remote = Pointer;

// OID结构
git_oid = record
  id: array[0..19] of Byte;
end;

// 时间结构
git_time = record
  time: git_time_t;
  offset: cint;
  sign: cchar;
end;
```

**核心函数**:

```pascal
// 库管理
function git_libgit2_init: cint;
function git_libgit2_shutdown: cint;

// 仓库操作
function git_repository_open(out repo: git_repository; const path: PChar): cint;
function git_clone(out repo: git_repository; const url, path: PChar; opts: Pointer): cint;

// 引用操作
function git_reference_lookup(out ref: git_reference; repo: git_repository; const name: PChar): cint;
function git_repository_head(out ref: git_reference; repo: git_repository): cint;
```

### git2.api.pas + git2.impl.pas - 首选现代接口

**设计原则**:

- 面向对象设计
- 自动资源管理
- 异常安全
- 类型安全

**核心类**:

#### IGitManager - Git管理器接口

```pascal
IGitManager = interface
  function Initialize: Boolean;
  function OpenRepository(const APath: string): IGitRepository;
  function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
  function IsRepository(const APath: string): Boolean;
end;
```

#### IGitRepository - 仓库接口

```pascal
IGitRepository = interface
  function CurrentBranch: string;
  function ListBranches: TStringArray;
  function HeadCommit: IGitCommit;
  function Remote(const AName: string = 'origin'): IGitRemote;
  function Fetch: Boolean;
end;
```

#### 便利包装与 legacy 包装

```pascal
git2.modern.pas   // TGitManagerWrapper / TGitRepository（基于 IGitManager）
fpdev.git2.pas    // TGitManager / TGitRepository / TGit2Manager（legacy 兼容）
```

## 🔨 构建与运行时布局

如需在本地构建 libgit2，请使用你当前平台的标准 CMake/包管理工作流，并把产物整理到仓库当前约定的布局中。当前工作树未跟踪专用的 libgit2 构建辅助脚本。

### Windows 产物布局

**依赖**:

- CMake 3.16+
- MinGW-w64 GCC
- Git

**期望产物**:

```bash
3rd\libgit2\install\bin\git2.dll         # 动态库（与 src/libgit2.pas 的 Windows 名称一致）
3rd\libgit2\install\lib\git2.lib         # 导入库
3rd\libgit2\install\include\git2.h       # 头文件
```

### Linux 产物布局

**依赖**:

```bash
# Ubuntu/Debian
sudo apt install cmake build-essential libssl-dev zlib1g-dev

# CentOS/RHEL
sudo yum install cmake gcc gcc-c++ openssl-devel zlib-devel
```

**期望产物**:

```bash
3rd/libgit2/install/lib/libgit2.so       # 动态库
3rd/libgit2/install/lib/libgit2.a        # 静态库
3rd/libgit2/install/include/git2.h       # 头文件
```

### 运行时装载约定

- Windows: `src/libgit2.pas` 期望运行时库名为 `git2.dll`
- Linux: `src/libgit2.pas` 期望运行时库名为 `libgit2.so`
- macOS: `src/libgit2.pas` 期望运行时库名为 `libgit2.1.dylib`
- 若你自行构建 libgit2，请按平台把对应文件放到可执行文件相邻目录或系统 loader 可见的位置

## 🧪 测试套件

### 测试程序

1. **tests/fpdev.libgit2.base/test_libgit2_complete.lpr** - 完整功能测试
   - libgit2初始化测试
   - 仓库操作测试
   - 提交信息测试
   - 远程操作测试
   - OID操作测试
   - 位于默认 discoverable 测试清单之外，主要用于手工/兼容性检查

2. **tests/fpdev.git2.adapter/test_git_real.lpr** - 实际Git操作测试
   - Git环境检查
   - 实际仓库克隆
   - 网络连接测试
   - 位于默认 discoverable 测试清单之外，主要用于手工/兼容性检查

3. **tests/migrated/root-lpr/test_fpc_source.lpr** - FPC源码管理历史遗留手动样例
   - FPC版本管理
   - 源码路径管理
   - 分支信息显示
   - 不属于当前自动回归测试套件，仅保留作参考
   - 位于默认 discoverable 测试清单之外

### 运行测试

```bash
# 手动验证样例（默认 discoverable 测试清单之外）
fpc -Fusrc -Fisrc -FEbin -FUlib tests/fpdev.libgit2.base/test_libgit2_complete.lpr
fpc -Fusrc -Fisrc -FEbin -FUlib tests/fpdev.git2.adapter/test_git_real.lpr
fpc -Fusrc -Fisrc -FEbin -FUlib tests/migrated/root-lpr/test_fpc_source.lpr
```

## 📊 性能特性

### 内存管理

- 自动资源释放
- RAII模式实现
- 异常安全保证

### 网络优化

- 支持浅克隆 (--depth 1)
- 进度回调支持
- 中断和恢复机制

### 跨平台支持

- Windows (MinGW/MSVC)
- Linux (GCC/Clang)
- macOS (Clang)

## 🔍 使用示例

### 基本仓库操作

```pascal
var
  Manager: IGitManager;
  Repo: IGitRepository;
  Commit: IGitCommit;
begin
  Manager := NewGitManager();
  if not Manager.Initialize then
    Halt(1);

  // 克隆仓库
  Repo := Manager.CloneRepository(
    'https://github.com/user/repo.git',
    'local-repo'
  );

  // 获取当前分支
  WriteLn('Current branch: ', Repo.CurrentBranch);

  // 获取最新提交
  Commit := Repo.HeadCommit;
  WriteLn('Last commit: ', Commit.OIDString);
  WriteLn('Message: ', Commit.Message);
  WriteLn('Author: ', Commit.AuthorString);
end;
```

### FPC源码管理

```pascal
var
  FPCManager: TFPCSourceManager;
begin
  FPCManager := TFPCSourceManager.Create;
  try
    // 克隆FPC 3.2.2源码
    if FPCManager.CloneFPCSource('3.2.2') then
    begin
      WriteLn('FPC source cloned to: ', FPCManager.GetFPCSourcePath('3.2.2'));

      // 列出本地版本
      var Versions := FPCManager.ListLocalVersions;
      for var Version in Versions do
        WriteLn('Local version: ', Version);
    end;
  finally
    FPCManager.Free;
  end;
end;
```

## 🚀 集成示例

### 现代接口集成示例

```pascal
uses
  git2.api, git2.impl, fpdev.fpc.source;

var
  GitManager: IGitManager;
  FPCManager: TFPCSourceManager;

begin
  GitManager := NewGitManager();
  FPCManager := TFPCSourceManager.Create;
  try
    GitManager.Initialize;

    // 处理命令行参数
    case ParamStr(1) of
      'fpc':
        HandleFPCCommand(FPCManager, ParamStr(2));
      'clone':
        HandleCloneCommand(GitManager, ParamStr(2), ParamStr(3));
    end;

  finally
    FPCManager.Free;
  end;
end;
```

## 📈 未来扩展

### 计划功能

- [ ] 分支管理 (创建/切换/合并)
- [ ] 提交创建和推送
- [ ] 冲突解决
- [ ] 子模块支持
- [ ] LFS支持
- [ ] SSH密钥管理

### 性能优化

- [ ] 多线程下载
- [ ] 增量更新
- [ ] 本地缓存
- [ ] 压缩传输

## 🔧 故障排除

### 常见问题

1. **libgit2 共享库装载失败**
   - `src/libgit2.pas` 在不同平台期望的运行时库名不同：
     - Windows: `git2.dll`
     - Linux: `libgit2.so`
     - macOS: `libgit2.1.dylib`
   - 确保对应平台的共享库位于可执行文件相邻目录，或位于系统 loader 可见的位置
   - 检查架构匹配 (32位/64位)

2. **编译错误**
   - 检查FreePascal版本 (3.2.0+)
   - 确保所有依赖单元可用

3. **网络连接问题**
   - 检查防火墙设置
   - 配置代理 (如需要)
   - 验证SSL证书

### 调试技巧

```pascal
// 启用详细错误信息
try
  // Git操作
except
  on E: EGitError do
  begin
    WriteLn('Git Error: ', E.Message);
    WriteLn('Error Code: ', E.ErrorCode);
  end;
end;
```

## 📄 许可证

本集成遵循以下许可证:

- **FPDev**: MIT License
- **libgit2**: GPL v2 with Linking Exception
- **FreePascal**: Modified LGPL

---

**文档版本**: 1.0.0  
**最后更新**: 2026-04-06  
**作者**: FPDev Team
