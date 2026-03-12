# FPDev 常见问题解答 (FAQ)

本文档回答 FPDev 使用过程中的常见问题。

---

## 📦 安装相关

### Q: 如何安装 FPDev？

**A**: 从源码构建：

```bash
git clone https://github.com/fpdev/fpdev.git
cd fpdev
lazbuild -B fpdev.lpi
./bin/fpdev system help
```

### Q: 需要哪些依赖？

**A**: 
- **构建 FPDev**: FPC 3.2.2+, Lazarus (可选)
- **使用 FPDev**: 无特殊依赖
- **从源码安装 FPC**: Git, Make, Bootstrap 编译器（自动下载）

### Q: 二进制安装失败怎么办？

**A**: 使用源码安装：

```bash
fpdev fpc install 3.2.2 --from-source
```

二进制安装依赖 manifest 系统，如果不可用，源码安装是最可靠的方法。

---

## 🔧 FPC 管理

### Q: 如何安装 FPC？

**A**: 推荐使用源码安装：

```bash
# 从源码安装（推荐）
fpdev fpc install 3.2.2 --from-source

# 激活版本
fpdev fpc use 3.2.2

# 验证安装
fpdev fpc verify 3.2.2
```

### Q: 如何切换 FPC 版本？

**A**: 使用 `use` 命令：

```bash
fpdev fpc use 3.2.2
```

这会生成激活脚本：
- Windows: `.fpdev\env\activate.cmd`
- Linux/macOS: `.fpdev/env/activate.sh`

### Q: 如何查看当前 FPC 版本？

**A**: 

```bash
fpdev fpc current
```

### Q: 源码安装需要多长时间？

**A**: 
- **首次安装**: 20-40 分钟（下载源码 + 编译）
- **后续安装**: 10-20 分钟（重用已下载的源码）

时间取决于：
- 网络速度（下载源码）
- CPU 性能（编译速度）
- 并行任务数（`--jobs` 参数）

### Q: 如何加速源码编译？

**A**: 使用 `--jobs` 参数：

```bash
# 使用 4 个并行任务
fpdev fpc install 3.2.2 --from-source --jobs=4
```

---

## 📁 项目管理

### Q: 如何创建新项目？

**A**: 

```bash
# 控制台应用
fpdev project new console myapp

# GUI 应用
fpdev project new gui myapp

# 动态库
fpdev project new library mylib
```

### Q: 项目名称可以包含连字符吗？

**A**: 可以，但会自动转换为下划线：

```bash
fpdev project new console hello-world
# 生成的程序名: hello_world
```

这是因为 Pascal 标识符不允许连字符。

### Q: 如何构建项目？

**A**: 

```bash
# 使用 FPC 直接编译
fpc myapp.lpr

# 或使用 lazbuild
lazbuild myapp.lpi

# 或使用 fpdev（未来版本）
fpdev project build
```

### Q: 如何清理构建产物？

**A**: 

```bash
fpdev project clean
```

这会删除：
- `*.o` - 目标文件
- `*.ppu` - 编译单元
- `*.exe` / 可执行文件
- `*.a`, `*.so` - 库文件

---

## 🐛 故障排除

### Q: 安装命令超时怎么办？

**A**: 这通常是网络问题。解决方案：

1. **使用源码安装**（不依赖网络下载二进制）:
   ```bash
   fpdev fpc install 3.2.2 --from-source
   ```

2. **检查网络连接**

3. **使用代理**（如果在防火墙后）

### Q: 编译错误：找不到单元

**A**: 检查 FPC 配置：

```bash
# 验证 FPC 安装
fpdev fpc verify 3.2.2

# 查看 FPC 配置
fpc -vut
```

### Q: Windows 上找不到 git2.dll

**A**: 确保 `git2.dll` 在以下位置之一：
- FPDev 可执行文件目录
- PATH 环境变量中的目录

### Q: 权限错误

**A**: 
- **Linux/macOS**: 使用 `sudo` 或安装到用户目录
- **Windows**: 以管理员身份运行

---

## 🔍 高级用法

### Q: 如何自定义安装路径？

**A**: 使用 `--prefix` 参数：

```bash
fpdev fpc install 3.2.2 --from-source --prefix=/custom/path
```

### Q: 如何使用项目作用域安装？

**A**: 在项目目录中运行安装命令：

```bash
cd myproject
fpdev fpc install 3.2.2
# 安装到 .fpdev/toolchains/
```

### Q: 如何清理 FPC 源码构建产物？

**A**: 

```bash
fpdev fpc clean 3.2.2
```

这会删除编译产物，但保留源码仓库。

### Q: 如何更新 FPC 源码？

**A**: 

```bash
fpdev fpc update 3.2.2
```

这会执行 `git pull` 更新源码到最新版本。

---

## 📚 更多资源

- [快速开始指南](QUICKSTART.md)
- [完整文档](../README.md)
- [架构文档](ARCHITECTURE.md)
- [GitHub Issues](https://github.com/fpdev/fpdev/issues)
- [社区讨论](https://github.com/fpdev/fpdev/discussions)

---

## 💬 获取帮助

如果您的问题没有在这里找到答案：

1. 查看 [GitHub Issues](https://github.com/fpdev/fpdev/issues)
2. 搜索 [社区讨论](https://github.com/fpdev/fpdev/discussions)
3. 提交新的 Issue 或讨论

---

**最后更新**: 2026-01-22
