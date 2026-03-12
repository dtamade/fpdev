# FPDev 架构设计文档

## 概述

FPDev 是一个模块化的 FreePascal 和 Lazarus 开发环境管理工具，采用分层架构设计，确保代码的可维护性、可扩展性和可测试性。

## 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    命令行界面层                              │
├─────────────────────────────────────────────────────────────┤
│                    命令处理层                                │
│  ┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐ │
│  │   fpc   │ lazarus │  cross  │ package │ project │ system  │ │
│  └─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    核心服务层                                │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│  │ 配置管理     │ 版本管理     │ 构建系统     │ Git操作     │   │
│  └─────────────┴─────────────┴─────────────┴─────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    基础设施层                                │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│  │ 文件系统     │ 进程管理     │ 网络操作     │ 系统信息     │   │
│  └─────────────┴─────────────┴─────────────┴─────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 核心模块设计

### 1. 配置管理模块 (fpdev.config)

**职责**: 管理应用程序的配置信息，包括工具链、Lazarus版本、交叉编译目标等。

**设计原则**:
- 使用 JSON 格式存储配置，便于人工编辑和版本控制
- 提供类型安全的配置访问接口
- 支持配置的验证和迁移
- 采用延迟加载策略，提高启动性能

**核心类**:
```pascal
TFPDevConfigManager = class
  // 配置文件操作
  function LoadConfig: Boolean;
  function SaveConfig: Boolean;
  
  // 工具链管理
  function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
  function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
  
  // 设置管理
  function GetSettings: TFPDevSettings;
  function SetSettings(const ASettings: TFPDevSettings): Boolean;
end;
```

### 2. 命令处理框架 (fpdev.cmd)

**职责**: 提供统一的命令注册、命令树分发，以及 CLI 上下文注入。

**设计模式**: 命令模式 + 注册表分发

**核心接口和类型**:
```pascal
IContext = interface
  function Config: IConfigManager;
  function Out: IOutput;
  function Err: IOutput;
  function Logger: ILogger;
  procedure SaveIfModified;
end;

ICommand = interface
  function Name: string;
  function Aliases: TStringArray;
  function FindSub(const AName: string): ICommand;
  function Execute(const AParams: array of string; const Ctx: IContext): Integer;
end;

TCommandRegistry = class
  procedure RegisterPath(const APath: array of string; AFactory: TCommandFactory; const Aliases: array of string);
  function DispatchPath(const AArgs: array of string; const Ctx: IContext): Integer;
  function ListChildren(const APath: array of string): TStringArray;
end;
```

**关键实现文件**:
- `src/fpdev.command.intf.pas`: `ICommand` / `IContext`
- `src/fpdev.command.tree.pas`: `TCommandNode`
- `src/fpdev.command.registration.pas`: 路径注册与别名挂接
- `src/fpdev.command.registry.pas`: 注册表外观与分发
- `src/fpdev.command.imports.pas`: 导入所有命令单元，触发 `initialization` 注册
- `src/fpdev.cli.bootstrap.pas`: 默认 help / context / registry bootstrap
- `src/fpdev.cli.runner.pas`: 入口层 orchestration

**命令层次结构**:
```
fpdev
├── fpc
│   ├── install / list / use / current / show
│   ├── test / verify / update / uninstall
│   ├── policy
│   │   └── check
│   └── cache
│       ├── list / stats / clean / path
├── lazarus
│   ├── install / list / use / current / show
│   ├── run / test / doctor / update / uninstall
│   └── configure
├── cross
│   ├── list / show / install / uninstall
│   ├── enable / disable / configure / doctor
│   └── test / update / clean / build
├── package
│   ├── install / uninstall / update / list / search / info
│   ├── publish / clean / install-local / deps / why
│   └── repo
│       ├── add / list / remove / update
├── system
│   ├── help / version / doctor
│   ├── toolchain
│   │   ├── check / self-test
│   ├── repo
│   ├── config
│   ├── env
│   │   ├── data-root / vars / path / export / hook / resolve
│   ├── index
│   ├── cache
│   └── perf
└── project
    ├── new / list / info / build / run / test / clean
    └── template
        ├── list / install / remove / update

入口层只保留 `--portable` 预解析；根帮助、版本、工具链检查和策略检查都通过命令树暴露。
```

### 3. 工具函数库 (fpdev.utils)

**职责**: 提供跨平台的系统操作接口，包括文件操作、进程管理、系统信息获取等。

**设计原则**:
- 统一的跨平台接口
- 平台特定的实现分离
- 错误处理和异常安全

**功能模块**:
- 系统信息: CPU、内存、主机名等
- 进程管理: 进程创建、监控、终止
- 文件操作: 路径处理、文件权限、目录操作
- 时间函数: 高精度时间、系统运行时间

### 4. 终端输出管理 (fpdev.terminal)

**职责**: 管理终端输出格式，支持彩色输出、进度条、表格等。

**特性**:
- 跨平台彩色输出支持
- 进度条和状态指示器
- 表格格式化输出
- 日志级别管理

## 数据流设计

### 配置数据流

```
用户输入 → 命令解析 → 配置管理器 → JSON文件
                ↓
            配置验证 → 内存缓存 → 业务逻辑
```

### 构建数据流

```
构建请求 → 版本检查 → 源码获取 → 依赖解析 → 编译执行 → 结果输出
```

## 错误处理策略

### 1. 分层错误处理

- **用户层**: 友好的错误消息和建议
- **业务层**: 业务逻辑错误和恢复策略
- **系统层**: 系统调用错误和资源管理

### 2. 错误类型

```pascal
type
  TFPDevErrorType = (
    etConfigError,    // 配置错误
    etNetworkError,   // 网络错误
    etFileSystemError,// 文件系统错误
    etCompileError,   // 编译错误
    etRuntimeError    // 运行时错误
  );
```

### 3. 错误恢复机制

- 自动重试机制
- 回滚操作支持
- 用户确认机制
- 日志记录和诊断

## 扩展性设计

### 1. 插件架构

预留插件接口，支持第三方扩展：

```pascal
IFPDevPlugin = interface
  function GetName: string;
  function GetVersion: string;
  procedure Initialize(const AContext: IFPDevContext);
  procedure Execute(const AParams: TStringArray);
end;
```

### 2. 配置扩展

支持自定义配置字段和验证规则：

```json
{
  "extensions": {
    "custom_plugin": {
      "enabled": true,
      "config": {
        "custom_field": "value"
      }
    }
  }
}
```

## 性能优化

### 1. 缓存策略

- 配置文件缓存
- 版本信息缓存
- 网络请求缓存

### 2. 并发处理

- 异步文件操作
- 并行编译支持
- 后台任务管理

### 3. 资源管理

- 内存池管理
- 文件句柄复用
- 网络连接池

## 安全考虑

### 1. 输入验证

- 命令行参数验证
- 配置文件格式验证
- URL和路径安全检查

### 2. 权限管理

- 最小权限原则
- 文件权限检查
- 执行权限验证

### 3. 数据保护

- 敏感信息加密
- 临时文件清理
- 安全的默认配置

## 测试策略

### 1. 单元测试

- 每个模块独立测试
- 模拟依赖和外部服务
- 边界条件和异常测试

### 2. 集成测试

- 模块间交互测试
- 端到端功能测试
- 性能和压力测试

### 3. 测试覆盖率

- 代码覆盖率 > 80%
- 分支覆盖率 > 70%
- 关键路径 100% 覆盖

## 部署和维护

### 1. 构建系统

- 自动化构建流程
- 多平台交叉编译
- 版本管理和发布

### 2. 监控和诊断

- 性能监控
- 错误报告
- 使用统计

### 3. 更新机制

- 自动更新检查
- 增量更新支持
- 回滚机制

## 未来规划

### 短期目标 (3个月)

- 完成核心功能开发
- 实现基本的FPC/Lazarus管理
- 添加交叉编译支持

### 中期目标 (6个月)

- 完善包管理系统
- 添加GUI界面
- 支持更多平台

### 长期目标 (1年)

- 插件生态系统
- 云端同步功能
- 企业级功能支持
