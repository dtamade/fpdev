# FPDev API 文档

## 配置管理 API (fpdev.config)

### TFPDevConfigManager 类

配置管理的核心类，负责处理所有配置相关的操作。

#### 构造函数

```pascal
constructor Create(const AConfigPath: string = '');
```

- `AConfigPath`: 配置文件路径，如果为空则使用默认路径

#### 配置文件操作

```pascal
function LoadConfig: Boolean;
function SaveConfig: Boolean;
function CreateDefaultConfig: Boolean;
function GetDefaultConfigPath: string;
```

- `LoadConfig`: 从文件加载配置
- `SaveConfig`: 保存配置到文件
- `CreateDefaultConfig`: 创建默认配置文件
- `GetDefaultConfigPath`: 获取默认配置文件路径

#### 工具链管理

```pascal
function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
function RemoveToolchain(const AName: string): Boolean;
function GetToolchain(const AName: string; out AInfo: TToolchainInfo): Boolean;
function SetDefaultToolchain(const AName: string): Boolean;
function GetDefaultToolchain: string;
function ListToolchains: TStringArray;
```

- `AddToolchain`: 添加新的工具链
- `RemoveToolchain`: 删除指定工具链
- `GetToolchain`: 获取工具链信息
- `SetDefaultToolchain`: 设置默认工具链
- `GetDefaultToolchain`: 获取默认工具链名称
- `ListToolchains`: 列出所有工具链

#### Lazarus 管理

```pascal
function AddLazarusVersion(const AName: string; const AInfo: TLazarusInfo): Boolean;
function RemoveLazarusVersion(const AName: string): Boolean;
function GetLazarusVersion(const AName: string; out AInfo: TLazarusInfo): Boolean;
function SetDefaultLazarusVersion(const AName: string): Boolean;
function GetDefaultLazarusVersion: string;
function ListLazarusVersions: TStringArray;
```

#### 交叉编译目标管理

```pascal
function AddCrossTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
function RemoveCrossTarget(const ATarget: string): Boolean;
function GetCrossTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
function ListCrossTargets: TStringArray;
```

#### 仓库管理

```pascal
function AddRepository(const AName, AURL: string): Boolean;
function RemoveRepository(const AName: string): Boolean;
function GetRepository(const AName: string): string;
function ListRepositories: TStringArray;
```

#### 设置管理

```pascal
function GetSettings: TFPDevSettings;
function SetSettings(const ASettings: TFPDevSettings): Boolean;
```

### 数据结构

#### TToolchainType

```pascal
TToolchainType = (ttRelease, ttDevelopment, ttCustom);
```

工具链类型枚举：
- `ttRelease`: 发布版本
- `ttDevelopment`: 开发版本
- `ttCustom`: 自定义版本

#### TToolchainInfo

```pascal
TToolchainInfo = record
  ToolchainType: TToolchainType;
  Version: string;
  InstallPath: string;
  SourceURL: string;
  Branch: string;
  Installed: Boolean;
  InstallDate: TDateTime;
end;
```

工具链信息记录：
- `ToolchainType`: 工具链类型
- `Version`: 版本号
- `InstallPath`: 安装路径
- `SourceURL`: 源码仓库URL
- `Branch`: Git分支
- `Installed`: 是否已安装
- `InstallDate`: 安装日期

#### TLazarusInfo

```pascal
TLazarusInfo = record
  Version: string;
  FPCVersion: string;
  InstallPath: string;
  SourceURL: string;
  Branch: string;
  Installed: Boolean;
end;
```

Lazarus信息记录：
- `Version`: Lazarus版本
- `FPCVersion`: 对应的FPC版本
- `InstallPath`: 安装路径
- `SourceURL`: 源码仓库URL
- `Branch`: Git分支
- `Installed`: 是否已安装

#### TCrossTarget

```pascal
TCrossTarget = record
  Enabled: Boolean;
  BinutilsPath: string;
  LibrariesPath: string;
end;
```

交叉编译目标记录：
- `Enabled`: 是否启用
- `BinutilsPath`: 二进制工具路径
- `LibrariesPath`: 库文件路径

#### TFPDevSettings

```pascal
TFPDevSettings = record
  AutoUpdate: Boolean;
  ParallelJobs: Integer;
  KeepSources: Boolean;
  InstallRoot: string;
end;
```

FPDev设置记录：
- `AutoUpdate`: 是否自动更新
- `ParallelJobs`: 并行编译任务数
- `KeepSources`: 是否保留源码
- `InstallRoot`: 安装根目录

## 命令处理 API (fpdev.cmd)

### TFPCMD 类

命令处理的基类，提供命令执行框架。

```pascal
TFPCMD = class
private
  FParams: TStringArray;
  FChilds: array of TFPCMD;
public
  constructor Create(const aParams: array of string);
  procedure Execute; virtual;
  procedure AddChild(const aChild: TFPCMD);
  function Find(const aName: string): TFPCMD;
end;
```

- `Create`: 创建命令对象
- `Execute`: 执行命令（虚方法，需要子类实现）
- `AddChild`: 添加子命令
- `Find`: 查找子命令

## 工具函数 API (fpdev.utils)

### 系统信息函数

```pascal
function exepath: string;
function cwd: string;
function get_hostname: String;
function get_cpu_count: UInt32;
function get_pid: pid_t;
function get_ppid: pid_t;
```

### 内存管理函数

```pascal
function get_free_memory: UInt64;
function get_total_memory: UInt64;
function resident_set_memory(aRss: PSizeUInt): Boolean;
```

### 时间函数

```pascal
function hrtime: uint64;
function uptime: Integer;
function get_timeofday(aTimeSpec: ptimeval64_t): Boolean;
```

## 使用示例

### 配置管理示例

```pascal
var
  ConfigManager: TFPDevConfigManager;
  ToolchainInfo: TToolchainInfo;
begin
  ConfigManager := TFPDevConfigManager.Create;
  try
    // 加载配置
    if not ConfigManager.LoadConfig then
      ConfigManager.CreateDefaultConfig;
    
    // 添加工具链
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := '/usr/local/fpc/3.2.2';
    ToolchainInfo.SourceURL := 'https://gitlab.com/freepascal.org/fpc/source.git';
    ToolchainInfo.Branch := 'fixes_3_2';
    ToolchainInfo.Installed := True;
    
    ConfigManager.AddToolchain('fpc-3.2.2', ToolchainInfo);
    ConfigManager.SetDefaultToolchain('fpc-3.2.2');
    
    // 保存配置
    ConfigManager.SaveConfig;
  finally
    ConfigManager.Free;
  end;
end;
```

### 命令处理示例

```pascal
var
  Cmd: TFPCMD;
begin
  Cmd := TFPCMD.Create(['help', 'version']);
  try
    Cmd.Execute;
  finally
    Cmd.Free;
  end;
end;
```
