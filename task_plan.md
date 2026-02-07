# Task Plan: 项目问题长期修复

## Goal
系统性修复项目中的编译警告、技术债务和代码质量问题，提升代码健壮性和可维护性。

## Current Phase
Phase 1 (partial) / Phase 2 (partial)

## Baseline (2026-02-07)
- 测试状态: 94/94 通过 (100%)
- 编译警告: 28 → 19 (-9)
- 编译提示: 60+ → 28 (-32+)

## Phases

### Phase 1: 高优先级 Warning 修复
- [x] 1.1 修复函数返回值未初始化 (8 处)
- [x] 1.2 修复 Case 语句不完整 (3 处)
- [ ] 1.3 迁移 @deprecated GitManager 调用 (17+ 处) - 需要更大重构
- [ ] 1.4 实现 SHA256 校验和计算 (替换占位符) - 需要更大重构
- **Status:** partial (9/28 warnings fixed)
- **预估工期:** 1-2 天 (剩余部分需要更大重构)

### Phase 2: 中优先级 Hint 修复
- [x] 2.1 修复局部变量未初始化 (9/11 处)
- [x] 2.2 移除未使用的单元引用 (11 个文件)
- [ ] 2.3 移除未使用的参数/变量 (20+ 处) - 需要评估
- **Status:** partial
- **预估工期:** 1-2 天

### Phase 3: 代码重构
- [ ] 3.1 提取重复的错误处理逻辑
- [ ] 3.2 拆分超大文件 (fpdev.cmd.package.pas 等)
- [ ] 3.3 优化长函数
- **Status:** pending
- **预估工期:** 2-3 天

### Phase 4: 文档与测试完善
- [ ] 4.1 BuildManager 文档完善
- [ ] 4.2 日志系统优化 (Windows 时间戳)
- [ ] 4.3 测试覆盖率提升
- **Status:** pending
- **预估工期:** 2-3 天

## Key Files to Fix

### 高优先级 (Warning)
| 文件 | 问题数 | 问题类型 |
|------|--------|---------|
| fpdev.git2.pas | 6 | @deprecated GitManager |
| fpdev.source.repo.pas | 6 | @deprecated GitManager |
| fpdev.fpc.source.pas | 2 | @deprecated 函数 |
| fpdev.fpc.installer.pas | 2 | @deprecated 函数 |
| fpdev.cmd.fpc.pas | 2 | @deprecated 函数 |
| fpdev.config.project.pas | 1 | 返回值未初始化 |
| fpdev.cmd.show.pas | 2 | Case 不完整 |
| fpdev.manifest.pas | 2 | 返回值未初始化 |
| fpdev.fpc.types.pas | 2 | 返回值未初始化 |
| fpdev.cross.manifest.pas | 2 | 返回值未初始化 |
| fpdev.cmd.package.pas | 2 | 返回值未初始化 |
| fpdev.toolchain.fetcher.pas | 1 | Case 不完整 |
| fpdev.package.resolver.pas | 1 | TODO: SHA256 |

### 中优先级 (Hint)
| 文件 | 问题数 | 问题类型 |
|------|--------|---------|
| fpdev.utils.fs.pas | 1 | 变量未初始化 |
| fpdev.build.cache.pas | 2 | 变量未初始化/未使用 |
| fpdev.command.registry.pas | 1 | 变量未初始化 |
| fpdev.toolchain.fetcher.pas | 1 | 变量未初始化 |
| fpdev.cmd.package.pas | 6 | 变量未初始化/未使用 |
| fpdev.cross.manifest.pas | 2 | 变量未初始化 |
| fpdev.fpc.version.pas | 1 | 变量未初始化 |

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 先修 Warning 再修 Hint | Warning 可能导致运行时错误 |
| 保持测试通过 | 每次修改后验证测试 |
| 分批提交 | 便于回滚和追踪 |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
|       | 1       |            |

## Verification Command
```bash
# 编译检查
lazbuild -B fpdev.lpi 2>&1 | grep -E "(Warning|Error|Hint)"

# 测试验证
bash scripts/run_all_tests.sh
```

## Notes
- 当前工作区有未提交的改动 (16 files changed)
- 这些改动是之前测试稳定化任务的结果
- 建议先提交这些改动，再开始新的修复工作
