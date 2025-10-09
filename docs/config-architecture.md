# FPDev 配置管理架构

## 概述

FPDev 的配置管理系统采用**模块化、接口驱动**的架构设计，通过引用计数管理生命周期，提供清晰的职责分离和易于测试的组件。

## 架构层次

```
┌─────────────────────────────────────────────────────────────┐
│                      应用层 (Application)                    │
│  使用 TFPDevConfigManager (向后兼容) 或直接使用接口          │
├─────────────────────────────────────────────────────────────┤
│                    接口层 (Interfaces)                       │
│  fpdev.config.interfaces.pas                                 │
│  ┌──────────────┬──────────────┬──────────────┬──────────┐  │
│  │ IConfigMgr   │ IToolchainMgr│ ILazarusMgr  │ ICrossMgr│  │
│  │              │ IRepoMgr     │ ISettingsMgr │          │  │
│  └──────────────┴──────────────┴──────────────┴──────────┘  │
├─────────────────────────────────────────────────────────────┤
│                   实现层 (Implementation)                    │
│  fpdev.config.managers.pas                                   │
│  ┌──────────────┬──────────────┬──────────────┬──────────┐  │
│  │ TConfigMgr   │TToolchainMgr │ TLazarusMgr  │TCrossMgr │  │
│  │              │ TRepoMgr     │ TSettingsMgr │          │  │
│  └──────────────┴──────────────┴──────────────┴──────────┘  │
├─────────────────────────────────────────────────────────────┤
│                 向后兼容层 (Compatibility)                   │
│  fpdev.config.pas                                            │
│  TFPDevConfigManager (已废弃，包装 IConfigManager)          │
└─────────────────────────────────────────────────────────────┘
```

## 核心组件

### 1. 配置管理器（TConfigManager）

**职责**: 配置管理总入口，协调所有子管理器

**接口**: `IConfigManager`

**关键方法**:
- `LoadConfig()` - 从 JSON 文件加载配置
- `SaveConfig()` - 保存配置到 JSON 文件
- `GetToolchainManager()` - 获取工具链管理器
- `GetLazarusManager()` - 获取 Lazarus 管理器
- `GetCrossTargetManager()` - 获取交叉编译目标管理器
- `GetRepositoryManager()` - 获取仓库管理器
- `GetSettingsManager()` - 获取设置管理器

### 2. 工具链管理器（TToolchainManager）

**职责**: 管理 FPC 工具链版本

**接口**: `IToolchainManager`

**关键方法**:
- `AddToolchain(name, info)` - 添加工具链
- `RemoveToolchain(name)` - 删除工具链
- `GetToolchain(name, out info)` - 获取工具链信息
- `SetDefaultToolchain(name)` - 设置默认工具链
- `GetDefaultToolchain()` - 获取默认工具链
- `ListToolchains()` - 列出所有工具链

### 3. Lazarus 管理器（TLazarusManager）

**职责**: 管理 Lazarus IDE 版本

**接口**: `ILazarusManager`

**关键方法**:
- `AddLazarusVersion(name, info)` - 添加 Lazarus 版本
- `RemoveLazarusVersion(name)` - 删除版本
- `GetLazarusVersion(name, out info)` - 获取版本信息
- `SetDefaultLazarusVersion(name)` - 设置默认版本
- `GetDefaultLazarusVersion()` - 获取默认版本
- `ListLazarusVersions()` - 列出所有版本

### 4. 交叉编译目标管理器（TCrossTargetManager）

**职责**: 管理交叉编译目标配置

**接口**: `ICrossTargetManager`

**关键方法**:
- `AddCrossTarget(target, info)` - 添加交叉编译目标
- `RemoveCrossTarget(target)` - 删除目标
- `GetCrossTarget(target, out info)` - 获取目标信息
- `ListCrossTargets()` - 列出所有目标

### 5. 仓库管理器（TRepositoryManager）

**职责**: 管理源代码仓库 URL

**接口**: `IRepositoryManager`

**关键方法**:
- `AddRepository(name, url)` - 添加仓库
- `RemoveRepository(name)` - 删除仓库
- `GetRepository(name)` - 获取仓库 URL
- `HasRepository(name)` - 检查仓库是否存在
- `GetDefaultRepository()` - 获取默认仓库
- `ListRepositories()` - 列出所有仓库

### 6. 设置管理器（TSettingsManager）

**职责**: 管理全局设置

**接口**: `ISettingsManager`

**关键方法**:
- `GetSettings()` - 获取当前设置
- `SetSettings(settings)` - 更新设置

## 生命周期管理

### 引用计数

所有管理器实现 `TInterfacedObject`，使用 Free Pascal 的自动引用计数机制：

```pascal
// 接口引用自动管理生命周期
var
  ConfigMgr: IConfigManager;
begin
  ConfigMgr := TConfigManager.Create('config.json');
  // 使用 ConfigMgr...
  // 无需手动释放，接口引用离开作用域时自动释放
end;
```

### 变更通知

子管理器通过 `IConfigChangeNotifier` 接口通知父管理器配置变更：

```pascal
type
  IConfigChangeNotifier = interface
    procedure NotifyConfigChanged;
  end;

// 子管理器调用通知
if FNotifier <> nil then
  IConfigChangeNotifier(FNotifier).NotifyConfigChanged;
```

## 使用示例

### 推荐方式：直接使用接口

```pascal
uses
  fpdev.config.interfaces,
  fpdev.config.managers;

var
  ConfigMgr: IConfigManager;
  ToolchainMgr: IToolchainManager;
  ToolchainInfo: TToolchainInfo;
begin
  // 创建配置管理器
  ConfigMgr := TConfigManager.Create('~/.fpdev/config.json');
  
  // 加载配置
  if not ConfigMgr.LoadConfig then
    ConfigMgr.CreateDefaultConfig;
  
  // 获取工具链管理器
  ToolchainMgr := ConfigMgr.GetToolchainManager;
  
  // 添加工具链
  FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
  ToolchainInfo.Version := '3.2.2';
  ToolchainInfo.InstallPath := '/usr/local/fpc/3.2.2';
  ToolchainInfo.ToolchainType := ttRelease;
  ToolchainMgr.AddToolchain('fpc-3.2.2', ToolchainInfo);
  
  // 设置默认工具链
  ToolchainMgr.SetDefaultToolchain('fpc-3.2.2');
  
  // 保存配置
  ConfigMgr.SaveConfig;
  
  // 自动清理，无需手动释放
end;
```

### 向后兼容方式（已废弃）

```pascal
uses
  fpdev.config;

var
  ConfigMgr: TFPDevConfigManager;
  ToolchainInfo: TToolchainInfo;
begin
  ConfigMgr := TFPDevConfigManager.Create('~/.fpdev/config.json');
  try
    if not ConfigMgr.LoadConfig then
      ConfigMgr.CreateDefaultConfig;
    
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := '/usr/local/fpc/3.2.2';
    ConfigMgr.AddToolchain('fpc-3.2.2', ToolchainInfo);
    
    ConfigMgr.SaveConfig;
  finally
    ConfigMgr.Free;  // 需要手动释放
  end;
end;
```

## 废弃通知

### ⚠️ TFPDevConfigManager 已废弃

`TFPDevConfigManager` 类保留用于向后兼容，但**不推荐在新代码中使用**。

**废弃原因**:
1. 需要手动管理内存（调用 `Free`）
2. 不遵循接口驱动设计原则
3. 代码耦合度高，不易测试
4. 无法充分利用接口引用计数的优势

**迁移指南**:

旧代码：
```pascal
var
  Config: TFPDevConfigManager;
begin
  Config := TFPDevConfigManager.Create;
  try
    Config.AddToolchain('fpc-3.2.2', Info);
  finally
    Config.Free;
  end;
end;
```

新代码：
```pascal
var
  Config: IConfigManager;
  ToolchainMgr: IToolchainManager;
begin
  Config := TConfigManager.Create;
  ToolchainMgr := Config.GetToolchainManager;
  ToolchainMgr.AddToolchain('fpc-3.2.2', Info);
  // 无需 Free，自动管理
end;
```

## 配置文件格式

配置以 JSON 格式存储在 `~/.fpdev/config.json`（Windows: `%APPDATA%\.fpdev\config.json`）:

```json
{
  "version": "1.0",
  "toolchains": {
    "fpc-3.2.2": {
      "type": "release",
      "version": "3.2.2",
      "install_path": "/usr/local/fpc/3.2.2",
      "source_url": "https://gitlab.com/freepascal.org/fpc/source.git",
      "branch": "fixes_3_2",
      "installed": true,
      "install_date": "2025-01-15T10:30:00",
      "default": true
    }
  },
  "lazarus_installs": {
    "lazarus-3.0": {
      "version": "3.0",
      "fpc_version": "fpc-3.2.2",
      "install_path": "/usr/local/lazarus",
      "source_url": "https://gitlab.com/freepascal.org/lazarus.git",
      "branch": "lazarus_3_0",
      "installed": true,
      "default": true
    }
  },
  "cross_targets": {
    "win64": {
      "enabled": true,
      "binutils_path": "/usr/local/cross/win64/bin",
      "libraries_path": "/usr/local/cross/win64/lib"
    }
  },
  "repositories": {
    "fpc": "https://gitlab.com/freepascal.org/fpc/source.git",
    "lazarus": "https://gitlab.com/freepascal.org/lazarus.git"
  },
  "settings": {
    "default_repo": "fpc",
    "auto_update": false,
    "parallel_jobs": 4,
    "keep_sources": true,
    "install_root": "/opt/fpdev"
  }
}
```

## 测试

### 测试套件

配置管理系统包含完整的测试套件：

1. **wrapper_test.lpr** - 测试向后兼容包装器
2. **submgr_test.lpr** - 测试子管理器接口
3. **test_config_management.lpr** - 完整功能测试（29个测试用例）

### 运行测试

```bash
# 编译测试
fpc -Fusrc -Fisrc -FEbin -FUlib tests\wrapper_test.lpr
fpc -Fusrc -Fisrc -FEbin -FUlib tests\submgr_test.lpr
fpc -Fusrc -Fisrc -FEbin -FUlib tests\test_config_management.lpr

# 运行测试
.\bin\wrapper_test.exe
.\bin\submgr_test.exe
.\bin\test_config_management.exe
```

### 测试覆盖

- ✅ 配置创建和加载
- ✅ 工具链管理（添加、删除、查询、默认）
- ✅ Lazarus 版本管理
- ✅ 交叉编译目标管理
- ✅ 仓库管理
- ✅ 设置管理
- ✅ 配置持久化
- ✅ 向后兼容性
- ✅ 接口引用计数生命周期

## 设计原则

### 1. 单一职责原则（SRP）

每个管理器负责单一领域的配置管理，职责清晰。

### 2. 接口隔离原则（ISP）

通过接口暴露功能，隐藏实现细节，便于测试和替换。

### 3. 依赖注入

子管理器通过接口接收通知器，而不是直接依赖具体类型。

### 4. 开闭原则（OCP）

可以通过实现新的接口扩展功能，无需修改现有代码。

### 5. 生命周期自动化

使用接口引用计数自动管理内存，避免内存泄漏。

## 未来改进

### 计划中的功能

1. **配置模板** - 预定义的配置模板（开发、生产、CI/CD）
2. **配置验证** - JSON Schema 验证配置文件有效性
3. **配置迁移** - 自动从旧版本配置迁移
4. **配置导入/导出** - 导出配置供其他机器使用
5. **环境变量支持** - 配置路径支持环境变量展开

### 性能优化

1. 延迟加载子管理器
2. 配置缓存策略
3. 批量配置更新

## 参考资料

- **源文件**:
  - `src/fpdev.config.interfaces.pas` - 接口定义
  - `src/fpdev.config.managers.pas` - 实现代码
  - `src/fpdev.config.pas` - 向后兼容层
  
- **测试文件**:
  - `tests/wrapper_test.lpr`
  - `tests/submgr_test.lpr`
  - `tests/test_config_management.lpr`

- **相关文档**:
  - `warp.md` - 项目总体文档
  - `README.md` - 快速入门

---

**最后更新**: 2025-01-28  
**维护者**: FPDev Team  
**状态**: ✅ 已实现并测试通过
