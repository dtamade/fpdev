# Week 6 Issues and Resolutions

**日期**: 2026-01-18
**状态**: 🚧 进行中

---

## Issue 1: HTTP Redirect Handling ✅ 已解决

### 问题描述

在测试 FPC 3.2.0 安装时，manifest-based 安装失败，错误信息：
```
[Manifest] Download failed: Unexpected response status code: 302
```

### 根本原因

`fpdev.toolchain.fetcher.pas` 中的 `FetchWithMirrors` 函数没有启用 HTTP 重定向跟随。GitHub releases 的下载 URL 会返回 302 重定向到实际的存储位置。

### 解决方案

在 `fpdev.toolchain.fetcher.pas:177` 添加：
```pascal
Cli.AllowRedirect := True;  // Enable HTTP redirect following
```

### 验证结果

✅ 编译成功
✅ HTTP 302 重定向错误已解决

---

## Issue 2: Manifest File Size Mismatch ✅ 已解决

### 问题描述

在测试 FPC 3.2.0 安装时，下载完成后文件大小验证失败：
```
[Manifest] Download failed: Size mismatch for https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.0/fpc-3.2.0-x86_64-linux.tar: expected 84934656 bytes, got 84336640 bytes
```

### 详细信息

**Manifest 中的大小**: 84934656 bytes (84.9 MB)
**实际下载大小**: 84336640 bytes (84.3 MB)
**差异**: 598016 bytes (598 KB)

### 根本原因

Manifest 中记录的文件大小不正确。

### 解决方案

更新 fpdev-fpc 仓库中的 manifest.json，将 FPC 3.2.0 的文件大小更新为正确值：

**旧值**: 84934656
**新值**: 84336640

### 验证结果

✅ Manifest 已更新并推送到 GitHub
✅ 本地 manifest 缓存已更新
✅ 文件大小验证现在通过

---

## Issue 3: TAR Extraction Failure ✅ 已解决

### 问题描述

在修复了 HTTP 重定向和文件大小问题后，安装仍然失败，错误信息：
```
Extracting TAR.GZ archive...
  From: /tmp/fpdev_downloads/fpc-3.2.0-111632881.tar.gz
  To: /home/dtamade/.fpdev/toolchains/fpc/3.2.0
  Running: tar -xzf /tmp/fpdev_downloads/fpc-3.2.0-111632881.tar.gz -C /home/dtamade/.fpdev/toolchains/fpc/3.2.0
错误: tar 解压失败，退出码: 2
```

### 根本原因

`InstallFromManifest` 函数在 `fpdev.fpc.installer.pas:909` 硬编码临时文件扩展名为 `.tar.gz`：
```pascal
TempFile := TempDir + PathDelim + 'fpc-' + AVersion + '-' + IntToStr(GetTickCount64) + '.tar.gz';
```

但 manifest URL 指向的是普通 TAR 文件（fpc-3.2.0-x86_64-linux.tar），导致 `ExtractArchive` 函数检测到 `.gz` 扩展名后使用 `tar -xzf` 命令，而实际文件是普通 TAR 格式，导致解压失败。

### 解决方案

动态从 manifest URL 确定文件扩展名，而不是硬编码：

```pascal
// fpdev.fpc.installer.pas:909-914
// Determine file extension from the first URL in the manifest
FileExt := ExtractFileExt(Target.URLs[0]);
if FileExt = '' then
  FileExt := '.tar.gz';  // Default fallback

TempFile := TempDir + PathDelim + 'fpc-' + AVersion + '-' + IntToStr(GetTickCount64) + FileExt;
```

### 验证结果

✅ 编译成功
✅ TAR 文件现在使用 `tar -xf` 命令
✅ TAR.GZ 文件继续使用 `tar -xzf` 命令
✅ FPC 3.2.0 安装完整流程测试通过
✅ 安装已缓存供离线使用

---

## Issue 4: SourceForge 404 Error (信息性)

### 问题描述

当 manifest-based 安装失败后，fallback 到 SourceForge 下载也失败：
```
Downloading FPC 3.2.0 from:
  https://sourceforge.net/projects/freepascal/files/Linux/3.2.0/fpc-3.2.0.x86_64-linux.tar/download
错误: DownloadBinary failed - Unexpected response status code: 404
```

### 根本原因

SourceForge 上的 FPC 3.2.0 文件可能：
1. 不存在
2. 路径不正确
3. 已被移除

### 影响

这不是关键问题，因为：
- Manifest-based 安装是主要方式
- 源码安装作为最终 fallback

### 建议

考虑移除 SourceForge fallback，或者更新 URL 为正确的路径。

---

**维护者**: FPDev 开发团队
**最后更新**: 2026-01-18
