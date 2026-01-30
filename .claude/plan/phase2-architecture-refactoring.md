# Phase 2: 架构重构详细计划

**创建时间**: 2026-01-31  
**状态**: 已批准，准备实施  
**预计工期**: 8 天（可压缩至 6 天通过并行）  
**风险等级**: 低（3/10）

---

## 📋 执行摘要

### 目标
消除 FPDev 代码库中的技术债：
1. TBuildManager 紧耦合 → 接口化 + 依赖注入
2. Git 管理器重复 → 统一为单一实现
3. 全局单例滥用 → 构造函数注入

### 策略
**渐进式重构**（4 个独立波次）：
- 每个波次独立提交、独立验证
- 保留向后兼容层 30 天（标记 @deprecated）
- 零回归要求（所有现有测试必须通过）

### 成功案例参考
**fpdev.config 接口化重构**（已完成）：
- 6 个接口 + 实现类
- 依赖注入模式
- ✅ 零回归，测试覆盖率提升

---

## 🎯 Wave 1: TBuildManager 接口化（3 天）

### 问题分析
- **影响范围**: 54 处引用
- **紧耦合**: 硬编码依赖 TBuildLogger、TBuildToolchainChecker
- **后果**: 无法独立测试、难以扩展

### 实施步骤

#### 步骤 1.1: 创建接口层（0.5 天）

**文件**: `src/fpdev.build.interfaces.pas`

```pascal
unit fpdev.build.interfaces;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  // 日志接口
  IBuildLogger = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure LogInfo(const AMessage: string);
    procedure LogWarning(const AMessage: string);
    procedure LogError(const AMessage: string);
    procedure LogCommand(const ACommand: string);
    function GetLogFileName: string;
  end;

  // 工具链检查接口
  IToolchainChecker = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function CheckMake: Boolean;
    function CheckCompiler(const APath: string): Boolean;
    function CheckSourcePath(const APath: string): Boolean;
    function CheckSandboxWritable(const APath: string): Boolean;
  end;

  // 构建管理器接口
  IBuildManager = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function Preflight: Boolean;
    function BuildCompiler(const AVersion: string): Boolean;
    function BuildRTL(const AVersion: string): Boolean;
    function Install(const AVersion: string): Boolean;
    function TestResults(const AVersion: string): Boolean;
    procedure SetSandboxRoot(const APath: string);
    procedure SetAllowInstall(AValue: Boolean);
    function GetLogFileName: string;
  end;

implementation

end.
```

**验收标准**:
- [ ] 编译通过，无警告
- [ ] 接口 GUID 唯一
- [ ] 方法签名与现有 TBuildManager 匹配

---

#### 步骤 1.2: 实现接口（1 天）

**文件**: `src/fpdev.build.managers.pas`

```pascal
unit fpdev.build.managers;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.build.interfaces;

type
  // 日志实现
  TBuildLoggerImpl = class(TInterfacedObject, IBuildLogger)
  private
    FLogFile: TextFile;
    FLogFileName: string;
  public
    constructor Create(const ALogFileName: string);
    destructor Destroy; override;
    procedure LogInfo(const AMessage: string);
    procedure LogWarning(const AMessage: string);
    procedure LogError(const AMessage: string);
    procedure LogCommand(const ACommand: string);
    function GetLogFileName: string;
  end;

  // 工具链检查实现
  TToolchainCheckerImpl = class(TInterfacedObject, IToolchainChecker)
  public
    function CheckMake: Boolean;
    function CheckCompiler(const APath: string): Boolean;
    function CheckSourcePath(const APath: string): Boolean;
    function CheckSandboxWritable(const APath: string): Boolean;
  end;

  // 构建管理器实现（依赖注入）
  TBuildManagerImpl = class(TInterfacedObject, IBuildManager)
  private
    FLogger: IBuildLogger;
    FChecker: IToolchainChecker;
    FSourcePath: string;
    FParallelJobs: Integer;
    FVerbose: Boolean;
    FSandboxRoot: string;
    FAllowInstall: Boolean;
  public
    constructor Create(
      const ASourcePath: string;
      AParallelJobs: Integer;
      AVerbose: Boolean;
      ALogger: IBuildLogger;
      AChecker: IToolchainChecker
    );
    function Preflight: Boolean;
    function BuildCompiler(const AVersion: string): Boolean;
    function BuildRTL(const AVersion: string): Boolean;
    function Install(const AVersion: string): Boolean;
    function TestResults(const AVersion: string): Boolean;
    procedure SetSandboxRoot(const APath: string);
    procedure SetAllowInstall(AValue: Boolean);
    function GetLogFileName: string;
  end;

implementation

// 实现细节（从现有 TBuildManager 迁移）
// ...

end.
```

**验收标准**:
- [ ] 所有接口方法实现
- [ ] 构造函数注入依赖（不使用全局变量）
- [ ] 编译通过，无警告

---

#### 步骤 1.3: 向后兼容层（0.5 天）

**文件**: `src/fpdev.build.manager.pas`（修改现有文件）

```pascal
unit fpdev.build.manager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.build.interfaces, fpdev.build.managers;

type
  // @deprecated Use TBuildManagerImpl with dependency injection instead
  // This class will be removed after 2026-03-02 (30 days)
  TBuildManager = class
  private
    FImpl: IBuildManager;
  public
    constructor Create(const ASourcePath: string; AParallelJobs: Integer; AVerbose: Boolean);
    destructor Destroy; override;
    function Preflight: Boolean;
    function BuildCompiler(const AVersion: string): Boolean;
    function BuildRTL(const AVersion: string): Boolean;
    function Install(const AVersion: string): Boolean;
    function TestResults(const AVersion: string): Boolean;
    procedure SetSandboxRoot(const APath: string);
    procedure SetAllowInstall(AValue: Boolean);
    function GetLogFileName: string;
  end;

implementation

constructor TBuildManager.Create(const ASourcePath: string; AParallelJobs: Integer; AVerbose: Boolean);
var
  Logger: IBuildLogger;
  Checker: IToolchainChecker;
begin
  inherited Create;
  {$WARN DEPRECATED ON}
  WriteLn('Warning: TBuildManager is deprecated. Use TBuildManagerImpl with dependency injection.');
  WriteLn('This class will be removed after 2026-03-02.');
  {$WARN DEPRECATED OFF}
  
  Logger := TBuildLoggerImpl.Create('logs/build_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.log');
  Checker := TToolchainCheckerImpl.Create;
  FImpl := TBuildManagerImpl.Create(ASourcePath, AParallelJobs, AVerbose, Logger, Checker);
end;

destructor TBuildManager.Destroy;
begin
  FImpl := nil;  // 接口自动释放
  inherited;
end;

function TBuildManager.Preflight: Boolean;
begin
  Result := FImpl.Preflight;
end;

// 其他方法委托给 FImpl...

end.
```

**验收标准**:
- [ ] 旧 API 仍可用
- [ ] 编译时显示 @deprecated 警告
- [ ] 内部委托给新实现

---

#### 步骤 1.4: 测试迁移（1 天）

**文件**: `tests/fpdev.build.manager/test_build_manager_interfaces.lpr`（新增）

```pascal
program test_build_manager_interfaces;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, fpcunit, testregistry,
  fpdev.build.interfaces, fpdev.build.managers;

type
  // Mock 日志实现
  TMockLogger = class(TInterfacedObject, IBuildLogger)
  private
    FMessages: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LogInfo(const AMessage: string);
    procedure LogWarning(const AMessage: string);
    procedure LogError(const AMessage: string);
    procedure LogCommand(const ACommand: string);
    function GetLogFileName: string;
    function GetMessages: TStringList;
  end;

  // Mock 工具链检查实现
  TMockChecker = class(TInterfacedObject, IToolchainChecker)
  private
    FMakeAvailable: Boolean;
  public
    constructor Create(AMakeAvailable: Boolean);
    function CheckMake: Boolean;
    function CheckCompiler(const APath: string): Boolean;
    function CheckSourcePath(const APath: string): Boolean;
    function CheckSandboxWritable(const APath: string): Boolean;
  end;

  // 测试用例
  TTestBuildManagerInterfaces = class(TTestCase)
  published
    procedure TestLoggerIsolation;
    procedure TestCheckerIsolation;
    procedure TestDependencyInjection;
    procedure TestPreflightWithMockChecker;
  end;

implementation

// 测试实现...

initialization
  RegisterTest(TTestBuildManagerInterfaces);
end.
```

**验收标准**:
- [ ] 14/14 现有测试通过（向后兼容）
- [ ] 新增 10+ 接口隔离测试
- [ ] Mock 对象验证依赖注入有效

---

### Wave 1 验收标准

- [ ] 所有现有测试通过（14/14）
- [ ] 新接口可独立 mock 测试
- [ ] 旧 API 仍可用（带 @deprecated 警告）
- [ ] 零编译错误
- [ ] 文档更新（CLAUDE.md 添加新接口使用示例）

---

## 🎯 Wave 2: 统一 Git 管理器（2 天）

### 问题分析
- **SharedGitManager**: 17 处引用（fpdev.utils.git.pas）
- **FGitManager**: 4 处引用（fpdev.git2.pas）
- **问题**: 两套实现、功能重复

### 实施步骤

#### 步骤 2.1: 选择统一实现（0.5 天）

**决策**: 采用 `git2.api.pas` + `git2.impl.pas`（已接口化）

**理由**:
- ✅ 已有接口定义（IGitManager, IGitRepository）
- ✅ 现代化设计（引用计数）
- ✅ 易于测试（接口驱动）

**废弃**: `fpdev.utils.git.pas` 的 SharedGitManager

---

#### 步骤 2.2: 迁移引用（1 天）

**影响文件**:
- `src/fpdev.fpc.source.pas` - FPC 源码管理
- `src/fpdev.cmd.repo.*.pas` - 仓库命令
- 其他 17 处 SharedGitManager 引用

**迁移模式**:
```pascal
// 旧代码
uses fpdev.utils.git;
var Repo: TGitRepository;
begin
  Repo := SharedGitManager.OpenRepository('.');
  try
    // ...
  finally
    Repo.Free;
  end;
end;

// 新代码
uses git2.api, git2.impl;
var
  Mgr: IGitManager;
  Repo: IGitRepository;
begin
  Mgr := NewGitManager();
  Mgr.Initialize;
  Repo := Mgr.OpenRepository('.');
  // 无需 Free，自动释放
end;
```

---

#### 步骤 2.3: 向后兼容（0.5 天）

**文件**: `src/fpdev.utils.git.pas`（修改）

```pascal
unit fpdev.utils.git;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, git2.api, git2.impl;

// @deprecated Use NewGitManager() from git2.impl instead
// This function will be removed after 2026-03-02
function SharedGitManager: IGitManager; deprecated 'Use NewGitManager() from git2.impl';

implementation

var
  FSharedInstance: IGitManager;

function SharedGitManager: IGitManager;
begin
  if FSharedInstance = nil then
  begin
    FSharedInstance := NewGitManager();
    FSharedInstance.Initialize;
  end;
  Result := FSharedInstance;
end;

end.
```

---

### Wave 2 验收标准

- [ ] 所有 Git 操作使用统一接口
- [ ] 现有功能零回归
- [ ] 旧 API 仍可用（带警告）
- [ ] 文档更新

---

## 🎯 Wave 3: 全局单例迁移（2 天）

### 问题分析
- **TErrorRegistry**: 3 处引用
- **GI18nManager**: 6 处引用
- **问题**: 全局状态、测试困难

### 实施步骤

#### 步骤 3.1: TErrorRegistry 接口化（1 天）

**文件**: `src/fpdev.errors.interfaces.pas`（新增）

```pascal
unit fpdev.errors.interfaces;

interface

type
  IErrorRegistry = interface
    ['{D4E5F6A7-B8C9-0123-DEFG-234567890123}']
    procedure RegisterError(const ACode: string; const AMessage: string);
    function GetErrorMessage(const ACode: string): string;
    function HasError(const ACode: string): Boolean;
  end;

implementation

end.
```

**迁移**: 3 处引用改为构造函数注入

---

#### 步骤 3.2: GI18nManager 接口化（1 天）

**文件**: `src/fpdev.i18n.interfaces.pas`（新增）

```pascal
unit fpdev.i18n.interfaces;

interface

type
  II18nManager = interface
    ['{E5F6A7B8-C9D0-1234-EFGH-345678901234}']
    function Translate(const AKey: string): string;
    procedure SetLanguage(const ALang: string);
    function GetCurrentLanguage: string;
  end;

implementation

end.
```

**迁移**: 6 处引用改为构造函数注入

---

### Wave 3 验收标准

- [ ] 所有单例可通过接口注入
- [ ] 测试可使用 mock 实现
- [ ] 旧全局访问仍可用（带警告）

---

## 🎯 Wave 4: 清理过渡代码（1 天）

**时间**: 2026-03-02（30 天后）

### 步骤

1. **移除 @deprecated 代码**（0.5 天）
   - 删除 `TBuildManager` 旧类
   - 删除 `SharedGitManager` 函数
   - 删除全局单例变量

2. **更新文档**（0.5 天）
   - 更新 CLAUDE.md 架构说明
   - 添加迁移指南到 docs/migration-guide.md
   - 更新代码示例

---

## 📊 实施时间线

```
Day 1-3:  Wave 1 (TBuildManager 接口化)
Day 4-5:  Wave 2 (统一 Git 管理器)
Day 6-7:  Wave 3 (全局单例迁移)
Day 8:    Wave 4 (清理过渡代码)

并行机会:
- Wave 2 和 Wave 3 可并行（无依赖）
- 实际可压缩到 6 天
```

---

## ⚠️ 风险管理

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 测试失败 | 中 | 高 | 每个 Wave 独立验证，失败立即回滚 |
| 循环依赖 | 低 | 中 | 接口层独立单元，避免交叉引用 |
| 性能退化 | 低 | 低 | 接口调用开销可忽略（编译器内联） |
| 迁移遗漏 | 中 | 中 | 使用 grep 全局搜索旧 API 引用 |

---

## ✅ 总体验收标准

- [ ] 所有现有测试通过（44+ 测试）
- [ ] 新增接口测试通过（20+ 测试）
- [ ] 零编译错误和警告
- [ ] 文档完整更新
- [ ] 代码审查通过

---

**批准人**: 用户  
**批准日期**: 2026-01-31  
**计划状态**: ✅ 已批准，准备实施
