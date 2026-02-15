# FPDev 错误处理最佳实践指南

**版本**: 1.0.0
**最后更新**: 2026-02-15

---

## 概述

FPDev 使用统一的错误处理机制，提供丰富的错误上下文和恢复建议。本指南说明如何正确使用错误处理系统。

---

## 核心组件

### 1. TErrorCode 枚举

定义了14种标准错误类型：

```pascal
type
  TErrorCode = (
    ecSuccess,                  // 成功（无错误）
    ecNetworkTimeout,           // 网络超时
    ecNetworkConnectionFailed,  // 网络连接失败
    ecPermissionDenied,         // 权限被拒绝
    ecFileNotFound,             // 文件未找到
    ecDirectoryNotFound,        // 目录未找到
    ecDependencyMissing,        // 依赖缺失
    ecInvalidVersion,           // 无效版本
    ecInvalidInput,             // 无效输入
    ecChecksumMismatch,         // 校验和不匹配
    ecBuildFailed,              // 构建失败
    ecInstallationFailed,       // 安装失败
    ecConfigurationError,       // 配置错误
    ecUnknownError              // 未知错误
  );
```

### 2. TEnhancedError 类

增强的错误对象，包含：
- 错误代码（TErrorCode）
- 错误消息（string）
- 上下文信息（key-value pairs）
- 恢复建议（TRecoverySuggestion数组）

### 3. 快捷创建函数

`fpdev.errors.recovery.pas` 提供了11个预配置的错误创建函数：

- `CreateNetworkTimeoutError`
- `CreateNetworkConnectionError`
- `CreateFileNotFoundError`
- `CreatePermissionDeniedError`
- `CreateDependencyMissingError`
- `CreateInvalidVersionError`
- `CreateInvalidInputError`
- `CreateChecksumMismatchError`
- `CreateBuildFailedError`
- `CreateInstallationFailedError`
- `CreateConfigurationError`

---

## 使用指南

### 何时使用 Boolean vs TEnhancedError

#### 使用 Boolean 返回值

适用于：
- 简单的成功/失败判断
- 调用者不需要详细错误信息
- 内部辅助函数
- 性能关键路径

```pascal
function FileExists(const APath: string): Boolean;
begin
  Result := SysUtils.FileExists(APath);
end;
```

#### 使用 TEnhancedError

适用于：
- 用户可见的操作
- 需要提供恢复建议
- 需要记录详细上下文
- 复杂的错误场景

```pascal
function DownloadFile(const AURL, ADestPath: string): TEnhancedError;
begin
  Result := nil;
  try
    // Download logic
    if not Success then
    begin
      Result := CreateNetworkTimeoutError(AURL, 30);
      Exit;
    end;
  except
    on E: Exception do
    begin
      Result := NewError(ecNetworkConnectionFailed, E.Message);
      Result.AddContext('url', AURL);
      Result.AddContext('dest', ADestPath);
    end;
  end;
end;
```

### 创建和使用 TEnhancedError

#### 方法1：使用快捷创建函数（推荐）

```pascal
uses fpdev.errors.recovery;

var
  Err: TEnhancedError;
begin
  Err := CreateFileNotFoundError('/path/to/file.txt', '/expected/location');
  try
    Err.Display;  // 显示格式化的错误信息
  finally
    Err.Free;
  end;
end;
```

#### 方法2：手动创建

```pascal
uses fpdev.errors;

var
  Err: TEnhancedError;
begin
  Err := NewError(ecBuildFailed, 'Compilation failed');
  try
    Err.AddContext('compiler', 'fpc');
    Err.AddContext('version', '3.2.2');
    Err.AddSuggestion(
      'Check compiler installation',
      'fpdev fpc doctor',
      'Verify FPC is correctly installed and configured'
    );
    Err.Display;
  finally
    Err.Free;
  end;
end;
```

### 在命令中使用错误处理

#### 模式1：返回错误对象

```pascal
function TMyCommand.Execute(const AParams: array of string; const Ctx: IContext): TEnhancedError;
var
  FilePath: string;
begin
  Result := nil;

  if Length(AParams) = 0 then
  begin
    Result := NewError(ecInvalidInput, 'Missing file path argument');
    Result.AddSuggestion('Provide file path', 'fpdev mycommand <file>', '');
    Exit;
  end;

  FilePath := AParams[0];
  if not FileExists(FilePath) then
  begin
    Result := CreateFileNotFoundError(FilePath, GetCurrentDir);
    Exit;
  end;

  // Process file...
end;
```

#### 模式2：使用 IOutput 接口报告错误

```pascal
procedure TMyCommand.Execute(const AParams: array of string; const Ctx: IContext);
var
  Err: TEnhancedError;
begin
  Err := DoSomething();
  if Err <> nil then
  begin
    try
      Ctx.Err.WriteLn('[ERROR] ' + Err.Message);
      Err.Verbose := True;
      Err.Display;
    finally
      Err.Free;
    end;
    Exit;
  end;

  Ctx.Out.WriteLn('Success!');
end;
```

---

## 错误恢复建议编写指南

### 好的恢复建议

✅ **具体可执行**
```pascal
Err.AddSuggestion(
  'Install missing dependency',
  'fpdev package install libfoo',
  'This package is required for cross-compilation'
);
```

✅ **提供多个选项**
```pascal
Err.AddSuggestion('Check network connection', '', 'Verify internet connectivity');
Err.AddSuggestion('Use offline mode', 'fpdev fpc install 3.2.2 --offline', 'Install from cache');
Err.AddSuggestion('Configure proxy', 'fpdev config set proxy http://proxy:8080', '');
```

✅ **包含诊断命令**
```pascal
Err.AddSuggestion(
  'Run diagnostics',
  'fpdev doctor',
  'Check system configuration and dependencies'
);
```

### 避免的做法

❌ **模糊不清**
```pascal
Err.AddSuggestion('Fix the problem', '', '');  // 太模糊
```

❌ **无法执行**
```pascal
Err.AddSuggestion('Contact system administrator', '', '');  // 用户无法自行解决
```

❌ **过于技术化**
```pascal
Err.AddSuggestion(
  'Modify kernel parameters',
  'sysctl -w net.ipv4.tcp_keepalive_time=600',
  ''  // 对普通用户太复杂
);
```

---

## 迁移现有代码

### 从 Boolean 返回值迁移

#### 迁移前
```pascal
function InstallPackage(const AName: string): Boolean;
begin
  Result := False;
  if not FileExists(AName + '.tar.gz') then
  begin
    WriteLn('Error: Package file not found');
    Exit;
  end;

  // Install logic...
  Result := True;
end;
```

#### 迁移后
```pascal
function InstallPackage(const AName: string): TEnhancedError;
var
  PackageFile: string;
begin
  Result := nil;
  PackageFile := AName + '.tar.gz';

  if not FileExists(PackageFile) then
  begin
    Result := CreateFileNotFoundError(PackageFile, GetCurrentDir);
    Exit;
  end;

  // Install logic...
  // If error occurs:
  // Result := CreateInstallationFailedError(AName, 'reason');
end;
```

### 从 WriteLn 错误输出迁移

#### 迁移前
```pascal
if not Success then
begin
  WriteLn('Error: Build failed');
  Exit;
end;
```

#### 迁移后（使用 IOutput）
```pascal
if not Success then
begin
  Ctx.Err.WriteLn('Error: Build failed');
  Exit;
end;
```

#### 迁移后（使用 TEnhancedError）
```pascal
if not Success then
begin
  Err := CreateBuildFailedError('main', 'Compilation error');
  try
    Err.Display;
  finally
    Err.Free;
  end;
  Exit;
end;
```

---

## 代码示例

### 示例1：文件操作错误处理

```pascal
uses fpdev.errors, fpdev.errors.recovery;

function ProcessConfigFile(const APath: string): TEnhancedError;
var
  Content: TStringList;
begin
  Result := nil;

  if not FileExists(APath) then
  begin
    Result := CreateFileNotFoundError(APath, GetConfigDir);
    Exit;
  end;

  Content := TStringList.Create;
  try
    try
      Content.LoadFromFile(APath);
    except
      on E: Exception do
      begin
        Result := NewError(ecPermissionDenied, 'Cannot read config file');
        Result.AddContext('file', APath);
        Result.AddContext('error', E.Message);
        Result.AddSuggestion('Check file permissions', 'ls -l ' + APath, '');
        Exit;
      end;
    end;

    // Process content...
  finally
    Content.Free;
  end;
end;
```

### 示例2：网络操作错误处理

```pascal
function DownloadWithRetry(const AURL: string; ARetries: Integer): TEnhancedError;
var
  I: Integer;
begin
  Result := nil;

  for I := 1 to ARetries do
  begin
    try
      // Download logic
      Exit;  // Success
    except
      on E: Exception do
      begin
        if I = ARetries then
        begin
          Result := CreateNetworkConnectionError(AURL);
          Result.AddContext('attempts', IntToStr(ARetries));
          Exit;
        end;
        Sleep(1000 * I);  // Exponential backoff
      end;
    end;
  end;
end;
```

---

## 反模式

### 反模式1：吞噬错误

❌ **错误做法**
```pascal
function DoSomething: Boolean;
begin
  try
    // Risky operation
    Result := True;
  except
    Result := False;  // 错误信息丢失
  end;
end;
```

✅ **正确做法**
```pascal
function DoSomething: TEnhancedError;
begin
  Result := nil;
  try
    // Risky operation
  except
    on E: Exception do
    begin
      Result := NewError(ecUnknownError, E.Message);
      Result.AddContext('operation', 'DoSomething');
    end;
  end;
end;
```

### 反模式2：过度使用异常

❌ **错误做法**
```pascal
if not FileExists(Path) then
  raise Exception.Create('File not found');  // 用户看到原始异常
```

✅ **正确做法**
```pascal
if not FileExists(Path) then
begin
  Err := CreateFileNotFoundError(Path, GetCurrentDir);
  // 返回或显示错误
end;
```

### 反模式3：重复的错误处理代码

❌ **错误做法**
```pascal
// 在多个地方重复相同的错误处理逻辑
if not FileExists(Path) then
begin
  WriteLn('Error: File not found: ', Path);
  WriteLn('Please check the file path');
  Exit;
end;
```

✅ **正确做法**
```pascal
// 使用统一的错误创建函数
if not FileExists(Path) then
begin
  Err := CreateFileNotFoundError(Path, GetCurrentDir);
  // 错误处理逻辑集中在一处
end;
```

---

## 测试错误处理

### 单元测试示例

```pascal
procedure TestFileNotFoundError;
var
  Err: TEnhancedError;
begin
  Err := CreateFileNotFoundError('/nonexistent/file.txt', '/current/dir');
  try
    AssertEquals('Error code should be ecFileNotFound',
                 Ord(ecFileNotFound), Ord(Err.Code));
    AssertTrue('Error message should contain file path',
               Pos('/nonexistent/file.txt', Err.Message) > 0);
    AssertTrue('Should have recovery suggestions',
               Length(Err.Suggestions) > 0);
  finally
    Err.Free;
  end;
end;
```

---

## 总结

### 关键原则

1. **用户可见的操作使用 TEnhancedError**
2. **提供具体可执行的恢复建议**
3. **记录详细的错误上下文**
4. **使用预定义的错误创建函数**
5. **避免直接使用 WriteLn 输出错误**

### 快速检查清单

- [ ] 错误消息清晰易懂？
- [ ] 提供了恢复建议？
- [ ] 记录了相关上下文？
- [ ] 使用了正确的错误代码？
- [ ] 错误对象正确释放？

---

**参考文档**:
- `src/fpdev.errors.pas` - 核心错误处理模块
- `src/fpdev.errors.recovery.pas` - 预配置错误创建函数
- `tests/test_errors.lpr` - 错误处理单元测试
- `tests/test_errors_recovery.lpr` - 错误恢复测试
