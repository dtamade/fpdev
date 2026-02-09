# B166: @deprecated 清理准备

## 完成日期
2026-02-10

## 现状扫描

### @deprecated 标记分布

| 文件 | 行号 | 废弃内容 | 替代方案 |
|------|------|----------|----------|
| fpdev.cmd.repo.list.pas | 53 | Legacy Execute interface | Execute(IContext) |
| fpdev.cmd.repo.remove.pas | 64 | Legacy Execute interface | Execute(IContext) |
| fpdev.cmd.repo.add.pas | 68 | Legacy Execute interface | Execute(IContext) |
| fpdev.cmd.repo.default.pas | 67 | Legacy Execute interface | Execute(IContext) |
| fpdev.utils.git.pas | 67 | SharedGitManager singleton | git2.api + git2.impl |

**总计**: 5 处 @deprecated 标记

### 分类分析

#### 类型 1: Legacy Execute 接口 (4 处)

```pascal
{ @deprecated Use Execute(IContext) instead. Legacy interface for backward compatibility. }
```

**影响范围**:
- `fpdev.cmd.repo.list.pas`
- `fpdev.cmd.repo.remove.pas`
- `fpdev.cmd.repo.add.pas`
- `fpdev.cmd.repo.default.pas`

**迁移状态**: 已完成
- 新的 Execute(IContext) 接口已实现并在使用
- @deprecated 代码保留用于向后兼容
- 无外部依赖，可安全移除

#### 类型 2: Git 单例 (1 处)

```pascal
{ @deprecated Internal implementation detail. Use git2.api.pas + git2.impl.pas directly. }
```

**影响范围**:
- `fpdev.utils.git.pas:67` - `SharedGitManager` 函数

**迁移状态**: Phase 2 已完成
- `git2.api.pas` + `git2.impl.pas` 新接口已可用
- 所有新代码应使用 `NewGitManager()` 工厂函数
- 旧代码可继续使用 `SharedGitManager` 直到 Wave 4 移除

## 清理计划

### 阶段 1: 标记审计 (完成)
- [x] 扫描所有 @deprecated 标记
- [x] 分类分析影响范围
- [x] 确认替代方案可用

### 阶段 2: 渐进移除 (计划)

| 优先级 | 目标 | 风险 | 时间估算 |
|--------|------|------|----------|
| P1 | repo.*.pas 旧 Execute | 低 | 0.5h |
| P2 | SharedGitManager | 中 | 1h |

### 阶段 3: 验证 (计划)
- [ ] 运行全量测试确保无回归
- [ ] 更新 CLAUDE.md 移除废弃代码文档
- [ ] 提交变更

## 建议

1. **保守策略**: 当前 @deprecated 代码不影响功能，可延迟清理
2. **如需清理**: 优先移除 repo.*.pas 中的 4 处，风险最低
3. **Git 单例**: 保留 SharedGitManager 直到确认所有调用已迁移

## 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 外部工具依赖旧接口 | 低 | 中 | 先发布废弃警告 |
| 测试覆盖不足 | 低 | 高 | 清理前运行全量测试 |
| 文档不同步 | 中 | 低 | 同步更新 CLAUDE.md |
