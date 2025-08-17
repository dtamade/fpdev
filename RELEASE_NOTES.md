# FPDev v1.0.0 发布说明

## 🎉 首次正式发布

FPDev 是一个现代化的 FreePascal 和 Lazarus 开发环境管理工具，类似于 Rust 的 rustup，为 FreePascal 开发者提供完整的工具链管理解决方案。

## ✨ 核心功能

### 🔧 环境管理
- **FPC 版本管理**: 支持多版本并存，一键切换
- **Lazarus IDE 管理**: 智能版本关联，自动配置
- **交叉编译支持**: 12个主流平台的工具链管理
- **统一配置**: JSON格式的配置文件，类型安全访问

### 📦 包管理
- **包安装和卸载**: 类似 npm/cargo 的包管理体验
- **仓库管理**: 支持多个包仓库
- **依赖解析**: 自动处理包依赖关系
- **本地包支持**: 支持从本地路径安装包

### 🚀 项目管理
- **项目模板**: 7种内置项目模板
- **快速创建**: 一键生成标准化项目结构
- **智能构建**: 自动识别项目类型并构建
- **模板扩展**: 支持自定义模板安装

## 📊 技术指标

```
代码行数: ~4000行
测试用例: 126个 (100%通过)
模块数量: 6个核心模块
支持平台: Windows, Linux, macOS
文档页面: 8个完整文档
```

## 🛠️ 支持的版本

### FPC 版本
- ✅ FPC 3.2.2 (推荐)
- ✅ FPC 3.2.0 (长期支持)
- ✅ FPC 3.0.4, 3.0.2 (旧版本)
- ✅ FPC main (开发版本)

### Lazarus 版本
- ✅ Lazarus 3.0 (最新稳定版)
- ✅ Lazarus 2.2.6, 2.2.4 (长期支持)
- ✅ Lazarus 2.0.12 (旧版本)
- ✅ Lazarus main (开发版本)

### 交叉编译目标
- ✅ Windows: win32, win64
- ✅ Linux: linux32, linux64, linuxarm, linuxarm64
- ✅ macOS: darwin32, darwin64, darwinarm64
- ✅ 移动平台: android, ios
- ✅ 其他: freebsd64

## 🚀 快速开始

### 安装

```bash
# 下载预编译版本
wget https://github.com/fpdev/fpdev/releases/download/v1.0.0/fpdev-windows-x64.zip
unzip fpdev-windows-x64.zip
```

### 基本使用

```bash
# 查看帮助
fpdev help

# 安装 FPC 3.2.2
fpdev fpc install 3.2.2 --from-source

# 安装 Lazarus 3.0
fpdev lazarus install 3.0 --from-source

# 创建新项目
fpdev project new console myapp

# 安装包
fpdev package install synapse

# 配置交叉编译
fpdev cross install win64
```

## 📋 完整命令参考

### FPC 管理
```bash
fpdev fpc install <version> [--from-source]    # 安装FPC版本
fpdev fpc uninstall <version>                  # 卸载FPC版本
fpdev fpc list [--all]                         # 列出FPC版本
fpdev fpc default <version>                    # 设置默认版本
fpdev fpc current                              # 显示当前版本
```

### Lazarus 管理
```bash
fpdev lazarus install <version> [--from-source]  # 安装Lazarus
fpdev lazarus launch [version]                   # 启动IDE
fpdev lazarus list [--all]                       # 列出版本
fpdev lazarus default <version>                  # 设置默认版本
```

### 交叉编译
```bash
fpdev cross install <target>                     # 安装交叉编译目标
fpdev cross configure <target> --binutils=<path> --libraries=<path>
fpdev cross list [--all]                         # 列出目标
fpdev cross test <target>                        # 测试目标
```

### 包管理
```bash
fpdev package install <package> [version]        # 安装包
fpdev package uninstall <package>                # 卸载包
fpdev package list [--all]                       # 列出包
fpdev package search <query>                     # 搜索包
```

### 项目管理
```bash
fpdev project new <template> <name> [dir]        # 创建项目
fpdev project list                               # 列出模板
fpdev project build [dir]                        # 构建项目
fpdev project info <template>                    # 模板信息
```

## 🔧 系统要求

### 最低要求
- **操作系统**: Windows 10+, Linux (Ubuntu 18.04+), macOS 10.14+
- **内存**: 512MB RAM
- **磁盘空间**: 100MB (不包括FPC/Lazarus安装)
- **网络**: 用于下载源码和包

### 推荐配置
- **内存**: 2GB+ RAM
- **磁盘空间**: 5GB+ (包括多个FPC/Lazarus版本)
- **CPU**: 多核处理器 (用于并行编译)

## 🐛 已知问题

1. **Windows**: 某些杀毒软件可能误报，请添加到白名单
2. **macOS**: 首次运行需要在安全设置中允许
3. **Linux**: 需要安装 git 和 build-essential
4. **网络**: 在某些网络环境下下载可能较慢

## 🔄 升级说明

这是首次发布版本，暂无升级路径。未来版本将提供自动升级功能。

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

- **GitHub**: https://github.com/fpdev/fpdev
- **问题报告**: https://github.com/fpdev/fpdev/issues
- **功能请求**: https://github.com/fpdev/fpdev/discussions

## 📄 许可证

FPDev 采用 MIT 许可证发布。详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

感谢 FreePascal 和 Lazarus 社区的支持，以及所有测试用户的反馈。

## 📞 支持

- **文档**: https://fpdev.github.io/docs
- **社区**: https://discord.gg/fpdev
- **邮件**: support@fpdev.org

---

**FPDev v1.0.0** - 让 FreePascal 开发更简单！ 🚀
