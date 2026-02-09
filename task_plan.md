# Task Plan: 项目问题长期修复（Phase 4 长期自治）

## Goal
在保持测试稳定通过的前提下，通过“批次模式”持续清理编译警告、技术债务和代码质量问题，做到低干预长期推进。

## Working Mode (Phase 4)
- Mode: Autonomous Batch
- Batch SLA: 每批 60-120 分钟，单目标，WIP=1
- Batch Output: 修改文件 + 验证命令 + 风险 + 下一批建议
- Milestone Report: 每完成 5 个批次或 1 天输出一次
- Stop Rules: 触发破坏性操作、外部依赖变更、架构级变更时暂停并请求确认

## Current Phase
Phase 4 (active) / Phase 1-3 (rolling backlog)

## Active Milestones (Phase 4)

### M1: 编译健康与基线冻结
- [x] B001 重新冻结基线（warning/hint/test）
- [x] B002 收敛可安全修复的 warning 列表并分批

### M2: 高风险债务有序迁移
- [x] B003 第一批命令占位实现清零（installer/lockfile/registry）
- [x] B004 第二批 @deprecated GitManager 迁移（低耦合点）
- [x] B005 第三批 deprecated API 迁移（TFPCBinaryInstaller + cross.downloader）

### M3: 质量闭环与可持续交付
- [x] B006 补充对应测试并跑回归
- [x] B007 清理低风险未使用参数/变量
- [x] B008 文档同步（迁移说明 + 验证路径）

### M4: 结构化治理与自治扩展
- [x] B009 大文件拆分预研（切片方案）
- [x] B010 里程碑报告（阶段收口）
- [x] B011 剩余 Hint 收敛（src=0）
- [x] B012 新任务池扫描（自治续跑）
- [x] B013 大文件拆分试点（Semantic Version helper 抽离）
- [x] B014 质量项清理（debug 检测误报收敛）
- [x] B015 常量治理（硬编码常量分类并抽离可配置项）
- [x] B016 拆分第二切片（Dependency Graph helper 抽离）
- [x] B017 自治复盘（任务池刷新与优先级重排）
- [x] B018 下一轮拆分立项（B019-B021 切片边界确定）
- [x] B019 第三切片执行（Package Verification helper 抽离）
- [x] B020 第四切片执行（Package Creation helper 抽离）
- [x] B021 第五切片执行（Package Validation helper 抽离）
- [x] B022 周期复盘（B015-B021 收口确认）
- [x] B023 横向拆分立项（resource.repo/build.cache）
- [x] B024 resource.repo 第一切片执行（bootstrap helper）
- [x] B025 build.cache 第一切片执行（key helper）
- [x] B026 周期复盘（B023-B025 收口）
- [x] B027 resource.repo 第二切片执行（mirror helper）
- [x] B028 build.cache 第二切片执行（entries helper）
- [x] B029 周期复盘（B027-B028 收口）
- [x] B030 resource.repo 第三切片执行（mirror candidates helper）
- [x] B031 build.cache 第三切片执行（indexjson helper）
- [x] B032 周期复盘（B030-B031 收口）
- [x] B033 resource.repo 第四切片执行（getmirrors helper）
- [x] B034 build.cache 第四切片执行（indexio helper）
- [x] B035 周期复盘（B033-B034 收口）
- [x] B036 resource.repo 第五切片执行（selectbest helper）
- [x] B037 build.cache 第五切片执行（rebuildscan helper）
- [x] B038 周期复盘（B036-B037 收口）
- [x] B039 resource.repo 第六切片执行（ttl helper）
- [x] B040 build.cache 第六切片执行（index stats helper）
- [x] B041 周期复盘（B039-B040 收口）
- [x] B042 resource.repo 第七切片执行（mirror cache set helper）
- [x] B043 build.cache 第七切片执行（index lookup helper）
- [x] B044 周期复盘（B042-B043 收口）
- [x] B045 resource.repo 第八切片执行（package query helper）
- [x] B046 build.cache 第八切片执行（stats report helper）
- [x] B047 周期复盘（B045-B046 收口）
- [x] B048 resource.repo 第九切片执行（search packages helper）
- [x] B049-B051 周期复盘与低风险 Note 清理
- [x] B053 命令注册表测试 (test_command_registry.lpr)
- [x] B055 退出码常量收口
- [x] B057 package deps 命令
- [x] B058 package why 命令
- [x] B059 README 测试数量更新
- [x] B062 build.cache/resource.repo 懒加载优化
- [x] B063 清理 package 命令未使用的单元和变量
- [x] B064 修复 Manifest 懒加载状态机一致性
- [x] B065 修复 RebuildIndex 旧索引回灌问题
- [x] B066 统一 Ensure* 契约文档
- [x] B067 大文件拆分 (resource.repo binary 查询)
- [x] B068 懒加载并发安全文档
- [x] B069 大文件拆分 (resource.repo cross 查询)
- [x] B070 大文件拆分 (build.cache metajson 处理)
- [x] B071 大文件拆分 (build.cache SHA256 验证)
- [x] B072 大文件拆分 (build.cache TTL 过期检测)
- [x] B073 大文件拆分 (build.cache 文件操作工具)
- [x] B074 大文件拆分 (build.cache 旧版 meta 格式)
- [x] B075 大文件拆分 (build.cache binary meta 格式)
- [x] B076 大文件拆分 (build.cache 目录扫描)
- [x] B077 大文件拆分 (build.cache 条目文件 I/O)
- [x] B078 大文件拆分收口评估
- [x] B079 helper 单元测试补充 (7 个测试文件 + scan bug 修复)
- [x] B080 helper 单元测试补充 (剩余 7 个测试文件)
- [x] B081 resource.repo helper 单元测试 (6 个测试文件)
- [x] B082 修复 TJSONObject.Objects[] latent bug

## Batch Queue (Week 1)

| Batch | Scope | Done Criteria |
|------|-------|---------------|
| B001 | 基线冻结 | 输出 warning/hint/test 当前真实值并写入 progress |
| B002 | Warning 分批清单 | 形成可执行批次（按文件+风险分组） |
| B003 | GitManager 迁移批次 1 | 相关模块编译通过 + 关键测试通过 |
| B004 | GitManager 迁移批次 2 | 相关模块编译通过 + 无新增 warning |
| B005 | deprecated API 迁移 | 清理 installer/cmd/cross/source 弃用调用并无新增 warning |
| B006 | 回归验证 | `scripts/run_all_tests.sh` 通过 |
| B007 | Hint 清理 | 无行为变更前提下减少未使用项 |
| B008 | 文档补齐 | 文档可指导下一批执行 |
| B009 | 大文件拆分预研 | 给出拆分设计和最小切片计划 |
| B010 | 里程碑报告 | 输出里程碑总结与下一周待办池 |
| B011 | 剩余 Hint 收敛 | 收敛最后两条 hint，保持测试通过 |
| B012 | 新任务池扫描 | 基于指标自动生成下一轮批次 |
| B013 | 大文件拆分试点 | 对 `fpdev.cmd.package` 执行第一切片且回归通过 |
| B014 | 质量项清理 | 收敛代码风格/调试输出类低风险问题 |
| B015 | 常量治理 | 硬编码常量分类并抽离可配置项 |
| B016 | 拆分第二切片 | 对 `fpdev.cmd.package` 抽离 Dependency Graph 并回归通过 |
| B017 | 自治复盘 | 更新任务池与下一轮优先级 |
| B018 | 下一轮拆分立项 | 基于热区与风险生成 B019-B021 可执行切片 |
| B019 | 第三切片执行 | 对 `fpdev.cmd.package` 执行 Package Verification 切片 |
| B020 | 第四切片执行 | 对 `fpdev.cmd.package` 执行 Package Creation 切片 |
| B021 | 第五切片执行 | 对 `fpdev.cmd.package` 执行 Package Validation 切片 |
| B022 | 周期复盘 | 汇总 B015-B021 结果并刷新下轮池 |
| B023 | 横向拆分立项 | 为 `resource.repo/build.cache` 生成切片计划 |
| B024 | resource.repo 第一切片执行 | 抽离 bootstrap 映射/解析 helper 并回归通过 |
| B025 | build.cache 第一切片执行 | 抽离平台/键值 helper 并回归通过 |
| B026 | 周期复盘 | 汇总 B023-B025 并刷新任务池 |
| B027 | resource.repo 第二切片执行 | 抽离镜像探测/延迟测试 helper 并回归通过 |
| B028 | build.cache 第二切片执行 | 抽离 entries/index helper 并回归通过 |
| B029 | 周期复盘 | 汇总 B027-B028 并刷新任务池 |
| B030 | resource.repo 第三切片执行 | 抽离 GetMirrors/SelectBestMirror 候选逻辑并回归通过 |
| B031 | build.cache 第三切片执行 | 抽离 index JSON 读写 helper 并回归通过 |
| B032 | 周期复盘 | 汇总 B030-B031 并刷新任务池 |
| B033 | resource.repo 第四切片执行 | 抽离 GetMirrors 解析 helper 并回归通过 |
| B034 | build.cache 第四切片执行 | 抽离 Load/SaveIndex I/O helper 并回归通过 |
| B035 | 周期复盘 | 汇总 B033-B034 并刷新任务池 |
| B036 | resource.repo 第五切片执行 | 抽离 SelectBestMirror 测速选择 helper 并回归通过 |
| B037 | build.cache 第五切片执行 | 抽离 RebuildIndex 扫描 helper 并回归通过 |
| B038 | 周期复盘 | 汇总 B036-B037 并刷新任务池 |
| B039 | resource.repo 第六切片执行 | 抽离 mirror cache TTL helper 并回归通过 |
| B040 | build.cache 第六切片执行 | 抽离 index stats helper 并回归通过 |
| B041 | 周期复盘 | 汇总 B039-B040 结果并刷新下轮池 |
| B042 | resource.repo 第七切片执行 | 抽离 mirror cache set helper 并回归通过 |
| B043 | build.cache 第七切片执行 | 抽离 index lookup helper 并回归通过 |
| B044 | 周期复盘 | 汇总 B042-B043 结果并刷新下轮池 |
| B045 | resource.repo 第八切片执行 | 抽离 package query helper 并回归通过 |
| B046 | build.cache 第八切片执行 | 抽离 stats report helper 并回归通过 |
| B047 | 周期复盘 | 汇总 B045-B046 结果并刷新下轮池 |

## Current Batch
B083 (next)

## Baseline (2026-02-09)
- 测试状态: 115/115 通过 (100%)
- 编译警告: 0（`/src/` 范围）
- 编译提示: 0 hints, 0 notes（`/src/` 范围）
- 测试覆盖增加: +29 (B082 恢复跳过的测试)

## Phases

### Phase 1: 高优先级 Warning 修复
- [x] 1.1 修复函数返回值未初始化 (8 处)
- [x] 1.2 修复 Case 语句不完整 (3 处)
- [x] 1.3 迁移 @deprecated GitManager 调用 (17+ 处) - 需要更大重构
- [x] 1.4 实现 SHA256 校验和计算 (替换占位符) - 需要更大重构
- **Status:** complete (warnings(src)=0)
- **预估工期:** 已完成

### Phase 2: 中优先级 Hint 修复
- [x] 2.1 修复局部变量未初始化 (9/11 处)
- [x] 2.2 移除未使用的单元引用 (11 个文件)
- [x] 2.3 移除未使用的参数/变量 (20+ 处) - 已完成低风险收敛
- **Status:** complete (hints(src)=0)
- **预估工期:** 已完成

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
| `zsh: read-only variable: status` | 1 | 变量改名为 `exit_code` 后重跑通过 |
| B013 语义块初次定位错位（命中 interface 声明） | 1 | 改为从 `start` 后查找 `end marker`，精确替换成功 |
| B016 首次切片命中范围错误（误替换过大） | 1 | 立即 `git checkout -- src/fpdev.cmd.package.pas`，改为“implementation 后锚点”重做成功 |
| B020 helper 编译失败（`GetFileListRecursive` 未定义） | 1 | 改为复用原始递归扫描实现，编译恢复 |
| B021 误覆盖现有命令单元 `fpdev.cmd.package.validate` | 1 | 立即恢复原单元，helper 改名为 `fpdev.cmd.package.validation` |

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

### M5: 后端探索开发任务（B053-B062）
- [ ] B053 命令契约测试矩阵 - 新增 command-registry 级别测试
- [ ] B054 测试发现器升级 - 支持嵌套测试目录
- [ ] B055 退出码残余清理 - 检查遗漏的魔法数字
- [ ] B056 错误语义统一 - 帮助文档与实际行为对齐
- [ ] B057 package deps 命令 - 依赖树展示
- [ ] B058 package why 命令 - 依赖路径解释
- [ ] B059 文档基线对齐 - README 命令集更新
- [ ] B060 文档测试规模更新 - 测试数量与覆盖率
- [ ] B061 resource.repo 懒加载 - 延迟初始化优化
- [ ] B062 build.cache 分层 - 子服务拆分

## Current Batch
B053 (in_progress)
