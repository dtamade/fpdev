# Phase 3.4: Lazarus IDE Integration - Implementation Plan

**Status**: In Progress
**Start Date**: 2026-01-17
**Estimated Duration**: 1-2 weeks
**Methodology**: Test-Driven Development (TDD)

---

## 目标

完成 Lazarus IDE 配置功能，实现"开箱即用"体验。用户安装 FPC/Lazarus 后，IDE 应自动识别 fpdev 管理的工具链。

---

## 后端架构（Codex 规划）

### 1. 配置文件处理策略

**流水线**：读取 → 规范化 → 合并 → 写入

**目标文件**：
- `environmentoptions.xml` - 主要环境配置
- `fpcdefines.xml` - FPC 定义
- `lazarus.conf` / `lazarus.cfg` - Lazarus 配置

**映射表驱动**：
- JSON 配置 → XML/INI 字段映射
- 声明式配置同步
- 保留未知字段和注释

### 2. 幂等性保证机制

**哨兵标记**：
- 使用 `fpdev:managed=true` 属性/注释标记
- 内容哈希对比，一致则跳过
- 路径规范化（统一分隔符、展开符号链接）

**合并策略**：
- 检测现有配置
- 仅在不冲突时追加
- 冲突时输出诊断并中止

### 3. 安全机制

**备份策略**：
- 带时间戳备份：`filename.bak.YYYYMMDDHHMMSS`
- 原子替换：`write temp → fsync → rename`
- 失败自动回滚到最新备份

**错误处理**：
- 分类错误：解析错误、路径不可写、权限不足、配置冲突
- 校验逻辑：写入后重新读取并对比
- 明确反馈：列出修改/跳过/失败的文件和字段

### 4. 测试策略（TDD）

**单元测试**：
- 映射表覆盖（JSON → XML/INI 字段变更）
- 幂等性测试（多次执行产生零差异）
- 冲突检测与回滚逻辑

**组件测试**：
- 固定样例 XML/INI 作为基线
- 对比写入后文件结构（含未知字段保留）

**端到端测试**：
- 临时目录模拟 Lazarus 配置路径
- 验证文件更新、备份生成、回滚正常

---

## 前端架构（Gemini 规划）

### 命令接口

```bash
fpdev lazarus configure <version> [options]

选项：
  -i, --interactive   交互模式（显示变更计划并请求确认）
  -n, --dry-run      预演模式（仅显示变更，不实际修改）
  -f, --force        强制模式（不询问直接应用）
  --backup           强制备份（默认开启）
  --restore <id>     恢复模式（从备份恢复）
  --global           应用到全局配置
```

### 交互流程

1. **初始化检查**
   - 检查目标 Lazarus 版本是否已安装
   - 扫描关联的 FPC 版本和工具链
   - 定位 Lazarus 配置文件

2. **生成配置计划**
   - 读取现有配置
   - 计算目标配置值
   - 生成差异报告

3. **预演/交互确认**
   - 输出差异对比表
   - 交互模式询问：`Apply these changes? [Y/n]`

4. **执行与反馈**
   - 备份：`Backing up configuration to: ...`
   - 应用：`Updating Compiler path... [OK]`
   - 验证：`Validating configuration... [OK]`

### 差异展示示例

```text
[Configuration Plan for Lazarus 3.0]

Compiler Path (fpc):
  Current: /usr/bin/fpc (System)
  New:     /home/user/.fpdev/fpc/3.2.2/bin/fpc (FPDev Managed)

Make Path:
  Current: (not set)
  New:     /usr/bin/make

FPC Source Directory:
  Current: /usr/share/fpcsrc
  New:     /home/user/.fpdev/sources/fpc-3.2.2
```

### 用户体验关键点

- ✅ **幂等性**：配置正确时提示"已是最新"
- ✅ **透明性**：明确告知修改了哪个文件
- ✅ **安全性**：默认备份，清晰的恢复路径
- ✅ **引导性**：安装后提示可用 `configure` 命令

---

## 实施步骤

### 第 1 步：配置文件解析器（TDD Red）
- [ ] 创建 `tests/test_lazarus_configure.lpr`
- [ ] 测试 XML/INI 解析和写入
- [ ] 测试路径规范化和哨兵标记
- [ ] 测试幂等性检查

### 第 2 步：配置映射和合并（TDD Green）
- [ ] 实现 `TLazarusConfigManager` 类
- [ ] 实现映射表驱动的配置同步
- [ ] 实现幂等性检查和哈希对比
- [ ] 实现配置合并逻辑

### 第 3 步：备份和回滚机制（TDD Green）
- [ ] 实现带时间戳的备份生成
- [ ] 实现原子替换写入
- [ ] 实现失败自动回滚
- [ ] 测试回滚机制

### 第 4 步：CLI 命令实现（TDD Green）
- [ ] 创建 `fpdev.cmd.lazarus.configure.pas`
- [ ] 实现命令行参数解析
- [ ] 实现交互式确认和差异显示
- [ ] 集成到命令注册系统

### 第 5 步：集成测试和文档（TDD Refactor）
- [ ] 端到端测试完整配置流程
- [ ] 更新 README.md
- [ ] 更新 CLAUDE.md
- [ ] 更新 ROADMAP.md
- [ ] 提交并标记 Phase 3.4 完成

---

## 技术挑战和解决方案

### 1. Round-trip 写入难点
- **挑战**：XML/INI 保留格式与注释
- **方案**：选用支持保留的解析器，应用最小 diff 写入

### 2. 路径与平台差异
- **挑战**：Windows/Linux/macOS 路径差异
- **方案**：统一路径规范化逻辑，配置映射层做平台分支

### 3. 配置冲突处理
- **挑战**：用户自定义配置与 fpdev 配置冲突
- **方案**：明确定义优先级，允许策略配置

### 4. 诊断可视化
- **挑战**：用户需要清晰了解变更内容
- **方案**：输出变更摘要，包含文件、字段、旧值/新值

---

## 成功标准

- [ ] 所有测试通过（单元测试、组件测试、端到端测试）
- [ ] 幂等性验证：多次运行不产生重复配置
- [ ] 备份和回滚机制正常工作
- [ ] CLI 交互体验流畅
- [ ] 文档完整更新

---

## 后续计划

Phase 3.4 完成后，将开始 Phase 3.1 (Package Dependency Resolution)，预计 4-6 周完成。

---

**Last Updated**: 2026-01-17
**Maintained By**: FPDev Development Team
