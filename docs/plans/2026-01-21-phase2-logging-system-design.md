# Phase 2 日志系统设计文档

**日期**: 2026-01-21
**作者**: Claude Code + User
**状态**: 设计完成，待实现

## 1. 概述

Phase 2 日志系统是一个全新的结构化日志系统，与现有的 `ILogger` 系统并行运行，提供更强大的日志记录、轮转和归档功能。

### 1.1 设计目标

- **结构化日志**: 支持 JSON 格式的结构化日志记录
- **双输出平衡**: 文件和控制台输出同等重要，可独立控制
- **灵活轮转**: 支持基于大小和时间的混合轮转策略
- **扩展字段**: 包含来源信息、线程/进程信息、错误堆栈、关联 ID
- **向后兼容**: 与现有 `ILogger` 系统并行，不影响现有代码

### 1.2 核心架构

```
IStructuredLogger (接口)
    ↓
TStructuredLogger (实现)
    ↓
    ├─→ TFileLogWriter (文件输出)
    │   ├─→ TLogRotator (轮转管理)
    │   └─→ TLogArchiver (归档管理)
    │
    └─→ TConsoleLogWriter (控制台输出)
        └─→ TLogFormatter (格式化器)
```

## 2. 核心接口定义

### 2.1 TLogContext 记录

```pascal
type
  TLogContext = record
    Source: string;           // 模块名（如 'fpdev.fpc.installer'）
    CorrelationId: string;    // 关联ID（用于追踪请求链）
    ThreadId: Cardinal;       // 线程ID
    ProcessId: Cardinal;      // 进程ID
    CustomFields: TStringList; // 自定义键值对
  end;
```

### 2.2 IStructuredLogger 接口

```pascal
type
  IStructuredLogger = interface
    ['{3F8A9B2C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}']
    // 核心日志方法
    procedure Log(const ALevel: TLogLevel; const AMessage: string;
                  const AContext: TLogContext);
    procedure Debug(const AMessage: string; const AContext: TLogContext);
    procedure Info(const AMessage: string; const AContext: TLogContext);
    procedure Warn(const AMessage: string; const AContext: TLogContext);
    procedure Error(const AMessage: string; const AContext: TLogContext;
                    const AStackTrace: string = '');

    // 输出控制
    procedure SetFileOutput(AEnabled: Boolean);
    procedure SetConsoleOutput(AEnabled: Boolean);
    function IsFileOutputEnabled: Boolean;
    function IsConsoleOutputEnabled: Boolean;
  end;
```

### 2.3 ILogWriter 接口

```pascal
type
  TLogEntry = record
    Timestamp: TDateTime;
    Level: TLogLevel;
    Message: string;
    Context: TLogContext;
    StackTrace: string;
  end;

  ILogWriter = interface
    ['{4A9B0C1D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']
    procedure Write(const AEntry: TLogEntry);
    procedure Flush;
    procedure Close;
  end;
```

## 3. 日志轮转和归档

### 3.1 轮转配置

```pascal
type
  TRotationTrigger = (rtSize, rtTime, rtManual);

  TRotationConfig = record
    MaxFileSize: Int64;        // 最大文件大小（字节，如 10MB）
    RotationInterval: Integer; // 轮转间隔（小时，如 24）
    MaxFiles: Integer;         // 保留文件数量（如 5）
    MaxAge: Integer;           // 保留天数（如 7）
    CompressOld: Boolean;      // 是否压缩旧日志
  end;
```

### 3.2 ILogRotator 接口

```pascal
type
  ILogRotator = interface
    ['{5B0C1D2E-6F7A-8B9C-0D1E-2F3A4B5C6D7E}']
    function ShouldRotate(const ACurrentFile: string): Boolean;
    procedure Rotate(const ACurrentFile: string);
    procedure CleanupOldLogs(const ALogDir: string);
  end;
```

### 3.3 轮转逻辑

1. 每次写入日志前检查是否需要轮转
2. 检查文件大小是否超过 `MaxFileSize`
3. 检查文件创建时间是否超过 `RotationInterval`
4. 如果任一条件满足，触发轮转
5. 轮转时重命名当前文件（添加时间戳）
6. 创建新的日志文件
7. 清理超过 `MaxFiles` 或 `MaxAge` 的旧日志

### 3.4 归档策略

- 旧日志文件命名：`fpdev_2026-01-21_001.log`
- 可选压缩：`fpdev_2026-01-21_001.log.gz`
- 自动清理：删除超过保留策略的文件

## 4. JSON 日志格式

### 4.1 扩展字段集

```json
{
  "timestamp": "2026-01-21T10:30:45.123Z",
  "level": "info",
  "message": "FPC 3.2.2 installation started",
  "source": "fpdev.fpc.installer",
  "correlation_id": "req-abc123",
  "thread_id": 12345,
  "process_id": 67890,
  "context": {
    "version": "3.2.2",
    "target": "x86_64-linux",
    "cache_hit": true
  },
  "stack_trace": null
}
```

### 4.2 字段说明

- **timestamp**: ISO 8601 格式的时间戳
- **level**: 日志级别（debug/info/warn/error）
- **message**: 日志消息
- **source**: 来源模块名
- **correlation_id**: 关联 ID（用于追踪请求链）
- **thread_id**: 线程 ID
- **process_id**: 进程 ID
- **context**: 自定义上下文字段（键值对）
- **stack_trace**: 错误堆栈（仅 Error 级别）

## 5. 配置接口

### 5.1 TLoggerConfig 记录

```pascal
type
  TLoggerConfig = record
    // 输出控制
    FileOutputEnabled: Boolean;
    ConsoleOutputEnabled: Boolean;

    // 文件配置
    LogDir: string;
    LogFileName: string;  // 可选，默认自动生成

    // 轮转配置
    RotationConfig: TRotationConfig;

    // 日志级别过滤
    MinLevel: TLogLevel;  // 最低日志级别（如 llInfo）

    // 格式化选项
    UseColorOutput: Boolean;  // 控制台彩色输出
    IncludeThreadId: Boolean;
    IncludeProcessId: Boolean;
  end;
```

## 6. 使用示例

### 6.1 基本使用

```pascal
uses
  fpdev.logger.structured;

var
  Logger: IStructuredLogger;
  Config: TLoggerConfig;
  Context: TLogContext;
begin
  // 配置
  Config.FileOutputEnabled := True;
  Config.ConsoleOutputEnabled := True;
  Config.LogDir := 'logs';
  Config.RotationConfig.MaxFileSize := 10 * 1024 * 1024;  // 10MB
  Config.RotationConfig.MaxFiles := 5;
  Config.MinLevel := llInfo;

  // 创建日志器
  Logger := TStructuredLogger.Create(Config);

  // 记录日志
  Context.Source := 'fpdev.fpc.installer';
  Context.CorrelationId := 'install-123';
  Context.CustomFields := TStringList.Create;
  try
    Context.CustomFields.Values['version'] := '3.2.2';

    Logger.Info('Installation started', Context);
    Logger.Error('Installation failed', Context, GetStackTrace);
  finally
    Context.CustomFields.Free;
  end;
end;
```

### 6.2 独立控制输出

```pascal
// 仅文件输出（生产环境）
Logger.SetFileOutput(True);
Logger.SetConsoleOutput(False);

// 仅控制台输出（开发调试）
Logger.SetFileOutput(False);
Logger.SetConsoleOutput(True);

// 双输出（默认）
Logger.SetFileOutput(True);
Logger.SetConsoleOutput(True);
```

## 7. 实现计划（TDD 方式）

### 7.1 Week 1-2: 核心基础设施

**文件**:
- `src/fpdev.logger.structured.pas` - IStructuredLogger 接口和 TStructuredLogger 实现
- `src/fpdev.logger.writer.pas` - ILogWriter 接口和基础实现
- `src/fpdev.logger.formatter.pas` - JSON 和控制台格式化器

**测试**:
- `tests/test_structured_logger.lpr` (50+ tests)
  - 测试日志记录功能
  - 测试输出控制
  - 测试上下文字段
  - 测试日志级别过滤

### 7.2 Week 3: 日志轮转

**文件**:
- `src/fpdev.logger.rotator.pas` - TLogRotator 实现（大小+时间触发）
- `src/fpdev.logger.archiver.pas` - TLogArchiver 实现（压缩+清理）

**测试**:
- `tests/test_log_rotation.lpr` (40+ tests)
  - 测试大小触发轮转
  - 测试时间触发轮转
  - 测试文件清理
  - 测试压缩功能

### 7.3 Week 4: 集成和优化

**任务**:
- 集成到现有命令（如 `fpdev fpc install`）
- 性能优化（异步写入、缓冲）
- 文档更新

**测试**:
- `tests/test_logger_integration.lpr` (30+ tests)
  - 测试与现有系统集成
  - 测试性能
  - 测试并发写入

## 8. 文件结构

```
src/
├── fpdev.logger.structured.pas    # 核心日志器实现
├── fpdev.logger.writer.pas        # 日志写入器
├── fpdev.logger.formatter.pas     # 格式化器
├── fpdev.logger.rotator.pas       # 轮转管理
└── fpdev.logger.archiver.pas      # 归档管理

tests/
├── test_structured_logger.lpr     # 核心功能测试
├── test_log_rotation.lpr          # 轮转功能测试
└── test_logger_integration.lpr    # 集成测试
```

## 9. 设计原则

1. **接口分离**: 日志记录、写入、格式化、轮转各司其职
2. **独立输出**: 文件和控制台输出完全独立，可单独启用/禁用
3. **向后兼容**: 与现有 `ILogger` 系统并行，不影响现有代码
4. **TDD 方式**: 先写测试，再写实现
5. **YAGNI 原则**: 只实现必要功能，避免过度设计

## 10. 后续扩展

Phase 2 完成后，可以考虑以下扩展：

- **异步写入**: 使用后台线程异步写入日志
- **远程日志**: 支持发送日志到远程服务器
- **日志查询**: 提供日志查询和分析工具
- **性能监控**: 集成性能指标记录

---

**设计完成日期**: 2026-01-21
**预计实现周期**: 4 周
**预计测试数量**: 120+ tests
