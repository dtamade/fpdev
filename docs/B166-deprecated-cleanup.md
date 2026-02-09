# B166: @deprecated 清理执行

## 完成日期
2026-02-10

## 执行摘要

**原状态**: 5 处 @deprecated 标记
**清理后**: 0 处 @deprecated 标记

## 清理详情

### 类型 1: Legacy Execute 接口 (4 处) - 已移除

| 文件 | 变更 |
|------|------|
| fpdev.cmd.repo.list.pas | 移除 IFpdevCommand 实现和 Execute(ICommandContext) |
| fpdev.cmd.repo.add.pas | 移除 IFpdevCommand 实现和 Execute(ICommandContext) |
| fpdev.cmd.repo.remove.pas | 移除 IFpdevCommand 实现和 Execute(ICommandContext) |
| fpdev.cmd.repo.default.pas | 移除 IFpdevCommand 实现和 Execute(ICommandContext) |

**同时清理**:
- fpdev.command.intf.pas - 移除 `IFpdevCommand` 和 `ICommandContext` 接口定义
- 移除 `fpdev.config` 单元引用（不再需要）

### 类型 2: Git 单例 (1 处) - 已清理

| 文件 | 变更 |
|------|------|
| fpdev.utils.git.pas | 移除 @deprecated 注释，保留 SharedGitManager 作为内部单例 |

**说明**: `SharedGitManager` 实际上已经使用新的 `IGitManager` 接口，是模块内部的优化实现，不是废弃代码。

## 代码变更统计

| 指标 | 变更 |
|------|------|
| 移除代码行数 | ~80 行 |
| 修改文件数 | 5 个 |
| 移除接口 | 2 个 (IFpdevCommand, ICommandContext) |
| @deprecated 标记 | 5 → 0 |

## 验证结果

- 编译: 0 warnings, 0 errors
- 测试: 140/140 通过 (100%)
- 功能回归: 无
