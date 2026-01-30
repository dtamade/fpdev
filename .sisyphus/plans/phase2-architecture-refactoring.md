# Phase 2: 架构重构实施计划

## TL;DR

> **Quick Summary**: 基于实际代码库状态重构架构问题：TBuildManager 紧耦合、4个全局单例、重复的Git管理器。采用接口驱动的依赖注入模式（参考现有 config 系统）。
> 
> **Deliverables**: 
> - TBuildManager 接口化（IBuildLogger, IToolchainChecker, IBuildManager）
> - 统一 Git 管理器（合并 SharedGitManager 和 FGitManager）
> - 全局单例迁移到构造函数注入（TErrorRegistry, GI18nManager）
> - 工具类接口抽象（IProcessExecutor, IGitOperations）
> 
> **Estimated Effort**: Medium (8-12 days, 2-3 weeks)
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Phase 2.1 → Phase 2.2 → Phase 2.3 → Phase 2.4

---

## 执行摘要

### 总工作量
- **预计时间**: 8-12 天（2-3 周）
- **总任务数**: 18 个主要任务
- **并行机会**: 4 个并行波次，可节省约 30% 时间

### 关键里程碑
1. **Milestone 1** (Day 3): TBuildManager 接口化完成，所有测试通过
2. **Milestone 2** (Day 6): Git 管理器统一完成，重复代码消除
3. **Milestone 3** (Day 9): 全局单例迁移完成，依赖注入全面应用
4. **Milestone 4** (Day 12): 工具类接口化完成，架构重构验收

### 主要风险
1. **风险 1**: TBuildManager 依赖复杂，可能影响现有构建流程
   - **缓解**: 保留向后兼容的 Facade 模式，渐进式迁移
   - **回滚**: Git 分支隔离，每个 Phase 独立提交

2. **风险 2**: Git 管理器合并可能破坏现有调用点
   - **缓解**: 先创建统一接口，保留旧实现作为 deprecated wrapper
   - **回滚**: 保留旧代码 30 天，标记 @deprecated

3. **风险 3**: 全局单例迁移可能引入循环依赖
   - **缓解**: 使用接口间接引用（参考 config 系统的 IConfigChangeNotifier 模式）
   - **回滚**: 每个单例独立提交，可单独回滚

---

## Context

### Original Request
用户要求基于 fpdev 项目成熟度审查报告，制定 Phase 2: 架构重构的详细实施计划。

### Interview Summary
**关键发现**:
- **TFPCManager 不存在**: 原审查报告已过时，该类已被重构为 5 个专业服务
  - `TFPCBinaryInstaller`, `TFPCVersionManager`, `TFPCSourceBuilder`, `TFPCActivationManager`, `TFPCValidator`
- **TBuildManager 存在**: 需要接口注入重构（当前紧耦合到 TBuildLogger, TBuildToolchainChecker）
- **4 个全局单例**: TErrorRegistry, GI18nManager, SharedGitManager, FGitManager
- **成功模式存在**: `fpdev.config.interfaces.pas` + `fpdev.config.managers.pas` 是完美的参考模型

**Research Findings**:
- **Explore Agent**: 发现 TFPCManager 已不存在，TBuildManager 需要重构，Git 管理器重复
- **Librarian Agent**: 推荐接口驱动的 DI（无容器），适合 CLI 工具，简单且可测试

### Metis Review
**Identified Gaps** (addressed):
- Gap 1: 原计划基于过时信息（TFPCManager） → 重新定义 Phase 2 范围
- Gap 2: 需要明确向后兼容策略 → 采用 Facade 模式保留旧 API
- Gap 3: 测试策略未明确 → 每个 Phase 包含 TDD 测试任务

---

## Work Objectives

### Core Objective
重构 fpdev 架构，消除紧耦合和全局单例，采用接口驱动的依赖注入模式，提升可测试性和可维护性。

### Concrete Deliverables
1. **接口定义文件**:
   - `src/fpdev.build.interfaces.pas` - Build 系统接口
   - `src/fpdev.git.interfaces.pas` - Git 操作接口（统一）
   - `src/fpdev.process.interfaces.pas` - 进程执行接口

2. **重构后的实现**:
   - `src/fpdev.build.manager.pas` - 使用接口注入
   - `src/fpdev.git.unified.pas` - 统一的 Git 管理器
   - `src/fpdev.errors.pas` - 作用域实例（非单例）
   - `src/fpc.i18n.pas` - 作用域实例（非单例）

3. **测试文件**:
   - `tests/test_build_interfaces.lpr` - Build 接口测试
   - `tests/test_git_unified.lpr` - 统一 Git 管理器测试
   - `tests/test_di_migration.lpr` - DI 迁移集成测试

### Definition of Done
- [ ] 所有现有测试通过（零回归）
- [ ] 新增接口测试覆盖率 ≥ 80%
- [ ] 所有全局单例已迁移到构造函数注入
- [ ] TBuildManager 使用接口注入
- [ ] Git 管理器统一为单一实现
- [ ] 向后兼容 API 保留（标记 @deprecated）
- [ ] 文档更新（CLAUDE.md, docs/architecture.md）

### Must Have
- **零回归**: 所有现有测试必须通过
- **向后兼容**: 旧 API 保留至少 30 天（标记 deprecated）
- **渐进式重构**: 每个 Phase 独立提交，可单独回滚
- **测试驱动**: 每个重构步骤都有测试覆盖

### Must NOT Have (Guardrails)
- **不引入外部 DI 容器**: 使用简单的接口注入模式（参考 config 系统）
- **不一次性重写**: 渐进式迁移，保留 Facade 模式
- **不破坏现有 API**: 命令层调用保持兼容
- **不引入循环依赖**: 使用接口间接引用打破循环

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (FPCUnit framework)
- **User wants tests**: TDD (Red-Green-Refactor)
- **Framework**: FPCUnit (Object Pascal 标准测试框架)

### TDD Workflow

Each TODO follows RED-GREEN-REFACTOR:

**Task Structure:**
1. **RED**: Write failing test first
   - Test file: `tests/test_*.lpr`
   - Test command: `lazbuild -B tests/test_*.lpr && ./bin/test_*`
   - Expected: FAIL (test exists, implementation doesn't)
2. **GREEN**: Implement minimum code to pass
   - Command: `lazbuild -B tests/test_*.lpr && ./bin/test_*`
   - Expected: PASS
3. **REFACTOR**: Clean up while keeping green
   - Command: `lazbuild -B tests/test_*.lpr && ./bin/test_*`
   - Expected: PASS (still)

### Automated Verification

**For each Phase:**
```bash
# Build all tests
lazbuild -B tests/test_build_interfaces.lpr
lazbuild -B tests/test_git_unified.lpr
lazbuild -B tests/test_di_migration.lpr

# Run all tests
./bin/test_build_interfaces
./bin/test_git_unified
./bin/test_di_migration

# Expected: All tests PASS
```

**Regression Check:**
```bash
# Run existing test suite
tests/fpdev.build.manager/run_tests.bat  # Windows
tests/fpdev.build.manager/run_tests.sh   # Linux/macOS

# Expected: All existing tests still PASS
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Day 1-3): Phase 2.1 - TBuildManager 接口化
├── Task 1: 创建 Build 接口定义
├── Task 2: 重构 TBuildLogger 为接口
├── Task 3: 重构 TBuildToolchainChecker 为接口
└── Task 4: 更新 TBuildManager 构造函数

Wave 2 (Day 4-6): Phase 2.2 - Git 管理器统一
├── Task 5: 创建统一 Git 接口
├── Task 6: 实现统一 Git 管理器
├── Task 7: 迁移 SharedGitManager 调用点
└── Task 8: 迁移 FGitManager 调用点

Wave 3 (Day 7-9): Phase 2.3 - 全局单例迁移
├── Task 9: TErrorRegistry 迁移
├── Task 10: GI18nManager 迁移
└── Task 11: 命令层依赖注入更新

Wave 4 (Day 10-12): Phase 2.4 - 工具类接口化
├── Task 12: IProcessExecutor 接口
├── Task 13: IGitOperations 接口
└── Task 14: 集成测试和文档更新

Critical Path: Wave 1 → Wave 2 → Wave 3 → Wave 4
Parallel Speedup: ~30% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3, 4 | 5 |
| 2 | 1 | 4 | 3 |
| 3 | 1 | 4 | 2 |
| 4 | 2, 3 | None | None |
| 5 | None | 6, 7, 8 | 1 |
| 6 | 5 | 7, 8 | None |
| 7 | 6 | None | 8 |
| 8 | 6 | None | 7 |
| 9 | 4 | 11 | 10 |
| 10 | 4 | 11 | 9 |
| 11 | 9, 10 | None | None |
| 12 | 11 | 14 | 13 |
| 13 | 11 | 14 | 12 |
| 14 | 12, 13 | None | None |

---

