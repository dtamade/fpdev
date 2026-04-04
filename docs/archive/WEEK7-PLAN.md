# Week 7 计划：性能优化和二进制缓存

**日期**: 2026-01-19
**状态**: 🚀 进行中
**优先级**: 高
**预期完成度**: 100%

---

## 目录

1. [概述](#概述)
2. [Week 6 回顾](#week-6-回顾)
3. [Week 7 目标](#week-7-目标)
4. [性能分析](#性能分析)
5. [二进制缓存设计](#二进制缓存设计)
6. [实施计划](#实施计划)
7. [测试策略](#测试策略)
8. [成功标准](#成功标准)

---

## 概述

Week 7 专注于 FPDev manifest 系统的性能优化和二进制缓存功能实现。基于 Week 6 的成功（manifest 系统已生产就绪），我们现在要提升用户体验，减少下载时间，实现离线安装能力。

**核心目标**:
- 🚀 优化 manifest 下载速度
- 💾 实现完整的二进制缓存功能
- ⚡ 添加并行下载支持
- 📊 提供缓存管理命令

---

## Week 6 回顾

### 已完成的工作

**核心修复（3 个关键问题）**:
- ✅ HTTP 重定向处理修复
- ✅ Manifest 文件大小不匹配修复
- ✅ TAR 提取失败修复

**测试验证（12 个测试场景）**:
- ✅ 完整安装流程测试（端到端）
- ✅ 多镜像 Fallback 测试（代码审查 + 端到端）
- ✅ 离线模式测试（代码审查）
- ✅ 边缘情况测试（5 个场景，代码审查）

**文档完成（8 个文档，2000+ 行）**:
- ✅ Week 6 规划和进度文档
- ✅ 用户使用指南（MANIFEST-USAGE.md）
- ✅ 测试文档（多镜像、离线模式、边缘情况）

**状态**: Manifest 系统已生产就绪

### 发现的性能问题

从 Week 6 的测试中，我们发现了以下性能瓶颈：

1. **重复下载问题**
   - 每次安装都需要重新下载二进制包
   - FPC 3.2.0 二进制包大小：84.3 MB
   - 在网络较慢的环境下，下载时间较长

2. **缓存机制不完整**
   - 当前只缓存 manifest 文件（8 KB）
   - 二进制包未缓存，无法离线安装
   - 缺少缓存管理命令

3. **串行下载**
   - 当前下载是串行的（一个镜像失败后才尝试下一个）
   - 无法利用多个镜像的并行下载能力

---

## Week 7 目标

### 主要目标

#### 1. 二进制缓存功能 ⭐⭐⭐

**目标**: 实现完整的二进制缓存系统，支持离线安装

**功能需求**:
- 下载后自动缓存二进制包
- 安装前检查缓存，优先使用缓存
- 支持 `--offline` 标志强制使用缓存
- 支持 `--no-cache` 标志跳过缓存

**技术实现**:
- 使用 `fpdev.build.cache.pas` 中的 `TBuildCache` 类
- 缓存目录：`<data-root>/cache/`
- 缓存格式：`fpc-{version}-{cpu}-{os}.tar.gz`
- 元数据文件：`fpc-{version}-{cpu}-{os}.meta`

**预期效果**:
- 首次安装：正常下载 + 自动缓存
- 二次安装：直接从缓存恢复（0 下载时间）
- 离线模式：完全离线安装

#### 2. 缓存管理命令 ⭐⭐

**目标**: 提供用户友好的缓存管理命令

**命令列表**:
```bash
# 列出所有缓存的版本
fpdev fpc cache list

# 显示缓存统计信息
fpdev fpc cache stats

# 清理特定版本的缓存
fpdev fpc cache clean <version>

# 清理所有缓存
fpdev fpc cache clean --all

# 显示缓存目录路径
fpdev fpc cache path

# 验证缓存完整性
fpdev fpc cache verify <version>
```

**实现文件**:
- `src/fpdev.cmd.fpc.cache.list.pas`
- `src/fpdev.cmd.fpc.cache.stats.pas`
- `src/fpdev.cmd.fpc.cache.clean.pas`
- `src/fpdev.cmd.fpc.cache.path.pas`
- `src/fpdev.cmd.fpc.cache.verify.pas`

#### 3. 性能优化 ⭐⭐

**目标**: 优化下载速度和用户体验

**优化项**:
- Manifest 缓存优化（已完成）
- 下载进度显示
- 并行下载支持（可选，Week 8）
- 断点续传支持（可选，Week 8）

#### 4. 测试和文档 ⭐

**目标**: 确保功能稳定可靠

**测试场景**:
- 二进制缓存保存和恢复
- 离线模式安装
- 缓存管理命令
- 缓存完整性验证

**文档**:
- Week 7 进度报告
- 二进制缓存使用指南
- 缓存管理命令文档
- Week 7 总结

---

## 性能分析

### 当前性能基线

**FPC 3.2.0 安装流程（Week 6 测试）**:

| 阶段 | 时间 | 说明 |
|------|------|------|
| Manifest 下载 | ~1s | 8 KB，已缓存 |
| 二进制下载 | ~30s | 84.3 MB，取决于网络速度 |
| Hash 验证 | ~2s | SHA256 计算 |
| TAR 提取 | ~5s | 解压到安装目录 |
| 环境配置 | ~1s | 更新配置文件 |
| **总计** | **~39s** | 首次安装 |

**性能瓶颈**:
1. **二进制下载**：占用 77% 的时间（30s / 39s）
2. **TAR 提取**：占用 13% 的时间（5s / 39s）
3. **Hash 验证**：占用 5% 的时间（2s / 39s）

### 优化目标

**二进制缓存后的性能**:

| 阶段 | 首次安装 | 二次安装（缓存命中） | 改进 |
|------|---------|-------------------|------|
| Manifest 下载 | ~1s | ~0s（缓存） | - |
| 二进制下载 | ~30s | ~0s（缓存） | **-30s** |
| Hash 验证 | ~2s | ~2s | - |
| TAR 提取 | ~5s | ~5s | - |
| 环境配置 | ~1s | ~1s | - |
| **总计** | **~39s** | **~8s** | **-79%** |

**预期改进**:
- 二次安装时间减少 79%（39s → 8s）
- 完全离线安装支持
- 网络流量减少 100%（缓存命中时）

---

## 二进制缓存设计

### 架构设计

```
用户命令
    ↓
fpdev fpc install 3.2.0
    ↓
安装流程
    ├── 1. 检查缓存
    │   ├── HasArtifacts(version) → 是否有缓存？
    │   ├── 是 → RestoreBinaryArtifact(version, dest)
    │   └── 否 → 继续下载
    ├── 2. 下载二进制（如果缓存未命中）
    │   ├── FetchWithMirrors(urls, dest, opts)
    │   └── 验证文件大小和 hash
    ├── 3. 保存到缓存
    │   └── SaveBinaryArtifact(version, file)
    ├── 4. 提取安装
    │   └── ExtractArchive(archive, dest)
    └── 5. 环境配置
        └── SetupEnvironment(version, path)
```

### 缓存结构

**缓存目录**:
```
<data-root>/cache/
├── manifests/
│   └── fpc.json                           # Manifest 缓存（已实现）
├── binaries/
│   ├── fpc-3.2.0-x86_64-linux.tar         # 二进制缓存
│   ├── fpc-3.2.0-x86_64-linux.meta        # 元数据
│   ├── fpc-3.2.2-x86_64-linux.tar.gz      # 二进制缓存
│   └── fpc-3.2.2-x86_64-linux.meta        # 元数据
└── cache-index.json                       # 缓存索引（可选）
```

**元数据文件格式** (`.meta`):
```
version=3.2.0
cpu=x86_64
os=linux
archive_path=<data-root>/cache/binaries/fpc-3.2.0-x86_64-linux.tar
archive_size=84336640
created_at=2026-01-19T10:30:00Z
source_type=binary
sha256=d19252e6cfe52f1217f4822a548ee699eaa7e044807aaf8429a0532cb7e4cb3d
download_url=https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.0/fpc-3.2.0-x86_64-linux.tar
```

### 核心 API

**TBuildCache 类扩展**:

```pascal
// 保存二进制包到缓存
function SaveBinaryArtifact(const AVersion, AFilePath: string): Boolean;

// 从缓存恢复二进制包
function RestoreBinaryArtifact(const AVersion, ADestPath: string): Boolean;

// 检查缓存是否存在
function HasArtifacts(const AVersion: string): Boolean;

// 获取缓存信息
function GetBinaryArtifactInfo(const AVersion: string): TArtifactInfo;

// 删除缓存
function DeleteArtifacts(const AVersion: string): Boolean;

// 验证缓存完整性
function VerifyArtifact(const AVersion: string): Boolean;

// 获取缓存统计
function GetCacheStats: TCacheIndexStats;

// 列出所有缓存
function ListArtifacts: TStringArray;
```

### 安装流程集成

**修改 `fpdev.fpc.installer.pas`**:

```pascal
function TFPCBinaryInstaller.InstallFromBinary(const AVersion: string;
  const APrefix: string = ''): Boolean;
var
  Cache: TBuildCache;
  TempFile: string;
  InstallPath: string;
begin
  Result := False;

  // 1. 检查缓存
  Cache := TBuildCache.Create;
  try
    if Cache.HasArtifacts(AVersion) and (not FNoCache) then
    begin
      FOut.WriteLn('[CACHE] Using cached binary for FPC ' + AVersion);

      // 从缓存恢复
      TempFile := GetTempDir + PathDelim + 'fpc-' + AVersion + '.tar';
      if Cache.RestoreBinaryArtifact(AVersion, TempFile) then
      begin
        // 提取安装
        InstallPath := GetVersionInstallPath(AVersion);
        if ExtractArchive(TempFile, InstallPath) then
        begin
          SetupEnvironment(AVersion, InstallPath);
          DeleteFile(TempFile);
          Exit(True);
        end;
      end;
    end;

    // 2. 缓存未命中，下载二进制
    if FOfflineMode then
    begin
      FErr.WriteLn('[ERROR] Offline mode enabled but cache not found');
      Exit(False);
    end;

    FOut.WriteLn('[DOWNLOAD] Downloading FPC ' + AVersion + '...');
    if not InstallFromManifest(AVersion, InstallPath) then
      Exit(False);

    // 3. 保存到缓存
    if not FNoCache then
    begin
      FOut.WriteLn('[CACHE] Saving to cache...');
      Cache.SaveBinaryArtifact(AVersion, TempFile);
    end;

    Result := True;
  finally
    Cache.Free;
  end;
end;
```

---

## 实施计划

### Phase 1: 二进制缓存核心功能（优先级：高）

**任务**:
1. ✅ 分析现有 `fpdev.build.cache.pas` 代码
2. 扩展 `TBuildCache` 类，添加二进制缓存 API
3. 实现 `SaveBinaryArtifact` 方法
4. 实现 `RestoreBinaryArtifact` 方法
5. 实现 `HasArtifacts` 方法
6. 实现 `GetBinaryArtifactInfo` 方法

**文件**:
- `src/fpdev.build.cache.pas`（修改）

**测试**:
- 单元测试：缓存保存和恢复
- 集成测试：完整安装流程

### Phase 2: 安装流程集成（优先级：高）

**任务**:
1. 修改 `fpdev.fpc.installer.pas`
2. 在 `InstallFromBinary` 中集成缓存检查
3. 添加 `--offline` 标志支持
4. 添加 `--no-cache` 标志支持
5. 添加缓存命中日志输出

**文件**:
- `src/fpdev.fpc.installer.pas`（修改）
- `src/fpdev.cmd.fpc.install.pas`（修改）

**测试**:
- 端到端测试：首次安装 + 缓存保存
- 端到端测试：二次安装 + 缓存恢复
- 端到端测试：离线模式安装

### Phase 3: 缓存管理命令（优先级：中）

**任务**:
1. 创建 `fpdev fpc cache list` 命令
2. 创建 `fpdev fpc cache stats` 命令
3. 创建 `fpdev fpc cache clean` 命令
4. 创建 `fpdev fpc cache path` 命令
5. 创建 `fpdev fpc cache verify` 命令

**文件**:
- `src/fpdev.cmd.fpc.cache.pas`（新建，根命令）
- `src/fpdev.cmd.fpc.cache.list.pas`（新建）
- `src/fpdev.cmd.fpc.cache.stats.pas`（新建）
- `src/fpdev.cmd.fpc.cache.clean.pas`（新建）
- `src/fpdev.cmd.fpc.cache.path.pas`（新建）
- `src/fpdev.cmd.fpc.cache.verify.pas`（新建）

**测试**:
- 功能测试：每个命令的基本功能
- 集成测试：命令与缓存系统的交互

### Phase 4: 测试和文档（优先级：中）

**任务**:
1. 编写二进制缓存测试
2. 编写离线模式测试
3. 编写缓存管理命令测试
4. 创建 Week 7 进度报告
5. 更新 MANIFEST-USAGE.md
6. 创建 Week 7 总结

**文件**:
- `tests/test_binary_cache.lpr`（新建）
- `docs/WEEK7-PROGRESS.md`（新建）
- `docs/WEEK7-SUMMARY.md`（新建）
- `docs/MANIFEST-USAGE.md`（更新）

---

## 测试策略

### 单元测试

**测试文件**: `tests/test_binary_cache.lpr`

**测试场景**:
1. `SaveBinaryArtifact` - 保存二进制到缓存
2. `RestoreBinaryArtifact` - 从缓存恢复二进制
3. `HasArtifacts` - 检查缓存是否存在
4. `GetBinaryArtifactInfo` - 获取缓存元数据
5. `DeleteArtifacts` - 删除缓存
6. `VerifyArtifact` - 验证缓存完整性
7. `GetCacheStats` - 获取缓存统计
8. `ListArtifacts` - 列出所有缓存

### 集成测试

**测试场景**:
1. **首次安装 + 缓存保存**
   - 安装 FPC 3.2.0
   - 验证缓存已创建
   - 验证元数据正确

2. **二次安装 + 缓存恢复**
   - 删除安装目录
   - 重新安装 FPC 3.2.0
   - 验证从缓存恢复
   - 验证安装成功

3. **离线模式安装**
   - 断开网络（模拟）
   - 使用 `--offline` 标志安装
   - 验证从缓存安装成功

4. **缓存管理命令**
   - 测试 `cache list` 命令
   - 测试 `cache stats` 命令
   - 测试 `cache clean` 命令
   - 测试 `cache verify` 命令

### 端到端测试

**测试流程**:
```bash
# 1. 清理环境
rm -rf <data-root>/cache/binaries
rm -rf <data-root>/toolchains/fpc/3.2.0

# 2. 首次安装（应该下载并缓存）
time ./bin/fpdev fpc install 3.2.0
# 预期：~39s，缓存已创建

# 3. 验证缓存
./bin/fpdev fpc cache list
# 预期：显示 FPC 3.2.0

# 4. 删除安装目录
rm -rf <data-root>/toolchains/fpc/3.2.0

# 5. 二次安装（应该从缓存恢复）
time ./bin/fpdev fpc install 3.2.0
# 预期：~8s，从缓存恢复

# 6. 验证安装
./bin/fpdev fpc verify 3.2.0
# 预期：验证成功

# 7. 离线模式测试
rm -rf <data-root>/toolchains/fpc/3.2.0
./bin/fpdev fpc install 3.2.0 --offline
# 预期：从缓存安装成功

# 8. 清理缓存
./bin/fpdev fpc cache clean 3.2.0
# 预期：缓存已删除
```

---

## 成功标准

### 功能完整性

- ✅ 二进制缓存保存功能正常工作
- ✅ 二进制缓存恢复功能正常工作
- ✅ 离线模式安装功能正常工作
- ✅ 缓存管理命令全部实现
- ✅ 缓存完整性验证功能正常工作

### 性能指标

- ✅ 二次安装时间减少 70% 以上（39s → <12s）
- ✅ 缓存命中率 100%（相同版本重复安装）
- ✅ 缓存验证时间 <3s

### 用户体验

- ✅ 清晰的缓存命中日志输出
- ✅ 友好的缓存管理命令
- ✅ 完整的错误处理和提示
- ✅ 完善的用户文档

### 代码质量

- ✅ 所有新代码通过编译
- ✅ 所有单元测试通过
- ✅ 所有集成测试通过
- ✅ 代码审查通过

---

## 风险和缓解措施

### 风险 1: 缓存损坏

**描述**: 缓存文件可能因磁盘错误或中断而损坏

**缓解措施**:
- 使用 SHA256 验证缓存完整性
- 提供 `cache verify` 命令检测损坏
- 损坏时自动删除并重新下载

### 风险 2: 磁盘空间不足

**描述**: 缓存可能占用大量磁盘空间

**缓解措施**:
- 提供 `cache stats` 命令显示空间占用
- 提供 `cache clean` 命令清理缓存
- 考虑添加缓存大小限制（Week 8）

### 风险 3: 平台兼容性

**描述**: 不同平台的缓存格式可能不兼容

**缓解措施**:
- 缓存文件名包含平台信息（cpu-os）
- 元数据文件记录平台信息
- 跨平台测试

---

## 时间线

**Week 7 时间线**:

| 阶段 | 任务 | 状态 |
|------|------|------|
| Phase 1 | 二进制缓存核心功能 | 🚀 进行中 |
| Phase 2 | 安装流程集成 | ⏸️ 待开始 |
| Phase 3 | 缓存管理命令 | ⏸️ 待开始 |
| Phase 4 | 测试和文档 | ⏸️ 待开始 |

---

## 参考资料

**相关文档**:
- [Week 6 总结](WEEK6-SUMMARY.md)
- [Manifest 使用指南](MANIFEST-USAGE.md)
- [Week 6 离线模式测试](WEEK6-OFFLINE-MODE-TEST.md)

**相关代码**:
- `src/fpdev.build.cache.pas` - 缓存管理
- `src/fpdev.fpc.installer.pas` - FPC 安装
- `src/fpdev.cmd.fpc.install.pas` - 安装命令

---

**维护者**: FPDev 开发团队
**创建日期**: 2026-01-19
**最后更新**: 2026-01-19
**状态**: 🚀 Week 7 进行中
