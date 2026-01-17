# FPC 二进制缓存和离线模式 - 详细实施计划

**版本**: v1.0
**日期**: 2026-01-16
**状态**: 待批准
**方法论**: TDD (Test-Driven Development)

---

## 📋 项目概述

### 目标
扩展 FPDev 的 FPC 安装系统，添加二进制下载缓存机制和离线模式支持，提升安装速度和可靠性。

### 核心价值
- **速度提升**: 缓存命中时从分钟级降至秒级
- **可靠性**: 消除网络不稳定导致的安装失败
- **离线支持**: 支持无网络环境下的开发

### 技术方案
**方案 A（推荐）**: 扩展现有 TBuildCache 类，统一管理源码和二进制缓存

---

## 🏗️ 架构设计

### 1. 后端架构

#### 1.1 扩展 TBuildCache 类

**文件**: `src/fpdev.build.cache.pas`

**新增方法**:

```pascal
{ Binary artifact cache methods }
function SaveBinaryArtifact(const AVersion, ADownloadedFile: string): Boolean;
function RestoreBinaryArtifact(const AVersion, ADestPath: string): Boolean;
function GetBinaryArtifactInfo(const AVersion: string; out AInfo: TArtifactInfo): Boolean;
```

**元数据扩展**:

```pascal
{ TArtifactInfo - 扩展字段 }
TArtifactInfo = record
  Version: string;
  CPU: string;
  OS: string;
  ArchivePath: string;
  ArchiveSize: Int64;
  CreatedAt: TDateTime;
  SourcePath: string;
  SourceType: string;      // NEW: 'binary' | 'source'
  SHA256: string;          // NEW: 文件校验和
  DownloadURL: string;     // NEW: 原始下载 URL
end;
```

**缓存键命名规范**:
- 源码构建: `fpc-{version}-{cpu}-{os}-source.tar.gz`
- 二进制包: `fpc-{version}-{cpu}-{os}-binary.tar.gz`

#### 1.2 集成到 FPC 安装流程

**文件**: `src/fpdev.cmd.fpc.install.pas`

**修改点**:

```pascal
procedure TFPCInstallCommand.Execute(const AParams: array of string; const Ctx: IContext);
var
  Cache: TBuildCache;
  Version: string;
  OfflineMode: Boolean;
begin
  // 1. 解析参数
  Version := AParams[0];
  OfflineMode := HasFlag('--offline', AParams);

  // 2. 初始化缓存
  Cache := TBuildCache.Create(GetCacheDir);
  try
    // 3. 检查缓存
    if Cache.HasArtifacts(Version) then
    begin
      WriteLn('[CACHE HIT] Found cached artifact: fpc-', Version);
      if Cache.RestoreBinaryArtifact(Version, GetInstallPath(Version)) then
      begin
        WriteLn('[OK] Installation complete (from cache)');
        Exit;
      end
      else
        WriteLn('[WARN] Cache corrupted, will re-download');
    end;

    // 4. 离线模式检查
    if OfflineMode then
    begin
      WriteLn('[FAIL] Cache miss for FPC ', Version);
      WriteLn('[HINT] Network disabled by --offline flag');
      Exit;
    end;

    // 5. 下载并安装
    WriteLn('[NET] Cache miss. Downloading...');
    DownloadedFile := DownloadFPC(Version);
    InstallFPC(DownloadedFile, Version);

    // 6. 保存到缓存
    WriteLn('[CACHE] Saving build artifact...');
    Cache.SaveBinaryArtifact(Version, GetInstallPath(Version));

    WriteLn('[OK] Installation complete');
  finally
    Cache.Free;
  end;
end;
```

#### 1.3 新增缓存管理命令

**文件**: `src/fpdev.cmd.fpc.cache.pas` (新建)

**命令结构**:

```pascal
unit fpdev.cmd.fpc.cache;

interface

uses
  fpdev.command.intf, fpdev.build.cache;

type
  { TFPCCacheListCommand - fpdev fpc cache list }
  TFPCCacheListCommand = class(TInterfacedObject, ICommand)
  public
    procedure Execute(const AParams: array of string; const Ctx: IContext);
    function GetHelp: string;
  end;

  { TFPCCacheCleanCommand - fpdev fpc cache clean }
  TFPCCacheCleanCommand = class(TInterfacedObject, ICommand)
  public
    procedure Execute(const AParams: array of string; const Ctx: IContext);
    function GetHelp: string;
  end;

  { TFPCCachePathCommand - fpdev fpc cache path }
  TFPCCachePathCommand = class(TInterfacedObject, ICommand)
  public
    procedure Execute(const AParams: array of string; const Ctx: IContext);
    function GetHelp: string;
  end;

implementation

{ TFPCCacheListCommand }

procedure TFPCCacheListCommand.Execute(const AParams: array of string; const Ctx: IContext);
var
  Cache: TBuildCache;
  Versions: TStringArray;
  Info: TArtifactInfo;
  i: Integer;
  TotalSize: Int64;
begin
  Cache := TBuildCache.Create(GetCacheDir);
  try
    Versions := Cache.ListCachedVersions;

    WriteLn('VERSION      ARCH        OS       SIZE     DATE                 STATUS');
    WriteLn('------------------------------------------------------------------------');

    TotalSize := 0;
    for i := 0 to Length(Versions) - 1 do
    begin
      if Cache.GetBinaryArtifactInfo(Versions[i], Info) then
      begin
        WriteLn(Format('%-12s %-11s %-8s %-8s %-20s Valid',
          [Info.Version, Info.CPU, Info.OS,
           FormatSize(Info.ArchiveSize),
           FormatDateTime('yyyy-mm-dd hh:nn', Info.CreatedAt)]));
        TotalSize := TotalSize + Info.ArchiveSize;
      end;
    end;

    WriteLn;
    WriteLn('Total: ', Length(Versions), ' versions (', FormatSize(TotalSize), ')');
  finally
    Cache.Free;
  end;
end;

{ TFPCCacheCleanCommand }

procedure TFPCCacheCleanCommand.Execute(const AParams: array of string; const Ctx: IContext);
var
  Cache: TBuildCache;
  Version: string;
  CleanAll: Boolean;
begin
  Cache := TBuildCache.Create(GetCacheDir);
  try
    CleanAll := HasFlag('--all', AParams);

    if CleanAll then
    begin
      WriteLn('[WARN] This will remove ALL cached FPC binaries. Continue? [y/N]');
      if not ConfirmAction then Exit;

      // Clean all
      Cache.DeleteAllArtifacts;
      WriteLn('[OK] Cache cleaned');
    end
    else
    begin
      Version := AParams[0];
      WriteLn('[INFO] Removing cached artifact for FPC ', Version, '...');
      if Cache.DeleteArtifacts(Version) then
        WriteLn('[OK] Freed ', GetArtifactSize(Version))
      else
        WriteLn('[FAIL] Version not found in cache');
    end;
  finally
    Cache.Free;
  end;
end;

{ TFPCCachePathCommand }

procedure TFPCCachePathCommand.Execute(const AParams: array of string; const Ctx: IContext);
begin
  WriteLn(GetCacheDir);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'cache', 'list'], @CreateCacheListCommand, []);
  GlobalCommandRegistry.RegisterPath(['fpc', 'cache', 'clean'], @CreateCacheCleanCommand, []);
  GlobalCommandRegistry.RegisterPath(['fpc', 'cache', 'path'], @CreateCachePathCommand, []);
end.
```

### 2. 前端交互设计

#### 2.1 命令行参数

**fpdev fpc install 新增参数**:

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `--offline` | Boolean | False | 强制离线模式，缓存未命中时报错 |
| `--no-cache` | Boolean | False | 忽略缓存，强制重新下载 |

**fpdev fpc cache 子命令**:

```bash
fpdev fpc cache list              # 列出所有缓存版本
fpdev fpc cache clean <version>   # 清理指定版本
fpdev fpc cache clean --all       # 清理所有缓存
fpdev fpc cache path              # 显示缓存目录路径
```

#### 2.2 输出格式

**场景 A: 缓存命中**

```
$ fpdev fpc install 3.2.2
[INIT]  fpdev v1.1 - FPC Installer
[CACHE] Found cached artifact: fpc-3.2.2-x86_64-linux.tar.gz (Hit)
[INFO]  Extracting cached binary...
[OK]    FPC 3.2.2 installed successfully.
```

**场景 B: 缓存未命中（正常模式）**

```
$ fpdev fpc install 3.2.2
[INIT]  fpdev v1.1 - FPC Installer
[NET]   Cache miss. Downloading from remote repository...
[INFO]  Downloading https://.../fpc-3.2.2.tar.gz
[=====>              ] 30% (15.2MB/50.5MB)
[CACHE] Saving build artifact to cache...
[OK]    FPC 3.2.2 installed successfully.
```

**场景 C: 离线模式（缓存未命中）**

```
$ fpdev fpc install 3.2.2 --offline
[INIT]  fpdev v1.1 - FPC Installer (Offline Mode)
[FAIL]  Cache miss for FPC 3.2.2 (x86_64-linux).
[HINT]  Network disabled by --offline flag.
[HINT]  Run without --offline to download, or use 'fpdev fpc cache list' to see available versions.
```

**缓存列表输出**

```
$ fpdev fpc cache list
VERSION      ARCH        OS       SIZE     DATE                 STATUS
------------------------------------------------------------------------
3.0.4        x86_64      linux    45MB     2025-12-01 10:00     Valid
3.2.2        x86_64      linux    55MB     2026-01-15 09:15     Valid

Total: 2 versions (100MB)
```

---

## 🧪 测试策略 (TDD)

### Phase 1: TBuildCache 扩展测试

**测试文件**: `tests/test_build_cache_binary.lpr`

**测试用例**:

```pascal
program test_build_cache_binary;

uses
  fpdev.build.cache, SysUtils;

procedure TestSaveBinaryArtifact;
var
  Cache: TBuildCache;
begin
  Cache := TBuildCache.Create('test_cache');
  try
    Assert(Cache.SaveBinaryArtifact('3.2.2', 'test_binary.tar.gz'));
    Assert(Cache.HasArtifacts('3.2.2'));
  finally
    Cache.Free;
  end;
end;

procedure TestRestoreBinaryArtifact;
var
  Cache: TBuildCache;
begin
  Cache := TBuildCache.Create('test_cache');
  try
    Assert(Cache.RestoreBinaryArtifact('3.2.2', 'test_dest'));
    Assert(DirectoryExists('test_dest'));
  finally
    Cache.Free;
  end;
end;

procedure TestGetBinaryArtifactInfo;
var
  Cache: TBuildCache;
  Info: TArtifactInfo;
begin
  Cache := TBuildCache.Create('test_cache');
  try
    Assert(Cache.GetBinaryArtifactInfo('3.2.2', Info));
    Assert(Info.SourceType = 'binary');
    Assert(Info.Version = '3.2.2');
  finally
    Cache.Free;
  end;
end;

begin
  TestSaveBinaryArtifact;
  TestRestoreBinaryArtifact;
  TestGetBinaryArtifactInfo;
  WriteLn('All tests passed!');
end.
```

### Phase 2: FPC Install 集成测试

**测试文件**: `tests/test_fpc_install_cache.lpr`

**测试用例**:

1. `TestInstallWithCacheHit` - 缓存命中时快速安装
2. `TestInstallWithCacheMiss` - 缓存未命中时下载并缓存
3. `TestInstallOfflineMode` - 离线模式下缓存未命中报错
4. `TestInstallNoCacheFlag` - --no-cache 强制重新下载

### Phase 3: 缓存管理命令测试

**测试文件**: `tests/test_fpc_cache_commands.lpr`

**测试用例**:

1. `TestCacheList` - 列出所有缓存版本
2. `TestCacheClean` - 清理指定版本
3. `TestCacheCleanAll` - 清理所有缓存
4. `TestCachePath` - 显示缓存目录

---

## 📁 文件修改清单

### 新建文件

1. `src/fpdev.cmd.fpc.cache.pas` - 缓存管理命令
2. `tests/test_build_cache_binary.lpr` - TBuildCache 扩展测试
3. `tests/test_fpc_install_cache.lpr` - FPC 安装集成测试
4. `tests/test_fpc_cache_commands.lpr` - 缓存管理命令测试

### 修改文件

1. `src/fpdev.build.cache.pas`
   - 添加 `SaveBinaryArtifact()` 方法
   - 添加 `RestoreBinaryArtifact()` 方法
   - 添加 `GetBinaryArtifactInfo()` 方法
   - 扩展 `TArtifactInfo` 记录

2. `src/fpdev.cmd.fpc.install.pas`
   - 添加 `--offline` flag 解析
   - 添加 `--no-cache` flag 解析
   - 集成缓存检查逻辑
   - 添加缓存保存逻辑

3. `src/fpdev.lpr`
   - 导入 `fpdev.cmd.fpc.cache` 单元

4. `CLAUDE.md`
   - 更新缓存系统文档
   - 添加离线模式使用说明

---

## 🔄 数据流设计

### 安装流程（带缓存）

```
用户执行: fpdev fpc install 3.2.2
    ↓
解析参数 (version, --offline, --no-cache)
    ↓
初始化 TBuildCache
    ↓
检查缓存: HasArtifacts(version)?
    ↓ YES                    ↓ NO
恢复缓存                  检查离线模式?
    ↓                         ↓ YES        ↓ NO
安装完成                  报错退出      下载二进制
                                            ↓
                                        安装二进制
                                            ↓
                                        保存到缓存
                                            ↓
                                        安装完成
```

### 缓存保存流程

```
SaveBinaryArtifact(version, installPath)
    ↓
生成缓存键: fpc-{version}-{cpu}-{os}-binary.tar.gz
    ↓
创建 tar.gz 归档
    ↓
计算 SHA256 校验和
    ↓
写入元数据文件 (.meta)
    ↓
更新缓存索引 (build-cache.txt)
    ↓
返回成功
```

### 缓存恢复流程

```
RestoreBinaryArtifact(version, destPath)
    ↓
查找缓存文件
    ↓
读取元数据 (.meta)
    ↓
验证 SHA256 校验和
    ↓ PASS                ↓ FAIL
解压 tar.gz            删除损坏缓存
    ↓                      ↓
安装到目标路径        返回失败
    ↓
返回成功
```

---

## ⚠️ 错误处理策略

### 1. 缓存损坏

**检测**: SHA256 校验和不匹配

**处理**:
```pascal
if not VerifySHA256(ArchivePath, ExpectedHash) then
begin
  WriteLn('[WARN] Cache corrupted, removing...');
  DeleteFile(ArchivePath);
  DeleteFile(MetaPath);
  if not OfflineMode then
    WriteLn('[INFO] Will re-download from network')
  else
    WriteLn('[FAIL] Cannot recover in offline mode');
end;
```

### 2. 磁盘空间不足

**检测**: 保存缓存前检查可用空间

**处理**:
```pascal
if GetDiskFreeSpace(CacheDir) < ArchiveSize * 1.2 then
begin
  WriteLn('[WARN] Low disk space in cache directory');
  WriteLn('[HINT] Run "fpdev fpc cache clean --all" to free space');
  Exit(False);
end;
```

### 3. 离线模式缓存未命中

**检测**: `OfflineMode = True` 且 `HasArtifacts = False`

**处理**:
```pascal
if OfflineMode and not Cache.HasArtifacts(Version) then
begin
  WriteLn('[FAIL] Cache miss for FPC ', Version);
  WriteLn('[HINT] Network disabled by --offline flag');
  WriteLn('[HINT] Available versions:');
  ShowCachedVersions(Cache);
  Exit;
end;
```

---

## 📊 实施里程碑

### Milestone 1: TBuildCache 扩展 (Week 1)
- [ ] 添加 `SaveBinaryArtifact()` 方法
- [ ] 添加 `RestoreBinaryArtifact()` 方法
- [ ] 添加 `GetBinaryArtifactInfo()` 方法
- [ ] 扩展 `TArtifactInfo` 记录
- [ ] 编写单元测试（TDD）
- [ ] 所有测试通过

### Milestone 2: FPC Install 集成 (Week 2)
- [ ] 修改 `fpdev.cmd.fpc.install.pas`
- [ ] 添加 `--offline` flag 支持
- [ ] 添加 `--no-cache` flag 支持
- [ ] 集成缓存检查逻辑
- [ ] 集成缓存保存逻辑
- [ ] 编写集成测试（TDD）
- [ ] 所有测试通过

### Milestone 3: 缓存管理命令 (Week 3)
- [ ] 创建 `fpdev.cmd.fpc.cache.pas`
- [ ] 实现 `cache list` 命令
- [ ] 实现 `cache clean` 命令
- [ ] 实现 `cache path` 命令
- [ ] 编写命令测试（TDD）
- [ ] 所有测试通过

### Milestone 4: 文档和发布 (Week 4)
- [ ] 更新 CLAUDE.md
- [ ] 更新 README.md
- [ ] 添加使用示例
- [ ] 更新 CHANGELOG.md
- [ ] 代码审查
- [ ] 发布 v2.1.0

---

## 🎯 验收标准

### 功能验收

1. **缓存保存**
   - ✅ 安装成功后自动保存到缓存
   - ✅ 元数据包含 SHA256 校验和
   - ✅ 缓存文件命名正确

2. **缓存恢复**
   - ✅ 缓存命中时秒级安装
   - ✅ SHA256 校验通过
   - ✅ 损坏缓存自动删除

3. **离线模式**
   - ✅ `--offline` flag 生效
   - ✅ 缓存未命中时友好报错
   - ✅ 不发起任何网络请求

4. **缓存管理**
   - ✅ `cache list` 显示所有版本
   - ✅ `cache clean` 清理指定版本
   - ✅ `cache path` 显示缓存目录

### 性能验收

- ✅ 缓存命中时安装时间 < 10 秒
- ✅ 缓存保存时间 < 30 秒
- ✅ 缓存列表响应时间 < 1 秒

### 测试覆盖率

- ✅ 单元测试覆盖率 > 90%
- ✅ 集成测试覆盖率 > 80%
- ✅ 所有测试用例通过

---

## 📚 参考资料

- **现有代码**: `src/fpdev.build.cache.pas` (TBuildCache 实现)
- **命令模式**: `src/fpdev.command.intf.pas` (ICommand 接口)
- **配置管理**: `src/fpdev.config.interfaces.pas` (配置接口)
- **测试示例**: `tests/test_config_management.lpr` (TDD 示例)

---

**最后更新**: 2026-01-16
**计划作者**: Claude Sonnet 4.5 + Gemini (UX 设计)
**审批状态**: 待用户批准
