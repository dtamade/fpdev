# Week 5 计划：端到端集成和 CLI 命令

**日期**: 2026-01-18
**状态**: 🚧 进行中

---

## 目标

Week 5 的目标是完成 manifest 系统的端到端集成，实现用户友好的 CLI 命令，并进行完整的集成测试。

---

## 任务列表

### 1. 实现 Manifest 管理 CLI 命令

#### 1.1 `fpdev fpc update-manifest` 命令
- **功能**: 从远程仓库下载最新的 manifest.json
- **实现位置**: `src/fpdev.cmd.fpc.update_manifest.pas`
- **行为**:
  - 从 GitHub 下载 `fpdev-fpc/manifest.json`
  - 缓存到本地 `<data-root>/cache/manifests/fpc.json`
  - 支持 `--force` 强制更新
  - 显示下载进度和验证结果

#### 1.2 `fpdev fpc list --remote` 命令
- **功能**: 从 manifest 列出所有可用版本
- **实现位置**: 修改 `src/fpdev.cmd.fpc.list.pas`
- **行为**:
  - 读取本地缓存的 manifest
  - 如果没有缓存，自动调用 update-manifest
  - 显示版本号、平台支持、文件大小
  - 标记已安装的版本

#### 1.3 `fpdev fpc install <version>` 增强
- **功能**: 使用 manifest 安装 FPC
- **实现位置**: 修改 `src/fpdev.cmd.fpc.install.pas`
- **行为**:
  - 优先从 manifest 获取下载信息
  - 如果 manifest 不存在，自动调用 update-manifest
  - 显示多镜像 fallback 过程
  - 验证 SHA256/SHA512 哈希

### 2. Manifest 缓存管理

#### 2.1 本地缓存结构
```
<data-root>/cache/manifests/
├── fpc.json              # FPC manifest
├── lazarus.json          # Lazarus manifest
├── bootstrap.json        # Bootstrap manifest
└── cross.json            # Cross-compilation manifest
```

#### 2.2 缓存策略
- **TTL**: 24 小时（可配置）
- **自动更新**: 如果缓存过期，自动下载
- **离线模式**: 如果网络不可用，使用过期缓存

### 3. 端到端集成测试

#### 3.1 测试场景
1. **首次安装流程**:
   - 用户运行 `fpdev fpc install 3.2.2`
   - 自动下载 manifest
   - 从 manifest 获取 URL 和 hash
   - 下载并验证二进制包
   - 安装到系统

2. **多镜像 fallback**:
   - 主 URL 失败
   - 自动尝试镜像 URL
   - 所有 URL 都验证 hash

3. **离线安装**:
   - 使用缓存的 manifest
   - 使用缓存的二进制包
   - 完全离线安装

#### 3.2 测试实现
- **文件**: `tests/test_manifest_integration.lpr`
- **覆盖**:
  - Manifest 下载和缓存
  - 版本列表显示
  - 完整安装流程
  - 错误处理（网络失败、hash 不匹配等）

### 4. 用户文档更新

#### 4.1 README.md 更新
- 添加 manifest 系统说明
- 更新安装命令示例
- 添加离线安装说明

#### 4.2 新增文档
- `docs/MANIFEST-USAGE.md`: 用户使用指南
- `docs/MANIFEST-HOSTING.md`: Manifest 托管指南

---

## 技术实现细节

### Manifest 下载实现

```pascal
function DownloadManifest(const APackage: string; out AError: string): Boolean;
var
  URL: string;
  CachePath: string;
  HTTP: TFPHTTPClient;
begin
  Result := False;

  // 构建 URL
  URL := Format('https://raw.githubusercontent.com/dtamade/fpdev-%s/main/manifest.json', [APackage]);

  // 缓存路径
  CachePath := GetManifestCachePath(APackage);
  EnsureDir(ExtractFileDir(CachePath));

  // 下载
  HTTP := TFPHTTPClient.Create(nil);
  try
    HTTP.Get(URL, CachePath);
    Result := True;
  except
    on E: Exception do
      AError := E.Message;
  end;
end;
```

### Manifest 缓存读取

```pascal
function LoadCachedManifest(const APackage: string; out AManifest: TManifestParser): Boolean;
var
  CachePath: string;
  Age: Integer;
begin
  Result := False;

  CachePath := GetManifestCachePath(APackage);
  if not FileExists(CachePath) then
    Exit;

  // 检查缓存年龄
  Age := GetFileAge(CachePath);
  if Age > MANIFEST_CACHE_TTL then
  begin
    // 缓存过期，尝试更新
    if not DownloadManifest(APackage, Err) then
    begin
      // 网络失败，使用过期缓存
      WriteLn('Warning: Using expired manifest cache');
    end;
  end;

  // 加载 manifest
  AManifest := TManifestParser.Create;
  Result := AManifest.LoadFromFile(CachePath);
end;
```

---

## 验收标准

### 功能验收
- ✅ `fpdev fpc update-manifest` 成功下载并缓存 manifest
- ✅ `fpdev fpc list --remote` 显示所有可用版本
- ✅ `fpdev fpc install 3.2.2` 使用 manifest 完成安装
- ✅ 多镜像 fallback 正常工作
- ✅ 离线模式正常工作

### 测试验收
- ✅ 所有单元测试通过（57 + 新增测试）
- ✅ 端到端集成测试通过
- ✅ 错误处理测试通过

### 文档验收
- ✅ README.md 更新完成
- ✅ MANIFEST-USAGE.md 编写完成
- ✅ 所有命令有 help 文档

---

## 时间线

### Phase 5.1: CLI 命令实现（预计 1-2 天）
- 实现 update-manifest 命令
- 实现 list --remote 命令
- 增强 install 命令

### Phase 5.2: 缓存管理（预计 1 天）
- 实现缓存读写
- 实现 TTL 检查
- 实现离线模式

### Phase 5.3: 集成测试（预计 1 天）
- 编写端到端测试
- 测试所有场景
- 修复发现的问题

### Phase 5.4: 文档更新（预计 0.5 天）
- 更新 README.md
- 编写使用指南
- 更新命令帮助

---

## 依赖关系

### 已完成（Week 1-4）
- ✅ Manifest 规范定义
- ✅ Manifest parser 实现（57 tests）
- ✅ SHA512 支持
- ✅ Manifest 集成到 installer
- ✅ 所有仓库迁移到新格式

### Week 5 依赖
- fpdev.manifest.pas (已完成)
- fpdev.fpc.installer.pas (已完成)
- fpdev.toolchain.fetcher.pas (已完成)
- fpdev.command.registry.pas (已完成)

---

## 风险和缓解

### 风险 1: 网络不稳定
- **缓解**: 实现多镜像 fallback
- **缓解**: 实现离线模式

### 风险 2: Manifest 格式变更
- **缓解**: 版本检查（manifest-version 字段）
- **缓解**: 向后兼容性测试

### 风险 3: 缓存损坏
- **缓解**: 验证 JSON 格式
- **缓解**: 自动重新下载

---

## 后续工作（Week 6+）

### 可能的增强
1. **Manifest 签名验证**: 使用 minisign/GPG 验证 manifest 完整性
2. **增量更新**: 支持 delta 下载
3. **并行下载**: 同时下载多个文件
4. **进度条优化**: 更好的下载进度显示
5. **自动更新检查**: 定期检查新版本

---

**维护者**: FPDev 开发团队
**最后更新**: 2026-01-18
