# B166: @deprecated 清理执行

## 完成日期

2026-02-10

> 历史快照说明：本文记录 2026-02-10 当时的批次执行结果。当前工作树中的代码组织、统计数字和实现边界可能已变化。
> 当前工作树补充说明：`fpdev.utils.git.pas` 后续已继续演进，不再承载 `SharedGitManager` 这类内部实现；
> 它指向的 compatibility shim has since been removed，外部调用方应改用 `fpdev.git.operations`。

## 执行摘要

**原状态**: 5 处 @deprecated 标记
**清理后**: 0 处 @deprecated 标记

## 清理详情

### 类型 1: Legacy Execute 接口 (4 处) - 已移除

| 文件                       | 变更                                               |
| -------------------------- | -------------------------------------------------- |
| fpdev.cmd.repo.list.pas    | 移除 IFpdevCommand 实现和 Execute(ICommandContext) |
| fpdev.cmd.repo.add.pas     | 移除 IFpdevCommand 实现和 Execute(ICommandContext) |
| fpdev.cmd.repo.remove.pas  | 移除 IFpdevCommand 实现和 Execute(ICommandContext) |
| fpdev.cmd.repo.default.pas | 移除 IFpdevCommand 实现和 Execute(ICommandContext) |

**同时清理**:

- fpdev.command.intf.pas - 移除 `IFpdevCommand` 和 `ICommandContext` 接口定义
- 移除 `fpdev.config` 单元引用（不再需要）

### 类型 2: Git 单例 (1 处) - 已清理

| 文件                | 变更                                                                          |
| ------------------- | ----------------------------------------------------------------------------- |
| fpdev.utils.git.pas | 移除当时的 @deprecated 注释；该历史批次发生时仍保留 SharedGitManager 内部实现 |

**说明（历史语境）**: 当时的 `SharedGitManager` 已经使用新的 `IGitManager` 接口，因此在该批次里被视为内部优化实现而不是废弃代码。
**当前语境补充**: 后续 Git migration 已把默认入口迁到 `fpdev.git.operations` / `fpdev.git.operations.impl`，`fpdev.utils.git` compatibility shim has since been removed。

## 代码变更统计

| 指标             | 变更                                  |
| ---------------- | ------------------------------------- |
| 移除代码行数     | ~80 行                                |
| 修改文件数       | 5 个                                  |
| 移除接口         | 2 个 (IFpdevCommand, ICommandContext) |
| @deprecated 标记 | 5 → 0                                 |

## 验证结果

- 编译: 0 warnings, 0 errors
- 测试: 140/140 通过 (100%)
- 功能回归: 无
