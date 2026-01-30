# FPDev 示例项目

本目录包含 FPDev 的示例项目，帮助您快速上手。

---

## 📁 示例列表

### 1. hello-console

**描述**: 最简单的控制台应用示例

**文件**:
- `hello.lpr` - 主程序文件
- `hello.lpi` - Lazarus 项目文件
- `README.md` - 项目说明

**运行**:
```bash
cd hello-console
fpc hello.lpr
./hello
```

**预期输出**:
```
Hello from hello!
```

---

## 🚀 如何使用示例

### 方法 1: 直接运行

```bash
cd examples/hello-console
fpc hello.lpr
./hello
```

### 方法 2: 复制到新项目

```bash
cp -r examples/hello-console ~/myproject
cd ~/myproject
fpc hello.lpr
```

### 方法 3: 使用 FPDev 创建

```bash
fpdev project new console myapp
cd myapp
fpc myapp.lpr
```

---

## 📚 更多示例

更多示例正在开发中，敬请期待：

- [ ] GUI 应用示例
- [ ] 动态库示例
- [ ] 包管理示例
- [ ] 交叉编译示例

---

## 💡 贡献示例

欢迎贡献新的示例项目！请遵循以下规范：

1. 每个示例一个目录
2. 包含 README.md 说明
3. 代码简洁易懂
4. 添加注释说明关键部分

---

**最后更新**: 2026-01-22
