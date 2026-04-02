# FPDev 快速开始指南

## 🚀 5分钟上手 FPDev

本指南将帮助您在5分钟内完成 FPDev 的基本设置并创建第一个项目。

## 📋 前提条件

确保您已经完成了 [安装](INSTALLATION.md)，并且可以运行：
```bash
fpdev system version
```

## 🎯 第一步：验证安装

```bash
# 查看帮助信息
fpdev system help

# 查看可用的 FPC 版本
fpdev fpc list --all

# 查看可用的 Lazarus 版本  
fpdev lazarus list --all
```

## 🔧 第二步：安装开发环境

### 安装 FPC (FreePascal 编译器)

```bash
# 安装推荐版本 FPC 3.2.2
fpdev fpc install 3.2.2 --from-source

# 设置为默认版本
fpdev fpc use 3.2.2

# 验证安装
fpdev fpc current
```

**注意**: 从源码编译可能需要 10-30 分钟，请耐心等待。

### 安装 Lazarus IDE (可选)

```bash
# 安装 Lazarus 3.0
fpdev lazarus install 3.0 --from-source

# 设置为默认版本
fpdev lazarus use 3.0

# 验证安装
fpdev lazarus current
```

## 🚀 第三步：创建第一个项目

### 创建控制台应用

```bash
# 创建新的控制台项目
fpdev project new console hello-world

# 进入项目目录
cd hello-world

# 查看生成的文件
ls -la
# 应该看到: hello-world.lpr
```

### 查看生成的代码

```pascal
// hello-world.lpr
program hello_world;

{$mode objfpc}{$H+}

uses
  SysUtils;

begin
  WriteLn('Hello from hello-world!');
end.
```

### 构建和运行项目

```bash
# 构建项目
fpdev project build

# 运行项目 (如果构建成功)
./hello-world        # Linux/macOS
# 或
hello-world.exe      # Windows
```

## 🎨 第四步：尝试其他项目类型

### GUI 应用程序

```bash
# 创建 GUI 项目
fpdev project new gui my-gui-app
cd my-gui-app

# 查看项目结构
ls -la
# 应该看到: my-gui-app.lpr, my-gui-app.lpi
```

### Web 应用程序

```bash
# 创建 Web 应用
fpdev project new webapp my-web-app
cd my-web-app
```

### 查看所有可用模板

```bash
# 列出所有项目模板
fpdev project list

# 查看特定模板信息
fpdev project info console
fpdev project info gui
```

## 📦 第五步：包管理

### 安装包

```bash
# 列出已安装的包
fpdev package list

# 搜索包 (功能开发中)
fpdev package search synapse

# 安装包 (功能开发中)
fpdev package install synapse
```

### 管理仓库

```bash
# 添加包仓库
fpdev package repo add custom https://example.com/packages

# 列出仓库
fpdev package repo list
```

## 🌐 第六步：交叉编译 (高级)

### 安装交叉编译目标

```bash
# 查看可用的交叉编译目标
fpdev cross list --all

# 安装 Windows 64位目标 (在 Linux/macOS 上)
fpdev cross install x86_64-win64

# 配置工具链路径 (需要手动安装工具链)
fpdev cross configure x86_64-win64 \
  --binutils=/usr/x86_64-w64-mingw32/bin \
  --libraries=/usr/x86_64-w64-mingw32/lib
```

### 交叉编译项目

```bash
# 为特定目标构建
fpdev project build . win64
```

## 🛠️ 常用命令速查

### FPC 管理
```bash
fpdev fpc install <version> [--from-source]    # 安装版本
fpdev fpc list [--all]                         # 列出版本
fpdev fpc use <version>                        # 切换到指定版本
fpdev fpc current                              # 当前版本
fpdev fpc uninstall <version>                  # 卸载版本
```

### Lazarus 管理
```bash
fpdev lazarus install <version> [--from-source]  # 安装版本
fpdev lazarus run [version]                      # 启动 IDE
fpdev lazarus list [--all]                       # 列出版本
fpdev lazarus use <version>                    # 切换到指定版本
```

### 项目管理
```bash
fpdev project new <template> <name> [dir]        # 创建项目
fpdev project list                               # 列出模板
fpdev project build [dir] [target]               # 构建项目
fpdev project info <template>                    # 模板信息
```

### 包管理
```bash
fpdev package install <package>                  # 安装包
fpdev package list [--all]                       # 列出包
fpdev package repo add <name> <url>              # 添加仓库
```

### 交叉编译
```bash
fpdev cross install <target>                     # 安装目标
fpdev cross list [--all]                         # 列出目标
fpdev cross configure <target> --binutils=<path> --libraries=<path>
```

## 📁 项目结构最佳实践

### 推荐的项目结构

```
my-project/
├── src/                    # 源代码
│   ├── my-project.lpr     # 主程序
│   ├── units/             # 单元文件
│   └── forms/             # 窗体文件 (GUI项目)
├── tests/                 # 测试代码
├── docs/                  # 文档
├── bin/                   # 编译输出
├── lib/                   # 库文件
└── README.md              # 项目说明
```

### 配置文件

FPDev 会把配置文件保存在当前数据根中的 `config.json`：
- **portable release 默认位置**: `<安装目录>/data/config.json`
- **如果显式设置了 `FPDEV_DATA_ROOT`**: `$FPDEV_DATA_ROOT/config.json`

也就是说，快速开始场景下通常直接编辑与 `fpdev` 可执行文件同级的 `data/config.json` 即可。

## 🔧 配置优化

### 性能优化

```bash
# 如需把配置、缓存、日志放到其他位置，可覆盖数据根
export FPDEV_DATA_ROOT=/fast/ssd/fpdev-data
mkdir -p "$FPDEV_DATA_ROOT"

# 启用源码缓存 (加速重复安装)
fpdev system config set keep_sources true
```

并行编译任务数请在当前生效的 `config.json` 中调整 `settings.parallel_jobs`，而不是依赖额外的环境变量。

### 网络优化

```bash
# 设置代理 (如果需要)
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# 使用镜像源 (中国用户)
fpdev system config set mirror gitee
```

## 🐛 常见问题

### Q: 编译失败怎么办？
A: 检查以下几点：
1. 确保已安装必要的构建工具 (gcc, make 等)
2. 检查网络连接
3. 查看详细错误信息：`fpdev fpc install 3.2.2 --from-source --verbose`

### Q: 如何切换 FPC 版本？
A: 使用 `fpdev fpc use <version>` 命令

### Q: 如何启动特定版本的 Lazarus？
A: 使用 `fpdev lazarus run <version>` 命令

### Q: 项目构建失败？
A: 确保：
1. 当前目录包含项目文件 (.lpr 或 .lpi)
2. 已安装对应的 FPC 版本
3. 项目代码语法正确

## 📚 下一步

现在您已经掌握了 FPDev 的基本使用，可以：

1. 📖 阅读 [完整文档](API.md) 了解所有功能
2. 🏗️ 查看 [架构文档](ARCHITECTURE.md) 了解内部设计
3. 🤝 参与 [社区讨论](https://discord.gg/fpdev)
4. 🐛 [报告问题](https://github.com/fpdev/fpdev/issues) 或提出建议

## 💡 小贴士

1. **使用 Tab 补全**: 大多数 shell 支持命令补全
2. **查看帮助**: 任何命令后加 `--help` 查看详细帮助
3. **保持更新**: 用 `fpdev system version` 检查本地版本，并定期查看发布说明
4. **备份配置**: 重要项目建议备份 `.fpdev` 目录

---

🎉 恭喜！您已经成功上手 FPDev。开始享受现代化的 FreePascal 开发体验吧！
