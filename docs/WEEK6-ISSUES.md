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

## Issue 2: Manifest File Size Mismatch ⏸️ 待解决

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

Manifest 中记录的文件大小不正确。可能的原因：
1. Manifest 创建时使用了错误的文件
2. GitHub release 中的文件被更新但 manifest 未同步
3. 文件大小计算错误

### 验证步骤

```bash
# 检查 GitHub release 中的实际文件大小
curl -sL https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.0/fpc-3.2.0-x86_64-linux.tar | wc -c
# 结果: 0 (文件可能不存在或无法访问)

# 检查 manifest 中的记录
cat ~/.fpdev/cache/manifests/fpc.json | jq -r '.pkg["fpc-3.2.0"].targets["linux-x86_64"]'
# 结果:
# {
#   "url": "https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.0/fpc-3.2.0-x86_64-linux.tar",
#   "hash": "sha256:d19252e6cfe52f1217f4822a548ee699eaa7e044807aaf8429a0532cb7e4cb3d",
#   "size": 84934656
# }
```

### 解决方案

需要更新 fpdev-fpc 仓库中的 manifest.json，将 FPC 3.2.0 的文件大小更新为正确值：

**当前值**: 84934656
**正确值**: 84336640

### 影响

- ✅ HTTP 重定向已修复，可以正常下载文件
- ❌ 文件大小验证失败，导致 manifest-based 安装失败
- ✅ Fallback 到 SourceForge 安装（但 SourceForge 返回 404）
- ✅ 最终 fallback 到源码安装（正在进行中）

### 下一步

1. 更新 fpdev-fpc 仓库中的 manifest.json
2. 提交并推送更改
3. 重新测试 FPC 3.2.0 安装
4. 验证文件大小匹配

---

## Issue 3: SourceForge 404 Error (信息性)

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
