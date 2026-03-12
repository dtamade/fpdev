# FPDev 快速开始（5 分钟）

欢迎使用 **FPDev** - FreePascal 开发环境管理器！本指南将帮助您在 5 分钟内完成基本设置并创建第一个项目。

## 📋 前提条件

确保您已经完成了安装，并且可以运行：

```bash
fpdev system version
```

如果尚未安装，请参考 [完整安装指南](docs/INSTALLATION.md)。

---

## 🚀 第一步：安装 FPC 编译器

```bash
# 安装推荐版本 FPC 3.2.2（二进制安装，快速）
fpdev fpc install 3.2.2

# 或者从源码编译（可定制，需要 10-30 分钟）
fpdev fpc install 3.2.2 --from-source

# 设置为默认版本
fpdev fpc use 3.2.2

# 验证安装
fpdev fpc current
```

---

## 🎯 第二步：创建第一个项目

```bash
# 创建控制台应用
fpdev project new console hello-world

# 进入项目目录
cd hello-world

# 查看生成的代码
cat hello-world.lpr
```

生成的代码示例：

```pascal
program hello_world;

{$mode objfpc}{$H+}

uses
  SysUtils;

begin
  WriteLn('Hello from hello-world!');
end.
```

---

## ▶️ 第三步：构建和运行

```bash
# 构建项目
fpdev project build

# 运行项目
./hello-world        # Linux/macOS
hello-world.exe      # Windows
```

---

## 🎨 尝试其他项目类型

### GUI 应用程序

```bash
fpdev project new gui my-gui-app
cd my-gui-app
fpdev project build
```

### Web 应用程序

```bash
fpdev project new webapp my-web-app
cd my-web-app
fpdev project build
```

### 查看所有模板

```bash
fpdev project list
```

---

## 📦 包管理（快速预览）

```bash
# 列出已安装的包
fpdev package list

# 搜索包
fpdev package search synapse

# 安装包
fpdev package install synapse
```

---

## 🛠️ 常用命令速查

### FPC 管理
```bash
fpdev fpc install <version>     # 安装版本
fpdev fpc list                  # 列出已安装版本
fpdev fpc use <version>         # 切换版本
fpdev fpc current               # 查看当前版本
```

### 项目管理
```bash
fpdev project new <template> <name>  # 创建项目
fpdev project build                  # 构建项目
fpdev project run                    # 运行项目
fpdev project clean                  # 清理构建产物
```

### Lazarus IDE（可选）
```bash
fpdev lazarus install 3.0       # 安装 Lazarus IDE
fpdev lazarus run               # 启动 IDE
```

---

## 📚 下一步

- 📖 阅读 [完整文档](docs/QUICKSTART.md) 了解所有功能
- 🏗️ 查看 [架构文档](docs/ARCHITECTURE.md) 了解内部设计
- ❓ 查看 [常见问题](FAQ.md) 解决疑问
- 🐛 [报告问题](https://github.com/fpdev/fpdev/issues) 或提出建议

---

## 💡 小贴士

1. **使用 Tab 补全**：大多数 shell 支持命令补全
2. **查看帮助**：任何命令后加 `--help` 查看详细帮助
3. **离线模式**：使用 `--offline` 标志从缓存安装
4. **强制刷新**：使用 `--no-cache` 标志强制重新下载

---

🎉 **恭喜！您已经成功上手 FPDev。开始享受现代化的 FreePascal 开发体验吧！**
