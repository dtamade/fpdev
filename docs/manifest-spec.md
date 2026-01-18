# FPDev Manifest 文件格式规范 v1.0

## 概述

Manifest 文件是 FPDev 用于管理 FPC 二进制包的元数据文件，包含版本信息、下载 URL、校验和等关键信息。本规范定义了 manifest 文件的格式和使用方式。

**设计目标**：
- 提供完整的包完整性验证（SHA256/SHA512）
- 支持多镜像 fallback 机制
- 版本化格式，便于未来扩展
- 易于人工阅读和机器解析

**参考**：本规范参考了 Rust 的 rustup channel manifest 设计。

---

## 文件格式

Manifest 文件使用 JSON 格式，UTF-8 编码。

### 基本结构

```json
{
  "manifest-version": "1",
  "date": "2026-01-18",
  "pkg": {
    "fpc": {
      "version": "3.2.2",
      "targets": {
        "linux-x86_64": {
          "url": "https://sourceforge.net/projects/freepascal/files/3.2.2/fpc-3.2.2.linux-x86_64.tar.gz",
          "hash": "sha256:abc123...",
          "size": 123456789
        }
      }
    }
  }
}
```

---

## 字段说明

### 顶层字段

#### `manifest-version` (必需)
- **类型**：字符串
- **说明**：Manifest 格式版本号
- **当前版本**：`"1"`
- **用途**：用于向后兼容性检查

#### `date` (必需)
- **类型**：字符串（ISO 8601 日期格式）
- **说明**：Manifest 生成日期
- **格式**：`YYYY-MM-DD`
- **示例**：`"2026-01-18"`

#### `pkg` (必需)
- **类型**：对象
- **说明**：包含所有软件包的元数据
- **子字段**：
  - `fpc`: FPC 编译器包
  - `lazarus`: Lazarus IDE 包（未来支持）

---

### FPC 包字段

#### `version` (必需)
- **类型**：字符串
- **说明**：FPC 版本号
- **格式**：`major.minor.patch` 或 `main`（开发版）
- **示例**：`"3.2.2"`, `"3.2.0"`, `"main"`

#### `targets` (必需)
- **类型**：对象
- **说明**：不同平台的二进制包信息
- **键名格式**：`{os}-{cpu}`
- **支持的平台**：
  - `linux-x86_64`
  - `linux-i386`
  - `linux-aarch64`
  - `windows-x86_64`
  - `windows-i386`
  - `darwin-x86_64`
  - `darwin-aarch64`
  - `freebsd-x86_64`

---

### Target 字段

#### `url` (必需)
- **类型**：字符串或字符串数组
- **说明**：下载 URL（支持多镜像）
- **单镜像示例**：
  ```json
  "url": "https://sourceforge.net/projects/freepascal/files/3.2.2/fpc-3.2.2.linux-x86_64.tar.gz"
  ```
- **多镜像示例**：
  ```json
  "url": [
    "https://sourceforge.net/projects/freepascal/files/3.2.2/fpc-3.2.2.linux-x86_64.tar.gz",
    "https://github.com/fpc/releases/download/v3.2.2/fpc-3.2.2.linux-x86_64.tar.gz",
    "https://gitee.com/freepascal/fpc/releases/download/v3.2.2/fpc-3.2.2.linux-x86_64.tar.gz"
  ]
  ```

#### `hash` (必需)
- **类型**：字符串
- **说明**：文件校验和
- **格式**：`{algorithm}:{hex_digest}`
- **支持的算法**：
  - `sha256`: SHA-256（推荐）
  - `sha512`: SHA-512（更安全）
- **示例**：
  ```json
  "hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  ```

#### `size` (必需)
- **类型**：整数
- **说明**：文件大小（字节）
- **用途**：
  - 进度显示
  - 预检查磁盘空间
  - 下载完整性验证
- **示例**：`123456789`

#### `signature` (可选)
- **类型**：字符串
- **说明**：文件签名（用于签名验证）
- **格式**：`{algorithm}:{signature_data}`
- **支持的算法**：
  - `minisign`: minisign 签名（推荐）
  - `gpg`: GPG 签名
- **示例**：
  ```json
  "signature": "minisign:RWS..."
  ```

---

## 完整示例

### 单版本 Manifest

```json
{
  "manifest-version": "1",
  "date": "2026-01-18",
  "pkg": {
    "fpc": {
      "version": "3.2.2",
      "targets": {
        "linux-x86_64": {
          "url": [
            "https://sourceforge.net/projects/freepascal/files/3.2.2/fpc-3.2.2.linux-x86_64.tar.gz",
            "https://github.com/fpc/releases/download/v3.2.2/fpc-3.2.2.linux-x86_64.tar.gz"
          ],
          "hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          "size": 123456789,
          "signature": "minisign:RWS..."
        },
        "windows-x86_64": {
          "url": "https://sourceforge.net/projects/freepascal/files/3.2.2/fpc-3.2.2.win64.exe",
          "hash": "sha256:d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592",
          "size": 987654321
        },
        "darwin-aarch64": {
          "url": "https://sourceforge.net/projects/freepascal/files/3.2.2/fpc-3.2.2.darwin-aarch64.dmg",
          "hash": "sha256:cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce",
          "size": 456789123
        }
      }
    }
  }
}
```

### 多版本 Manifest（Channel）

```json
{
  "manifest-version": "1",
  "date": "2026-01-18",
  "channel": "stable",
  "pkg": {
    "fpc": {
      "version": "3.2.2",
      "targets": {
        "linux-x86_64": {
          "url": "https://sourceforge.net/projects/freepascal/files/3.2.2/fpc-3.2.2.linux-x86_64.tar.gz",
          "hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
          "size": 123456789
        }
      }
    },
    "fpc-3.2.0": {
      "version": "3.2.0",
      "targets": {
        "linux-x86_64": {
          "url": "https://sourceforge.net/projects/freepascal/files/3.2.0/fpc-3.2.0.linux-x86_64.tar.gz",
          "hash": "sha256:a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3",
          "size": 120000000
        }
      }
    }
  }
}
```

---

## Manifest 托管

### 文件命名约定

- **稳定版本**：`channel-stable.json`
- **测试版本**：`channel-beta.json`
- **每日构建**：`channel-nightly.json`
- **归档版本**：`archives/YYYY-MM-DD-{channel}.json`

### 托管位置

**主仓库**：`https://github.com/fpdev/fpdev-manifests`

**CDN 加速**：`https://fpdev.github.io/fpdev-manifests/`

### 更新频率

- **stable**: 每次 FPC 正式发布时更新
- **beta**: 每周更新
- **nightly**: 每日自动构建

---

## 使用流程

### 1. 下载 Manifest

```bash
fpdev fpc update-manifest
# 下载最新的 stable manifest 到本地缓存
```

### 2. 查询可用版本

```bash
fpdev fpc list --remote
# 从 manifest 读取所有可用版本
```

### 3. 安装指定版本

```bash
fpdev fpc install 3.2.2
# 1. 从 manifest 获取 URL 和 hash
# 2. 下载二进制包
# 3. 验证 SHA256 校验和
# 4. 解压安装
```

---

## 安全考虑

### 完整性验证

1. **必须验证 hash**：所有下载必须验证 SHA256/SHA512
2. **签名验证**（可选）：支持 minisign/GPG 签名验证
3. **HTTPS 传输**：所有 URL 必须使用 HTTPS

### 镜像 Fallback

1. 按顺序尝试所有镜像
2. 每个镜像下载后都验证 hash
3. 如果所有镜像都失败，返回错误

### Manifest 验证

1. 验证 `manifest-version` 字段
2. 验证必需字段存在
3. 验证 hash 格式正确
4. 验证 URL 格式正确

---

## 错误处理

### Manifest 解析错误

```json
{
  "error": "invalid_manifest",
  "message": "Missing required field: pkg.fpc.version",
  "manifest_version": "1"
}
```

### 下载失败

```json
{
  "error": "download_failed",
  "message": "All mirrors failed",
  "attempted_urls": [
    "https://sourceforge.net/...",
    "https://github.com/..."
  ]
}
```

### 校验和不匹配

```json
{
  "error": "hash_mismatch",
  "message": "Downloaded file hash does not match manifest",
  "expected": "sha256:abc123...",
  "actual": "sha256:def456..."
}
```

---

## 未来扩展

### v2 可能的改进

1. **增量更新**：支持 delta 下载
2. **压缩 manifest**：支持 gzip 压缩
3. **组件化安装**：支持选择性安装组件
4. **依赖管理**：支持包依赖关系

### 向后兼容性

- 新版本 manifest 必须保持 `manifest-version` 字段
- 解析器必须检查版本号并拒绝不支持的版本
- 可选字段的添加不影响旧版本解析器

---

## 参考资料

- [Rust rustup channel manifest](https://rust-lang.github.io/rustup/concepts/channels.html)
- [Debian package format](https://www.debian.org/doc/debian-policy/ch-controlfields.html)
- [SHA-256 specification](https://en.wikipedia.org/wiki/SHA-2)
- [minisign](https://jedisct1.github.io/minisign/)

---

**版本历史**：
- v1.0 (2026-01-18): 初始版本

**维护者**：FPDev 开发团队
