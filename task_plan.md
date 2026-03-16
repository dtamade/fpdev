# 2026-03-15 GitOps Builder.DI 收口计划

## Goal
让 `src/fpdev.fpc.builder.di.pas` 的 git clone/pull 统一经过 `fpdev.utils.git.TGitOperations`，并把 `TFPCBuilder.UpdateSources` 收敛为 fast-forward-only，同时保持 DI 测试可控和现有 `TGitOperations` 调用兼容。

## Current Phase
Phase 1

## Phases

### Phase 1: Discovery & Test Targets
- [ ] 读取 `builder.di`、`fpdev.utils.git`、process runner/result 类型与相关测试
- [ ] 确认现有 clone/pull fallback 行为与测试断言
- [ ] 在 `findings.md` 记录接口边界与风险
- **Status:** complete

### Phase 2: RED
- [ ] 调整或新增测试，先捕获 injectable CLI fallback 和 fast-forward-only 行为
- [ ] 运行定向测试，确认至少一个失败点来自目标变更
- **Status:** complete

### Phase 3: GREEN
- [ ] 给 `TGitOperations` 增加 injectable CLI runner / cli-only 构造能力
- [ ] 在 `builder.di` 增加 runner adapter，并改为通过 `TGitOperations` 执行 clone
- [ ] 将 `UpdateSources` 的非 fast-forward 场景改成可行动错误
- **Status:** complete

### Phase 4: Verification
- [ ] 跑 `tests/test_fpc_builder.lpr`
- [ ] 跑 `tests/test_git_operations.lpr`
- [ ] 跑 `scripts/run_all_tests.sh`
- **Status:** complete

### Phase 5: Delivery
- [ ] 复核需求逐条满足情况
- [ ] 记录风险、剩余假设和验证结果
- **Status:** in_progress

## 2026-03-16 User-Facing Update Flow Alignment

### Goal
确认用户态 `fpdev fpc update` 是否也需要和 `builder.di` 一样收敛为 fast-forward-only；若需要，则先用测试锁定行为再最小实现。

### Current Phase
Phase 1

### Phases

#### Phase 1: Discovery
- [ ] 确认 `fpdev fpc update` 的实际调用链与当前语义
- [ ] 确认现有 `test_fpc_update` / `test_fpc_runtimeflow` 覆盖边界
- [ ] 记录 runtime 路径和 builder 路径的差异
- **Status:** complete

#### Phase 2: RED
- [ ] 如果决定对齐语义，先新增失败测试
- [ ] 运行 focused tests 确认 RED
- **Status:** pending

#### Phase 3: GREEN
- [ ] 最小修改 runtime/git 层实现
- [ ] 保持 `no remote` / `local-only` 等既有语义不变
- **Status:** pending

#### Phase 4: Verification
- [ ] 跑 focused tests
- [ ] 跑相关回归
- **Status:** complete

#### Phase 5: Wording Cleanup
- [ ] 清理活跃文件中仍残留的过时 `git pull` 表述
- [ ] 保持历史归档文档不动
- **Status:** complete

#### Phase 6: Test Naming Cleanup
- [ ] 清理活跃测试中与当前行为不符的 update 文案
- [ ] 跑最小验证确认仅为措辞调整
- **Status:** complete

## 2026-03-16 FPC/Lazarus Cross-Platform Build Hardening

### Goal
优先修复当前已复现/已证据化的构建稳定性问题，并为 FPC/Lazarus 源码构建的跨平台 make-family 选择建立可测试 contract。

### Current Phase
Phase 4

### Phases

#### Phase 1: Discovery
- [ ] 盘点 FPC/Lazarus 主构建入口、平台分支和现有测试覆盖
- [ ] 复现当前本地构建基线与真实不稳定点
- [ ] 记录可在本机直接证明的问题与无法直接证明的平台风险
- **Status:** complete

#### Phase 2: RED
- [ ] 建立 make-family 选择的 focused test
- [ ] 建立 `run_all_tests` FPC fallback 隔离 unit output 的回归测试
- **Status:** complete

#### Phase 3: GREEN
- [ ] 在 `fpdev.build.toolchain` 中抽出纯 helper，统一 Windows/Unix make-family 选择
- [ ] 让 `run_all_tests.sh` 的 direct `fpc` fallback 不再写共享 `lib/`
- **Status:** complete

#### Phase 4: Verification
- [ ] 跑 focused Python / Pascal tests
- [ ] 跑 `lazbuild -B fpdev.lpi`
- [ ] 跑 `scripts/run_all_tests.sh`
- **Status:** complete

#### Phase 5: Residual Risks
- [ ] 记录这批没有解决的高风险项：FPC/Lazarus 主源码构建仍未完全收敛到统一平台 helper，Windows/macOS 真实执行仍待后续批次
- **Status:** in_progress

#### Phase 6: Lazarus/FPC Source Build Wiring
- [ ] 为 Lazarus 源码构建增加纯 build-plan helper，并锁定 Windows/Unix 参数差异
- [ ] 让 `TLazarusManager.BuildFromSource` 使用共享 make-family 选择
- [ ] 让 `TFPCSourceBuilder.BuildFromSource` 使用共享 make-family 选择
- [ ] 跑 focused + broader verification
- **Status:** complete

## Key Questions
1. `TGitOperations` 当前 CLI fallback 的执行点和错误语义是什么？
2. `tests/test_fpc_builder.lpr` 对 clone/pull 的 mock 断言有多细，哪些需要顺着实现调整？
3. `IGitRepositoryExt.PullFastForward` 返回值在 builder 层目前分别如何处理？

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| 先按 TDD 跑 focused tests，再改实现 | 这次改动会碰到 DI、libgit2/CLI 后端和错误语义，先锁测试边界更稳 |
| 规划文件沿用仓库现有 `task_plan.md` / `findings.md` / `progress.md`，追加本次任务节 | 避免覆盖已有长期自治记录，同时满足 planning-with-files 持久化要求 |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `search_context` 返回了很多历史 planning 命中，精确源码命中不足 | 1 | 结合精确文件读取和符号搜索继续收敛 |
| `tests/test_git_operations.lpr` 新增 RED 测试编译失败：`IGitCliRunner` 未定义 | 1 | 进入实现阶段，为 `fpdev.utils.git` 增加新接口和构造重载 |

# Task Plan: 项目问题长期修复（Phase 4 长期自治）

## Goal
在保持测试稳定通过的前提下，通过“批次模式”持续清理编译警告、技术债务和代码质量问题，做到低干预长期推进。

## M5: CLI Smoke & Acceptance (2026-02-13)

- [x] Fix `--help` dispatch: leaf commands must receive `--help/-h` flags; namespace roots should route to `<prefix> help`.
- [x] Make `cross build --dry-run` side-effect free and exit 0 even when sources/toolchains are absent.
- [x] Ensure `cross list` is local-only (no implicit network manifest load / no first-run hang).
- [x] Make `cross build` fail fast with actionable errors when sources are missing (`<sourceRoot>/fpc-<version>/Makefile`).
- [x] Add `resolve-version --help` usage output.
- [x] Implement `fpdev --self-test` (toolchain JSON; exit 2 on FAIL).
- [x] Make `fpdev fpc test` (no default toolchain) fall back to system `fpc` in `PATH` and exit 0 on success.
- [x] Prevent `project build` hangs by running verbose build tools without pipe buffering deadlocks.
- [x] Keep `fpc install` CLI tests offline: short-circuit network installs when `FPDEV_SKIP_NETWORK_TESTS=1`.
- [x] Fix BuildManager to fail gracefully when `make` is missing (no `EOSError` crash) + regression test.
- [x] Relax `scripts/check_toolchain.sh` default: required tools gate exit code; optional cross tools are warnings (use `--strict` to enforce).
- [x] Verify smoke: `python3 /tmp/fpdev_cli_smoke.py` => `total 35 ok 35 fail 0 timeout 0`.
- [x] Verify tests: `bash scripts/run_all_tests.sh` => `177/177` pass.
- [x] Verify build: `lazbuild -B fpdev.lpi` => exit 0.

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
B266 ✅ 完成 (`cross targetflow` helper 化；`src/fpdev.cmd.cross.pas` 的 enable/disable/configure/test/buildtest 收成 wrapper；新增 `test_cross_targetflow`；`run_all_tests 234/234`)

## Phase 5: Comprehensive Enhancement (B173+)

### M1: P0 - 清理与基线恢复 (B173-B175)

| Batch | Scope | Done Criteria | Status |
|-------|-------|---------------|--------|
| B173 | 提交当前工作 | 两个逻辑提交（repo.types + env 命令）| ✅ 完成 |
| B174 | 修复 14 个编译警告 | Default() 替代 FillChar | ✅ 完成 (14→0) |
| B175 | 更新文档基线 | CLAUDE.md + CHANGELOG.md + task_plan.md | ✅ 完成 |

### M2: P1-A - 二进制安装核心强化 (B176-B180)

| Batch | Scope | Done Criteria | Status |
|-------|-------|---------------|--------|
| B176 | TDD: 二进制安装测试骨架 | 15+ 测试 (URL/缓存/离线/目录/环境) | ✅ 完成 |
| B177 | Manifest 安装路径修复 | Linux tarball 三层解包 | ✅ 完成 |
| B178 | SourceForge 安装路径修复 | 下载→解压→验证→注册流程 | ✅ 完成 |
| B179 | 缓存 SHA256 真实化 | build.cache placeholder→真实哈希 | ✅ 完成 |
| B180 | 安装后环境设置完善 | fpc.cfg + activate + config.json | ✅ 完成 |

### M3: P1-B - Doctor 与性能监控强化 (B181-B185)

| Batch | Scope | Done Criteria | Status |
|-------|-------|---------------|--------|
| B181 | TDD: FPC Doctor 增强测试 | 20+ 测试 | ✅ 完成 |
| B182 | FPC Doctor 新增检查项 | 7→11 项检查 | ✅ 完成 |
| B183 | TDD: 性能监控集成测试 | 15+ 测试 | ✅ 完成 |
| B184 | 性能监控真实实现 | GetCurrentMemory + BuildManager 埋点 | ✅ 完成 |
| B185 | Package 依赖安装真实化 | InstallDependencies stub→真实实现 | ✅ 完成 |

### M4-M6: P2 - CLI 集成测试覆盖 (B186-B200)

| Batch | Scope | Done Criteria | Status |
|-------|-------|---------------|--------|
| B186 | CLI 测试基础设施 | test_cli_helpers.pas 共享单元 | ✅ 完成 |
| B187-B190 | FPC 命令族 CLI 测试 | 85+ tests | ✅ 完成 |
| B191-B195 | Lazarus/Cross CLI 测试 | 115+ tests | ✅ 完成 |
| B196-B200 | Package/Project/Config CLI 测试 | 125+ tests, 覆盖>80% | ✅ 完成 |

### M7: P3 - 收尾与打磨 (B201-B205)

| Batch | Scope | Done Criteria | Status |
|-------|-------|---------------|--------|
| B201 | 文档 i18n 补全 | *.en.md >= 10 | ✅ 完成 |
| B202 | 大文件拆分（可选）| >500 行文件评估 | ✅ 完成 |
| B203 | 剩余 Stub 清理 | stub < 3 处 | ✅ 完成 |
| B204 | Phase 5 回顾文档 | PHASE5-SUMMARY.md | ✅ 完成 |
| B205 | 全面回归 + 发布准备 | Release 编译 + 0 warnings | ✅ 完成 |

### M8: CLI Contract 收口 (B206)

| Batch | Scope | Done Criteria | Status |
|-------|-------|---------------|--------|
| B206 | `package create` 契约收口 | help/i18n/docs/changelog/test 一致，不再把 create 作为公开命令 | ✅ 完成 (2026-03-05) |
| B207 | `package deps/why` 参数契约收口 | 未知参数与非法 depth 一律 usage error + 回归测试 | ✅ 完成 (2026-03-05) |
| B208 | `package help deps/why` i18n 收口 | deps/why usage/desc/hint 全部改用 i18n 常量 + 回归测试 | ✅ 完成 (2026-03-05) |
| B209 | `package deps/why` 内部 help 文案 i18n 收口 | deps/why 命令内 Options/Examples 迁移到 i18n + 回归测试 | ✅ 完成 (2026-03-05) |
| B210 | `package deps/why` 运行态输出 i18n 收口 | deps/why header/path/summary/constraint 改用 i18n + 运行态断言测试 | ✅ 完成 (2026-03-05) |
| B211 | `package` 子命令未知选项契约收口 | install/list/search/info/publish/clean/install-local/repo* 未知选项统一 usage error + 回归测试 | ✅ 完成 (2026-03-05) |
| B212 | `package` 子命令 help/options i18n 尾差收口 | `--json`/`--dry-run`/`--no-deps` 等剩余 help 文案迁移到 i18n 常量 | ✅ 完成 (2026-03-05) |
| B213 | `package` 运行态提示文案 i18n 收口 | install + deps/why + search 运行态文案迁移到 i18n 并补回归测试 | ✅ 完成 (2026-03-05) |
| B214 | `package list(--all)` 运行态文案尾差收口 | list/all 的 Available/Empty 文案迁移到 i18n 并补最小回归 | ✅ 完成 (2026-03-05) |
| B215 | `package` 核心流程运行态文案尾差扫描 | 继续收口 `src/fpdev.cmd.package.pas` 其余用户可见硬编码并补最小回归 | ✅ 完成 (2026-03-05) |
| B216 | `package` 其余子命令运行态文案尾差扫描 | 收口 `src/fpdev.cmd.package.*.pas` 非 help 的剩余硬编码输出并补最小回归 | ✅ 完成 (2026-03-05，Step 1-3 完成，`run_all_tests 177/177`) |
| B217 | `package install-local` 成功路径语义修复 | 修复 `InstallPackageFromSource` 返回值反转 + 新增 success path CLI 回归 | ✅ 完成 (2026-03-05，`test_cli_package 187/187`, `run_all_tests 177/177`) |
| B218 | `package install-local` 名称解析对齐 | 优先使用 `package.json.name` 作为安装目标名，避免目录名与元数据名不一致导致 publish 路径偏差 | ✅ 完成 (2026-03-05，`test_cli_package 190/190`, `run_all_tests 177/177`) |
| B219 | `package install-local -> publish` 连续性修复 | 安装阶段保留源 metadata 关键字段；发布阶段对空 version 回退并优先使用 source_path 归档；新增 e2e 回归 | ✅ 完成 (2026-03-05，`test_cli_package 196/196`, `run_all_tests 177/177`) |
| B220 | `package publish` 源路径失败语义收口 | metadata `source_path` 不存在时明确失败；空源码目录时输出可定位错误；新增 CLI 回归与 i18n key 断言 | ✅ 完成 (2026-03-05，`test_cli_package 204/204`, `run_all_tests 177/177`) |
| B221 | `package publish` 归档错误码契约收口 | `PublishPackage` 改用归档器错误码判断 no-source 场景，去除英文字符串匹配；补归档器错误码回归 | ✅ 完成 (2026-03-05，`test_package_archiver 18/18`, `test_cli_package 204/204`, `run_all_tests 177/177`) |
| B222 | `package publish` 失败退出码细分 | 命令层返回 manager 提供的 publish 退出码；source_path 缺失映射 `EXIT_NOT_FOUND`，空源码目录保持 `EXIT_ERROR` | ✅ 完成 (2026-03-05，`test_cli_package 204/204`, `run_all_tests 177/177`) |
| B223 | `package publish` 归档 I/O 失败退出码细分 | `tar` 执行失败/归档未生成映射 `EXIT_IO_ERROR`，空源码目录继续 `EXIT_ERROR`；新增 tar 不可用 CLI 回归 | ✅ 完成 (2026-03-06，`test_cli_package 208/208`, `run_all_tests 177/177`) |
| B224 | `package publish` 相对 `source_path` 解析修复 | metadata 相对 `source_path` 改为按安装目录解析，避免受当前工作目录影响；新增 CLI 回归 | ✅ 完成 (2026-03-06，`test_cli_package 211/211`, `run_all_tests 177/177`) |
| B225 | `package publish` metadata 读取异常收口 | metadata 不可读时返回 `EXIT_IO_ERROR`（不崩溃）；metadata 非法 JSON 返回 `EXIT_ERROR`；新增 CLI 回归 | ✅ 完成 (2026-03-06，`test_cli_package 215/215`, `run_all_tests 177/177`) |
| B226 | `package publish` metadata 非法 JSON 契约锁定 | 新增 CLI 回归固定非法 JSON 分支为 `EXIT_ERROR` 并输出 metadata 解析错误提示 | ✅ 完成 (2026-03-06，`test_cli_package 218/218`, `run_all_tests 177/177`) |
| B227 | `package install-local` 自包含发布路径收口 | 安装阶段递归复制源码到安装目录并清空 metadata `source_path`；新增“删除原始源码后仍可 publish”CLI 回归 | ✅ 完成 (2026-03-06，`test_cli_package 222/222`, `run_all_tests 177/177`) |

## Baseline (2026-02-11 Phase 5 M1 End)
- 测试状态: 154/154 通过 (100%)
- 编译警告: 0（全范围）
- @deprecated 标记: 0 处
- 源码文件: 248 个 (.pas)
- 新增命令: fpdev env (overview/vars/path/export)
- 新增类型单元: fpdev.resource.repo.types

## Batch Queue (Week 11 - Phase 2)

| Batch | Scope | Done Criteria | Status |
|-------|-------|---------------|--------|
| B168 | fpdev.cross.platform 测试 | 新单元专项测试 | ✅ 完成 (62用例) |
| B169 | 文档整理 - 归档历史周报 | WEEK*.md 归档到 docs/archive/ | ✅ 完成 (23文件) |
| B170 | 文档整理 - 清理重复文档 | 合并/删除冗余文档 | ✅ 完成 (15文件) |
| B171 | 大文件监控报告 | 更新大文件拆分状态 | ✅ 完成 |
| B172 | Week 11 周期复盘 | 汇总 B162-B171 | ✅ 完成 |

## Baseline (2026-02-10 Week 11 End)
- 测试状态: 141/141 通过 (100%)
- 编译警告: 0（`/src/` 范围）
- @deprecated 标记: 0 处 (B166 清理完成)
- 源码文件: 246 个 (.pas)
- 英文文档: 5 个 (.en.md)
- docs/ 文件: 40 个 (38 个已归档)

---

## B162-B167 完成报告 (已归档)

**完成日期**: 2026-02-10

**文档国际化 (B162-B165)**:
- docs/API.en.md - 英文 API 文档 (~230 行)
- docs/FAQ.en.md - 英文 FAQ 文档 (~200 行)
- docs/ARCHITECTURE.en.md - 英文架构文档 (~200 行)
- docs/B165-i18n-retrospective.md - 国际化复盘报告

**技术债务分析 (B166-B167)**:
- docs/B166-deprecated-cleanup.md - @deprecated 清理准备 (5 处标记分析)
- docs/B167-cross-split-analysis.md - cmd.cross.pas 拆分方案 (1,263行 → 3单元)

## B161 任务池扫描报告 (2026-02-10)

### 当前基线

| 维度 | 状态 |
|------|------|
| 测试文件 | 143 个 |
| 测试用例 | 140/140 通过 (100%) |
| 源码文件 | 245 个 |
| 源码行数 | ~66,000 行 |
| 编译警告 | 0 (src/ 范围) |
| 编译提示 | 2 hints (已用 {%H-} 抑制) |
| 文档文件 | 72 个 |

### 扫描发现

#### 1. 编译健康 ✅
- 0 warnings, 2 hints (已抑制)
- 所有测试通过

#### 2. @deprecated 标记 (5 处)
- `src/fpdev.utils.git.pas` - SharedGitManager
- `src/fpdev.git2.pas` - 旧 GitManager 接口
- 其他 3 处在 repo 命令中

#### 3. 大文件状态 (>1000行)

| 文件 | 行数 | 备注 |
|------|------|------|
| fpdev.cmd.package.pas | 1890 | 有 helper 单元 |
| fpdev.resource.repo.pas | 1669 | 有 helper 单元 |
| fpdev.i18n.strings.pas | 1537 | 纯数据，无需拆分 |
| fpdev.config.managers.pas | 1365 | 接口实现 |
| fpdev.build.cache.pas | 1355 | 有 helper 单元 |
| fpdev.cmd.cross.pas | 1263 | 待拆分候选 |
| fpdev.build.manager.pas | 1255 | 已接口化 |

#### 4. 文档国际化缺口
- 70+ 个中文文档缺少英文版
- 优先级高: API.md, ARCHITECTURE.md, FAQ.md

#### 5. 测试覆盖
- 143 测试文件
- 所有命令组有测试 (fpc, lazarus, cross, package, project, repo)
- 核心模块有专项测试

### 改进建议

| 优先级 | 任务 | 预估 | 风险 |
|--------|------|------|------|
| P1 | 剩余文档国际化 (API.en.md, FAQ.en.md) | 2 天 | 低 |
| P2 | @deprecated 迁移 (SharedGitManager 移除) | 1 天 | 中 |
| P3 | cmd.cross.pas 拆分 (1263行) | 1 天 | 低 |
| P4 | 性能监控集成 | 2 天 | 低 |

### 下一步建议

1. **B162-B165**: 文档国际化 (API.en.md, FAQ.en.md, ARCHITECTURE.en.md)
2. **B166**: @deprecated 清理准备
3. **B167**: cmd.cross.pas 拆分预研

---

## Baseline (2026-02-10)
- 测试状态: 140/140 通过 (100%)
- 编译警告: 0（`/src/` 范围）
- 编译提示: 0 hints, 0 notes（`/src/` 范围）
- 源码文件: 244 个 (.pas/.lpr)
- 源码行数: ~66,000 行
- 测试文件: 141 个 (.lpr)
- 测试代码: ~41,400 行
- 命令单元: 100 个 (fpc:20, lazarus:13, package:25, project:9, repo:8, cross:12, 其他:13)
- @deprecated 标记: 0 处 (B166 清理完成)

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
- [x] 3.1 提取重复的错误处理逻辑 (B155)
- [x] 3.2 拆分超大文件 (fpdev.cmd.package.pas 等) - 已审计，已有 helper 单元
- [x] 3.3 优化长函数 - 已审计，命令执行器逻辑清晰
- **Status:** complete
- **预估工期:** 已完成

### Phase 4: 文档与测试完善
- [x] 4.1 BuildManager 文档完善 (B158) - 已有 612 行详细文档
- [x] 4.2 日志系统优化 (B159) - 时间戳已使用零填充格式
- [x] 4.3 测试覆盖率提升 (B160) - 143 文件, 140/140 通过
- **Status:** complete
- **预估工期:** 已完成

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
- [x] B053 命令契约测试矩阵 - 新增 command-registry 级别测试
- [x] B054 测试发现器升级 - 支持嵌套测试目录 (done in B084)
- [x] B055 退出码残余清理 - 检查遗漏的魔法数字
- [x] B056 错误语义统一 - 帮助文档与实际行为对齐 (done in B105)
- [x] B057 package deps 命令 - 依赖树展示
- [x] B058 package why 命令 - 依赖路径解释
- [x] B059 文档基线对齐 - README 命令集更新
- [x] B060 文档测试规模更新 - 测试数量与覆盖率 (done in B085)
- [x] B061/B062 resource.repo/build.cache 懒加载优化

### M6: 代码健壮性（B083+）
- [x] B083 剩余 Objects[]/Arrays[] 安全审计 (审计完成，内部API安全)
- [x] B084 测试发现器升级 - 支持嵌套测试目录 (115->118)
- [x] B085 文档测试规模更新 - README badge 94->118
- [x] B086 周期复盘 - M4-M6 收口

## Batch Queue (Week 2)

| Batch | Scope | Done Criteria |
|-------|-------|---------------|
| B087 | cross 命令测试补充 | ✓ 10 个测试覆盖 cross 命令注册 |
| B088 | config 命令测试 | ✓ 4 个测试覆盖 config 命令 |
| B089 | @deprecated 代码清理 | ✓ 审计完成，保留兼容层 |
| B090 | 错误语义统一 (B056) | ✓ --help/-h 返回退出码 0 |
| B091 | 子命令 help 退出码统一 | ✓ 所有 cmd --help/-h 返回 0 |
| B092 | 未知命令错误提示审计 | ✓ 退出码语义正确，无需修改 |
| B093 | 命令别名文档对齐审计 | ✓ 别名功能正常，文档已包含别名显示 |
| B094 | 任务池扫描 | ✓ 编译干净，测试 120/120，规划下轮任务 |

## Batch Queue (Week 3)

| Batch | Scope | Done Criteria |
|-------|-------|---------------|
| B095 | fpc 命令组测试补充 | ✓ 22 个测试覆盖 fpc 子命令注册 |
| B096 | lazarus 命令组测试补充 | ✓ 15 个测试覆盖 lazarus 子命令注册 |
| B097 | package 命令组测试补充 | ✓ 21 个测试覆盖 package 子命令注册 |
| B098 | project 命令组测试补充 | ✓ 11 个测试覆盖 project 子命令注册 |
| B099 | repo 命令组测试补充 | ✓ 11 个测试覆盖 repo 子命令注册 |
| B100 | 周期复盘 | ✓ B095-B099 收口，基线 124 测试，规划 Week 4 |

## B100 周期复盘报告

### 三周总成果 (B001-B099)

| 维度 | 起始状态 | 当前状态 | 变化 |
|------|---------|---------|------|
| 测试数 | ~80 (Week 0) | 124 | +44 (+55%) |
| 编译 Warning | 8+ (src) | 0 | 清零 |
| 编译 Hint | 14+ (src) | 0 | 清零 |
| @deprecated | 17+ | 5 | -12 (保留向后兼容层) |
| 大文件拆分 | 0 helper | 25+ helper | 大幅解耦 |

### Week 3 成果 (B095-B099)

- **新增 80 个命令组注册测试**: fpc(22) + lazarus(15) + package(21) + project(11) + repo(11)
- **基线提升**: 120 → 124 测试
- **编译健康**: 0 warning, 0 hint, 0 note (src/ 范围)
- **零回归**: 所有历史测试保持通过

### 当前技术债务清单

1. **大文件 (>1000 行)**: 13 个文件
   - fpdev.cmd.package.pas (1875 行) - 已部分拆分
   - fpdev.resource.repo.pas (1669 行) - 已拆分多个 helper
   - fpdev.i18n.strings.pas (1529 行) - 纯数据，无需拆分
   - fpdev.build.cache.pas (1355 行) - 已拆分多个 helper
   - fpdev.config.managers.pas (1345 行) - 接口实现，合理复杂度
   - fpdev.fpc.installer.pas (1320 行) - 待拆分候选
   - fpdev.cmd.fpc.pas (1291 行) - 待拆分候选
   - fpdev.cmd.cross.pas (1250 行) - 待拆分候选
   - fpdev.build.manager.pas (1235 行) - 已接口化
   - fpdev.git2.pas (1074 行) - 已接口化
   - fpdev.fpc.source.pas (1063 行) - 待拆分候选
   - fpdev.cmd.lazarus.pas (1040 行) - 待拆分候选
   - fpdev.cmd.project.pas (1017 行) - 待拆分候选

2. **@deprecated 残余**: 5 处
   - repo 命令 (4 处): 旧接口兼容层，已审计 B089 决定保留
   - fpdev.utils.git.pas (1 处): SharedGitManager 全局单例

3. **命令单元测试空白**: 99 个命令子单元无独立单元测试
   - 已通过 B095-B099 注册测试覆盖了命令注册层
   - 具体命令逻辑测试通过功能级测试间接覆盖

### 可执行的 Week 4 任务池

| 优先级 | 类别 | 候选任务 | 风险 |
|-------|------|---------|------|
| P1 | 测试强化 | 核心模块功能测试补充 (config/fpc/lazarus) | 低 |
| P1 | 代码质量 | 大文件继续拆分 (fpc.installer, cmd.fpc) | 中 |
| P2 | 功能完善 | B056 错误语义统一 (唯一未完成的 M5 项) | 低 |
| P2 | 代码质量 | 长函数重构 (>100 行函数) | 中 |
| P3 | 文档 | CLAUDE.md 精简与更新 | 低 |
| P3 | 探索 | CI/CD 集成可行性调研 | 低 |

## Batch Queue (Week 4)

| Batch | Scope | Done Criteria |
|-------|-------|---------------|
| B101 | fpc.installer 辅助方法提取 | ✓ GetFPCArchSuffix + GenerateFpcConfig + CreateLinuxCompilerWrapper |
| B102 | InstallFromManifest 嵌套解包抽离 | ✓ ExtractNestedFPCPackage, ~163→~100 行 |
| B103 | InstallFromBinary repo 逻辑抽离 | ✓ TryInstallFromRepo, ~150→~100 行 |
| B104 | cmd.package 索引解析抽离 | ✓ ParseLocalPackageIndex, GetAvailablePackages 163→42 行 |
| B105 | B056 错误语义统一 | ✓ 分发器+8 个文件退出码常量迁移 |
| B106 | 周期复盘 | ✓ B101-B105 收口，基线 124 测试 |

### M7: 交叉编译能力增强 (B107-B119)
- [x] B107 TCrossTarget 类型统一 + ICrossBuildEngine 接口
- [x] B108 CROSSOPT 构造器 + 编译器路径解析
- [x] B109 TCrossBuildEngine 8步构建编排
- [x] B110 fpc.cfg 交叉编译段管理器
- [x] B111 Linux->Win64 端到端 dry-run 验证
- [x] B112 多层策略搜索框架
- [x] B113 Libraries 搜索 + 自动发现
- [x] B114 搜索引擎集成 install/configure
- [x] B115 JSON 目标定义模板
- [x] B116 配置接口序列化扩展
- [x] B117 目标注册表集成 CLI
- [x] B118 完整集成测试套件 (94+22 测试)
- [x] B119 文档更新 + M7 周期复盘

## Batch Queue (Week 5 - Cross-Compilation)

| Batch | Scope | Done Criteria |
|-------|-------|---------------|
| B107 | TCrossTarget 类型统一 + ICrossBuildEngine 接口 | ✓ 两处 TCrossTarget 统一，47 个新测试通过，基线 125 |
| B108 | CROSSOPT 构造器 + 编译器路径解析 | ✓ TCrossOptBuilder + TCrossCompilerResolver, 53 个新测试通过, 基线 127 |
| B109 | TCrossBuildEngine 8 步构建编排 | ✓ 7步编排 + dry-run 命令日志, 29 个新测试通过, 基线 128 |
| B110 | fpc.cfg 交叉编译段管理器 | ✓ TFPCCfgManager CRUD, 55 个新测试通过, 基线 129 |
| B111 | Linux->Win64 端到端 dry-run 验证 | ✓ fpdev cross build 子命令 + 28 个 E2E 测试通过, 基线 130 |
| B112 | 多层策略搜索框架 | ✓ TCrossToolchainSearch 6 层策略, 44 个新测试通过, 基线 131 |
| B113 | Libraries 搜索 + 自动发现 | ✓ SearchLibraries multiarch/multilib + DiagnoseTarget + doctor 集成, 19 个新测试, 基线 132 |
| B114 | 搜索引擎集成 install/configure | ✓ cross configure --auto 自动填充, 12 个新测试通过, 基线 133 |
| B115 | JSON 目标定义模板 | ✓ TCrossTargetRegistry 21 内置目标 + JSON 序列化, 80 个新测试通过, 基线 134 |
| B116 | 配置接口序列化扩展 | ✓ B107 已完成序列化实现, 50 个验证测试通过, 基线 135 |
| B117 | 目标注册表集成 CLI | ✓ CROSS_TARGETS 数组移除, GetAvailableTargets/ValidateTarget/GetTargetInfo 迁移至注册表, 27 个新测试, 基线 136 |
| B118 | 完整集成测试套件 | ✓ 94 个集成测试 + 22 个回归测试, 全 M7 组件端到端验证, 基线 138 |
| B119 | 文档更新 + 周期复盘 | ✓ CLAUDE.md 新增交叉编译引擎章节, task_plan.md M7 复盘报告 |

## B119 M7 里程碑复盘报告

### M7 总成果 (B107-B119, 13 个批次)

| 维度 | M7 前 | M7 后 | 变化 |
|------|-------|-------|------|
| 测试数 | 124 | 138 | +14 测试文件, +491 测试用例 |
| 源码文件 | 228 | 239 | +11 个新源码单元 |
| M7 源码行数 | 0 | 3,143 | 新增交叉编译引擎 |
| M7 测试行数 | 0 | 5,733 | 14 个测试文件 |
| 交叉编译目标 | 12 (硬编码) | 21 (注册表驱动) | +9 目标, 可扩展 |
| 构建能力 | 仅配置管理 | 完整 7 步编排 | 质的飞跃 |
| Binutils 搜索 | 4 路径 | 6 层策略链 | +50% 策略覆盖 |
| fpc.cfg 管理 | 片段生成 | 完整 CRUD | 段管理 |
| TCrossTarget | 2 个同名不同定义 | 1 个统一记录 | 消除类型歧义 |
| CLI 子命令 | 8 个 | 12 个 | +4 (build/doctor/configure/test) |
| 编译健康 | 0 warning | 0 warning | 保持 |

### M7 新增组件清单

**源码单元 (11 个, 3,143 行)**:
| 单元 | 行数 | 职责 |
|------|------|------|
| fpdev.cross.engine.pas | 484 | 7 步构建编排引擎 |
| fpdev.cross.engine.intf.pas | 90 | ICrossBuildEngine 接口 |
| fpdev.cross.opts.pas | 141 | CROSSOPT 字符串构造器 |
| fpdev.cross.compiler.pas | 125 | 交叉编译器路径解析 |
| fpdev.cross.fpccfg.pas | 368 | fpc.cfg 段管理器 |
| fpdev.cross.search.pas | 847 | 6 层工具链搜索引擎 |
| fpdev.cross.targets.pas | 482 | JSON 驱动目标注册表 |
| fpdev.cmd.cross.build.pas | 176 | cross build 子命令 |
| fpdev.cmd.cross.doctor.pas | 195 | cross doctor 子命令 |
| fpdev.cmd.cross.configure.pas | 162 | cross configure 子命令 |
| fpdev.cmd.cross.test.pas | 73 | cross test 子命令 |

**测试文件 (14 个, 5,733 行, 491 测试)**:
| 测试文件 | 测试数 | 覆盖范围 |
|----------|--------|---------|
| test_cross_engine_types | 10 | 类型兼容性 |
| test_cross_opts | 15 | CROSSOPT 构造器 |
| test_cross_compiler_resolve | 8 | 编译器路径解析 |
| test_cross_engine | 29 | 引擎编排 |
| test_cross_engine_e2e | 28 | 端到端 dry-run |
| test_cross_fpccfg | 55 | fpc.cfg CRUD |
| test_cross_search | 44 | 搜索引擎 |
| test_cross_search_libs | 19 | 库搜索 |
| test_cross_targets | 80 | 目标注册表 |
| test_cross_config_extended | 50 | 配置序列化 |
| test_cross_cli_integration | 27 | CLI 集成 |
| test_cross_commands | 10 | 命令注册 |
| test_cross_integration | 94 | 全组件集成 |
| test_cross_regression | 22 | 回归验证 |

### M7 四个子里程碑

| 子里程碑 | 批次 | 核心产出 |
|----------|------|---------|
| M7a 构建引擎 | B107-B111 | TCrossTarget 统一, OptBuilder, CompilerResolver, 7步 Engine, fpc.cfg Manager |
| M7b 搜索引擎 | B112-B114 | 6 层策略搜索, 库发现, configure --auto 集成 |
| M7c 目标配置 | B115-B117 | 21 目标注册表, JSON 序列化, CLI 迁移 |
| M7d 集成测试 | B118-B119 | 94+22 集成/回归测试, CLAUDE.md 文档更新 |

### 已知限制与后续方向

1. **dry-run 仅验证命令序列** — 没有真实交叉编译环境时，Engine 无法到达 cbsComplete 阶段。需要真实 FPC 源码目录验证
2. **21 个内置目标** — 覆盖主流平台，但未包含 WebAssembly、Xtensa (ESP32) 等嵌入式目标，可通过 RegisterCustomTarget 扩展
3. **搜索引擎 Layer 5/6** — linker 解析和 config hints 在非标准环境下可能需要调优
4. **fpc.cfg 管理** — 假设标准 FPC 安装路径，自定义安装可能需要手动指定

### 项目整体状态 (B001-B119, 6 个里程碑)

| 里程碑 | 批次范围 | 状态 | 核心成果 |
|--------|---------|------|---------|
| M1 编译健康 | B001-B002 | ✓ | 基线冻结, warning 清零 |
| M2 高风险债务 | B003-B005 | ✓ | deprecated 迁移, 占位实现清零 |
| M3 质量闭环 | B006-B008 | ✓ | 测试补充, hint 清零, 文档同步 |
| M4 结构治理 | B009-B082 | ✓ | 大文件拆分 25+ helper, 常量治理 |
| M5 后端探索 | B053-B062 | ✓ | 命令测试矩阵, 退出码, 懒加载 |
| M6 代码健壮性 | B083-B106 | ✓ | 安全审计, 长函数重构, 错误语义 |
| M7 交叉编译 | B107-B119 | ✓ | 完整构建引擎 + 搜索 + 目标注册表 |

## Batch Queue (Week 6 - Polish & Stability)

| Batch | Scope | Done Criteria |
|-------|-------|---------------|
| B120 | 任务池扫描 + Week 6 规划 | ✓ 识别帮助文本缺失、大文件候选 |
| B121 | cross 子命令帮助文本补全 | ✓ i18n 添加 build 帮助，HELP_CROSS_SUBCOMMANDS 更新，cross help 添加 build 分支 |
| B122 | cross build --help 参数解析修复 | ✓ 处理 dispatcher 的 --help->help 转换，支持 --help/-h 正确显示帮助 |
| B123 | fpc.installer 大函数拆分 | ✓ TFPCArchiveExtractor helper 抽离，InstallFromSourceForge 1367→1253 行 |
| B124 | cmd.fpc 元数据操作抽离 | ✓ 预研完成：发现 TInstallScope 双重定义 (fpdev.types vs fpdev.fpc.types)，需后续统一 |
| B125 | 周期复盘 | ✓ Week 6 成果总结，类型重复债务识别，下一步建议 |

### M8: 代码整理与帮助完善 (B120-B125)
- [x] B120 任务池扫描 + Week 6 规划
- [x] B121 cross 子命令帮助文本补全
- [x] B122 cross build --help 参数解析修复
- [x] B123 fpc.installer 大函数拆分
- [x] B124 cmd.fpc 类型重复预研
- [x] B125 周期复盘

## B125 Week 6 周期复盘报告

### Week 6 成果 (B120-B125)

| 批次 | 任务 | 成果 |
|------|------|------|
| B120 | 任务池扫描 | 识别帮助文本缺失、大文件候选 |
| B121 | cross 帮助文本补全 | HELP_CROSS_SUBCOMMANDS 添加 build/doctor |
| B122 | cross build --help 修复 | 处理 dispatcher 的 --help->help 转换 |
| B123 | fpc.installer 拆分 | TFPCArchiveExtractor helper, 1367→1253 行 |
| B124 | 类型重复预研 | 发现 TInstallScope 双重定义 |
| B125 | 周期复盘 | 本报告 |

### 新增文件
- `src/fpdev.fpc.installer.extract.pas` (261 行) — FPC 归档提取 helper

### 修改文件
- `src/fpdev.i18n.strings.pas` — 添加 HELP_CROSS_BUILD_* 常量
- `src/fpdev.cmd.cross.help.pas` — 添加 build 子命令帮助
- `src/fpdev.cmd.cross.build.pas` — 修复 --help 参数解析
- `src/fpdev.fpc.installer.pas` — 使用提取 helper，减少 114 行

### 已知技术债务更新

1. **类型重复定义** — B126 已修复 TInstallScope
   - ✓ `TInstallScope`: 统一使用 fpdev.types.pas 定义
   - `TSourceMode`, `TVerifyInfo`, `TOriginInfo`, `TFPDevMetadata`, `TBinaryDownloadInfo`: fpdev.cmd.fpc.pas vs fpdev.fpc.types.pas (待统一)

2. **大文件** (>1000 行): 仍有 12 个文件
   - fpdev.cmd.fpc.pas (1253 行) — 已部分拆分
   - fpdev.fpc.installer.pas (1253 行) — 已部分拆分

### 下一步建议

| 优先级 | 任务 | 风险 |
|--------|------|------|
| P1 | 类型统一 (TInstallScope 等) | 中 |
| P2 | 继续大文件拆分 (resource.repo, build.cache) | 低 |
| P3 | CI/CD 集成调研 | 低 |

## Batch Queue (Week 7 - Type Unification)

| Batch | Scope | Done Criteria |
|-------|-------|---------------|
| B126 | TInstallScope 类型统一 | ✓ fpdev.fpc.types 导入 fpdev.types，5 个文件更新 |
| B127 | TSourceMode 类型统一 | ✓ fpdev.cmd.fpc.pas 移除重复定义，fpdev.fpc.types 作为权威定义，2 个测试文件更新 |
| B128 | Metadata 类型统一 | ✓ TVerifyInfo/TOriginInfo/TFPDevMetadata/TBinaryDownloadInfo 已在 B127 一并统一 |
| B129 | 类型统一测试验证 | ✓ 全量测试 138/138 通过，无回归 |
| B130 | 周期复盘 | ✓ Week 7 M9 收口，类型统一完成 |

### M9: 类型系统统一 (B126-B130)
- [x] B126 TInstallScope 类型统一
- [x] B127 TSourceMode 类型统一
- [x] B128 Metadata 类型统一
- [x] B129 类型统一测试验证
- [x] B130 周期复盘

## B130 Week 7 M9 周期复盘报告

### M9 成果 (B126-B130)

| 批次 | 任务 | 成果 |
|------|------|------|
| B126 | TInstallScope 类型统一 | fpdev.types.pas 作为权威定义，5 个文件更新 |
| B127 | TSourceMode 类型统一 | fpdev.cmd.fpc.pas 移除 ~38 行重复定义，2 个测试更新 |
| B128 | Metadata 类型统一 | TVerifyInfo/TOriginInfo/TFPDevMetadata/TBinaryDownloadInfo 统一 |
| B129 | 测试验证 | 138/138 测试通过，零回归 |
| B130 | 周期复盘 | 本报告 |

### 类型统一详情

**已统一的类型**:
| 类型 | 权威定义位置 | 原重复位置 |
|------|-------------|-----------|
| TInstallScope | fpdev.types.pas | fpdev.fpc.types.pas (已移除) |
| TSourceMode | fpdev.fpc.types.pas | fpdev.cmd.fpc.pas (已移除) |
| TVerifyInfo | fpdev.fpc.types.pas | fpdev.cmd.fpc.pas (已移除) |
| TOriginInfo | fpdev.fpc.types.pas | fpdev.cmd.fpc.pas (已移除) |
| TFPDevMetadata | fpdev.fpc.types.pas | fpdev.cmd.fpc.pas (已移除) |
| TBinaryDownloadInfo | fpdev.fpc.types.pas | fpdev.cmd.fpc.pas (已移除) |

**修改文件**:
| 文件 | 变更 |
|------|------|
| src/fpdev.fpc.types.pas | 导入 fpdev.types，移除 TInstallScope 定义 |
| src/fpdev.fpc.utils.pas | 添加 fpdev.types 导入 |
| src/fpdev.fpc.activator.pas | 添加 fpdev.types 导入，更新类型引用 |
| src/fpdev.cmd.fpc.pas | 添加 fpdev.fpc.types 导入，移除 6 个重复类型 |
| tests/test_fpc_utils.lpr | 添加 fpdev.types 导入 |
| tests/test_fpc_activator.lpr | 添加 fpdev.types 导入 |
| tests/test_fpc_scoped_install.lpr | 添加 fpdev.fpc.types 导入 |
| tests/test_fpc_binary_install.lpr | 添加 fpdev.fpc.types 导入 |

### 当前基线

| 维度 | 状态 |
|------|------|
| 测试数 | 139/139 通过 (100%) |
| 编译警告 | 0 (src/ 范围) |
| 编译提示 | 0 hints, 0 notes |
| @deprecated | 5 处 (向后兼容保留) |

### 剩余技术债务

1. **大文件** (>1000 行): 11 个文件待拆分 (fpdev.cmd.fpc.pas 1253→1119)
2. **@deprecated 残余**: 5 处向后兼容层
3. **其他类型重复**: 暂未发现其他重复定义

## Batch Queue (Week 8 - Large File Refactoring)

| Batch | Scope | Done Criteria |
|-------|-------|---------------|
| B131 | cmd.fpc Metadata helper 抽离 | ✓ fpdev.fpc.metadata.pas 新建，cmd.fpc 1253→1119 行，+33 测试 |
| B132 | Week 8 任务池扫描 | ✓ 基线 139 测试，规划后续批次 |
| B133 | cmd.package 结构评估 | ✓ 已有 25 个 helper，3 个大方法待优化 |
| B134 | cmd.cross/fpc.source 结构评估 | ✓ 已充分拆分，无高优先级拆分任务 |
| B135 | 测试覆盖扫描 | ✓ 139/139 测试，覆盖充分 |
| B136 | 文档完善 | ✓ README/CLAUDE.md 测试数更新 139 |
| B137 | CI/CD 集成 | ✓ 创建 .github/workflows/ci.yml |
| B138 | Week 8 周期复盘 | ✓ M10 收口，基线 139 测试 |

## Batch Queue (Week 9 - UX Enhancement)

| Batch | Scope | Done Criteria |
|-------|-------|---------------|
| B139 | UX 改进扫描 | ✓ 识别改进机会，选择命令补全 |
| B140 | 命令自动补全 | ✓ Bash/Zsh 补全脚本创建 |
| B141 | --json 输出 | ✓ fpc list/current 支持 --json |
| B142 | lazarus --json | ✓ lazarus list/current 支持 --json |
| B143 | cross --json | ✓ cross list 支持 --json |
| B144 | package --json | ✓ package list/search 支持 --json |
| B145 | 周期复盘 | ✓ Week 9 M11 完成报告 |

### M12 Batch Queue

| Batch | 任务 | 预期产出 |
|-------|------|----------|
| B146 | project --json | project list 支持 --json |
| B147 | repo --json | repo versions 支持 --json |
| B148 | doctor/config --json | 诊断和配置命令 JSON 输出 |
| B149 | 性能基准 | 启动时间/命令响应测量 |
| B150 | 懒加载优化 | 减少启动时加载 |
| B151 | 缓存改进 | 命令结果缓存 |
| B152 | README.en.md | 英文 README |
| B153 | QUICKSTART.en.md | 英文快速开始 |
| B154 | 周期复盘 | Week 10 M12 完成报告 |

### M10: 大文件持续重构 (B131+)
- [x] B131 cmd.fpc Metadata helper 抽离
- [x] B132 Week 8 任务池扫描
- [x] B133 cmd.package 结构评估
- [x] B134 cmd.cross/fpc.source 结构评估
- [x] B135 测试覆盖扫描
- [x] B136 文档完善
- [x] B137 CI/CD 集成
- [x] B138 Week 8 周期复盘

### M11: 用户体验增强 (B139-B145)
- [x] B139 UX 改进扫描
- [x] B140 命令自动补全
- [x] B141 --json 输出格式支持
- [x] B142 lazarus list/current --json
- [x] B143 cross list --json
- [x] B144 package list/search --json
- [x] B145 Week 9 周期复盘

### M12: 综合完善 (B146+)

#### M12a: 剩余 JSON 支持 (B146-B148)
- [x] B146 project list --json
- [x] B147 repo versions --json
- [x] B148 doctor --json

#### M12b: 性能优化 (B149-B151)
- [x] B149 性能基准测试
- [ ] B150 懒加载优化
- [ ] B151 缓存改进

### B149 性能基准测试报告

**测试环境**: Linux x86_64, FPC 3.3.1

| 命令 | 执行时间 | 状态 |
|------|---------|------|
| `fpdev help` | ~34ms | ✓ 优秀 |
| `fpdev version` | ~42ms | ✓ 优秀 |
| `fpdev fpc list` | ~41ms | ✓ 优秀 |
| `fpdev fpc current` | ~30ms | ✓ 优秀 |

**结论**: 当前性能已经非常好，所有命令在 50ms 内完成。无需进行进一步优化。

**建议**:
- B150/B151 可跳过，当前已满足性能要求
- 如需优化，重点关注网络操作（repo 命令）而非本地命令

#### M12c: 文档国际化 (B152-B154)
- [x] B152 README 英文版
- [x] B153 QUICKSTART 英文版
- [x] B154 Week 10 周期复盘

### B154 Week 10 M12 周期复盘报告

**日期**: 2026-02-10
**批次范围**: B139-B154 (M11 UX Enhancement + M12 Comprehensive Improvement)

#### 里程碑成果总结

| 里程碑 | 批次 | 状态 | 主要产出 |
|--------|------|------|----------|
| M11 UX Enhancement | B139-B145 | ✅ 完成 | JSON 输出支持 (fpc/lazarus/cross/package), 命令自动补全 |
| M12a JSON 支持 | B146-B148 | ✅ 完成 | project/repo/doctor --json 全覆盖 |
| M12b 性能优化 | B149-B151 | ✅ 完成 | 基准测试确认无需优化，B150/B151 跳过 |
| M12c 文档国际化 | B152-B154 | ✅ 完成 | README.en.md, QUICKSTART.en.md |

#### 代码变更统计

| 指标 | Week 9 开始 | Week 10 结束 | 变化 |
|------|-------------|--------------|------|
| 测试用例 | 124 | 140 | +16 |
| 测试通过率 | 100% | 100% | - |
| 编译警告 | 0 | 0 | - |
| 编译提示 | 0 | 0 | - |
| 新增文件 | - | 6 | README.en.md, QUICKSTART.en.md, fpdev.output.json.pas, test_output_json.lpr, completion scripts |

#### JSON 输出覆盖率

| 命令组 | 支持的子命令 | 状态 |
|--------|--------------|------|
| fpc | list, current | ✅ |
| lazarus | list, current | ✅ |
| cross | list | ✅ |
| package | list, search | ✅ |
| project | list | ✅ |
| repo | versions | ✅ |
| doctor | - | ✅ |

#### 性能基准

所有命令执行时间 < 50ms，无需进一步优化。

#### 文档国际化完成度

| 文档 | 中文 | 英文 | 状态 |
|------|------|------|------|
| README | ✅ | ✅ | 完成 |
| QUICKSTART | ✅ | ✅ | 完成 |
| API | ✅ | - | 待做 |
| ARCHITECTURE | ✅ | - | 待做 |

#### 下周建议任务池

| 优先级 | 任务 | 预估 |
|--------|------|------|
| P1 | M7 交叉编译构建引擎 (B107-B119) | 2-3 周 |
| P2 | 剩余文档国际化 (API.en.md, ARCHITECTURE.en.md) | 1 天 |
| P3 | 大文件拆分继续 (fpdev.cmd.cross.pas) | 2-3 天 |

#### 经验教训

1. **JSON 输出模式**: 使用局部函数避免循环依赖比引入公共 helper 更简洁
2. **性能优化**: 先测量再优化，当前已足够快无需过度工程
3. **文档国际化**: 保持文件结构一致便于维护

---

## B132 Week 8 任务池扫描报告

### 当前基线

| 维度 | 状态 |
|------|------|
| 测试文件 | 142 个 |
| 测试用例 | 139/139 通过 (100%) |
| 源码文件 | 244 个 |
| 源码行数 | ~65,500 行 |
| 编译警告 | 0 (src/ 范围) |
| 编译提示 | 0 hints, 0 notes |

### 大文件状态 (>1000行)

| 文件 | 行数 | 变化 | 备注 |
|------|------|------|------|
| fpdev.cmd.package.pas | 1884 | - | 待拆分，已有多个 helper |
| fpdev.resource.repo.pas | 1669 | - | 已拆分多个 helper |
| fpdev.i18n.strings.pas | 1537 | - | 纯数据，无需拆分 |
| fpdev.config.managers.pas | 1365 | - | 接口实现 |
| fpdev.build.cache.pas | 1355 | - | 已拆分多个 helper |
| fpdev.cmd.cross.pas | 1261 | - | 待拆分候选 |
| fpdev.build.manager.pas | 1255 | - | 已接口化 |
| fpdev.fpc.installer.pas | 1253 | - | 已部分拆分 |
| fpdev.cmd.fpc.pas | 1119 | -134 | B131 拆分 Metadata |
| fpdev.git2.pas | 1074 | - | 已接口化 |
| fpdev.fpc.source.pas | 1063 | - | 待拆分候选 |
| fpdev.cmd.lazarus.pas | 1040 | - | 待拆分候选 |
| fpdev.cmd.project.pas | 1017 | - | 待拆分候选 |

### Week 8 成果

| 批次 | 成果 |
|------|------|
| M9 B126-B130 | 类型统一完成，消除 TInstallScope/TSourceMode 等重复定义 |
| B131 | Metadata helper 抽离，cmd.fpc 减少 134 行 |
| Hint 清理 | 3 个 Hint 修复，编译干净 |

### 下一步建议

| 优先级 | 任务 | 风险 |
|--------|------|------|
| P1 | cmd.cross 拆分 | 中 |
| P2 | fpc.source 拆分 | 低 |
| P3 | 测试覆盖增强 | 低 |

## B133 cmd.package 结构评估

### 当前状态

| 维度 | 数值 |
|------|------|
| 主文件行数 | 1884 行 |
| 已拆分 helper 单元 | 25 个 |
| 大方法 (>100行) | 3 个 |

### 大方法清单

| 方法 | 行数 | 拆分建议 |
|------|------|----------|
| InstallPackage | 173 | 核心逻辑，拆分风险高 |
| ParseLocalPackageIndex | 124 | 可抽离为 index parser helper |
| ResolveAndInstallDependencies | 114 | 可抽离为 dependency resolver |

### 结论

fpdev.cmd.package.pas 已经过充分拆分（25 个 helper 单元）。剩余 3 个大方法是核心业务逻辑，拆分收益有限但风险较高。建议：
1. 保持当前结构
2. 优先处理其他大文件（cmd.cross, fpc.source）
3. 后续可考虑将 ParseLocalPackageIndex 抽离为独立 helper

## B134 cmd.cross/fpc.source 结构评估

### fpdev.cmd.cross.pas

| 维度 | 数值 |
|------|------|
| 主文件行数 | 1261 行 |
| 已拆分 helper 单元 | 23 个 |
| 最大方法 | InstallTarget (129 行) |

### fpdev.fpc.source.pas

| 维度 | 数值 |
|------|------|
| 主文件行数 | 1063 行 |
| 方法数 | 44 个 |
| 最大方法 | InstallFPCVersion (108 行) |

### 结论

两个文件都已经过充分拆分:
- cmd.cross: 23 个 helper 单元，最大方法 129 行
- fpc.source: 方法均在 110 行以内

大文件拆分工作已基本完成。后续建议转向其他质量提升方向:
1. 测试覆盖增强
2. 文档完善
3. CI/CD 集成

## B138 Week 8 M10 周期复盘报告

### Week 8 成果 (B131-B138)

| 批次 | 任务 | 成果 |
|------|------|------|
| B131 | Metadata helper 抽离 | fpdev.fpc.metadata.pas (+180行), cmd.fpc -134行 |
| B132 | 任务池扫描 | 13个大文件识别，规划后续方向 |
| B133 | cmd.package 评估 | 已有25个helper，充分拆分 |
| B134 | cmd.cross/fpc.source 评估 | 已充分拆分，无高优先级任务 |
| B135 | 测试覆盖扫描 | 139/139测试，覆盖充分 |
| B136 | 文档完善 | README/CLAUDE.md更新 |
| B137 | CI/CD 集成 | GitHub Actions工作流创建 |
| B138 | 周期复盘 | 本报告 |

### 基线变化

| 维度 | Week 8 前 | Week 8 后 | 变化 |
|------|----------|----------|------|
| 测试数 | 138 | 139 | +1 |
| cmd.fpc 行数 | 1253 | 1119 | -134 |
| 新 helper | - | fpdev.fpc.metadata.pas | +1 |
| CI/CD | 无 | GitHub Actions | 新增 |
| 编译警告 | 0 | 0 | 保持 |

### 关键结论

1. **大文件拆分已完成**: cmd.package(25 helper), cmd.cross(23 helper), fpc.source(44方法<110行)
2. **测试覆盖充分**: 139测试覆盖所有核心模块
3. **CI/CD 就绪**: GitHub Actions 可自动编译和测试
4. **文档已更新**: 反映当前139测试基线

### 项目整体状态 (B001-B138)

| 里程碑 | 批次范围 | 状态 |
|--------|---------|------|
| M1 编译健康 | B001-B002 | ✓ 完成 |
| M2 高风险债务 | B003-B005 | ✓ 完成 |
| M3 质量闭环 | B006-B008 | ✓ 完成 |
| M4 结构治理 | B009-B082 | ✓ 完成 |
| M5 后端探索 | B053-B062 | ✓ 完成 |
| M6 代码健壮性 | B083-B106 | ✓ 完成 |
| M7 交叉编译 | B107-B119 | ✓ 完成 |
| M8 帮助完善 | B120-B125 | ✓ 完成 |
| M9 类型统一 | B126-B130 | ✓ 完成 |
| M10 大文件重构 | B131-B138 | ✓ 完成 |
| M11 用户体验 | B139-B145 | ✓ 完成 |

### 下一步建议

项目已达到高质量稳定状态:
- 140测试全部通过
- 0编译警告
- 充分的代码拆分
- CI/CD就绪
- 完整的 --json 输出支持

后续可选方向:
1. 功能增强 (新命令/新特性)
2. 性能优化
3. 文档国际化
4. project list --json 等剩余命令

## B145 Week 9 M11 周期复盘报告

### Week 9 成果 (B139-B145)

| 批次 | 任务 | 成果 |
|------|------|------|
| B139 | UX 改进扫描 | 识别 5 项改进机会 |
| B140 | 命令补全 | Bash/Zsh 补全脚本 |
| B141 | fpc --json | fpc list/current 支持 JSON |
| B142 | lazarus --json | lazarus list/current 支持 JSON |
| B143 | cross --json | cross list 支持 JSON |
| B144 | package --json | package list/search 支持 JSON |
| B145 | 周期复盘 | 本报告 |

### 新增功能

**Shell 自动补全** (B140):
```bash
# Bash
source scripts/completions/fpdev.bash

# Zsh
fpath=(~/.zsh/completions $fpath)
cp scripts/completions/_fpdev ~/.zsh/completions/
```

**JSON 输出格式** (B141-B144):
```bash
fpdev fpc list --json       # FPC 版本列表
fpdev fpc current --json    # 当前 FPC 版本
fpdev lazarus list --json   # Lazarus 版本列表
fpdev lazarus current --json # 当前 Lazarus 版本
fpdev cross list --json     # 交叉编译目标
fpdev package list --json   # 已安装包
fpdev package search X --json # 搜索结果
```

### 代码变更统计

| 指标 | Week 8 结束 | Week 9 结束 | 变化 |
|------|------------|------------|------|
| 源码文件 | 244 | 245 | +1 |
| 测试文件 | 141 | 175 | +34 |
| 测试用例 | 139 | 140 | +1 |
| 源码行数 | ~66,000 | ~65,900 | ~ |

### 新增文件

- `src/fpdev.output.json.pas` - JSON 输出工具类
- `scripts/completions/fpdev.bash` - Bash 补全脚本
- `scripts/completions/_fpdev` - Zsh 补全脚本
- `tests/test_output_json.lpr` - JSON 输出测试

### 技术亮点

1. **类方法设计**: `TJsonOutputHelper` 使用 class function，无需实例化
2. **避免循环依赖**: Lazarus/Cross JSON 使用局部函数而非导入 output.json
3. **统一 API 可见性**: 将 GetXxxVersions/GetXxxTargets 方法移到 public

### 项目整体状态 (B001-B145)

| 维度 | 状态 |
|------|------|
| 测试通过率 | 140/140 (100%) |
| 编译警告 | 0 |
| --json 覆盖率 | 7 个核心查询命令 |
| Shell 补全 | Bash + Zsh |
| CI/CD | GitHub Actions 就绪 |

## P2/P3 流水线完成报告

### 完成时间: 2026-02-10

### P3: fpc.installer.pas 配置工具提取

**成果**:
- 新建 `src/fpdev.fpc.installer.config.pas` (194 行)
- 提取 `TFPCConfigGenerator` 类
- 提取 `GetFPCArchSuffix()` 和 `GetNativeCompilerName()` 函数
- fpc.installer.pas 从 1253 行减少到 1160 行 (-93 行)

**提交**: `34ca158 refactor(P3): Extract config utilities from fpc.installer.pas`

### P2: 性能监控系统

**成果**:
- 新建 `src/fpdev.perf.monitor.pas` (430 行)
- `TPerfMonitor` 类支持操作计时、父子关系、元数据
- `PerfMon()` 全局单例
- JSON 报告生成 (`GetReport`, `SaveReport`)
- Linux 内存追踪 (via /proc/self/status VmRSS)
- 集成到 `TBuildManager` (BuildCompiler, BuildRTL, BuildPackages, Install)
- 新建 `tests/test_perf_monitor.lpr` (26 测试用例)

**提交**: `7d28cf5 feat(P2): Add performance monitoring system`

### 基线更新

| 维度 | B145 结束 | P2/P3 后 | 变化 |
|------|----------|----------|------|
| 测试文件 | 141 | 142 | +1 |
| 测试通过 | 140/140 | 142/142 | +2 |
| 源码文件 | 245 | 247 | +2 |
| 编译警告 | 0 | 0 | - |

### M7 状态确认

M7 (B107-B119) 已在之前会话中完成，13 个批次全部标记 done。

### 下一步建议

| 优先级 | 任务 | 预估 |
|--------|------|------|
| P1 | 剩余文档国际化 (API.en.md) | 1 天 |
| P2 | cmd.cross.pas 拆分 | 2-3 天 |
| P3 | 测试覆盖增强 | 低 |

## P1-P3 流水线完成报告 (2026-02-10 Session 2)

### P1: 文档国际化

**状态**: 已完成 (API.en.md 已存在)

### P2: cmd.cross.pas 拆分

**成果**:
- 新建 `src/fpdev.cmd.cross.query.pas` (237 行)
- 提取 `TCrossTargetQuery` 类
- 提供方法: GetAvailableTargets, GetInstalledTargets, GetTargetInfo, ValidateTarget, IsTargetInstalled, GetTargetInstallPath
- cmd.cross.pas 从 1099 行减少到 947 行 (-152 行, -14%)

**提交**: `d204888 refactor(P2): Extract target query helper from cmd.cross.pas`

### P3: 测试覆盖增强

**成果**:
- 新建 `tests/test_cross_query.lpr` (14 个测试)
- 新建 `tests/test_fpc_installer_config.lpr` (9 个测试)
- 覆盖 TCrossTargetQuery 和 TFPCConfigGenerator 新单元

**提交**: `9b731fd test(P3): Add tests for new helper units`

### 最终基线

| 维度 | P2/P3 前 | P1-P3 后 | 变化 |
|------|----------|----------|------|
| 测试文件 | 142 | 144 | +2 |
| 测试通过 | 142/142 | 144/144 | +2 |
| 源码文件 | 247 | 248 | +1 |
| 编译警告 | 0 | 0 | - |

### 下一步建议

| 优先级 | 任务 | 预估 |
|--------|------|------|
| P1 | 继续大文件拆分 (fpc.source 1063 行) | 1-2 天 |
| P2 | 性能监控 CLI 命令 | 1 天 |
| P3 | CI/CD 集成 | 低 |

## Session 2026-02-12: 扫描后执行计划（一次性执行）

### Goal
基于全仓扫描结果，先消除最高优先级“功能未实现”缺口：远端 registry 客户端 POST/PUT/DELETE 通路。

### Priority Queue
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P0 | 实现 `TRemoteRegistryClient` 非 GET HTTP 方法并补测试 | `src/fpdev.registry.client.pas`, `tests/test_registry_client_remote.lpr` | 新测试红→绿，且不再出现 `not yet implemented` 错误文本 |
| P1 | 补 `TGitHubClient` 非 GET 请求能力 + 测试 | `src/fpdev.github.api.pas`, `tests/test_github_api*.lpr` | Create/Release/Asset 路径不再硬编码未实现 |
| P1 | 补 `TGitLabClient` 非 GET 请求能力 + 测试 | `src/fpdev.gitlab.api.pas`, `tests/test_gitlab_api*.lpr` | Create/Package/Release 路径不再硬编码未实现 |
| P2 | 代码质量低风险清理 | `src/fpdev.fpc.binary.pas` 等 | debug/style/hardcoded 报告项下降且无回归 |

### Execution Batch (this run)
- 执行 P0（完整 TDD：Red -> Green -> Refactor -> Verify）

### Execution Result Update (2026-02-12)
- [x] P0 `TRemoteRegistryClient` POST/PUT/DELETE 通路实现
- [x] 新增 `tests/test_registry_client_remote.lpr` 并完成 RED->GREEN
- [x] 回归验证：targeted + full suite (`174/174`)
- [ ] P1 `TGitHubClient` 非 GET 通路
- [ ] P1 `TGitLabClient` 非 GET 通路
- [ ] P2 低风险质量项清理

### Team Sprint Update (2026-02-12)
- [x] T1/P0 GitHub API 非 GET 通路 + 测试
- [ ] T2/P1 GitLab API 非 GET 通路 + 测试
- [ ] T3/P2 低风险质量项清理

### Team Sprint Update (2026-02-12, after T2)
- [x] T1/P0 GitHub API 非 GET 通路 + 测试
- [x] T2/P1 GitLab API 非 GET 通路 + 测试
- [ ] T3/P2 低风险质量项清理

### Session 2026-02-12 Round 2: Scan -> Plan -> Execute

#### Priority Queue (updated)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P0 | 修复质量扫描器 debug 误报 | `scripts/analyze_code_quality.py`, `tests/test_analyze_code_quality.py` | 新增回归测试红->绿；误报样例不再命中 |
| P1 | 代码风格分批修复 | `src/fpdev.cmd.lazarus.pas`, `src/fpdev.package.lockfile.pas`, `src/fpdev.cmd.package.repo.list.pas` | style 报告项下降且回归通过 |
| P2 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | hardcoded 报告项下降且行为不变 |

#### Execution Batch (this run)
- 执行 P0（严格 TDD：Red -> Green -> Verify）

### Execution Result Update (2026-02-12 Round 2)
- [x] P0 修复 `analyze_code_quality.py` debug 误报（TDD 红->绿完成）
- [ ] P1 代码风格分批修复
- [ ] P2 硬编码常量治理

### Execution Result Update (2026-02-12 Round 3)
- [x] P1 代码风格分批修复（Batch 1: lockfile + repo.list）
- [ ] P1 代码风格分批修复（Batch 2: lazarus/cmd.params/cross.cache）
- [ ] P2 Debug 输出分类治理
- [ ] P3 硬编码常量治理

### Priority Queue (updated after Round 3 scan)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 2 | `src/fpdev.cmd.lazarus.pas`, `src/fpdev.cmd.params.pas`, `src/fpdev.cross.cache.pas` | 新增测试红->绿，analyzer style 项减少 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分用户输出与调试输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并回归通过 |

### Execution Result Update (2026-02-12 Round 4)
- [x] P1 代码风格分批修复（Batch 2: lazarus/params/cross.cache）
- [ ] P1 代码风格分批修复（Batch 3: build.interfaces/collections/template.remove）
- [ ] P2 Debug 输出分类治理
- [ ] P3 硬编码常量治理

### Priority Queue (updated after Round 4 scan)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 3 | `src/fpdev.build.interfaces.pas`, `src/fpdev.collections.pas`, `src/fpdev.cmd.project.template.remove.pas` | 新增测试红->绿，analyzer style 项继续下降 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分用户输出与调试输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并回归通过 |

### Execution Result Update (2026-02-12 Round 5)
- [x] P1 代码风格分批修复（Batch 3: build.interfaces/collections/template.remove）
- [ ] P1 代码风格分批修复（Batch 4: template.update/source/fpc.verify）
- [ ] P2 Debug 输出分类治理
- [ ] P3 硬编码常量治理

### Priority Queue (updated after Round 5 scan)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 4 | `src/fpdev.cmd.project.template.update.pas`, `src/fpdev.source.pas`, `src/fpdev.fpc.verify.pas` | 新增测试红->绿，analyzer style 项继续下降 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分用户输出与调试输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并回归通过 |

### Execution Result Update (2026-02-12 Round 6)
- [x] P1 代码风格分批修复（Batch 4: template.update/source/fpc.verify）
- [ ] P1 代码风格分批修复（Batch 5: cmd.package/config.interfaces/toml.parser）
- [ ] P2 Debug 输出分类治理
- [ ] P3 硬编码常量治理

### Priority Queue (updated after Round 6 scan)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 5 | `src/fpdev.cmd.package.pas`, `src/fpdev.config.interfaces.pas`, `src/fpdev.toml.parser.pas` | 新增测试红->绿，analyzer style 项继续下降 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分用户输出与调试输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并回归通过 |

### Session 2026-02-12 Round 7: Scan -> Plan -> Execute (Batch 5)

#### Priority Queue (updated)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 5 | `src/fpdev.cmd.package.pas`, `src/fpdev.config.interfaces.pas`, `src/fpdev.toml.parser.pas` | 新增回归测试 RED->GREEN，analyzer style 不再命中这三文件 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音并保持 CLI 可见输出语义 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离并回归通过 |

#### Execution Batch (this run)
- 执行 P1（严格 TDD：Red -> Green -> Verify）
- 计划文件：`docs/plans/2026-02-12-style-cleanup-batch5.md`

### Execution Result Update (2026-02-12 Round 7)
- [x] P1 代码风格分批修复（Batch 5: cmd.package/config.interfaces/toml.parser）
- [ ] P1 代码风格分批修复（Batch 6: cmd.fpc/cmd.package.repo.update/toolchain）
- [ ] P2 Debug 输出治理
- [ ] P3 硬编码常量治理

### Priority Queue (updated after Round 7 scan)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 6 | `src/fpdev.cmd.fpc.pas`, `src/fpdev.cmd.package.repo.update.pas`, `src/fpdev.toolchain.pas` | 新增回归测试 RED->GREEN，analyzer style 从这三文件继续迁移 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出与用户提示输出，降低 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

### Session 2026-02-12 Round 8: Scan -> Plan -> Execute (Batch 6)

#### Priority Queue (updated)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 6 | `src/fpdev.cmd.fpc.pas`, `src/fpdev.cmd.package.repo.update.pas`, `src/fpdev.toolchain.pas` | 新增回归测试 RED->GREEN，analyzer style 不再命中这三文件 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音并保持 CLI 可见输出语义 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离并回归通过 |

#### Execution Batch (this run)
- 执行 P1（严格 TDD：Red -> Green -> Verify）
- 计划文件：`docs/plans/2026-02-12-style-cleanup-batch6.md`

### Execution Result Update (2026-02-12 Round 8)
- [x] P1 代码风格分批修复（Batch 6: cmd.fpc/cmd.package.repo.update/toolchain）
- [ ] P1 代码风格分批修复（Batch 7: fpc.interfaces/cmd.package.install_local/resource.repo）
- [ ] P2 Debug 输出治理
- [ ] P3 硬编码常量治理

### Priority Queue (updated after Round 8 scan)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 7 | `src/fpdev.fpc.interfaces.pas`, `src/fpdev.cmd.package.install_local.pas`, `src/fpdev.resource.repo.pas` | 新增回归测试 RED->GREEN，analyzer style 从这三文件继续迁移 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出与用户提示输出，降低 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

### Session 2026-02-12 Round 9: Scan -> Plan -> Execute (Batch 7)

#### Priority Queue (updated)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 7 | `src/fpdev.fpc.interfaces.pas`, `src/fpdev.cmd.package.install_local.pas`, `src/fpdev.resource.repo.pas` | 新增回归测试 RED->GREEN，analyzer style 不再命中这三文件 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音并保持 CLI 可见输出语义 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离并回归通过 |

#### Execution Batch (this run)
- 执行 P1（严格 TDD：Red -> Green -> Verify）
- 计划文件：`docs/plans/2026-02-12-style-cleanup-batch7.md`

### Execution Result Update (2026-02-12 Round 9)
- [x] P1 代码风格分批修复（Batch 7: fpc.interfaces/cmd.package.install_local/resource.repo）
- [ ] P1 代码风格分批修复（Batch 8: template.list/registry.retry/git2）
- [ ] P2 Debug 输出治理
- [ ] P3 硬编码常量治理

### Priority Queue (updated after Round 9 scan)
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 8 | `src/fpdev.cmd.project.template.list.pas`, `src/fpdev.registry.retry.pas`, `src/fpdev.git2.pas` | 新增回归测试 RED->GREEN，analyzer style 从这三文件继续迁移 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出与用户提示输出，降低 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

## Recent Completed Micro-Slices (2026-03-06)

- [x] B245 build.cache 第九切片执行（RecordAccess access helper）
  - 新增 `src/fpdev.build.cache.access.pas`，抽离 `BuildCacheRecordAccessInfo`
  - `src/fpdev.build.cache.pas` 中 `RecordAccess` 改为 thin wrapper
  - 新增 `tests/test_build_cache_access.lpr`
  - 验证：`test_build_cache_access 15/15`、`test_cache_stats 22/22`、`test_cache_index 23/23`、`lazbuild -B fpdev.lpi`、`run_all_tests 196/196`
- [x] B246 build.cache 第十切片执行（index collect helper）
  - 新增 `src/fpdev.build.cache.indexcollect.pas`，抽离 `BuildCacheCollectIndexInfos`
  - `src/fpdev.build.cache.pas` 中 `GetDetailedStats` / `GetLeastRecentlyUsed` 改为 thin wrapper
  - 新增 `tests/test_build_cache_indexcollect.lpr`
  - 验证：`test_build_cache_indexcollect 4/4`、`test_build_cache_detailedstats 12/12`、`test_build_cache_lru 3/3`、`test_cache_stats 22/22`、`test_cache_index 23/23`、`lazbuild -B fpdev.lpi`、`run_all_tests 197/197`
- [x] B247 build.cache 第十一切片执行（index stats summary helper）
  - 扩展 `src/fpdev.build.cache.indexstats.pas`，新增 `BuildCacheCalculateIndexStats`
  - `src/fpdev.build.cache.pas` 中 `GetIndexStatistics` 改为 thin wrapper
  - 扩展 `tests/test_build_cache_indexstats.lpr`
  - 验证：`test_build_cache_indexstats 23/23`、`test_cache_index 23/23`、`test_cache_stats 22/22`、`lazbuild -B fpdev.lpi`、`run_all_tests 197/197`
- [x] B248 build.cache 第十二切片执行（rebuild collect helper）
  - 扩展 `src/fpdev.build.cache.rebuildscan.pas`，新增 `BuildCacheCollectRebuildInfos`
  - `src/fpdev.build.cache.pas` 中 `RebuildIndex` 改为 thinner wrapper
  - 扩展 `tests/test_build_cache_rebuildscan.lpr`
  - 验证：`test_build_cache_rebuildscan 10/10`、`test_cache_index 23/23`、`test_build_cache_indexstats 23/23`、`lazbuild -B fpdev.lpi`、`run_all_tests 197/197`
- [x] B249 build.cache 第十三切片执行（binary save helper）
  - 新增 `src/fpdev.build.cache.binarysave.pas`
  - `src/fpdev.build.cache.pas` 中 `SaveBinaryArtifact` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_binarysave.lpr`
  - 验证：`test_build_cache_binarysave 8/8`、`test_build_cache_binary 19/19`、`lazbuild -B fpdev.lpi`、`run_all_tests 198/198`
- [x] B250 build.cache 第十四切片执行（binary restore helper）
  - 新增 `src/fpdev.build.cache.binaryrestore.pas`
  - `src/fpdev.build.cache.pas` 中 `RestoreBinaryArtifact` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_binaryrestore.lpr`
  - 验证：`test_build_cache_binaryrestore 10/10`、`test_build_cache_binary 19/19`、`lazbuild -B fpdev.lpi`、`run_all_tests 199/199`
- [x] B251 build.cache 第十五切片执行（binary info helper）
  - 新增 `src/fpdev.build.cache.binaryinfo.pas`
  - `src/fpdev.build.cache.pas` 中 `GetBinaryArtifactInfo` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_binaryinfo.lpr`
  - 验证：`test_build_cache_binaryinfo 10/10`、`test_build_cache_binary 19/19`、`lazbuild -B fpdev.lpi`、`run_all_tests 200/200`
- [x] B252 build.cache 第十六切片执行（binary presence helper）
  - 新增 `src/fpdev.build.cache.binarypresence.pas`
  - `src/fpdev.build.cache.pas` 中 `HasArtifacts` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_binarypresence.lpr`
  - 验证：`test_build_cache_binarypresence 3/3`、`test_build_cache_binary 19/19`、`lazbuild -B fpdev.lpi`、`run_all_tests 201/201`
- [x] B253 build.cache 第十七切片执行（expired scan helper）
  - 新增 `src/fpdev.build.cache.expiredscan.pas`
  - `src/fpdev.build.cache.pas` 中 `CleanExpired` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_expiredscan.lpr`
  - 验证：`test_build_cache_expiredscan 3/3`、`test_cache_ttl 9/9`、`lazbuild -B fpdev.lpi`、`run_all_tests 202/202`
- [x] B254 build.cache 第十八切片执行（source info helper）
  - 新增 `src/fpdev.build.cache.sourceinfo.pas`
  - `src/fpdev.build.cache.pas` 中 `GetArtifactInfo` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_sourceinfo.lpr`
  - 验证：`test_build_cache_sourceinfo 7/7`、`test_cache_metadata 38/38`、`lazbuild -B fpdev.lpi`、`run_all_tests 203/203`
- [x] B255 build.cache 第十九切片执行（delete files helper）
  - 新增 `src/fpdev.build.cache.deletefiles.pas`
  - `src/fpdev.build.cache.pas` 中 `DeleteArtifacts` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_deletefiles.lpr`
  - 验证：`test_build_cache_deletefiles 4/4`、`test_cache_ttl 9/9`、`lazbuild -B fpdev.lpi`、`run_all_tests 204/204`
- [x] B256 build.cache 第二十切片执行（migration backup helper）
  - 新增 `src/fpdev.build.cache.migrationbackup.pas`
  - `src/fpdev.build.cache.pas` 中 `MigrateMetadataToJSON` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_migrationbackup.lpr`
  - 验证：`test_build_cache_migrationbackup 7/7`、`test_cache_metadata 38/38`、`lazbuild -B fpdev.lpi`、`run_all_tests 205/205`
- [x] B257 build.cache 第二十一切片执行（json info helper）
  - 新增 `src/fpdev.build.cache.jsoninfo.pas`
  - `src/fpdev.build.cache.pas` 中 `LoadMetadataJSON` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_jsoninfo.lpr`
  - 验证：`test_build_cache_jsoninfo 12/12`、`test_cache_metadata 38/38`、`lazbuild -B fpdev.lpi`、`run_all_tests 206/206`
- [x] B258 build.cache 第二十二切片执行（json save helper）
  - 新增 `src/fpdev.build.cache.jsonsave.pas`
  - `src/fpdev.build.cache.pas` 中 `SaveMetadataJSON` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_jsonsave.lpr`
  - 验证：`test_build_cache_jsonsave 12/12`、`test_cache_metadata 38/38`、`lazbuild -B fpdev.lpi`、`run_all_tests 208/208`
- [x] B259 build.cache 第二十三切片执行（json path helper）
  - 新增 `src/fpdev.build.cache.jsonpath.pas`
  - `src/fpdev.build.cache.pas` 中 `GetJSONMetaPath` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_jsonpath.lpr`
  - 验证：`test_build_cache_jsonpath 1/1`、`test_cache_metadata 38/38`、`lazbuild -B fpdev.lpi`、`run_all_tests 208/208`
- [x] B260 build.cache 第二十四切片执行（source path helper）
  - 新增 `src/fpdev.build.cache.sourcepath.pas`
  - `src/fpdev.build.cache.pas` 中 `GetArtifactArchivePath` / `GetArtifactMetaPath` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_sourcepath.lpr`
  - 验证：`test_build_cache_sourcepath 2/2`、`test_cache_metadata 38/38`、`test_cache_ttl 9/9`、`lazbuild -B fpdev.lpi`、`run_all_tests 209/209`
- [x] B261 build.cache 第二十五切片执行（cache stats helper）
  - 新增 `src/fpdev.build.cache.cachestats.pas`
  - `src/fpdev.build.cache.pas` 中 `GetCacheStats` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_cachestats.lpr`
  - 验证：`test_build_cache_cachestats 2/2`、`test_build_cache_binary 19/19`、`lazbuild -B fpdev.lpi`、`run_all_tests 210/210`
- [x] B262 build.cache 第二十六切片执行（entry query helper）
  - 新增 `src/fpdev.build.cache.entryquery.pas`
  - `src/fpdev.build.cache.pas` 中 `NeedsRebuild` / `GetRevision` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_entryquery.lpr`
  - 验证：`test_build_cache_entryquery 7/7`、`test_build_cache_entryio 22/22`、`lazbuild -B fpdev.lpi`、`run_all_tests 212/212`
- [x] B263 build.cache 第二十七切片执行（artifact meta helper）
  - 新增 `src/fpdev.build.cache.artifactmeta.pas`
  - `src/fpdev.build.cache.pas` 中 `SaveArtifactMetadata` 改为 thinner wrapper
  - 新增 `tests/test_build_cache_artifactmeta.lpr`
  - 验证：`test_build_cache_artifactmeta 6/6`、`test_cache_space 8/8`、`lazbuild -B fpdev.lpi`、`run_all_tests 212/212`

## 2026-03-09 Batch: File-Based Planning Switch + Config Isolation Sweep

### Goal
- 在 `planning-with-files` 工作流下继续大批次推进，优先完成剩余测试配置隔离收口，并保持全量测试绿灯。

### Scope
- 同步当前验证基线：`bash scripts/run_all_tests.sh` = `216/216` passed。
- 审核剩余测试中的 `Create('')` / 默认配置路径落点。
- 优先处理仍可能触达真实用户配置目录的测试用例。
- 完成 focused 回归后，再跑一次全量测试。
- 完成本批次后继续做 repo 审查，刷新建议与后续计划。

### Batch Phases
- [x] 切换到 `planning-with-files` 工作流并完成 session catchup
- [ ] 盘点剩余配置隔离风险点并分类
- [ ] 实施下一大波测试隔离修复
- [ ] 跑 focused 回归与全量回归
- [ ] 输出新的审查建议与下一批计划
- **Status:** in_progress

### Batch Decisions
| Decision | Rationale |
|----------|-----------|
| 优先继续测试配置隔离，而不是立即再拆产品大文件 | 这是当前最直接的稳定性与环境污染风险，且已有 helper/基线可复用 |
| 采用“大块计划 + 大块实现”方式推进 | 符合用户新要求，也更适合当前仓库的长期自治节奏 |
| 先做测试侧显式注入，再评估产品入口层是否还需扩散注入 | 先解决真实污染风险，避免过早扩大产品改动面 |

### Batch Errors
| Error | Attempt | Resolution |
|-------|---------|------------|
| 直接执行 `scripts/session-catchup.py` 返回 permission denied | 1 | 改用 `python3 .../session-catchup.py` 成功执行 |
| `mcp__ace-tool__search_context` transport closed during isolation audit | 1 | 记录后降级到 `rg` 精确扫描，避免阻塞当前批次 |
- [x] 盘点剩余配置隔离风险点并分类
- [x] 实施下一大波测试隔离修复
- [x] 跑 focused 回归与全量回归
- [ ] 输出新的审查建议与下一批计划
- **Status:** in_progress

### Batch Completion Notes
- 已完成 6 个命令测试文件的默认 `TDefaultCommandContext.Create` 隔离收口。
- 已补充默认 context 使用隔离默认配置路径的回归测试。
- focused 回归与 `bash scripts/run_all_tests.sh` 均通过。
- [x] 输出新的审查建议与下一批计划
- **Status:** complete

### Second Wave Completion Notes
- 已修复 `tests/test_logger_integration.lpr` 的仓库根目录脏目录源头。
- 已清理历史残留 `test_full_pipeline_*` / `test_archive_cleanup_*` 目录。
- 第二次全量回归仍保持 `216/216` passed。

## 2026-03-09 Batch: Project/FPC/Logger Temp Root Final Sweep

### Goal
- 将剩余测试根目录脏目录热点彻底收口到 `test_temp_paths`，并验证仓库根目录 temp-like 目录回到 0。

### Scope
- 收口 `tests/test_project_run.lpr`、`tests/test_project_clean.lpr`、`tests/test_project_test.lpr`、`tests/test_fpc_current.lpr` 的 temp helper 使用。
- 收口 `tests/test_structured_logger.lpr`、`tests/test_log_rotation.lpr` 的根目录日志目录。
- 清理历史残留 `test_run_temp_*`、`test_current_root_*`、`test_testcmd_temp_*`、`test_logs`、`test_rotation_logs`、`test_fail_temp_*`、`test_integration_data`。
- 以 focused + full suite 验证最终根目录 temp-like 目录为 0。

### Phases
- [x] 定位 project/fpc/logger 家族残留来源
- [x] 完成 helper 统一化改造
- [x] 清理历史残留目录
- [x] 运行 focused 回归与最终 full suite
- [x] 记录结果与下一批候选
- **Status:** complete

## 2026-03-09 Batch: Stable Test Inventory Generation

### Goal
- 让测试数量同步机制稳定可重复，避免 `docs/testing.md` 因日期漂移每日自发 out-of-sync，并降低 README/docs 生成逻辑的脆弱性。

### Scope
- 审查 `scripts/update_test_stats.py`、README、`docs/testing.md`、CI 与 `run_all_tests.sh` 的测试口径链路。
- 去掉基于“当天日期”的不稳定生成内容。
- 为 README/docs 引入显式生成区块 marker（在不破坏渲染的前提下）。
- 补充脚本级 Python 回归。
- 验证 `--check`、`--count`、Python tests 与 full suite。

### Phases
- [x] 盘点测试口径链路
- [x] 修复日期漂移与生成区块脆弱性
- [x] 补充脚本级回归测试
- [x] 跑脚本验证与 full suite
- [x] 记录结论与后续计划
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (Manifest Plan Slice)

### Goal
- 将 `src/fpdev.fpc.installer.pas` 的 manifest 安装准备逻辑抽为独立 helper，降低 installer 的职责密度，并保持现有安装行为与 scoped manifest cache 语义不变。

### Scope
- 为 manifest 安装链路新增 helper 单元，负责：manifest cache 读取、platform target 选择、下载/解压临时路径规划。
- 在 `TFPCBinaryInstaller.InstallFromManifest` 中只保留 orchestration（日志、Fetch、解压、cleanup）。
- 补充 focused 离线测试覆盖 plan helper 的成功、缺失 target、扩展名回退与 scoped cache 路径行为。

### Phases
- [ ] 记录 installer campaign 边界与第一刀方案
- [ ] 先补 manifest plan helper 红灯测试
- [ ] 实现 helper 并接入 installer
- [ ] 运行 installer focused 回归
- [ ] 记录验证结果与下一刀候选
- **Status:** in_progress
- [x] 记录 installer campaign 边界与第一刀方案
- [x] 先补 manifest plan helper 红灯测试
- [x] 实现 helper 并接入 installer
- [x] 运行 installer focused 回归
- [x] 记录验证结果与下一刀候选
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (Post-Install Slice)

### Goal
- 将 `src/fpdev.fpc.installer.pas` 的 binary install 收尾逻辑抽为独立 helper，进一步收敛 installer 主流程到 orchestration。

### Scope
- 新增 post-install helper，负责 wrapper / `fpc.cfg` 生成、environment setup、completion summary、cache save。
- `InstallFromBinary` 只保留安装 fallback chain 与 helper 调用。
- 补充 focused 离线测试覆盖 cache on/off、missing bin、environment warning。

### Phases
- [x] 梳理 post-install 现状
- [x] 补 post-install 红灯测试
- [x] 抽离 post-install helper
- [x] 接回 installer orchestration
- [x] 跑 focused 与全量回归
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (Repo Flow Slice)

### Goal
- 将 `src/fpdev.fpc.installer.pas` 的 repo 安装分支抽为独立 helper，避免 manager 持有冗长 repo init / query / install / fallback 分支。

### Scope
- 新增 repo flow helper，负责 init、release 命中判断、安装和 fallback 提示。
- 在 installer 中保留 resource repo wrapper methods，处理真实 `TResourceRepository` 生命周期。
- 补充 callback-based focused tests，覆盖 init failure、install failure、missing release、success。

### Phases
- [x] 映射 repo flow 边界
- [x] 补 repo flow 红灯测试
- [x] 抽离 repo flow helper
- [x] 接回 installer wrappers
- [x] 跑 focused 与全量回归
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (SourceForge Flow Slice)

### Goal
- 将 `src/fpdev.fpc.installer.pas` 的 SourceForge fallback 分支抽为独立 helper，继续把 installer 主文件压回 orchestration 角色。

### Scope
- 新增 sourceforge flow helper，负责 download、Linux extract temp dir cleanup、manual-install messaging、verification。
- 在 installer 中保留 extraction wrapper，桥接真实 `TFPCArchiveExtractor`。
- 补充 focused callback-based tests，覆盖 success、download failure、extract failure、verify failure。

### Phases
- [x] 盘点 sourceforge flow 边界
- [x] 补 sourceforge 红灯测试
- [x] 抽离 sourceforge helper
- [x] 接回 installer wrapper
- [x] 跑 focused 与全量回归
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (Archive Flow Slice)

### Goal
- 将 `src/fpdev.fpc.installer.pas` 的 generic archive extraction 分支抽为独立 helper，继续压缩 installer 主文件的条件分支和 IO 细节。

### Scope
- 新增 archive flow helper，负责 missing file、zip/tar/tar.gz dispatch、manual-install messaging、unsupported-format error。
- 在 installer 中保留 zip/tar/targz wrapper，桥接真实 `TUnZipper` 和 `TProcessExecutor`。
- 补充 callback-based focused tests，覆盖 zip/tar/targz dispatch、manual install、unsupported format。

### Phases
- [x] 梳理 archive flow 边界
- [x] 补 archive helper 红灯测试
- [x] 抽离 archive helper
- [x] 接回 installer 调用
- [x] 跑 focused 与全量回归
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (Binary Flow Slice)

### Goal
- 将 `src/fpdev.fpc.installer.pas` 的 `InstallFromBinary` 主 orchestration 抽到独立 helper，进一步把 installer 压回 facade/orchestrator 角色。

### Scope
- 新增 binary flow helper，负责安装头部输出、manifest → repo → SourceForge fallback chain、SourceForge summary 和异常兜底。
- `TFPCBinaryInstaller.InstallFromBinary` 只保留 install path / platform 解析与 post-install 调用。
- 补充 focused callback-based tests，覆盖 manifest success、repo fallback、SourceForge fallback、全失败、exception path。

### Phases
- [x] 映射 binary flow 边界
- [x] 补 binary flow 红灯测试
- [x] 抽离 binary flow helper
- [x] 接回 installer facade
- [x] 跑 focused 与全量回归
- [x] 记录验证结果与下一批候选
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (Manifest Execution Wave)

### Goal
- 将 `src/fpdev.fpc.installer.pas` 中 manifest 运行态 orchestration 与 nested package extraction 一次性抽到独立 helpers，继续压缩 installer 主文件。

### Scope
- 新增 manifest flow helper，负责 manifest load/fetch/extract/cleanup orchestration 与错误输出。
- 新增 nested flow helper，负责 nested binary/base archive 搜索、direct fallback、post-validate。
- `TFPCBinaryInstaller` 仅保留薄 wrapper：prepare plan、fetch download、extract archive、delegate。
- 补充两组 focused callback/fixture tests，覆盖 success、fallback、cleanup、validation、exception path。

### Phases
- [x] 盘点 manifest wave 边界
- [x] 补 manifest wave 红灯测试
- [x] 抽 manifest 与 nested helpers
- [x] 同步测试统计并全量验证
- [x] 继续审查并更新下一波计划
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (Legacy Download + Verify Wave)

### Goal
- 将 legacy SourceForge URL/临时文件规划/HTTP 下载/checksum 校验整合抽到 helper 家族，继续压缩 installer 尾部兼容逻辑。

### Scope
- 新增 download flow helper，负责 legacy URL resolve、file extension、temp path planning、download orchestration、checksum verify。
- `TFPCBinaryInstaller` 仅保留实际 HTTP GET 与 SHA256 计算 wrapper。
- 补充 focused offline tests，覆盖 URL/plan、download success/failure/exception、verify success/missing-file/empty-hash。

### Phases
- [x] 盘点 legacy download 边界
- [x] 补 download wave 红灯测试
- [x] 抽 legacy download 与 verify helpers
- [x] 同步测试统计并全量验证
- [x] 更新审查结论与下波路线
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (Environment Registration Wave)

### Goal
- 将 `SetupEnvironment` 中 toolchain registration 细节抽为复用 helper，并同时消除 `src/fpdev.cmd.fpc.pas` 的重复实现。

### Scope
- 新增 environment flow helper，负责 `TToolchainInfo` 构造、`AddToolchain` 调用与错误输出。
- `TFPCBinaryInstaller.SetupEnvironment` 与 `TFPCManager.SetupEnvironment` 都改为 path resolve + helper delegate。
- 补充 focused offline tests，覆盖 record field mapping、success、missing version/dir、add failure、exception path。

### Phases
- [x] 盘点 environment wave 边界
- [x] 补 environment wave 红灯测试
- [x] 抽 environment registration helper
- [x] 同步测试统计并全量验证
- [x] 更新审查结论与下波路线
- **Status:** complete

## 2026-03-09 Batch: FPC Installer Structural Split (IO Bridge Wave)

### Goal
- 将 installer 中剩余的 HTTP/zip/tar/tar.gz 底层 IO bridge 抽到独立 helper，尽量把 `TFPCBinaryInstaller` 收成纯 facade/orchestrator。

### Scope
- 新增 IO bridge helper，负责实际 HTTP 下载、ZIP 提取、TAR/TAR.GZ 提取。
- `TFPCBinaryInstaller` 中的 bridge methods 改为一行 delegate。
- 补充 focused bridge tests，覆盖 local HTTP success/failure、zip/tar/targz extract success。

### Phases
- [x] 盘点 IO bridge 边界
- [x] 补 IO bridge 红灯测试
- [x] 抽 HTTP 与 archive bridge helper
- [x] 同步测试统计并全量验证
- [x] 更新审查结论与后续路线
- **Status:** complete

## 2026-03-09 Batch: Package Command Wave (Lifecycle Slice)

### Goal
- 将 `src/fpdev.cmd.package.pas` 中剩余的 uninstall/update orchestration 一次性抽到独立 helper，继续压缩 manager 主单元职责。

### Status
- [x] 新增 red test：`tests/test_package_lifecycle_flow.lpr`
- [x] 新增 helper：`src/fpdev.cmd.package.lifecycle.pas`
- [x] `TPackageManager.UninstallPackage` 改为 thin wrapper
- [x] `TPackageManager.UpdatePackage` 改为 gather context + helper delegate
- [x] 更新测试统计到 `228`
- [x] 跑通 focused / package / full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_lifecycle_flow.lpr` -> `Can't find unit fpdev.cmd.package.lifecycle`
- GREEN: `./bin/test_package_lifecycle_flow` -> `30/30` passed
- `./bin/test_cli_package` -> `223/223` passed
- `./bin/test_package_commands` -> `21/21` passed
- `./bin/test_package_updateplan` -> `6/6` passed
- `./bin/test_package_install_flow_helper` -> `13/13` passed
- `python3 scripts/update_test_stats.py --count` -> `228`
- `python3 scripts/update_test_stats.py --check` -> passed
- `bash scripts/run_all_tests.sh` -> `228/228` passed

### Next Candidate Waves
1. `src/fpdev.build.manager.pas` preflight input assembly/logging thin-wrapper 化
2. `src/fpdev.cmd.fpc.pas` `InstallVersion` 拆 cache-restore/source-install/verify path
3. `src/fpdev.resource.repo.pas` bootstrap fallback chain helper 化

## 2026-03-09 Batch: Build Manager Flow Wave

### Goal
- 将 `src/fpdev.build.manager.pas` 中剩余的 `Preflight` input assembly 与 `FullBuild` phase-runner orchestration 一次性抽到独立 helpers，继续把 manager 收回 facade/orchestrator。

### Status
- [x] 新增 red tests：`tests/test_build_preflightflow.lpr`、`tests/test_build_fullbuildflow.lpr`
- [x] 新增 helper：`src/fpdev.build.preflightflow.pas`
- [x] 新增 helper：`src/fpdev.build.fullbuildflow.pas`
- [x] `TBuildManager.Preflight` 改为 env snapshot + helper delegate + issue/log rendering
- [x] `TBuildManager.FullBuild` 改为 thin wrapper delegate
- [x] 更新测试统计到 `230`
- [x] 跑通 focused / build-manager / full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_preflightflow.lpr` -> `Can't find unit fpdev.build.preflightflow`
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_fullbuildflow.lpr` -> `Can't find unit fpdev.build.fullbuildflow`
- GREEN: `./bin/test_build_preflightflow` -> `21/21` passed
- GREEN: `./bin/test_build_fullbuildflow` -> `12/12` passed
- `./bin/test_full_build` -> `8/8` passed
- `tests/fpdev.build.manager/test_build_manager*` focused group -> passed
- `python3 scripts/update_test_stats.py --count` -> `230`
- `python3 scripts/update_test_stats.py --check` -> passed
- `bash scripts/run_all_tests.sh` -> `230/230` passed

### Next Candidate Waves
1. `src/fpdev.cmd.fpc.pas:510` `InstallVersion` 拆 verify/cache-restore/source-install/post-setup flow
2. `src/fpdev.resource.repo.pas:629` bootstrap fallback chain helper 化
3. `src/fpdev.cmd.project.pas` / `src/fpdev.cmd.cross.pas` 这类仍在 `1000+` 行的命令聚合单元继续 facade 化

## 2026-03-09 Batch: FPC InstallVersion Flow Wave

### Goal
- 将 `src/fpdev.cmd.fpc.pas` 中 `TFPCManager.InstallVersion` 的已安装复用、cache restore、source build、binary install orchestration 一次性抽到独立 helper，继续收薄 manager。

### Status
- [x] 新增 red test：`tests/test_fpc_installversionflow.lpr`
- [x] 新增 helper：`src/fpdev.cmd.fpc.installversionflow.pas`
- [x] `TFPCManager.InstallVersion` 改为 validation + helper delegate
- [x] 新增 verifier wrapper：`VerifyInstalledExecutableVersion`
- [x] 更新测试统计到 `231`
- [x] 跑通 focused / fpc / full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_fpc_installversionflow.lpr` -> `Can't find unit fpdev.cmd.fpc.installversionflow`
- GREEN: `./bin/test_fpc_installversionflow` -> `26/26` passed
- `./bin/test_fpc_binary_install` -> `11 passed, 0 failed`
- `./bin/test_fpc_install_cli` -> `38/38` passed
- `./bin/test_cli_fpc_lifecycle` -> `40/40` passed
- `./bin/test_fpc_commands` -> `22/22` passed
- `python3 scripts/update_test_stats.py --count` -> `231`
- `python3 scripts/update_test_stats.py --check` -> passed
- `bash scripts/run_all_tests.sh` -> `231/231` passed

### Next Candidate Waves
1. `src/fpdev.resource.repo.pas:629` bootstrap fallback chain helper 化
2. `src/fpdev.cmd.project.pas` command orchestration seam 压缩
3. `src/fpdev.cmd.cross.pas` facade 化继续推进

## 2026-03-09 Batch: Resource Repo Bootstrap Selector Wave

### Goal
- 将 `src/fpdev.resource.repo.pas:629` 的 bootstrap fallback chain 选择逻辑抽成可独立测试的 helper，同时保持主依赖树稳定，不引入新的大范围链接回归。

### Status
- [x] 新增 red test：`tests/test_resource_repo_bootstrapselector.lpr`
- [x] 抽离 selector core，并最终并回 `src/fpdev.resource.repo.bootstrap.pas`
- [x] `TResourceRepository.FindBestBootstrapVersion` 改为 thin wrapper + log replay
- [x] 修复首次抽离带来的 compile/link regression
- [x] 更新测试统计到 `232`
- [x] 跑通 focused / targeted / full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_bootstrapselector.lpr` -> `Can't find unit fpdev.resource.repo.bootstrapselector`
- GREEN: `./bin/test_resource_repo_bootstrapselector` -> `10/10` passed
- `./bin/test_resource_repo_bootstrap` -> `31/31` passed
- `./bin/test_resource_repo_binary` -> `21/21` passed
- `./bin/test_command_registry` -> `165/165` passed
- `./bin/test_cli_project` -> `42/42` passed
- `python3 scripts/update_test_stats.py --check` -> passed
- `bash scripts/run_all_tests.sh` -> `232/232` passed

### Next Candidate Waves
1. `src/fpdev.cmd.project.pas` orchestration seam 压缩（命令 facade 化）
2. `src/fpdev.cmd.cross.pas` facade 化继续推进
3. `scripts/run_all_tests.sh` transient failure recovery 再增强（磁盘/资源类波动）

## 2026-03-09 Batch: Project Exec Flow Wave

### Goal
- 将 `src/fpdev.cmd.project.pas` 中 `build/test/run` 的目录校验、目标发现、参数拆分与进程调用 orchestration 抽成独立 helper，让 manager 回到 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_project_execflow.lpr`
- [x] 新增 helper：`src/fpdev.cmd.project.execflow.pas`
- [x] `TProjectManager.BuildProject` 改为 thin wrapper delegate
- [x] `TProjectManager.TestProject` 改为 output setup + helper delegate
- [x] `TProjectManager.RunProject` 改为 output setup + helper delegate
- [x] 更新测试统计到 `233`
- [x] 跑通 focused / project / full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_project_execflow.lpr` -> `Can't find unit fpdev.cmd.project.execflow`
- GREEN: `./bin/test_project_execflow` -> `26/26` passed
- `./bin/test_project_run` -> passed
- `./bin/test_project_test` -> passed
- `./bin/test_project_clean` -> passed
- `./bin/test_cli_project` -> `42/42` passed
- `python3 scripts/update_test_stats.py --check` -> passed
- `bash scripts/run_all_tests.sh` -> `233/233` passed

### Next Candidate Waves
1. `src/fpdev.cmd.cross.pas` target lifecycle / configure / test flow facade 化
2. `scripts/run_all_tests.sh` transient failure recovery 增强（disk/linker/zero-byte binary）
3. `src/fpdev.cmd.lazarus.pas` 同类 exec/config flow 收口

## 2026-03-09 Batch: Cross Target Flow Wave

### Goal
- 将 `src/fpdev.cmd.cross.pas` 中 `enable/disable/configure/test/buildtest` 的状态读取、配置写回、进程探测与输出转译抽成独立 helper，让 manager 回到 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_cross_targetflow.lpr`
- [x] 新增 helper：`src/fpdev.cmd.cross.targetflow.pas`
- [x] `TCrossCompilerManager.EnableTarget` / `DisableTarget` 改为 thin wrapper delegate
- [x] `TCrossCompilerManager.ConfigureTarget` / `TestTarget` / `BuildTest` 改为 helper delegate
- [x] 顺手收掉本波新增的 managed-type hint
- [x] 更新测试统计到 `234`
- [x] 跑通 focused / cross / full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cross_targetflow.lpr` -> `Can't find unit fpdev.cmd.cross.targetflow`
- GREEN: `./bin/test_cross_targetflow` -> `25/25` passed
- `./bin/test_cross_commands` -> `85/85` passed
- `./bin/test_cli_cross` -> `85/85` passed
- `python3 scripts/update_test_stats.py --check` -> passed
- `bash scripts/run_all_tests.sh` -> `234/234` passed

### Next Candidate Waves
1. `scripts/run_all_tests.sh` transient recovery wave（disk/linker/zero-byte binary/cleanup retry）
2. `src/fpdev.cmd.lazarus.pas` exec/config flow wave（对齐 `project/cross` 的 helper 化路径）
3. `src/fpdev.cmd.cross.pas` install/update orchestration wave（下载/系统编译器/manual hint 分支继续 facade 化）


## 2026-03-09 Batch: Test Runner Resilience Wave

### Goal
- 加固 `scripts/run_all_tests.sh`，解决“构建表面成功但产物缺失/零字节”与磁盘资源类抖动的恢复能力，并把脚本改造成可单测的结构。

### Status
- [x] 新增 red tests：`tests/test_run_all_tests.py`
- [x] `scripts/run_all_tests.sh` 抽出 `main` 和可 source 的 helper functions
- [x] 新增 binary candidate cleanup / valid binary 校验 / successful-build-no-binary retry once
- [x] `is_transient_build_failure` 补 `No space left on device` / `Disk quota exceeded`
- [x] CI 新增 Python 脚本单测入口
- [x] 跑通 Python focused / Python full / Pascal full suite

### Verification
- RED: `python3 -m unittest discover -s tests -p 'test_run_all_tests.py'` -> fail（source 脚本时直接跑主流程，且缺少 `build_test_with_recovery`）
- GREEN: `python3 -m unittest discover -s tests -p 'test_run_all_tests.py'` -> `3 tests` passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `79 tests` passed
- `bash scripts/run_all_tests.sh` -> `234/234` passed

### Next Candidate Waves
1. `src/fpdev.cmd.lazarus.pas:374` `InstallVersion` 抽 source-install orchestration + post-config helper，收掉重复 source build 分支
2. `src/fpdev.cmd.lazarus.pas:957` `ConfigureIDE` 抽 config path / compiler path / IDE mutation flow，压缩 IO + config 混合逻辑
3. `src/fpdev.cmd.lazarus.pas:663` / `724` 收口 version/source-dir resolve helper，减少 `update` / `clean` / `run` 的重复前置判断

## 2026-03-09 Batch: Lazarus Install/Configure Flow Wave

### Goal
- 将 `src/fpdev.cmd.lazarus.pas` 中 `InstallVersion` / `ConfigureIDE` 的大块 orchestration 收进 helper，复用路径推导与 IDE config 流程，并保持 `TLazarusManager` 为 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_lazarus_flow.lpr`
- [x] 新增 helper：`src/fpdev.cmd.lazarus.flow.pas`
- [x] `TLazarusManager.InstallVersion` 改为 validation + helper delegate
- [x] `TLazarusManager.ConfigureIDE` 改为 output setup + helper delegate
- [x] 修复 `scripts/update_test_stats.py` 对新 `run_all_tests.sh` `mapfile` loader 的兼容
- [x] 同步测试统计到 `235`
- [x] 跑通 focused / lazarus / python / full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_lazarus_flow.lpr` -> `Can't find unit fpdev.cmd.lazarus.flow`
- GREEN: `./bin/test_lazarus_flow` -> `21/21` passed
- `./bin/test_lazarus_configure_workflow` -> `6 passed, 0 failed`
- `./bin/test_cli_lazarus` -> `89/89` passed
- `./bin/test_lazarus_commands` -> `15/15` passed
- `python3 -m unittest discover -s tests -p 'test_update_test_stats.py'` -> `4/4` passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `python3 scripts/update_test_stats.py --check` -> passed
- `bash scripts/run_all_tests.sh` -> `235/235` passed

### Next Candidate Waves
1. `src/fpdev.cmd.lazarus.pas:663` / `724` 抽 version/source-dir resolve helper，先收 `UpdateSources` / `CleanSources` 的重复前置判断
2. `src/fpdev.cmd.lazarus.pas:890` 抽 `LaunchIDE` version resolution + executable path helper，继续收口 run path
3. `src/fpdev.cmd.package.pas` 再挑一刀现存 orchestration seam，优先 install/update/registry 里剩余胖方法

## 2026-03-09 Batch: Lazarus Runtime/Source Flow Wave

### Goal
- 将 `src/fpdev.cmd.lazarus.pas` 中 `UpdateSources` / `CleanSources` / `LaunchIDE` 的 version fallback、source-dir 组装、git 决策与 launch 输出收进 helper，继续把 manager 压成 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_lazarus_runtimeflow.lpr`
- [x] 扩展 helper：`src/fpdev.cmd.lazarus.flow.pas`
- [x] `TLazarusManager.UpdateSources` 改为 source plan + update helper delegate
- [x] `TLazarusManager.CleanSources` 改为 source plan + clean helper delegate
- [x] `TLazarusManager.LaunchIDE` 改为 launch plan + execute helper delegate
- [x] 同步测试统计到 `236`
- [x] 跑通 focused / lazarus / python / full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_lazarus_runtimeflow.lpr` -> missing `TLazarusSourcePlan` / `CreateLazarusSourcePlanCore` / `CreateLazarusLaunchPlanCore`
- GREEN: `./bin/test_lazarus_runtimeflow` -> `19/19` passed
- `./bin/test_lazarus_flow` -> `21/21` passed
- `./bin/test_lazarus_update` -> `5 passed, 0 failed`
- `./bin/test_lazarus_clean` -> `17 passed, 0 failed`
- `./bin/test_cli_lazarus` -> `89/89` passed
- `./bin/test_lazarus_commands` -> `15/15` passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `python3 scripts/update_test_stats.py --check` -> passed
- `bash scripts/run_all_tests.sh` -> `236/236` passed

### Next Candidate Waves
1. `src/fpdev.cmd.package.pas` 重扫剩余 orchestration seam，优先 install/update/registry 相关重逻辑
2. `src/fpdev.cmd.lazarus.pas:707` / `772` / `896` 继续压缩 show/test/config 的 shared path/version helpers
3. `src/fpdev.cmd.fpc.pas` / `src/fpdev.cmd.cross.pas` 再盘一轮是否还有可安全抽离的 facade seam

## 2026-03-09 Batch: Package Install/Update Manager Orchestration Wave

### Goal
- 将 `src/fpdev.cmd.package.pas` 中 `InstallPackage` / `UpdatePackage` 的 manager orchestration 收进 lifecycle helper，保持 `TPackageManager` 只负责 facade/wrapper 级职责。

### Status
- [x] 新增 red test：`tests/test_package_manager_installupdateflow.lpr`
- [x] 扩展 helper：`src/fpdev.cmd.package.lifecycle.pas`
- [x] `TPackageManager.InstallPackage` 改为 validation + orchestration helper delegate
- [x] `TPackageManager.UpdatePackage` 改为 validation + install-or-update helper delegate
- [x] 修复 `src/fpdev.cmd.package.pas` 的重复 `uses fpdev.cmd.package.fetch` 编译冲突
- [x] 通过统计脚本同步 discoverable test count 到 `237`
- [x] 跑通 package focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_manager_installupdateflow.lpr` -> missing install/update lifecycle helper symbols
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_cli_package.lpr` -> duplicate identifier `fpdev.cmd.package.fetch`
- GREEN: `./bin/test_package_manager_installupdateflow` -> `19/19` passed
- `./bin/test_package_lifecycle_flow` -> `30/30` passed
- `./bin/test_package_install_flow_helper` -> all `13` assertions passed
- `./bin/test_cli_package` -> `223/223` passed
- `python3 scripts/update_test_stats.py --count` -> `237`
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `237/237` passed

### Next Candidate Waves
1. `src/fpdev.build.manager.pas`：拆 `Preflight` 的 issue collect / issue render / issue emit，先收日志与判定双职责
2. `src/fpdev.build.manager.pas`：拆 phase runner，将 phase iteration / reporting / short-circuit 独立 helper 化
3. `tests/test_project_test.lpr`：把 temp root 迁到系统临时目录并补递归清理，顺带消灭仓库根目录残留测试垃圾

## 2026-03-09 Batch: Build TestResults Flow Wave

### Goal
- 将 `src/fpdev.build.manager.pas` 中 `TestResults` 的 sandbox/source 校验、strict 分支与 summary 输出收进 helper，保持 `TBuildManager` 为 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_build_testresultsflow.lpr`
- [x] 新增 helper：`src/fpdev.build.testresultsflow.pas`
- [x] `TBuildManager.TestResults` 改为 helper delegate
- [x] 修复 `DirectoryExists` 默认参数导致的 callback 类型不兼容
- [x] 通过统计脚本同步 discoverable test count 到 `238`
- [x] 跑通 build focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Futests -Fusrc -Fisrc -FEbin -FUlib tests/test_build_testresultsflow.lpr` -> `Can't find unit fpdev.build.testresultsflow`
- GREEN: `./bin/test_build_testresultsflow` -> `29/29` passed
- `./bin/test_build_preflightflow` -> `21/21` passed
- `./bin/test_build_fullbuildflow` -> `12/12` passed
- `cd tests/fpdev.build.manager && ./run_tests.sh` -> `CASE1 OK` / `CASE2 OK` / `STRICT_FAIL OK` / `STRICT_PASS OK`
- `python3 scripts/update_test_stats.py --count` -> `238`
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `238/238` passed

### Next Candidate Waves
1. `src/fpdev.resource.repo.pas`：拆 `Initialize` / `Update` / `LoadManifest` / `EnsureManifestLoaded` 的 repo lifecycle + manifest state seam
2. `src/fpdev.cmd.fpc.pas`：拆 `UpdateSources` / `CleanSources` / `ShowVersionInfo` / `TestInstallation` 的 shared version/source-path flow
3. `src/fpdev.cmd.package.pas`：继续收 `InstallFromLocal` / `CreatePackage` / `PublishPackage` 的 facade seam

## 2026-03-09 Batch: Resource Repo Lifecycle / Manifest Flow Wave

### Goal
- 将 `src/fpdev.resource.repo.pas` 中 `Initialize` / `Update` / `LoadManifest` / `EnsureManifestLoaded` 的 repo lifecycle + manifest state logic 收进 helper，保持 `TResourceRepository` 为 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_resource_repo_lifecycleflow.lpr`
- [x] 新增 helper：`src/fpdev.resource.repo.lifecycle.pas`
- [x] `TResourceRepository.Initialize` / `Update` 改为 lifecycle helper delegate
- [x] `TResourceRepository.LoadManifest` / `EnsureManifestLoaded` 改为 manifest helper delegate
- [x] 新增 `MarkUpdateCheckNow`，统一更新时间戳写入点
- [x] 通过统计脚本同步 discoverable test count 到 `239`
- [x] 跑通 repo focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Futests -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_lifecycleflow.lpr` -> `Can't find unit fpdev.resource.repo.lifecycle`
- GREEN: `./bin/test_resource_repo_lifecycleflow` -> `38/38` passed
- `./bin/test_resource_repo_bootstrap` -> `31/31` passed
- `./bin/test_resource_repo_package` -> `6/6` passed
- `./bin/test_resource_repo_query` -> `8/8` passed
- `python3 scripts/update_test_stats.py --count` -> `239`
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `239/239` passed

### Next Candidate Waves
1. `src/fpdev.cmd.fpc.pas`：拆 `UpdateSources` / `CleanSources` / `ShowVersionInfo` / `TestInstallation` 的 shared version/source-path flow
2. `src/fpdev.cmd.package.pas`：继续收 `InstallFromLocal` / `CreatePackage` / `PublishPackage` 的 facade seam
3. `src/fpdev.resource.repo.pas`：若还要继续收薄，再拆 `GetStatus` / commit/query 输出与 git status seam

## 2026-03-09 Batch: FPC Runtime / Info Flow Wave

### Goal
- 将 `src/fpdev.cmd.fpc.pas` 中 `UpdateSources` / `CleanSources` / `ShowVersionInfo` / `TestInstallation` 的 shared source-path / runtime-info 逻辑收进 helper，保持 `TFPCManager` 为 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_fpc_runtimeflow.lpr`
- [x] 新增 helper：`src/fpdev.cmd.fpc.runtimeflow.pas`
- [x] `TFPCManager.UpdateSources` / `CleanSources` / `ShowVersionInfo` / `TestInstallation` 改为 helper delegate
- [x] 通过统计脚本同步 discoverable test count 到 `240`
- [x] 跑通 focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Futests -Fusrc -Fisrc -FEbin -FUlib tests/test_fpc_runtimeflow.lpr` -> `Can't find unit fpdev.cmd.fpc.runtimeflow`
- GREEN: `./bin/test_fpc_runtimeflow` -> `40/40` passed
- `./bin/test_fpc_update` -> all tests passed
- `./bin/test_fpc_clean` -> all tests passed
- `./bin/test_fpc_show` -> `5/5` passed
- `./bin/test_fpc_commands` -> `22/22` passed
- `python3 scripts/update_test_stats.py --count` -> `240`
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `240/240` passed

### Next Candidate Waves
1. `src/fpdev.build.manager.pas`：拆 phase runner，将 phase iteration / reporting / short-circuit 独立 helper 化
2. `src/fpdev.cmd.package.pas`：继续收 `InstallFromLocal` / `CreatePackage` / `PublishPackage` 的 facade seam
3. `src/fpdev.fpc.validator.pas`：与 `cmd.fpc.runtimeflow` 对齐，消灭 `ShowVersionInfo` / `TestInstallation` 剩余重复

## 2026-03-09 Batch: FPC Validator Runtimeflow Dedup Wave

### Goal
- 让 `src/fpdev.fpc.validator.pas` 的 `TestInstallation` / `ShowVersionInfo` 复用 `src/fpdev.cmd.fpc.runtimeflow.pas`，消灭重复逻辑并保留 validator 的既有输出语义。

### Status
- [x] 扩展 red test：`tests/test_fpc_runtimeflow.lpr`
- [x] 新增 validator focused test：`tests/test_fpc_validator_runtimeflow.lpr`
- [x] `TFPCValidator` 改为 runtimeflow delegate
- [x] 通过统计脚本同步 discoverable test count 到 `241`
- [x] 跑通 focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Futests -Fusrc -Fisrc -FEbin -FUlib tests/test_fpc_runtimeflow.lpr` -> wrong number of parameters for new `ExecuteFPCShowVersionInfoCore` overload
- GREEN: `./bin/test_fpc_runtimeflow` -> `43/43` passed
- `./bin/test_fpc_validator_runtimeflow` -> `12/12` passed
- `./bin/test_fpc_show` -> `5/5` passed
- `./bin/test_fpc_doctor` -> `6/6` passed
- `./bin/test_fpc_verify` -> all tests passed
- `./bin/test_fpc_commands` -> `22/22` passed
- `./bin/test_fpc_update` -> all tests passed
- `./bin/test_fpc_clean` -> all tests passed
- `python3 scripts/update_test_stats.py --count` -> `241`
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `241/241` passed

### Next Candidate Waves
1. `src/fpdev.resource.repo.pas`：继续收 `GetStatus` / commit/query 输出与 git status seam
2. `src/fpdev.cmd.package.pas`：继续收 `InstallFromLocal` / `CreatePackage` / `PublishPackage` 的 facade seam
3. `src/fpdev.build.cache.pas`：评估 index/reporting seam，继续压大单元复杂度

## 2026-03-09 Batch: Resource Repo Status / Commit Query Wave

### Goal
- 将 `src/fpdev.resource.repo.pas` 中 `GetLastCommitHash` / `GetStatus` 的 commit query 与 status 文本拼装逻辑收进 helper，保持 `TResourceRepository` 为 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_resource_repo_statusflow.lpr`
- [x] 新增 helper：`src/fpdev.resource.repo.statusflow.pas`
- [x] `TResourceRepository.GetLastCommitHash` / `GetStatus` 改为 helper delegate
- [x] 通过统计脚本同步 discoverable test count 到 `242`
- [x] 跑通 focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Futests -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_statusflow.lpr` -> `Can't find unit fpdev.resource.repo.statusflow`
- GREEN: `./bin/test_resource_repo_statusflow` -> `10/10` passed
- `./bin/test_resource_repo_lifecycleflow` -> `38/38` passed
- `./bin/test_resource_repo_bootstrap` -> `31/31` passed
- `./bin/test_resource_repo_package` -> `6/6` passed
- `./bin/test_resource_repo_query` -> `8/8` passed
- `python3 scripts/update_test_stats.py --count` -> `242`
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `242/242` passed

### Next Candidate Waves
1. `src/fpdev.cmd.package.pas`：继续收 `InstallFromLocal` / `CreatePackage` / `PublishPackage` 的 facade seam
2. `src/fpdev.build.cache.pas`：评估 index/reporting seam，继续压大单元复杂度
3. `src/fpdev.resource.repo.pas`：继续评估 bootstrap/package query 输出是否还能再薄一层

## 2026-03-09 Batch: Package Facade Install/Create/Publish Wave

### Goal
- 将 `src/fpdev.cmd.package.pas` 中 `InstallFromLocal` / `CreatePackage` / `PublishPackage` 的 facade orchestration 收进 helper，保持 `TPackageManager` 为 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_package_facadeflow.lpr`
- [x] 新增 helper：`src/fpdev.cmd.package.facadeflow.pas`
- [x] `TPackageManager.InstallFromLocal` / `CreatePackage` / `PublishPackage` 改为 helper delegate
- [x] 通过统计脚本同步 discoverable test count 到 `243`
- [x] 跑通 focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Futests -Fusrc -Fisrc -FEbin -FUlib tests/test_package_facadeflow.lpr` -> `Can't find unit fpdev.cmd.package.facadeflow`
- GREEN: `./bin/test_package_facadeflow` -> `25/25` passed
- `./bin/test_package_create` -> `28/28` passed
- `./bin/test_package_publish` -> `26/26` passed
- `./bin/test_package_create_metadata_helper` -> `5/5` passed
- `./bin/test_package_manager_installupdateflow` -> `19/19` passed
- `./bin/test_cli_package` -> `223/223` passed
- `python3 scripts/update_test_stats.py --count` -> `243`
- `python3 scripts/update_test_stats.py --write` -> updated docs/CI counts
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `243/243` passed

### Next Candidate Waves
1. `src/fpdev.build.manager.pas`：继续收 `RunBuildPhases` / phase iteration / short-circuit / phase 日志输出 seam
2. `src/fpdev.build.cache.pas`：评估 index/reporting seam，继续压大单元复杂度
3. `src/fpdev.resource.repo.pas`：继续评估 bootstrap/package query 输出是否还能再薄一层

## 2026-03-09 Batch: Build Manager Makeflow Wave

### Goal
- 将 `src/fpdev.build.manager.pas` 中 `BuildCompiler` / `BuildRTL` / `BuildPackages` / `InstallPackages` / `Install` 的重复 make-step orchestration 收进 helper，保持 `TBuildManager` 为 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_build_makeflow.lpr`
- [x] 新增 helper：`src/fpdev.build.makeflow.pas`
- [x] `TBuildManager` 五个 make-step 方法改为 helper delegate
- [x] 通过统计脚本同步 discoverable test count 到 `244`
- [x] 跑通 focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_makeflow.lpr` -> `Can't find unit fpdev.build.makeflow`
- GREEN: `./bin/test_build_makeflow` -> `21/21` passed
- `./bin/test_build_packages` -> all tests passed (`4/4`)
- `./bin/test_build_testresultsflow` -> `29/29` passed
- `./bin/test_build_manager_make_missing` -> passed
- `./bin/test_full_build` -> all tests passed (`8/8`)
- `python3 scripts/update_test_stats.py --count` -> `244`
- `python3 scripts/update_test_stats.py --write` -> updated docs/CI counts
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `244/244` passed

### Next Candidate Waves
1. `src/fpdev.build.cache.pas`：继续评估 index/reporting seam，沿既有 helper 模式压大单元复杂度
2. `src/fpdev.resource.repo.pas`：继续评估 bootstrap / package query 输出是否还能再薄一层
3. `tests/test_fpc_installer_iobridge.lpr` / `src/fpdev.fpc.installer.iobridge.pas`：排查 legacy HTTP bridge 的偶发波动，补稳定性回归

## 2026-03-10 Batch: Build Cache Indexflow Wave

### Goal
- 将 `src/fpdev.build.cache.pas` 中 `LookupIndexEntry` / `UpdateIndexEntry` / `RemoveIndexEntry` / `RecordAccess` 的 index JSON 映射与 access orchestration 收进 helper，继续压薄 `TBuildCache`。

### Status
- [x] 新增 red test：`tests/test_build_cache_indexflow.lpr`
- [x] 新增 helper：`src/fpdev.build.cache.indexflow.pas`
- [x] `TBuildCache` 四个 index/access 方法改为 helper delegate
- [x] 通过统计脚本同步 discoverable test count 到 `245`
- [x] 跑通 focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_build_cache_indexflow.lpr` -> `Can't find unit fpdev.build.cache.indexflow`
- GREEN: `./bin/test_build_cache_indexflow` -> `25/25` passed
- `./bin/test_cache_index` -> `23/23` passed
- `./bin/test_cache_stats` -> `29/29` passed
- `./bin/test_build_cache_access` -> `15/15` passed
- `./bin/test_build_cache_indexstats` -> `23/23` passed
- `./bin/test_build_cache_indexcollect` -> `4/4` passed
- `python3 scripts/update_test_stats.py --count` -> `245`
- `python3 scripts/update_test_stats.py --write` -> updated docs/CI counts
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `245/245` passed

### Next Candidate Waves
1. `src/fpdev.resource.repo.pas`：继续评估 bootstrap / package query 输出是否还能再薄一层
2. `tests/test_fpc_installer_iobridge.lpr` / `src/fpdev.fpc.installer.iobridge.pas`：排查 legacy HTTP bridge 的偶发波动并补稳定性回归
3. `src/fpdev.build.cache.pas`：继续评估 artifact save/restore seam，收 `SaveArtifacts` / `RestoreArtifacts` 的 tar/verify/orchestration

## 2026-03-10 Batch: Resource Repo BootstrapQuery Wave

### Goal
- 将 `src/fpdev.resource.repo.pas` 中 `HasBootstrapCompiler` / `GetBootstrapInfo` / `GetBootstrapExecutable` 的 bootstrap manifest 查询与 path 拼装收进 helper，保持 `TResourceRepository` 为 thin wrapper。

### Status
- [x] 新增 red test：`tests/test_resource_repo_bootstrapquery.lpr`
- [x] 新增 helper：`src/fpdev.resource.repo.bootstrapquery.pas`
- [x] `TResourceRepository` 三个 bootstrap query 方法改为 helper delegate
- [x] 通过统计脚本同步 discoverable test count 到 `246`
- [x] 跑通 focused / Python full / Pascal full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_resource_repo_bootstrapquery.lpr` -> `Can't find unit fpdev.resource.repo.bootstrapquery`
- GREEN: `./bin/test_resource_repo_bootstrapquery` -> `21/21` passed
- `./bin/test_resource_repo_bootstrap` -> `31/31` passed
- `./bin/test_resource_repo_bootstrapselector` -> `10/10` passed
- `./bin/test_resource_repo_binary` -> `21/21` passed
- `./bin/test_resource_repo_lifecycleflow` -> `38/38` passed
- `./bin/test_resource_repo_statusflow` -> `10/10` passed
- `./bin/test_resource_repo_query` -> `8/8` passed
- `python3 scripts/update_test_stats.py --count` -> `246`
- `python3 scripts/update_test_stats.py --write` -> updated docs/CI counts
- `python3 scripts/update_test_stats.py --check` -> passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `246/246` passed

### Next Candidate Waves
1. `tests/test_fpc_installer_iobridge.lpr` / `src/fpdev.fpc.installer.iobridge.pas`：排查 legacy HTTP bridge 的偶发波动并补稳定性回归
2. `src/fpdev.build.cache.pas`：继续评估 artifact save/restore seam，收 `SaveArtifacts` / `RestoreArtifacts` 的 tar/verify/orchestration
3. `src/fpdev.resource.repo.pas`：继续评估 binary/cross/package install/query 还剩哪些 facade seam 可整体收薄

## 2026-03-10 Batch: Installer IOBridge Stability Wave

### Goal
- 收敛 `src/fpdev.fpc.installer.iobridge.pas` 的 legacy HTTP bridge 偶发空错误 / 0-byte 抖动，补齐 retry、partial cleanup 与本地 server readiness 回归。

### Status
- [x] 在 `tests/test_fpc_installer_iobridge.lpr` 增加 delayed-server red test，稳定复现“server 进程已启动但端口未 ready”场景
- [x] 在 `tests/test_fpc_installer_iobridge.lpr` 增加 failure cleanup red test，锁定失败后 zero-byte temp file 残留
- [x] `src/fpdev.fpc.installer.iobridge.pas` 新增 attempt helper、transient error retry 与 partial temp file cleanup
- [x] `tests/test_fpc_installer_iobridge.lpr` 的本地 HTTP server `Start` 改为 readiness probe，不再只靠固定 `Sleep(400)`
- [x] 跑通 focused repeat / installer neighborhood / Python full / Pascal full suite

### Verification
- RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_fpc_installer_iobridge.lpr && ./bin/test_fpc_installer_iobridge` -> `22 total / 3 failed`（retry-until-ready 与 failure cleanup 红灯）
- GREEN: `./bin/test_fpc_installer_iobridge` -> `22/22` passed
- Repeat: `for i in $(seq 1 20); do ./bin/test_fpc_installer_iobridge; done` -> `20/20` passed
- `./bin/test_fpc_installer_downloadflow` -> `33/33` passed
- `./bin/test_fpc_installer_binaryflow` -> `33/33` passed
- `./bin/test_fpc_installer_archiveflow` -> `20/20` passed
- `./bin/test_fpc_installer_manifestflow` -> `26/26` passed
- `./bin/test_fpc_installer_repoflow` -> `19/19` passed
- `./bin/test_fpc_installer_sourceforgeflow` -> `19/19` passed
- `python3 -m unittest discover -s tests -p 'test_*.py'` -> `80/80` passed
- `bash scripts/run_all_tests.sh` -> `246/246` passed

### Next Candidate Waves
1. `src/fpdev.resource.repo.pas`：继续收 binary/cross/package query/install seam，争取把 query 映射和 install plan 再薄一层
2. `src/fpdev.build.cache.pas`：继续收 `SaveArtifacts` / `RestoreArtifacts` 的 tar/verify/cache-entry orchestration
3. `src/fpdev.cmd.fpc.pas` / `src/fpdev.cmd.lazarus.pas` / `src/fpdev.cmd.cross.pas`：按 namespace runtime / help / dispatch 再切一轮 flow helper
