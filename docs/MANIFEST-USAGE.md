# FPDev Manifest 系统使用指南

**版本**: 1.0
**日期**: 2026-01-19
**状态**: 生产就绪

---

## 目录

1. [概述](#概述)
2. [快速开始](#快速开始)
3. [基本使用](#基本使用)
4. [高级功能](#高级功能)
5. [故障排除](#故障排除)
6. [技术细节](#技术细节)

---

## 概述

### 什么是 Manifest 系统？

Manifest 系统是 FPDev 的核心组件，提供可靠、安全的 FPC 二进制包管理功能。它通过 JSON 格式的 manifest 文件记录所有可用版本的元数据，包括下载 URL、文件大小和 SHA256 hash 值。

### 主要特性

- **多镜像支持**: 自动在多个镜像之间切换，提高下载成功率
- **完整性验证**: SHA256 hash 验证确保下载文件完整性
- **自动缓存**: Manifest 文件自动缓存，减少网络请求
- **跨平台**: 支持 Linux、Windows、macOS 多个平台
- **安全可靠**: 所有下载通过 HTTPS，文件大小和 hash 双重验证

### 架构概览

```
用户命令
    ↓
fpdev fpc install
    ↓
Manifest 系统
    ├── 加载 manifest (缓存或下载)
    ├── 查找目标平台的包信息
    ├── 多镜像下载 (自动 fallback)
    ├── 文件大小验证
    ├── SHA256 hash 验证
    └── 提取并安装
```

---

## 快速开始

### 安装 FPC

最简单的使用方式：

```bash
# 安装最新版本 (3.2.2)
fpdev fpc install

# 安装特定版本
fpdev fpc install 3.2.0
```

Manifest 系统会自动：
1. 下载或使用缓存的 manifest 文件
2. 查找适合您平台的二进制包
3. 从多个镜像中选择最快的下载
4. 验证文件完整性
5. 安装到 `~/.fpdev/toolchains/fpc/<version>`

### 查看可用版本

```bash
# 列出所有可用版本
fpdev fpc list --all

# 查看当前安装的版本
fpdev fpc list
```

---

## 基本使用

### 更新 Manifest

Manifest 文件会自动缓存到 `~/.fpdev/cache/manifests/fpc.json`。如果需要手动更新：

```bash
# 强制更新 manifest
fpdev fpc update-manifest --force

# 查看 manifest 信息
cat ~/.fpdev/cache/manifests/fpc.json | jq .
```

### 安装流程详解

当您运行 `fpdev fpc install 3.2.0` 时，系统会：

1. **加载 Manifest**
   ```
   [Manifest] Loading manifest from cache...
   [Manifest] Manifest loaded successfully
   ```

2. **查找目标包**
   ```
   [Manifest] Platform: linux-x86_64
   [Manifest] Found target with 1 mirror(s)
   [Manifest] Hash: sha256:d19252e6cfe52f1217f4822a548ee699eaa7e044807aaf8429a0532cb7e4cb3d
   [Manifest] Size: 84336640 bytes
   ```

3. **下载并验证**
   ```
   [Manifest] Downloading with multi-mirror fallback...
   [Manifest] Download completed and verified
   ```

4. **提取安装**
   ```
   [Manifest] Extracting archive...
   [Manifest] Extraction completed
   ```

### 验证安装

```bash
# 验证 FPC 安装
fpdev fpc verify 3.2.0

# 使用已安装的 FPC
fpdev fpc use 3.2.0
fpc -version
```

---

## 高级功能

### 多镜像 Fallback

Manifest 系统支持为每个包配置多个下载镜像。当第一个镜像失败时，会自动切换到下一个镜像。

**Manifest 配置示例**:
```json
{
  "pkg": {
    "fpc": {
      "version": "3.2.2",
      "targets": {
        "linux-x86_64": {
          "url": [
            "https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.2/fpc-3.2.2-linux-x86_64.tar.gz",
            "https://gitee.com/dtamade/fpdev-fpc/releases/download/v3.2.2/fpc-3.2.2-linux-x86_64.tar.gz"
          ],
          "hash": "sha256:46c083c7308a6fb978f0244c0e2e7c4217210200232923f777fc4f0483ca1caf",
          "size": 85384375
        }
      }
    }
  }
}
```

**Fallback 流程**:
1. 尝试第一个镜像 (GitHub)
2. 如果失败（网络错误、404、超时），自动切换到第二个镜像 (Gitee)
3. 如果所有镜像都失败，报告错误

### 完整性验证

每个下载都会进行双重验证：

1. **文件大小验证**
   - 下载完成后立即检查文件大小
   - 如果不匹配，删除文件并尝试下一个镜像

2. **SHA256 Hash 验证**
   - 计算下载文件的 SHA256 hash
   - 与 manifest 中的 hash 比对
   - 如果不匹配，删除文件并尝试下一个镜像

### 自定义镜像配置

如果您在中国大陆，可以配置使用 Gitee 镜像：

```bash
# 配置使用 Gitee 镜像
fpdev system config set mirror gitee

# 配置使用 GitHub 镜像（默认）
fpdev system config set mirror github
```

---

## 故障排除

### 常见问题

#### 1. Manifest 下载失败

**症状**:
```
Error: Failed to download manifest: Connect to raw.githubusercontent.com:443 failed
```

**解决方案**:
```bash
# 方案 1: 检查网络连接
ping raw.githubusercontent.com

# 方案 2: 使用 Gitee 镜像
fpdev system config set mirror gitee

# 方案 3: 手动更新 manifest
fpdev fpc update-manifest --force
```

#### 2. 文件大小不匹配

**症状**:
```
[Manifest] Download failed: Size mismatch: expected 84934656 bytes, got 84336640 bytes
```

**解决方案**:
```bash
# 更新 manifest 到最新版本
fpdev fpc update-manifest --force

# 如果问题持续，报告 issue
# https://github.com/dtamade/fpdev/issues
```

#### 3. Hash 验证失败

**症状**:
```
[Manifest] Download failed: SHA256 hash mismatch
```

**解决方案**:
```bash
# 清除缓存并重新下载
rm -rf ~/.fpdev/cache/manifests/fpc.json
fpdev fpc install 3.2.0

# 如果问题持续，可能是镜像文件损坏
# 尝试使用其他镜像
fpdev system config set mirror gitee
```

#### 4. 所有镜像都失败

**症状**:
```
Error: All mirrors failed to download
```

**解决方案**:
```bash
# 检查网络连接
ping github.com
ping gitee.com

# 检查防火墙设置
# 确保允许 HTTPS 连接

# 作为最后手段，从源码安装
fpdev fpc install 3.2.0 --from-source
```

### 调试模式

如果需要查看详细的下载和验证过程：

```bash
# 查看安装日志
fpdev fpc install 3.2.0 2>&1 | tee install.log

# 检查 manifest 内容
cat ~/.fpdev/cache/manifests/fpc.json | jq '.pkg["fpc-3.2.0"]'
```

---

## 技术细节

### Manifest 文件格式

Manifest 文件使用 JSON 格式，结构如下：

```json
{
  "manifest-version": "1",
  "date": "2026-01-18",
  "pkg": {
    "fpc-3.2.0": {
      "version": "3.2.0",
      "targets": {
        "linux-x86_64": {
          "url": "https://github.com/dtamade/fpdev-fpc/releases/download/v3.2.0/fpc-3.2.0-x86_64-linux.tar",
          "hash": "sha256:d19252e6cfe52f1217f4822a548ee699eaa7e044807aaf8429a0532cb7e4cb3d",
          "size": 84336640
        }
      }
    }
  }
}
```

**字段说明**:
- `manifest-version`: Manifest 格式版本
- `date`: Manifest 更新日期
- `pkg`: 包信息字典
  - `fpc-3.2.0`: 包名和版本
    - `version`: 版本号
    - `targets`: 平台目标字典
      - `linux-x86_64`: 平台标识
        - `url`: 下载 URL（字符串或数组）
        - `hash`: SHA256 hash（格式：`sha256:<hex>`）
        - `size`: 文件大小（字节）

### 平台标识

FPDev 使用以下平台标识：

| 平台 | 标识 |
|------|------|
| Linux x86_64 | `linux-x86_64` |
| Linux i386 | `linux-i386` |
| Windows x86_64 | `windows-x86_64` |
| Windows i386 | `windows-i386` |
| macOS x86_64 | `darwin-x86_64` |
| macOS ARM64 | `darwin-aarch64` |

### 缓存机制

**Manifest 缓存**:
- 位置: `~/.fpdev/cache/manifests/fpc.json`
- 更新策略: 首次使用时下载，之后使用缓存
- 手动更新: `fpdev fpc update-manifest --force`

**二进制缓存**:
- 当前版本的 manifest 系统主要缓存 manifest 文件
- 二进制文件缓存功能可作为未来优化项

### HTTP 客户端配置

Manifest 系统使用 TFPHTTPClient 进行下载，配置如下：

```pascal
Cli.AllowRedirect := True;  // 启用 HTTP 重定向
Cli.ConnectTimeout := 30000; // 连接超时 30 秒
Cli.IOTimeout := 30000;      // IO 超时 30 秒
```

### 安全考虑

1. **HTTPS Only**: 所有下载必须通过 HTTPS
2. **Hash 验证**: 强制 SHA256 hash 验证
3. **文件大小验证**: 防止部分下载
4. **原子替换**: 使用临时文件，下载完成后原子替换

---

## 相关文档

- [Week 6 计划](WEEK6-PLAN.md) - Week 6 详细计划
- [Week 6 问题](WEEK6-ISSUES.md) - 问题诊断和解决方案
- [Week 6 进度](WEEK6-PROGRESS.md) - 进度报告
- [Week 6 总结](WEEK6-SUMMARY.md) - Week 6 总结

---

## 贡献

如果您发现 manifest 系统的问题或有改进建议，请：

1. 报告 Issue: https://github.com/dtamade/fpdev/issues
2. 提交 Pull Request: https://github.com/dtamade/fpdev/pulls
3. 更新 Manifest: https://github.com/dtamade/fpdev-fpc

---

**维护者**: FPDev 开发团队
**最后更新**: 2026-01-19
**版本**: 1.0
