# Findings & Decisions

## 项目问题扫描结果 (2026-02-07)

### 扫描范围
- 目录: `/home/dtamade/projects/fpdev`
- 重点: `src/` 目录下的 Pascal 源代码

### 问题统计
| 类别 | 数量 | 优先级 |
|------|------|--------|
| Warning: @deprecated 使用 | 17+ | 高 |
| Warning: 返回值未初始化 | 8 | 高 |
| Warning: Case 不完整 | 3 | 高 |
| Hint: 变量未初始化 | 10+ | 中 |
| Hint: 未使用单元 | 24+ | 低 |
| Hint: 未使用参数/变量 | 20+ | 低 |
| TODO/FIXME | 1 (关键) | 高 |
| 超大文件 (>1000行) | 10 | 中 |

## 高优先级问题详情

### 1. @deprecated GitManager 使用 (17+ 处)

**问题**: Phase 2 架构重构后，`GitManager` 已标记为 `@deprecated`，应迁移到 `NewGitManager()`。

**影响文件**:
- `fpdev.git2.pas` (6 处)
- `fpdev.source.repo.pas` (6 处)
- `fpdev.fpc.source.pas` (2 处)
- `fpdev.fpc.installer.pas` (2 处)
- `fpdev.cmd.fpc.pas` (2 处)

**迁移方案**:
```pascal
// 旧代码
uses fpdev.git2;
Repo := GitManager.OpenRepository('.');

// 新代码
uses git2.api, git2.impl;
var Mgr: IGitManager;
Mgr := NewGitManager();
Mgr.Initialize;
Repo := Mgr.OpenRepository('.');
```

### 2. 函数返回值未初始化 (8 处)

**问题**: 返回 managed type (string, array) 的函数未初始化返回值。

**影响文件**:
| 文件 | 行号 |
|------|------|
| fpdev.config.project.pas | 324 |
| fpdev.manifest.pas | 476, 486 |
| fpdev.fpc.types.pas | 163, 173 |
| fpdev.cross.manifest.pas | 161, 341 |
| fpdev.cmd.package.pas | 2297, 2447 |

**修复方案**:
```pascal
// 对于 string
Result := '';

// 对于 array
SetLength(Result, 0);
// 或
Result := nil;
```

### 3. Case 语句不完整 (3 处)

**影响文件**:
| 文件 | 行号 |
|------|------|
| fpdev.cmd.show.pas | 117, 132 |
| fpdev.toolchain.fetcher.pas | 209 |

**修复方案**: 添加 `else` 分支处理未覆盖的情况。

### 4. TODO: SHA256 校验和占位符

**位置**: `fpdev.package.resolver.pas:251`

**问题**: 包锁定文件使用 `'sha256-placeholder'` 占位符，影响完整性验证。

**修复方案**: 实现实际的 SHA256 计算逻辑。

## 中优先级问题详情

### 变量未初始化 (10+ 处)

| 文件 | 行号 | 变量 |
|------|------|------|
| fpdev.utils.fs.pas | 242 | StatBuf |
| fpdev.build.cache.pas | 1265 | Entries |
| fpdev.command.registry.pas | 124 | D |
| fpdev.toolchain.fetcher.pas | 285 | URLs |
| fpdev.cmd.package.pas | 1758, 1771, 2053, 2082 | 多个 |
| fpdev.cross.manifest.pas | 433, 455 | AManifestTarget, ABinutils |
| fpdev.fpc.version.pas | 369 | Info |

## 技术债务 (来自计划文件)

### Phase C: 技术债务清理
- C.1: Wave 4 提前执行 - 清理 @deprecated 代码 (1-2 天)
- C.2: 测试覆盖率提升 (2-3 天)
- C.3: 代码重构 (2-3 天)

### Phase A: 待办事项完成
- BuildManager 文档完善 (0.5-1 天)
- 日志系统优化 (0.5 天)
- Git2 功能扩展 (1-1.5 天)

## 超大文件 (需要拆分)

| 文件 | 行数 |
|------|------|
| fpdev.cmd.package.pas | 2487 |
| fpdev.resource.repo.pas | 1996 |
| fpdev.build.cache.pas | 1954 |
| fpdev.config.managers.pas | 1345 |
| fpdev.fpc.installer.pas | 1307 |
| fpdev.cmd.fpc.pas | 1279 |
| fpdev.cmd.cross.pas | 1247 |
| fpdev.build.manager.pas | 1234 |
| fpdev.git2.pas | 1050 |

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| 先修 Warning 再修 Hint | Warning 可能导致运行时错误 |
| 保持测试通过 | 每次修改后验证测试 |
| 分批提交 | 便于回滚和追踪 |
| @deprecated 迁移优先 | 符合 Phase 2 架构重构计划 |

## Resources

- 全量测试: `scripts/run_all_tests.sh`
- 编译检查: `lazbuild -B fpdev.lpi 2>&1 | grep -E "(Warning|Error|Hint)"`
- Phase 2 迁移指南: `docs/PHASE2-MIGRATION-GUIDE.md`
