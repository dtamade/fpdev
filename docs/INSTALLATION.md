# FPDev Installation Guide / FPDev 安装指南

Complete installation guide for FPDev - FreePascal Development Environment Manager.

## 📋 System Requirements / 系统要求

### Supported Operating Systems / 支持的操作系统
- **Windows**: Windows 7+ / Windows 10 或更高版本
- **Linux**: Ubuntu 18.04+, Debian 10+, CentOS 8+, Fedora 30+
- **macOS**: macOS 10.12+ / macOS 10.14 (Mojave) 或更高版本

### Hardware Requirements / 硬件要求
- **Minimum RAM / 最低内存**: 2GB RAM (512MB minimum)
- **Recommended RAM / 推荐内存**: 4GB+ RAM
- **Disk Space / 磁盘空间**:
  - FPDev itself / FPDev 本身: 100MB
  - Per FPC version / 每个 FPC 版本: 200-500MB
  - Full installation / 完整安装 (包括 FPC/Lazarus): 5GB+
- **Network / 网络连接**: Internet connection for downloads (optional with cache) / 用于下载源码和包（缓存模式可离线）

### 依赖软件

#### Windows
- **Git for Windows** (用于源码下载)
- **MSYS2** 或 **MinGW-w64** (用于编译工具)

#### Linux
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install git build-essential curl wget

# CentOS/RHEL/Fedora
sudo dnf install git gcc gcc-c++ make curl wget
# 或者 (CentOS 7)
sudo yum install git gcc gcc-c++ make curl wget
```

#### macOS
```bash
# 安装 Xcode Command Line Tools
xcode-select --install

# 安装 Homebrew (推荐)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装依赖
brew install git wget
```

## 🚀 安装方法

### 方法一：预编译二进制文件 (推荐)

> 保持发布资产的解压布局不变：`fpdev` / `fpdev.exe` 必须与同级 `data/` 目录放在一起，才能按 portable release 方式运行。

#### Windows
1. 下载最新版本:
   ```powershell
   # 使用 PowerShell
   Invoke-WebRequest -Uri "https://github.com/fpdev/fpdev/releases/download/v2.1.0/fpdev-windows-x64.zip" -OutFile "fpdev-windows-x64.zip"
   New-Item -ItemType Directory -Force -Path "C:\fpdev" | Out-Null
   Expand-Archive -Path "fpdev-windows-x64.zip" -DestinationPath "C:\fpdev" -Force
   ```

2. 添加到 PATH:
   ```powershell
   # 临时添加 (当前会话)
   $env:PATH += ";C:\fpdev"
   
   # 永久添加 (需要管理员权限)
   [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\fpdev", "Machine")
   ```

3. 验证安装:
   ```cmd
   fpdev system version
   ```

#### Linux
1. 下载并安装:
   ```bash
   # 下载
   wget https://github.com/fpdev/fpdev/releases/download/v2.1.0/fpdev-linux-x64.tar.gz
   
   # 保留 fpdev 与 data/ 的相对布局
   mkdir -p ~/.local/opt/fpdev
   tar -xzf fpdev-linux-x64.tar.gz -C ~/.local/opt/fpdev

   # 将解压目录加入 PATH
   export PATH="$HOME/.local/opt/fpdev:$PATH"
   ```

2. 验证安装:
   ```bash
   fpdev system version
   ```

#### macOS
1. 下载并安装:
   ```bash
   # 下载
   curl -L -o fpdev-macos-<arch>.tar.gz https://github.com/fpdev/fpdev/releases/download/v2.1.0/fpdev-macos-<arch>.tar.gz
   
   # 保留 fpdev 与 data/ 的相对布局
   mkdir -p "$HOME/Applications/fpdev"
   tar -xzf fpdev-macos-<arch>.tar.gz -C "$HOME/Applications/fpdev"

   # 将解压目录加入 PATH
   export PATH="$HOME/Applications/fpdev:$PATH"
   ```

2. 将 `<arch>` 替换为 `x64` 或 `arm64`

3. 首次运行可能需要在"系统偏好设置 > 安全性与隐私"中允许

### 方法二：从源码编译

#### 前提条件
- FreePascal 编译器 (FPC 3.2.0+)
- Git

#### 编译步骤
```bash
# 克隆仓库
git clone https://github.com/fpdev/fpdev.git
cd fpdev

# 编译
lazbuild -B --build-mode=Release fpdev.lpi

# 验证
./bin/fpdev system version
```

### 方法三：包管理器渠道状态

目前没有已发布的 Homebrew / Chocolatey / Snap / APT 渠道。

在这些渠道正式发布之前，请使用：
- 方法一：GitHub Release 预编译二进制文件
- 方法二：从源码编译

## ⚙️ 配置

### 初始配置
```bash
# 创建默认配置并写出配置文件
fpdev system config show

# 预编译 portable release 默认配置文件位置
# <install-dir>/data/config.json
#
# 如果显式设置了 FPDEV_DATA_ROOT，则配置文件位置变为：
# $FPDEV_DATA_ROOT/config.json
```

### 环境变量

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `FPDEV_DATA_ROOT` | 覆盖 FPDev 数据根目录（配置、缓存、日志、锁文件） | portable release 下默认为 `<install-dir>/data` |

### 代理配置
```bash
# 设置 HTTP 代理
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# 设置 Git 代理
git config --global http.proxy http://proxy.example.com:8080
```

## 🔧 验证安装

### 基本功能测试
```bash
# 检查版本
fpdev system version

# 查看帮助
fpdev system help

# 列出可用的 FPC 版本
fpdev fpc list --all

# 创建测试项目
fpdev project new console test-app
cd test-app
```

### 运行测试套件
```bash
# 如果从源码安装，可以运行测试
cd fpdev/src
fpc -Fu. ../tests/test_config_management.lpr
../tests/test_config_management
```

## 🐛 故障排除

### 常见问题

#### 1. "fpdev: command not found"
**原因**: PATH 环境变量未正确设置
**解决方案**:
```bash
# 检查 fpdev 位置
which fpdev

# 添加到 PATH
export PATH="/path/to/fpdev:$PATH"

# 永久添加到 shell 配置文件
echo 'export PATH="/path/to/fpdev:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 2. 权限错误 (Linux/macOS)
**原因**: 没有执行权限
**解决方案**:
```bash
chmod +x /path/to/fpdev
```

#### 3. Windows 安全警告
**原因**: Windows Defender 或杀毒软件误报
**解决方案**:
- 将 fpdev 添加到杀毒软件白名单
- 在 Windows Defender 中添加排除项

#### 4. 网络连接问题
**原因**: 防火墙或代理设置
**解决方案**:
```bash
# 测试网络连接
curl -I https://gitlab.com/freepascal.org/fpc/source.git

# 配置代理 (如果需要)
export HTTP_PROXY=http://your-proxy:port
```

#### 5. Git 相关错误
**原因**: Git 未安装或配置不正确
**解决方案**:
```bash
# 检查 Git 安装
git --version

# 配置 Git (首次使用)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 日志和调试

#### 日志文件位置
- **portable release 默认**: `<install-dir>/data/logs/`
- **若设置 `FPDEV_DATA_ROOT`**: `$FPDEV_DATA_ROOT/logs/`
- **非 portable 运行（例如源码构建）**:
  - Windows: `%APPDATA%\\fpdev\\logs\\`
  - Linux/macOS: `$XDG_DATA_HOME/fpdev/logs/` 或 `~/.fpdev/logs/`

### 获取帮助

如果遇到问题，可以通过以下方式获取帮助:

1. **查看文档**: https://fpdev.github.io/docs
2. **GitHub Issues**: https://github.com/fpdev/fpdev/issues
3. **社区论坛**: https://discord.gg/fpdev
4. **邮件支持**: support@fpdev.org

## 🔄 卸载

### 完全卸载
```bash
# 删除完整 portable release 目录（包括 fpdev 与同级 data/）
rm -rf ~/.local/opt/fpdev          # Linux 示例
rm -rf "$HOME/Applications/fpdev"  # macOS 示例
# 或删除 C:\fpdev\                 # Windows 示例

# 如果显式设置过 FPDEV_DATA_ROOT，也可一并删除该目录
rm -rf "$FPDEV_DATA_ROOT"

# 从 PATH 中移除 (如果手动添加过)
# 编辑 ~/.bashrc 或相应的 shell 配置文件
```

## 📈 性能优化

### 编译性能
```bash
# 使用 SSD 存储 mutable data（配置、缓存、日志）
export FPDEV_DATA_ROOT=/fast/ssd/fpdev-data
mkdir -p "$FPDEV_DATA_ROOT"
```

如需调整并行编译任务数，请编辑当前数据根中的 `config.json`，修改 `settings.parallel_jobs`。

### 网络优化
```bash
# 使用镜像源 (中国用户)
fpdev system config set mirror gitee
```

---

安装完成后，请查看 [快速开始指南](QUICKSTART.md) 了解基本使用方法。
