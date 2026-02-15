# FPDev 功能限制说明

**版本**: 1.0.0
**最后更新**: 2026-02-15

---

## 概述

本文档说明 FPDev 项目中有意未实现或暂时未实现的功能，以及相应的原因和替代方案。

---

## 1. Lazarus 预编译二进制安装

### 状态
❌ **未实现**

### 位置
- 消息定义: `src/fpdev.i18n.strings.pas:1201`
- 消息键: `CMD_LAZARUS_BINARY_NOT_IMPL`

### 原因

1. **复杂性高**
   - Lazarus 预编译二进制包的结构复杂
   - 不同平台的安装方式差异很大
   - 需要处理大量的依赖关系

2. **维护成本高**
   - 需要跟踪多个平台的二进制包
   - 版本更新频繁，维护困难
   - 不同发行版的包管理器差异大

3. **源码安装更可靠**
   - 从源码编译可以确保与 FPC 版本兼容
   - 可以自定义编译选项
   - 避免二进制包的兼容性问题

### 替代方案

**推荐方式：从源码安装**

```bash
# 安装 Lazarus（从源码）
fpdev lazarus install 3.0 --from-source

# 指定 FPC 版本
fpdev lazarus install 3.0 --from-source --fpc-version 3.2.2
```

**优点**:
- 与当前 FPC 版本完全兼容
- 可以自定义编译选项
- 支持所有平台

**缺点**:
- 编译时间较长（约 10-30 分钟）
- 需要编译工具链（make, gcc 等）

### 未来计划

可能在以下情况下实现预编译二进制安装：

1. **官方二进制包稳定**
   - Lazarus 官方提供统一的二进制包格式
   - 包结构标准化

2. **社区需求强烈**
   - 大量用户反馈需要此功能
   - 有贡献者愿意维护

3. **资源充足**
   - 有足够的维护资源
   - 可以持续跟踪更新

---

## 2. Windows 内存报告

### 状态
❌ **有意未实现**

### 位置
- 代码位置: `src/fpdev.perf.monitor.pas:199`
- 注释: "Windows memory reporting is intentionally not implemented."

### 原因

1. **Windows API 复杂性**
   - Windows 内存管理 API 复杂
   - 需要处理多种内存类型（物理内存、虚拟内存、页面文件等）
   - 不同 Windows 版本的 API 差异

2. **Free Pascal 限制**
   - Free Pascal 的 Windows API 绑定不完整
   - 需要直接调用 Windows API
   - 跨平台代码难以维护

3. **优先级低**
   - 内存报告主要用于性能监控
   - Windows 用户可以使用系统自带的任务管理器
   - 不影响核心功能

### 替代方案

**Windows 用户可以使用以下工具**:

1. **任务管理器**
   - 按 `Ctrl+Shift+Esc` 打开
   - 查看"性能"标签页
   - 实时监控内存使用

2. **资源监视器**
   - 按 `Win+R`，输入 `resmon`
   - 查看详细的内存使用情况
   - 可以按进程查看

3. **PowerShell 命令**
   ```powershell
   # 查看内存使用情况
   Get-Process | Sort-Object -Property WS -Descending | Select-Object -First 10

   # 查看系统内存信息
   Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
   ```

### 当前实现

FPDev 在 Windows 上的性能监控功能：

- ✅ **CPU 使用率** - 已实现
- ✅ **磁盘使用情况** - 已实现
- ✅ **构建时间统计** - 已实现
- ❌ **内存使用情况** - 未实现（仅 Windows）

**Linux/macOS 用户**:
- ✅ 完整的内存报告功能
- 使用 `/proc/meminfo` (Linux) 或 `vm_stat` (macOS)

### 未来计划

可能在以下情况下实现 Windows 内存报告：

1. **Free Pascal 改进**
   - Free Pascal 提供更好的 Windows API 支持
   - 跨平台内存 API 标准化

2. **社区贡献**
   - 有 Windows 开发者愿意贡献实现
   - 提供可维护的代码

3. **需求明确**
   - 用户明确需要此功能
   - 有具体的使用场景

---

## 3. 其他已知限制

### 3.1 交叉编译工具链

**部分平台支持有限**:
- ✅ 主流平台（Windows, Linux, macOS）完全支持
- ⚠️ 嵌入式平台（ARM, MIPS, RISC-V）部分支持
- ❌ 特殊平台（Amiga, OS/2）不支持

**原因**: 工具链可用性和维护成本

### 3.2 包管理

**私有包仓库**:
- ✅ 本地包安装支持
- ✅ Git 仓库支持
- ⚠️ 私有 HTTP 仓库需要手动配置
- ❌ 企业级包管理功能（权限、审计等）未实现

**原因**: 主要面向个人开发者和小团队

### 3.3 IDE 集成

**IDE 支持**:
- ✅ Lazarus IDE 完全支持
- ⚠️ VS Code 通过扩展支持
- ❌ 其他 IDE（IntelliJ, Eclipse）不支持

**原因**: 资源有限，优先支持主流 IDE

---

## 如何报告功能需求

如果您需要上述未实现的功能，或有其他功能需求，请：

1. **检查现有 Issues**
   - 访问 GitHub Issues 页面
   - 搜索是否已有相关讨论

2. **创建新 Issue**
   - 描述您的使用场景
   - 说明为什么需要此功能
   - 提供可能的实现方案（可选）

3. **贡献代码**
   - Fork 项目仓库
   - 实现功能并提交 Pull Request
   - 遵循项目的代码规范和测试要求

---

## 总结

### 功能限制概览

| 功能 | 状态 | 原因 | 替代方案 |
|------|------|------|----------|
| Lazarus 预编译二进制安装 | ❌ 未实现 | 复杂性高、维护成本高 | 从源码安装 |
| Windows 内存报告 | ❌ 有意未实现 | API 复杂、优先级低 | 使用系统工具 |

### 设计原则

FPDev 的功能实现遵循以下原则：

1. **核心功能优先** - 确保核心功能稳定可靠
2. **跨平台一致性** - 尽量保持各平台功能一致
3. **可维护性** - 避免引入难以维护的功能
4. **社区驱动** - 根据社区需求调整优先级

---

**参考文档**:
- README.md - 快速开始指南
- CLAUDE.md - 项目技术文档
- docs/ROADMAP.md - 开发路线图

**联系方式**:
- Email: dtamade@gmail.com
- QQ Group: 685403987
- QQ: 179033731
