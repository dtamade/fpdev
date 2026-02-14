# Findings & Decisions

## 2026-02-13 CLI Smoke / Acceptance Gaps

- Root cause: `TCommandRegistry.DispatchPath` rewrote `--help/-h` into positional `help`, breaking leaf commands (e.g. `shell-hook`, `fpc test`, `cross test`, `lazarus run`).
- Fix: only rewrite a trailing help flag when an actual `<prefix> help` command exists; otherwise keep args unchanged so leaf commands can handle `--help` directly.
- Fix: `cross build --dry-run` should be side-effect free and not fail when sources/toolchains are absent.
- Fix: `resolve-version --help` now prints usage (previously printed a version).
- Fix: `fpdev --self-test` implemented (toolchain report + exit code 2 on FAIL).

## 2026-02-13 Real Completion / Acceptance (P0 Blockers)

- `fpdev fpc test` in a clean config (no default toolchain) is now smoke-friendly:
  - Behavior: falls back to validating the system `fpc` in `PATH` (`Testing system FPC...`), exits `0` on success.
  - Rationale: makes `fpdev` CLI usable for first-run smoke; explicit versions still test fpdev-managed toolchains.
- `fpdev project build` could hang when invoking `lazbuild` via `TProcessExecutor.Execute` (pipes + verbose output can deadlock).
  - Fix: `TProjectManager.BuildProject` uses `TProcessExecutor.RunDirect` for `lazbuild/fpc/make` so output streams without pipe buffering deadlocks.
- Offline/deterministic test runs:
  - `TFPCInstallCommand` short-circuits network installs when `FPDEV_SKIP_NETWORK_TESTS=1`, returning `EXIT_IO_ERROR` with a hint.
  - Keeps `scripts/run_all_tests.sh` stable (default `FPDEV_SKIP_NETWORK_TESTS=1`).
- Host toolchain reality (external):
  - `scripts/check_toolchain.sh` now exits `0` when required tools are present and reports cross-only tools as optional by default (use `--strict` / `FPDEV_TOOLCHAIN_STRICT=1` to enforce).
  - Cross-compilation *execution* still depends on external prerequisites (target toolchains + populated FPC sources), but:
    - `fpdev cross list` no longer triggers network manifest loads (no first-run hangs/timeouts).
    - `fpdev cross build` now fails fast with actionable errors when the source tree is missing/incomplete.
    - Build system failures no longer crash the process when `make` is missing (BuildManager catches `EOSError` and sets `GetLastError`).

## Phase 4 自治运行策略 (2026-02-07)

### 目标
- 将“问题修复”从一次性任务转为可连续执行的批次流水线。
- 保持低上下文损耗：每批有输入、有输出、有验收、有下一批。

### 批次定义
| 项目 | 约束 |
|------|------|
| 批次时长 | 60-120 分钟 |
| WIP | 1（同一时间仅 1 个批次 in_progress） |
| 交付物 | 修改文件、验证命令、风险、下一批建议 |
| 里程碑汇报 | 每 5 批或每日一次 |

### 停机闸门（需要人工确认）
- 破坏性操作（删除大范围文件、reset 历史）
- 外部依赖重大变更（工具链版本/新网络依赖）
- 架构级重构（跨多个核心模块）

### 批次优先级策略
1. 先修“可证明安全”的 warning（行为不变）
2. 再做高收益迁移（@deprecated / SHA256）
3. 最后做低风险整理（unused 参数、文档补齐）

### 里程碑度量
| 指标 | 说明 |
|------|------|
| Warning 总量 | 趋势持续下降 |
| Hint 总量 | 不反弹 |
| 测试通过率 | 维持 100%（或明确说明失败原因） |
| 每批吞吐 | 每日 >= 1 批 |

## B001 基线冻结结果 (2026-02-07)

### 验证命令
- `lazbuild -B fpdev.lpi 2>&1 | tee /tmp/fpdev_b001_build.log | rg -n "(Warning|Hint|Error)"`
- `bash scripts/run_all_tests.sh`

### 基线值
| Metric | Value |
|--------|-------|
| Warnings (src) | 19 |
| Hints (src) | 28 |
| Hints (all lines) | 40 |
| Errors (src) | 0 |
| Tests | 94/94 passed |

### 说明
- `Hints (all lines)` 包含 Lazarus/FPC 工具链配置提示。
- 项目治理使用 `src` 范围指标作为后续批次对比基线。

## B002 Warning 分批清单（草案）

### 分批原则
- 先低耦合、后高耦合
- 每批只覆盖一种主要 warning 类型
- 每批完成后必须回归测试

### Warning 池拆分
| Batch | 目标 | 预估 warning 降幅 | 风险 |
|------|------|-------------------|------|
| B003 | `fpdev.source.repo.pas` + `fpdev.git2.pas` 的 GitManager 迁移（低风险调用点优先） | 4-8 | 中 |
| B004 | 剩余 GitManager 迁移 + `fpdev.fpc.source.pas` deprecated 替换 | 4-6 | 中高 |
| B005 | `fpdev.fpc.installer.pas` / `fpdev.cmd.fpc.pas` deprecated API 替换 | 4 | 中 |
| B006 | `fpdev.cross.downloader.pas` 的 `TBaseJSONReader.Create` 迁移 | 1 | 低 |

### B002 交付标准
- 给出每批涉及文件、预期替换点与回归命令
- 标注需要人工确认的高风险替换点

## B003 命令占位实现清零结果 (2026-02-07)

### 已清零项
- `src/fpdev.fpc.installer.pas`：`TFPCInstaller.InstallVersion` 移除 binary mode 的“not implemented”硬失败，统一回退到可执行路径。
- `src/fpdev.package.resolver.pas`：`GenerateLockFile` 移除 `sha256-placeholder`，改为真实 SHA256（文件哈希，失败时回退流哈希）。
- `src/fpdev.cmd.lazarus.pas`：`InstallVersion` 的 binary 分支不再直接失败，改为可运行的 source fallback。
- `src/fpdev.lpr`：补齐 `fpdev.cmd.fpc.verify`、`fpdev.cmd.fpc.autoinstall` 单元引入，确保命令注册生效。
- `src/fpdev.cmd.fpc.autoinstall.pas`：实现标准 `ICommand` 方法（`Name/Aliases/FindSub`）和 `--help`。
- `src/fpdev.cmd.fpc.verify.pas`：补充 `--help` 处理，避免将 `--help` 误当版本参数。

### 命令可达性巡检
| 项目 | 结果 |
|------|------|
| 注册命令总数 | 77 |
| `Unknown command` 失败数 | 0（按命令语义执行 help/--help） |

### 测试验证
- 定向测试：`tests/test_fpc_installer.lpr` PASS
- 定向测试：`tests/test_package_resolver_integration.lpr` PASS
- 全量测试：`scripts/run_all_tests.sh` PASS（94/94）

## B004 GitManager 弃用迁移（低耦合）结果 (2026-02-07)

### 变更
- `src/fpdev.source.repo.pas`：将 `GitManager` 全局弃用调用迁移到 `IGitManager/NewGitManager`。
- `src/fpdev.git2.pas`：`TGit2Manager` 内部不再调用弃用 `GitManager` 函数，改为持有 `TGitManager` 实例。

### 编译/测试结果
| Metric | Before | After |
|--------|--------|-------|
| Warnings (src) | 19 | 7 |
| Tests | 94/94 | 94/94 |

### 剩余 warning（下一批）
- `fpdev.fpc.source.pas`（2）
- `fpdev.cross.downloader.pas`（1）
- `fpdev.fpc.installer.pas`（2）
- `fpdev.cmd.fpc.pas`（2）

## B005 deprecated API 迁移结果 (2026-02-08)

### 变更
- `src/fpdev.fpc.source.pas`：补齐非弃用内部 helper 路径，避免内部再次调用弃用接口。
- `src/fpdev.fpc.installer.pas` / `src/fpdev.cmd.fpc.pas`：迁移到非弃用调用路径并保持行为兼容。
- `src/fpdev.cross.downloader.pas`：迁移 `TBaseJSONReader.Create` 的弃用构造调用。

### 编译/测试结果
| Metric | Before | After |
|--------|--------|-------|
| Warnings (src) | 7 | 0 |
| Warnings (all) | >0 | 0 |
| Hints (src) | 28 | 28 |
| Tests | 94/94 | 94/94 |

### 验证命令
- `lazbuild -B fpdev.lpi`（日志：`/tmp/fpdev_b005_build.log`）
- `grep -c "Warning:" /tmp/fpdev_b005_build.log` => `0`
- `bash scripts/run_all_tests.sh`（日志：`/tmp/fpdev_b005_tests.log`）

## B006 回归验证结果 (2026-02-08)

### 结果
- `bash scripts/run_all_tests.sh`：`Total=94, Passed=94, Failed=0`
- B003-B005 变更链路无回归，当前可进入 B007（Hint 清理）。

## B007 Hint 清理结果 (2026-02-08)

### 变更策略
- 仅做低风险、无行为变化改动：清理 `unused unit` 与参数 no-op 标记。
- 不改命令流程、不改业务分支，仅降低编译噪音，便于后续批次聚焦真实问题。

### 编译/测试结果
| Metric | Before | After |
|--------|--------|-------|
| Warnings (src) | 0 | 0 |
| Hints (src) | 28 | 2 |
| Hints (all) | 40 | 14 |
| Tests | 94/94 | 94/94 |

### 剩余 Hint（B007时点，已在 B011 收敛）
- `src/fpdev.utils.fs.pas`：`StatBuf` 初始化提示（5057，可能是编译器路径分析限制）
- `src/fpdev.lpr`：`fpdev.cmd.lazarus` 仅用于初始化注册，触发未使用单元提示（5023）


## B009 大文件拆分预研结果 (2026-02-08)

### 大文件热区（按行数）
| File | LOC | Functions/Procedures |
|------|-----|----------------------|
| `src/fpdev.cmd.package.pas` | 2497 | 58 |
| `src/fpdev.resource.repo.pas` | 1996 | 42 |
| `src/fpdev.build.cache.pas` | 1955 | 62 |
| `src/fpdev.config.managers.pas` | 1345 | 60 |
| `src/fpdev.fpc.installer.pas` | 1320 | 17 |

### 最小切片方案（先低风险再重构）
- `src/fpdev.cmd.package.pas`：优先按现有区段拆分（semantic/deps/verify/create/validate）为独立单元，先做 helper 提取，不动命令入口。
- `src/fpdev.resource.repo.pas`：按 mirror/cross/package 三块服务化拆分，保留 Facade 兼容层。
- `src/fpdev.build.cache.pas`：按 artifact/binary/index/stats 四块下沉到子模块，先抽纯函数与序列化逻辑。

### 风险评估
- 主要风险：初始化顺序、循环依赖、接口可见性变化。
- 控制策略：每次只切 1 个区段 + 全量回归。

## B010 里程碑报告 (2026-02-08)

### 里程碑区间
- 覆盖批次：`B001` → `B010`
- 目标达成：Phase 4 自治流水线稳定运行，warning/hint 债务基本收敛。

### 指标结果
| Metric | B001 Baseline | Current |
|--------|----------------|---------|
| Warnings (src) | 19 | 0 |
| Hints (src) | 28 | 0 |
| Hints (all) | 40 | 12 |
| Tests | 94/94 | 94/94 |

### 结论
- 编译面已从“问题修复”切换到“结构优化”阶段。
- 下一阶段优先级：大文件可维护性（B012+）。

## B011 剩余 Hint 收敛结果 (2026-02-08)

### 修复项
- `src/fpdev.utils.fs.pas`：将 `StatBuf` 初始化移到 `FpStat` 调用前（`Default(TStat)`），消除局部变量初始化提示。
- `src/fpdev.lpr`：移除未实际使用的 `fpdev.cmd.lazarus` uses 项，保留 `fpdev.cmd.lazarus.root` 与各子命令注册单元。

### 验证结果
- `lazbuild -B fpdev.lpi`（日志：`/tmp/fpdev_b011_build.log`）
  - `Warnings(all)=0`
  - `Hints(all)=12`（仅工具链配置提示）
  - `Warnings/Hints(src)=0`
- `bash scripts/run_all_tests.sh`（日志：`/tmp/fpdev_b011_tests.log`）
  - `Total=94, Passed=94, Failed=0`

## B012 新任务池扫描结果 (2026-02-08)

### 扫描输入
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests docs`
- `python3 scripts/analyze_code_quality.py`

### 发现
- 代码质量脚本识别 3 类低风险项：debug/style/hardcoded。
- TODO 类项主要在文档与 roadmap；代码侧高风险 TODO 已基本清空。
- 结构性机会主要集中在超大文件拆分：`cmd.package`、`resource.repo`、`build.cache`。

### 生成的下一轮批次
1. B013：`fpdev.cmd.package` 第一切片（helper 提取）
2. B014：代码风格与调试输出清理
3. B015：硬编码常量分层与配置化

## B013 拆分试点准备 (2026-02-08)

### 目标文件
- `src/fpdev.cmd.package.pas`（2497 LOC）

### 第一切片候选（按现有区段边界）
- `Semantic Version Functions Implementation`: `1737`–`1968`
- `Dependency Graph Functions`: `1969`–`2154`
- `Package Verification Functions Implementation`: `2155`–`2239`
- `Package Creation Functions Implementation`: `2240`–`2370`
- `Package Validation Functions Implementation`: `2371`–`2497`

### 执行策略
- 第一步仅抽取 `Semantic Version` + `Dependency Graph` 到新 helper 单元。
- 保留 `TPackageManager` 与命令入口在原文件，避免行为变化。
- 每次切片后执行 `lazbuild -B fpdev.lpi` + `bash scripts/run_all_tests.sh`。


## B013 拆分试点结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.semver.pas`，承载 `Parse/Compare/Constraint` 三个语义版本函数实现。
- `src/fpdev.cmd.package.pas` 中语义版本实现改为薄封装（wrapper），接口签名保持不变。
- 修复 `src/fpdev.lpr` 的噪音 diff，仅保留删除 `fpdev.cmd.lazarus` 一行逻辑改动。

### 验证结果
- `lazbuild -B fpdev.lpi`（日志：`/tmp/fpdev_b013b_build.log`）
  - `Warnings(src)=0`
  - `Hints(src)=0`（代码文件级）
- `bash scripts/run_all_tests.sh`（日志：`/tmp/fpdev_b013b_tests.log`）
  - `Total=94, Passed=94, Failed=0`

### 结论
- B013 第一切片（Semantic Version）已完成且无行为回归。
- 下一步可在同一策略下执行 `Dependency Graph` 切片（B016）。

## B014 质量项清理结果 (2026-02-08)

### 变更
- `scripts/analyze_code_quality.py`：
  - 增加 Pascal 注释状态机（`{...}`、`(*...*)`、`//`）以避免将注释/示例代码误报为 debug。
  - 对 `Write/WriteLn` 检测增加限定（忽略对象方法调用与声明行）。
  - 对字符串字面量进行剥离后再匹配，减少示例文本触发误报。

### 验证
- `python3 scripts/analyze_code_quality.py`（日志：`/tmp/fpdev_b014_quality3.log`）
  - 脚本运行正常，仍保留真实可疑项输出。

### 结论
- 已收敛“注释/示例触发 debug 误报”的主要噪音来源。
- 保留对真实 `Write/WriteLn` 可疑调用的检测能力。



## B015 常量治理结果 (2026-02-08)

### 变更
- `src/fpdev.constants.pas`：新增集中常量
  - `FPC_MIRROR_SOURCEFORGE`
  - `FPC_MIRROR_GITHUB_RELEASES`
  - `FPC_MIRROR_GITEE_RELEASES`
  - `UNIX_MAKE_PATH`
  - `PROC_UPTIME_FILE`
  - `PROC_MEMINFO_FILE`
- `src/fpdev.fpc.mirrors.pas`：默认镜像 URL 改为引用常量。
- `src/fpdev.cmd.lazarus.pas`：`3.2.2` 和 `/usr/bin/make` 改为引用常量。
- `src/fpdev.utils.pas`：`/proc/uptime` 与 `/proc/meminfo` 路径改为引用常量。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b015_build.log`）
  - `Warnings(src)=0`
  - `Hints(src)=0`
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b015_tests.log`）
  - `Total=94, Passed=94, Failed=0`

### 结论
- B015 完成：硬编码常量已完成第一轮集中治理且行为不变。


## B016 拆分第二切片结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.depgraph.pas`，承载依赖图构建与拓扑排序实现。
- `src/fpdev.cmd.package.pas` 中 `BuildDependencyGraph` / `TopologicalSortDependencies` 改为 wrapper，外部接口保持不变。
- 继续保持 `TPackageManager` 与命令层逻辑留在原文件，避免行为改动。

### 执行中问题与修复
- 首次替换时误命中 interface 区块，导致替换范围过大。
- 处理：立即回滚目标文件并改为 `implementation` 段后锚点精确替换，再次验证通过。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b016_build.log`）
  - `Warnings(src)=0`
  - `Hints(src)=0`
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b016_tests.log`）
  - `Total=94, Passed=94, Failed=0`

### 结论
- B016 完成：`cmd.package` 第二切片已落地，行为保持稳定。


## B017 自治复盘结果 (2026-02-08)

### 复盘输入
- `python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b017_quality.log`）
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests docs`
- `src/*.pas` 大文件统计（`>=1000 LOC`）

### 当前池状态
- 质量脚本仍为 3 类问题：`debug_code` / `code_style` / `hardcoded_constants`。
- 代码侧 TODO 基本清空，仅剩 `src/fpdev.resource.repo.pas` 一条注释型说明。
- 超大文件热区（Top）：
  - `src/fpdev.cmd.package.pas` (2131)
  - `src/fpdev.resource.repo.pas` (1996)
  - `src/fpdev.build.cache.pas` (1955)

### 决策
- 继续优先拆分 `fpdev.cmd.package`（上下文连续、风险可控）。
- 后续批次按 `Verification -> Creation -> Validation` 顺序继续切片。


## B018 下一轮拆分立项结果 (2026-02-08)

### 立项输入
- 复核 `src/fpdev.cmd.package.pas` 当前切片边界与剩余函数区段。

### 固化的执行边界
- `Package Verification`: `1790`–`1874`
- `Package Creation`: `1875`–`2004`
- `Package Validation`: `2005`–`2130`

### 决策
- B019 执行 `Package Verification` helper 抽离。
- B020/B021 继续按 Creation/Validation 顺序推进。


## B019 第三切片结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.verify.pas`，承载包验证与校验和实现。
- `src/fpdev.cmd.package.pas` 中 `VerifyInstalledPackage` / `VerifyPackageChecksum` 改为 wrapper。
- 包管理器对外接口保持不变，状态值通过 wrapper 映射回原枚举。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b019_build.log`）
  - `Warnings(src)=0`
  - `Hints(src)=0`
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b019_tests.log`）
  - `Total=94, Passed=94, Failed=0`

### 结论
- B019 完成，第三切片稳定通过回归。


## B020 第四切片结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.create.pas`，承载 package creation 相关实现。
- `src/fpdev.cmd.package.pas` 中 creation 相关函数改为 wrapper：
  - `IsBuildArtifact`
  - `CollectPackageSourceFiles`
  - `GeneratePackageMetadataJson`
  - `CreatePackageZipArchive`

### 过程问题与修复
- 首次 helper 使用了不存在的 `GetFileListRecursive`，导致编译失败。
- 修复：回退为原始递归扫描逻辑并保持原行为语义（含扩展名判断）。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b020_build.log`）
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b020_tests.log`）
  - `Total=94, Passed=94, Failed=0`


## B021 第五切片结果 (2026-02-08)

### 本批交付
- 新增 `src/fpdev.cmd.package.validation.pas`，承载 package validation 相关实现。
- `src/fpdev.cmd.package.pas` 中 validation 相关函数改为 wrapper：
  - `ValidatePackageSourcePath`
  - `ValidatePackageMetadata`
  - `CheckPackageRequiredFiles`

### 过程问题与修复
- 初次错误覆盖了已有命令单元 `src/fpdev.cmd.package.validate.pas`，导致 `test_package_validate` 编译失败。
- 修复：恢复原命令单元；新 helper 改用不冲突名称 `fpdev.cmd.package.validation`。

### 验证
- `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b021_build.log`）
- `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b021_tests.log`）
  - `Total=94, Passed=94, Failed=0`


## B022 周期复盘结果 (2026-02-08)

### 指标快照
- `scripts/analyze_code_quality.py`：仍为 `3` 类问题（debug/style/hardcoded），与 B017 持平。
- `src/fpdev.cmd.package.pas` 行数：`2131 -> 1874`（核心实现持续外移）。
- 新增 helper 单元：`semver/depgraph/verify/create/validation` 共 5 个。

### 结果
- 连续批次 B015-B021 完成，编译与全测维持稳定（`94/94`）。
- 下一阶段进入横向拆分立项：`resource.repo` 与 `build.cache`。

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

#### Batch B023: 横向拆分立项（完成）
- **Status:** complete
- **Goal:** 为 `src/fpdev.resource.repo.pas` / `src/fpdev.build.cache.pas` 生成低风险切片顺序
- **Actions:**
  - 基于函数簇与依赖关系完成横向切片边界划分
  - 明确首切片选择：`resource.repo` 的 bootstrap 映射/解析簇（低耦合）
- **Slice Plan (resource.repo):**
  - R1 `GetRequiredBootstrapVersion` + `GetBootstrapVersionFromMakefile` + `ListBootstrapVersions`（~655-844）
  - R2 镜像策略簇：`DetectUserRegion`/`TestMirrorLatency`/`SelectBestMirror`/`GetMirrors`（~1271-1525）
  - R3 包查询簇：`HasPackage`/`GetPackageInfo`/`ListPackages`/`SearchPackages`（~1718-1940）
- **Slice Plan (build.cache):**
  - C1 平台/键值/路径 helper：`GetCurrentCPU`/`GetCurrentOS`/`GetArtifactKey`/`GetArtifact*Path`（~261-346）
  - C2 条目元数据簇：`LoadEntries`/`SaveEntries`/`FindEntry`/`UpdateCache`（~375-547）
  - C3 工件缓存簇：`Has/Save/Restore/Delete/GetArtifactInfo/ListCachedVersions`（~555-768）
  - C4 二进制缓存+校验簇：`SaveBinaryArtifact`/`RestoreBinaryArtifact`/`VerifyArtifact`（~818-1174）
  - C5 JSON 元数据与索引簇：`Save/LoadMetadataJSON` + `Load/Save/RebuildIndex` + stats（~1351-1927）
- **Risk Controls:**
  - 保持 public API 与调用点不变，仅 implementation 改 wrapper
  - 先抽离纯函数/弱状态逻辑，避免首批触及 I/O 密集路径

#### Batch B024: resource.repo 第一切片（完成）
- **Status:** complete
- **Goal:** 抽离 bootstrap 映射/Makefile 解析 helper，保持行为与接口稳定
- **Actions:**
  - 新增 `src/fpdev.resource.repo.bootstrap.pas`
  - 抽离函数：
    - `ResourceRepoGetRequiredBootstrapVersion`
    - `ResourceRepoGetBootstrapVersionFromMakefile`
    - `ResourceRepoListBootstrapVersions`
  - `src/fpdev.resource.repo.pas` 中对应方法改为 wrapper（保留原日志语义与回退路径）
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b024_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b024_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 行为保持不变，完成 resource 首切片落地

#### Next Auto Batches
1. B025 build.cache 第一切片执行（C1 平台/键值 helper）
2. B026 周期复盘（B023-B025 收口）
3. B027 resource.repo 第二切片（镜像策略簇）

#### Batch B025: build.cache 第一切片（完成）
- **Status:** complete
- **Goal:** 抽离 `build.cache` 的平台/键值纯函数，降低核心类体积与耦合
- **Actions:**
  - 新增 `src/fpdev.build.cache.key.pas`
  - 抽离函数：
    - `BuildCacheGetCurrentCPU`
    - `BuildCacheGetCurrentOS`
    - `BuildCacheGetArtifactKey`
  - `src/fpdev.build.cache.pas` 中对应私有方法改为 wrapper：
    - `GetCurrentCPU`
    - `GetCurrentOS`
    - `GetArtifactKey`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b025_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b025_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 行为稳定，完成 build.cache 首切片

#### Next Auto Batches
1. B026 周期复盘（B023-B025 收口）
2. B027 resource.repo 第二切片（镜像策略簇）
3. B028 build.cache 第二切片（entries/index 边界优化）

#### Batch B026: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B023-B025 连续批次结果，确认稳定性并刷新任务池
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b026_quality.log`, exit=3）
  - 结构统计：`wc -l src/fpdev.resource.repo.pas src/fpdev.build.cache.pas`
    - `resource.repo: 1996 -> 1857`
    - `build.cache: 1955 -> 1923`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b025_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b025_tests.log`）
- **Result:**
  - 连续三批（B023-B025）均保持 `Build=0` 且 `Tests=94/94`
  - 大文件持续收敛，切片策略有效
  - 新任务池继续聚焦：镜像策略簇与 cache entries/index 簇

#### Next Auto Batches
1. B027 resource.repo 第二切片（镜像策略簇）
2. B028 build.cache 第二切片（entries/index 簇）
3. B029 周期复盘（B027-B028 收口）

#### Batch B027: resource.repo 第二切片（完成）
- **Status:** complete
- **Goal:** 抽离镜像区域探测与延迟测试逻辑，降低 `resource.repo` 复杂度
- **Actions:**
  - 新增 `src/fpdev.resource.repo.mirror.pas`
  - 抽离函数：
    - `ResourceRepoDetectUserRegion`
    - `ResourceRepoTestMirrorLatency`
  - `src/fpdev.resource.repo.pas` 改为 wrapper：
    - `DetectUserRegion`
    - `TestMirrorLatency`
  - implementation uses 增加 `fpdev.resource.repo.mirror`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b027_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b027_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 镜像策略簇切片推进完成（step-1）

#### Next Auto Batches
1. B028 build.cache 第二切片（entries/index helper）
2. B029 周期复盘（B027-B028 收口）
3. B030 resource.repo 第三切片（GetMirrors/SelectBestMirror 候选抽离）

#### Batch B028: build.cache 第二切片（完成）
- **Status:** complete
- **Goal:** 抽离 entries 基础函数，继续收敛 `TBuildCache` 方法体
- **Actions:**
  - 新增 `src/fpdev.build.cache.entries.pas`
  - 抽离函数：
    - `BuildCacheGetCacheFilePath`
    - `BuildCacheGetEntryCount`
    - `BuildCacheFindEntry`
  - `src/fpdev.build.cache.pas` 中对应方法改 wrapper：
    - `GetCacheFilePath`
    - `GetEntryCount`
    - `FindEntry`
  - implementation uses 增加 `fpdev.build.cache.entries`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b028_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b028_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - entries/index 路线切片完成首段落地

#### Next Auto Batches
1. B029 周期复盘（B027-B028 收口）
2. B030 resource.repo 第三切片（SelectBestMirror/GetMirrors 候选抽离）
3. B031 build.cache 第三切片（index JSON 读写 helper）

#### Batch B029: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B027-B028，并确认快速冲刺策略稳定性
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b029_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1857 -> 1774`
    - `build.cache: 1923 -> 1919`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b028_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b028_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` + `Tests=94/94`
  - 快速冲刺节奏有效，可继续按 helper + wrapper 路线推进

#### Next Auto Batches
1. B030 resource.repo 第三切片（GetMirrors/SelectBestMirror 候选抽离）
2. B031 build.cache 第三切片（index JSON 读写 helper）
3. B032 周期复盘（B030-B031 收口）

#### Batch B030: resource.repo 第三切片（完成）
- **Status:** complete
- **Goal:** 抽离 `SelectBestMirror` 的候选镜像构建逻辑，继续收敛镜像策略簇
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增 `ResourceRepoBuildCandidateMirrors`
  - `src/fpdev.resource.repo.pas`
    - `SelectBestMirror` 候选镜像收集段改为 helper 调用
    - 保留缓存 TTL、延迟测速、错误回退与缓存写回逻辑
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b030_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b030_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 镜像主流程切片推进完成（候选构建段）

#### Next Auto Batches
1. B031 build.cache 第三切片（index JSON 读写 helper）
2. B032 周期复盘（B030-B031 收口）
3. B033 resource.repo 第四切片（GetMirrors 解析 helper）

#### Batch B031: build.cache 第三切片（完成）
- **Status:** complete
- **Goal:** 抽离 index JSON 读写公共逻辑，降低 `LookupIndexEntry/UpdateIndexEntry` 复杂度
- **Actions:**
  - 新增 `src/fpdev.build.cache.indexjson.pas`
    - `BuildCacheParseIndexEntryJSON`
    - `BuildCacheBuildIndexEntryJSON`
    - `BuildCacheNormalizeIndexDate`
  - `src/fpdev.build.cache.pas`
    - `LookupIndexEntry` 改为复用 helper 解析与日期标准化
    - `UpdateIndexEntry` 改为复用 helper 序列化
    - implementation uses 增加 `fpdev.build.cache.indexjson`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b031_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b031_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - index JSON 切片完成，行为稳定

#### Next Auto Batches
1. B032 周期复盘（B030-B031 收口）
2. B033 resource.repo 第四切片（GetMirrors 解析 helper）
3. B034 build.cache 第四切片（Load/SaveIndex I/O helper）

#### Batch B032: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B030-B031 并确认快速冲刺延续稳定
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b032_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1774 -> 1726`
    - `build.cache: 1904`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b031_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b031_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 冲刺策略可继续，进入 `B033`

#### Next Auto Batches
1. B033 resource.repo 第四切片（GetMirrors 解析 helper）
2. B034 build.cache 第四切片（Load/SaveIndex I/O helper）
3. B035 周期复盘（B033-B034 收口）

#### Batch B033: resource.repo 第四切片（完成）
- **Status:** complete
- **Goal:** 抽离 `GetMirrors` 的 manifest 解析逻辑
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增 `TResourceRepoMirrorInfo` / `TResourceRepoMirrorInfoArray`
    - 新增 `ResourceRepoGetMirrorsFromManifest`
  - `src/fpdev.resource.repo.pas`
    - `GetMirrors` 改为 helper 解析 + 类型映射 wrapper
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b033_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b033_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 镜像策略簇切片继续收敛

#### Next Auto Batches
1. B034 build.cache 第四切片（Load/SaveIndex I/O helper）
2. B035 周期复盘（B033-B034 收口）
3. B036 resource.repo 第五切片（SelectBestMirror 主流程 helper）

#### Batch B034: build.cache 第四切片（完成）
- **Status:** complete
- **Goal:** 抽离 `LoadIndex/SaveIndex` 的索引 I/O 逻辑
- **Actions:**
  - 新增 `src/fpdev.build.cache.indexio.pas`
    - `BuildCacheLoadIndexEntries`
    - `BuildCacheSaveIndexEntries`
  - `src/fpdev.build.cache.pas`
    - `LoadIndex` 改为调用 `BuildCacheLoadIndexEntries`
    - `SaveIndex` 改为调用 `BuildCacheSaveIndexEntries`
    - implementation uses 增加 `fpdev.build.cache.indexio`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b034_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b034_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - index I/O 切片完成，行为稳定

#### Next Auto Batches
1. B035 周期复盘（B033-B034 收口）
2. B036 resource.repo 第五切片（SelectBestMirror 主流程 helper）
3. B037 build.cache 第五切片（RebuildIndex 扫描 helper）

#### Batch B035: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B033-B034 并刷新后续冲刺入口
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b035_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1726 -> 1718`
    - `build.cache: 1904 -> 1820`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b034_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b034_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 快速冲刺继续推进到 B036

#### Next Auto Batches
1. B036 resource.repo 第五切片（SelectBestMirror 主流程 helper）
2. B037 build.cache 第五切片（RebuildIndex 扫描 helper）
3. B038 周期复盘（B036-B037 收口）

#### Batch B036: resource.repo 第五切片（完成）
- **Status:** complete
- **Goal:** 抽离 `SelectBestMirror` 中“测速择优”主流程逻辑
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增类型：
      - `TResourceRepoMirrorLatencyArray`
      - `TResourceRepoMirrorLatencyTestFunc`
    - 新增函数：`ResourceRepoSelectBestMirrorFromCandidates`
  - `src/fpdev.resource.repo.pas`
    - `SelectBestMirror` 改为调用 `ResourceRepoSelectBestMirrorFromCandidates`
    - 保留缓存 TTL、错误回退、镜像延迟记录写回行为
  - 修复一次 managed-type hint：显式初始化 `ALatencies := nil`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b036_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b036_tests.log`）
- **Result:**
  - Build: `exit=0`（`4 hints`，恢复到切片前水平）
  - Tests: `94/94 passed`
  - SelectBestMirror 主流程进一步瘦身，行为保持稳定

#### Next Auto Batches
1. B037 build.cache 第五切片（RebuildIndex 扫描 helper）
2. B038 周期复盘（B036-B037 收口）
3. B039 resource.repo 第六切片（mirror cache TTL helper）

#### Batch B037: build.cache 第五切片（完成）
- **Status:** complete
- **Goal:** 抽离 `RebuildIndex` 的 metadata 文件扫描/版本提取逻辑
- **Actions:**
  - 新增 `src/fpdev.build.cache.rebuildscan.pas`
    - `BuildCacheExtractVersionFromMetadataFilename`
    - `BuildCacheListMetadataVersions`
  - `src/fpdev.build.cache.pas`
    - `RebuildIndex` 改为使用 `BuildCacheListMetadataVersions`
    - implementation uses 增加 `fpdev.build.cache.rebuildscan`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b037_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b037_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - RebuildIndex 扫描流程切片完成，行为稳定

#### Next Auto Batches
1. B038 周期复盘（B036-B037 收口）
2. B039 resource.repo 第六切片（mirror cache TTL helper）
3. B040 build.cache 第六切片（index stats helper）

#### Batch B038: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B036-B037 并刷新冲刺入口
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b038_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1718 -> 1721`（函数抽离+类型映射后的微小波动）
    - `build.cache: 1820 -> 1802`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b037_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b037_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 冲刺可继续推进 B039/B040

#### Next Auto Batches
1. B039 resource.repo 第六切片（mirror cache TTL helper）
2. B040 build.cache 第六切片（index stats helper）
3. B041 周期复盘（B039-B040 收口）

#### Batch B039: resource.repo 第六切片（完成）
- **Status:** complete
- **Goal:** 抽离镜像缓存 TTL 命中判断逻辑
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增 `ResourceRepoTryGetCachedMirror`
  - `src/fpdev.resource.repo.pas`
    - `SelectBestMirror` 的缓存判断改为 helper 调用
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b039_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b039_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 缓存 TTL 逻辑完成切片，行为保持稳定

#### Next Auto Batches
1. B040 build.cache 第六切片（index stats helper）
2. B041 周期复盘（B039-B040 收口）
3. B042 resource.repo 第七切片（mirror cache set helper）

#### Batch B040: build.cache 第六切片（完成）
- **Status:** complete
- **Goal:** 抽离 `GetIndexStatistics` 的统计累计逻辑到独立 helper
- **Actions:**
  - 新增 `src/fpdev.build.cache.indexstats.pas`
    - `BuildCacheIndexStatsInit`
    - `BuildCacheIndexStatsAccumulate`
    - `BuildCacheIndexStatsFinalize`
  - `src/fpdev.build.cache.pas`
    - `GetIndexStatistics` 改为 helper 驱动，保留原有字段语义
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b040_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b040_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 统计逻辑完成切片，行为保持稳定

#### Next Auto Batches
1. B041 周期复盘（B039-B040 收口）
2. B042 resource.repo 第七切片（mirror cache set helper）
3. B043 build.cache 第七切片（index lookup helper）

#### Batch B041: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B039-B040 并刷新下一轮冲刺入口
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b041_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1721 -> 1716`
    - `build.cache: 1802 -> 1786`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b040_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b040_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 质量扫描为存量项（exit=3）且无新增高风险
  - 进入 B042/B043 横向拆分

#### Next Auto Batches
1. B042 resource.repo 第七切片（mirror cache set helper）
2. B043 build.cache 第七切片（index lookup helper）
3. B044 周期复盘（B042-B043 收口）

#### Batch B042: resource.repo 第七切片（完成）
- **Status:** complete
- **Goal:** 抽离 `SelectBestMirror` 的镜像缓存写入逻辑为 helper
- **Actions:**
  - `src/fpdev.resource.repo.mirror.pas`
    - 新增 `ResourceRepoSetCachedMirror`
  - `src/fpdev.resource.repo.pas`
    - `SelectBestMirror` 内缓存写入改为 `ResourceRepoSetCachedMirror(...)`
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b042_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b042_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 缓存写入逻辑切片完成，镜像选择语义保持不变

#### Next Auto Batches
1. B043 build.cache 第七切片（index lookup helper）
2. B044 周期复盘（B042-B043 收口）
3. B045 resource.repo 第八切片（package query helper）

#### Batch B043: build.cache 第七切片（完成）
- **Status:** complete
- **Goal:** 抽离 `LookupIndexEntry` 的索引读取/日期归一化 helper
- **Actions:**
  - `src/fpdev.build.cache.indexjson.pas`
    - 新增 `BuildCacheGetIndexEntryJSON`
    - 新增 `BuildCacheGetNormalizedIndexDates`
  - `src/fpdev.build.cache.pas`
    - `LookupIndexEntry` 改为调用上述 helper
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b043_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b043_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - 索引查找逻辑进一步收敛，行为保持稳定

#### Next Auto Batches
1. B044 周期复盘（B042-B043 收口）
2. B045 resource.repo 第八切片（package query helper）
3. B046 build.cache 第八切片（stats report helper）

#### Batch B044: 周期复盘（完成）
- **Status:** complete
- **Goal:** 收口 B042-B043 并刷新后续冲刺队列
- **Evidence:**
  - 质量扫描：`python3 scripts/analyze_code_quality.py`（`/tmp/fpdev_b044_quality.log`, exit=3）
  - 结构统计：
    - `resource.repo: 1716 -> 1715`
    - `build.cache: 1786 -> 1782`
  - 验证基线：
    - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b043_build.log`）
    - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b043_tests.log`）
- **Result:**
  - 连续批次保持 `Build=0` 与 `Tests=94/94`
  - 质量扫描仍为存量项（exit=3），无新增高风险

#### Next Auto Batches
1. B045 resource.repo 第八切片（package query helper）
2. B046 build.cache 第八切片（stats report helper）
3. B047 周期复盘（B045-B046 收口）

#### Batch B045: resource.repo 第八切片（完成）
- **Status:** complete
- **Goal:** 抽离 package metadata 路径解析 helper，收敛 `GetPackageInfo` 文件定位逻辑
- **Actions:**
  - 新增 `src/fpdev.resource.repo.package.pas`
    - `ResourceRepoResolvePackageMetaPath`
  - `src/fpdev.resource.repo.pas`
    - implementation uses 增加 `fpdev.resource.repo.package`
    - `GetPackageInfo` 元数据路径解析改为 helper 调用
- **Verification:**
  - `lazbuild -B fpdev.lpi`（`/tmp/fpdev_b045_build.log`）
  - `bash scripts/run_all_tests.sh`（`/tmp/fpdev_b045_tests.log`）
- **Result:**
  - Build: `exit=0`
  - Tests: `94/94 passed`
  - package query 路径解析切片完成，行为保持稳定

#### Next Auto Batches
1. B046 build.cache 第八切片（stats report helper）
2. B047 周期复盘（B045-B046 收口）
3. B048 resource.repo 第九切片（search filter helper）

## Session 2026-02-12: 全仓未完成项/缺口扫描（writing-plans 输入）

### 扫描范围与命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests scripts docs`
- `python3 scripts/analyze_code_quality.py`
- `rg -n "not yet implemented|not implemented" src`
- `rg -n "fpdev.registry.client|fpdev.github.api|fpdev.gitlab.api|TRemoteRegistryClient|TGitHubClient|TGitLabClient" tests`

### 关键发现
1. `src/` 内与“未实现”直接相关的命中共 15 处，集中在 3 个网络客户端：
   - `src/fpdev.registry.client.pas`（POST/PUT 未实现）
   - `src/fpdev.github.api.pas`（POST/PUT/DELETE 与 create/upload/delete API 未实现）
   - `src/fpdev.gitlab.api.pas`（POST/PUT/DELETE 与 create/upload/delete API 未实现）
2. 针对上述 3 个单元，`tests/` 内当前没有直接覆盖（`rg` 命中为空）。
3. `python3 scripts/analyze_code_quality.py` 报告 3 类问题：debug_code(1)、code_style(1)、hardcoded_constants(1)，其中 `src/fpdev.fpc.binary.pas` 的直接 `WriteLn` 属可改进项，但优先级低于功能未实现路径。

### 优先级判断（用于执行计划）
- P0: 先补 `TRemoteRegistryClient` 的 POST/PUT/DELETE 请求通路，并以离线可复现测试验证“不再返回 not yet implemented”。
- P1: 为 `TGitHubClient`/`TGitLabClient` 做同类 HTTP 方法能力补全。
- P2: 清理 quality 脚本指示的 debug/style/hardcoded 低风险项。

## Session 2026-02-12: P0 执行结果（remote registry HTTP methods）

### Root Cause
`TRemoteRegistryClient.ExecuteWithRetry` 仅实现 GET；POST/PUT 直接返回硬编码错误，导致 `UploadPackage/PublishMetadata` 永远失败。

### Fix
在 `src/fpdev.registry.client.pas` 中将 POST/PUT 由占位分支改为真实 HTTP 调用：
- `FHTTPClient.RequestBody := ABody`
- `FHTTPClient.HTTPMethod(AMethod, AURL, AResponse, [200,201,202,204])`
- 调用后清空 `RequestBody`
- 同时新增 DELETE 分支（`HTTPMethod('DELETE', ...)`）

### Tests Added
- `tests/test_registry_client_remote.lpr`
  - 验证 `PublishMetadata` / `UploadPackage` 走真实请求路径（不可达地址时失败，但错误不应再是 `not yet implemented`）

### Verification
- 新增测试：RED 失败 -> GREEN 通过
- 目标回归：`test_package_registry` 35/35，`test_package_publish` 26/26
- 全量回归：`scripts/run_all_tests.sh` => `174/174` 通过

## Session 2026-02-12: Team T1 结果（GitHub API 非 GET）

### 缺口
`fpdev.github.api` 的 `ExecuteRequest` 仅实现 GET，Create/Release/Asset 操作使用硬编码 `not yet implemented`。

### 修复
- 在 `ExecuteRequest` 中实现 POST/PUT (`RequestBody + HTTPMethod`) 与 DELETE (`HTTPMethod('DELETE')`)。
- `CreateRepository` / `CreateRelease`：构建 JSON body 发起 POST，并解析 JSON object 响应。
- `UploadReleaseAsset`：读取文件并 POST 上传；文件不存在时返回明确错误。
- `DeleteReleaseAsset`：发起 DELETE 请求。

### 证据
- RED: 新测试 `tests/test_github_api_remote.lpr` 初次运行 `Failed: 4`。
- GREEN: 同测试修复后 `Passed: 8, Failed: 0`。
- 全量回归: `scripts/run_all_tests.sh` -> `175/175` 通过。

## Session 2026-02-12: Team T2 结果（GitLab API 非 GET）

### 缺口
`fpdev.gitlab.api` 的 `ExecuteRequest` 仅实现 GET，Create/Package/Release 的写操作路径使用硬编码 `not yet implemented`。

### 修复
- 在 `ExecuteRequest` 中实现 POST/PUT (`RequestBody + HTTPMethod`) 与 DELETE (`HTTPMethod('DELETE')`)。
- `CreateProject`：JSON body 发起 POST 并解析 JSON object 响应。
- `UploadPackage`：读取文件并 POST 上传；文件不存在时返回明确错误。
- `DeletePackage`：发起 DELETE 请求。
- `CreateRelease`：JSON body 发起 POST 并解析 JSON object 响应。

### 证据
- RED: 新测试 `tests/test_gitlab_api_remote.lpr` 初次运行 `Failed: 4`。
- GREEN: 同测试修复后 `Passed: 8, Failed: 0`。
- 全量回归: `scripts/run_all_tests.sh` -> `176/176` 通过。

## Session 2026-02-12 (Round 2): 全仓扫描结果与优先级

### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

### 结果摘要
1. 功能未实现类缺口已显著收敛；`src/` 中仅剩注释/提示类 `not implemented` 文案与平台保留分支。
2. 当前最可执行的真实缺口转为质量扫描噪音：`analyze_code_quality.py` 将以下场景误判为 debug：
   - `fpdev.output.console.pas` 中的输出封装方法
   - `Write(Source, ...)` 这种文件写入操作
3. `analyze_code_quality.py` 当前输出 `总问题数: 3`，其中 `debug_code` 包含明显误报，影响后续治理优先级判断。

### 本轮优先级
- P0: 修复 `analyze_code_quality.py` 的 debug 误报（先测试后修复）。
- P1: 处理 code_style 项（长行/行尾空格）按风险分批。
- P2: 硬编码常量治理（路径/版本字面量分类提取）。

## Session 2026-02-12 Round 2: P0 执行结果（质量扫描器误报治理）

### Root Cause
`analyze_temp_files_and_debug_code()` 使用通用 `write/writeln` 模式扫描，未区分以下非调试场景：
1. `fpdev.output.console.pas` 的输出封装方法
2. `Write(Source, ...)`/`WriteLn(Source, ...)` 的文件句柄写入

### Fix
- 新增回归测试 `tests/test_analyze_code_quality.py` 覆盖上述两类误报 + 一个真实 debug 命中样例。
- 在 `scripts/analyze_code_quality.py` 中加入最小规则修正：
  - `fpdev.output.console.pas` 不作为 debug 输出候选
  - `write(?:ln)?(<identifier>, ...)` 视为文件句柄写入，不计入 debug

### Evidence
- RED: `python3 -m unittest tests/test_analyze_code_quality.py -v` -> `FAILED (failures=2)`
- GREEN: 同命令 -> `OK`
- VERIFY: `python3 scripts/analyze_code_quality.py` 误报样例消失
- VERIFY: `bash scripts/run_all_tests.sh` -> `176/176` 通过

## Session 2026-02-12 Round 3: Style Batch 1 完成 + 新优先级计划

### 全仓扫描（本轮）

#### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

#### 关键发现
1. 功能性 `not yet implemented` 主路径已收敛，当前 `src/` 命中以注释/提示或平台保留说明为主。
2. 质量脚本仍报告 `3` 类问题，但 style 目标文件已从报告中消失：
   - `src/fpdev.package.lockfile.pas`
   - `src/fpdev.cmd.package.repo.list.pas`
3. 当前最具性价比的下一批缺口是剩余 code_style 项：
   - `src/fpdev.cmd.lazarus.pas`（5 处超长行）
   - `src/fpdev.cmd.params.pas`（行尾空格）
   - `src/fpdev.cross.cache.pas`（多处行尾空格）

### 可执行优先级计划（下一批建议）
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 2（长行 + 行尾空格） | `src/fpdev.cmd.lazarus.pas`, `src/fpdev.cmd.params.pas`, `src/fpdev.cross.cache.pas` | 新增 Python 风格回归测试 RED->GREEN，且 analyzer 的 style 项减少 |
| P2 | Debug 输出分类治理（真实调试 vs 用户可见输出） | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 约定输出策略后减少 debug_code 噪音，不影响 CLI 可见行为 |
| P3 | 硬编码常量分层 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 将路径/版本字面量分类为常量或保留项并补充注释 |

### 本轮执行结论
- Style Batch 1 已按 TDD 完成（RED->GREEN->VERIFY）。
- 验证通过：`run_all_tests.sh` 全量 `176/176`。

## Session 2026-02-12 Round 4: Batch 2 执行完成 + 优先级更新

### 全仓扫描（本轮）

#### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

#### 关键发现
1. `src/tests` 中“未实现”命中主要为注释、i18n 文案或测试断言文本，不是新功能缺口。
2. 当前最优先缺口仍为代码风格治理，但 Batch 2 的三个目标文件已清理完成。
3. `code_style` 现存文件为：
   - `src/fpdev.build.interfaces.pas`（行尾空格）
   - `src/fpdev.collections.pas`（长行）
   - `src/fpdev.cmd.project.template.remove.pas`（长行）

### 本轮执行（严格 TDD）
- RED: `python3 -m unittest tests/test_style_regressions_batch2.py -v` -> `FAILED (failures=3)`
- GREEN: 最小格式修复后同命令 -> `OK`
- VERIFY:
  - `python3 scripts/analyze_code_quality.py` -> `总问题数: 3`（style 已切换到下一批文件）
  - `bash scripts/run_all_tests.sh` -> `176/176` 通过

### 可执行优先级计划（更新）
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 3 | `src/fpdev.build.interfaces.pas`, `src/fpdev.collections.pas`, `src/fpdev.cmd.project.template.remove.pas` | 新增回归测试 RED->GREEN，analyzer style 项继续下降 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音且不改变用户可见输出语义 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

## Session 2026-02-12 Round 5: Batch 3 执行完成 + 优先级更新

### 全仓扫描（本轮）

#### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

#### 关键发现
1. 功能未实现类命中仍以注释、文案和测试断言文本为主。
2. Batch 3 目标 style 文件清理后，style 报告已切换到新一批文件：
   - `src/fpdev.cmd.project.template.update.pas`
   - `src/fpdev.source.pas`
   - `src/fpdev.fpc.verify.pas`
3. debug_code 与 hardcoded_constants 仍为稳定存量，尚未进入本批次。

### 本轮执行（严格 TDD）
- RED: `python3 -m unittest tests/test_style_regressions_batch3.py -v` -> `FAILED (failures=3)`
- GREEN: 最小格式修复后同命令 -> `OK`
- VERIFY:
  - `python3 scripts/analyze_code_quality.py` -> `总问题数: 3`（style 已切换到下一批文件）
  - `bash scripts/run_all_tests.sh` -> `176/176` 通过

### 可执行优先级计划（更新）
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 4 | `src/fpdev.cmd.project.template.update.pas`, `src/fpdev.source.pas`, `src/fpdev.fpc.verify.pas` | 新增回归测试 RED->GREEN，analyzer style 项继续下降 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出与用户提示输出，降低 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

## Session 2026-02-12 Round 6: Batch 4 执行完成 + 优先级更新

### 全仓扫描（本轮）

#### 扫描命令
- `rg -n "TODO|FIXME|HACK|XXX|TBD" src tests scripts docs --glob '!docs/archive/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests`
- `python3 scripts/analyze_code_quality.py`

#### 关键发现
1. 功能未实现类命中仍以注释、文案和测试断言文本为主。
2. Batch 4 目标 style 文件清理后，style 报告已切换到新一批文件：
   - `src/fpdev.cmd.package.pas`
   - `src/fpdev.config.interfaces.pas`
   - `src/fpdev.toml.parser.pas`
3. debug_code 与 hardcoded_constants 仍是稳定存量问题组。

### 本轮执行（严格 TDD）
- RED: `python3 -m unittest tests/test_style_regressions_batch4.py -v` -> `FAILED (failures=4)`
- GREEN: 最小格式修复后同命令 -> `OK`
- VERIFY:
  - `python3 scripts/analyze_code_quality.py` -> `总问题数: 3`（style 已切换到下一批文件）
  - `bash scripts/run_all_tests.sh` -> `176/176` 通过

### 可执行优先级计划（更新）
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 5 | `src/fpdev.cmd.package.pas`, `src/fpdev.config.interfaces.pas`, `src/fpdev.toml.parser.pas` | 新增回归测试 RED->GREEN，analyzer style 项继续下降 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出与用户提示输出，降低 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量分类抽离完成并保持回归通过 |

## Session 2026-02-12 Round 7: 全仓扫描结果与缺口

### 扫描命令
- `python3 scripts/analyze_code_quality.py`
- `rg -n "TODO|FIXME|XXX|TBD|HACK|WIP|未完成|待实现|待办" src tests scripts docs --glob '!**/__pycache__/**'`
- `rg -n "NotImplemented|raise Exception|assert\\(False\\)|fail\\(" src tests --glob '!**/__pycache__/**'`

### 结果摘要
1. 当前质量脚本输出仍为 `总问题数: 3`（`debug_code=1`, `code_style=1`, `hardcoded_constants=1`）。
2. `code_style` 明确命中 Batch 5 三文件：
   - `src/fpdev.cmd.package.pas`（5 处长行）
   - `src/fpdev.config.interfaces.pas`（5 处行尾空格）
   - `src/fpdev.toml.parser.pas`（5 处行尾空格）
3. `debug_code` 与 `hardcoded_constants` 仍是稳定存量组，适合作为 Batch 5 后的下一阶段任务。
4. TODO/FIXME 全仓命中以脚本文案、历史文档、归档记录为主，未发现新的高优先级“功能未实现”阻塞项。

### 本轮可执行优先级计划
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 5 | `src/fpdev.cmd.package.pas`, `src/fpdev.config.interfaces.pas`, `src/fpdev.toml.parser.pas` | 新增测试 RED->GREEN 且 style 从这三文件迁移 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出和用户输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量抽离并保持行为不变 |

## Session 2026-02-12 Round 7: Batch 5 执行结果（严格 TDD）

### RED
- 命令: `python3 -m unittest tests/test_style_regressions_batch5.py -v`
- 输出要点:
  - `FAILED (failures=3)`
  - `src/fpdev.cmd.package.pas` 超长行: 6 处（含 line 1802）
  - `src/fpdev.config.interfaces.pas` 行尾空白: 7 处
  - `src/fpdev.toml.parser.pas` 行尾空白: 29 处

### GREEN
- 修改:
  - `src/fpdev.cmd.package.pas`: 6 处长行换行（接口声明/函数签名/路径拼接）
  - `src/fpdev.config.interfaces.pas`: 清理行尾空白
  - `src/fpdev.toml.parser.pas`: 清理行尾空白
- 命令: `python3 -m unittest tests/test_style_regressions_batch5.py -v`
- 输出: `Ran 3 tests in 0.001s` + `OK`

### VERIFY
- 命令: `python3 scripts/analyze_code_quality.py`
- 输出摘要:
  - `总问题数: 3`
  - `debug_code: 1`, `code_style: 1`, `hardcoded_constants: 1`
  - style 已切换到下一批文件：
    - `src/fpdev.cmd.fpc.pas`
    - `src/fpdev.cmd.package.repo.update.pas`
    - `src/fpdev.toolchain.pas`
- 命令: `bash scripts/run_all_tests.sh`
- 输出摘要: `Total 176 / Passed 176 / Failed 0 / Skipped 0`

### 下一批可执行优先级
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 6 | `src/fpdev.cmd.fpc.pas`, `src/fpdev.cmd.package.repo.update.pas`, `src/fpdev.toolchain.pas` | 新增测试 RED->GREEN，style 项继续收敛 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音且行为不变 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量治理后回归通过 |

## Session 2026-02-12 Round 8: 全仓扫描结果与缺口

### 扫描命令
- `python3 scripts/analyze_code_quality.py`
- `rg -n "TODO|FIXME|XXX|TBD|HACK|WIP|未完成|待实现|待办" src tests scripts docs --glob '!docs/archive/**' --glob '!**/__pycache__/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests scripts docs --glob '!docs/archive/**' --glob '!**/__pycache__/**'`

### 结果摘要
1. 当前质量脚本输出仍为 `总问题数: 3`（`debug_code=1`, `code_style=1`, `hardcoded_constants=1`）。
2. `code_style` 明确命中 Batch 6 三文件（长行）：
   - `src/fpdev.cmd.fpc.pas`
   - `src/fpdev.cmd.package.repo.update.pas`
   - `src/fpdev.toolchain.pas`
3. `debug_code` 与 `hardcoded_constants` 仍是稳定存量组，适合作为 Batch 6 后的下一阶段任务。
4. TODO/FIXME 扫描命中以脚本/计划文档/roadmap 为主；“not implemented/stub/placeholder” 命中主要在 roadmap、注释与 i18n 文案，未发现新的高优先级阻塞项。

### 本轮可执行优先级计划
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 6 | `src/fpdev.cmd.fpc.pas`, `src/fpdev.cmd.package.repo.update.pas`, `src/fpdev.toolchain.pas` | 新增测试 RED->GREEN 且 style 从这三文件迁移 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出和用户输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量抽离并保持行为不变 |

## Session 2026-02-12 Round 8: Batch 6 执行结果（严格 TDD）

### RED
- 命令: `python3 -m unittest tests/test_style_regressions_batch6.py -v`
- 输出要点:
  - `FAILED (failures=3)`
  - `src/fpdev.cmd.fpc.pas` 超长行: 3 处（77/387/523）
  - `src/fpdev.cmd.package.repo.update.pas` 超长行: 1 处（27）
  - `src/fpdev.toolchain.pas` 超长行: 1 处（245）

### GREEN
- 修改:
  - `src/fpdev.cmd.fpc.pas`: 3 处长行换行（签名 + 路径拼接）
  - `src/fpdev.cmd.package.repo.update.pas`: `FindSub` 单行展开（保留 `if AName <> '' then;` 语义）
  - `src/fpdev.toolchain.pas`: `ProbeFirstAvailable` 签名换行
- 命令: `python3 -m unittest tests/test_style_regressions_batch6.py -v`
- 输出: `Ran 3 tests in 0.002s` + `OK`

### VERIFY
- 命令: `python3 scripts/analyze_code_quality.py`
- 输出摘要:
  - `总问题数: 3`
  - `debug_code: 1`, `code_style: 1`, `hardcoded_constants: 1`
  - style 已切换到下一批文件：
    - `src/fpdev.fpc.interfaces.pas`
    - `src/fpdev.cmd.package.install_local.pas`
    - `src/fpdev.resource.repo.pas`
- 命令: `bash scripts/run_all_tests.sh`
- 输出摘要: `Total 176 / Passed 176 / Failed 0 / Skipped 0`

### 下一批可执行优先级
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 7 | `src/fpdev.fpc.interfaces.pas`, `src/fpdev.cmd.package.install_local.pas`, `src/fpdev.resource.repo.pas` | 新增测试 RED->GREEN，style 项继续收敛 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音且行为不变 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量治理后回归通过 |

## Session 2026-02-12 Round 9: 全仓扫描结果与缺口

### 扫描命令
- `python3 scripts/analyze_code_quality.py`
- `rg -n "TODO|FIXME|XXX|TBD|HACK|WIP|未完成|待实现|待办" src tests scripts docs --glob '!docs/archive/**' --glob '!**/__pycache__/**'`
- `rg -n -i "not implemented|not yet implemented|stub|placeholder" src tests scripts docs --glob '!docs/archive/**' --glob '!**/__pycache__/**'`

### 结果摘要
1. 当前质量脚本输出仍为 `总问题数: 3`（`debug_code=1`, `code_style=1`, `hardcoded_constants=1`）。
2. `code_style` 明确命中 Batch 7 三文件：
   - `src/fpdev.fpc.interfaces.pas`（行尾空格）
   - `src/fpdev.cmd.package.install_local.pas`（长行）
   - `src/fpdev.resource.repo.pas`（长行）
3. `debug_code` 与 `hardcoded_constants` 仍是稳定存量组。
4. TODO/FIXME 与 stub/placeholder 命中仍以文档/注释为主，暂无新的高优先级阻塞项。

### 本轮可执行优先级计划
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 7 | `src/fpdev.fpc.interfaces.pas`, `src/fpdev.cmd.package.install_local.pas`, `src/fpdev.resource.repo.pas` | 新增测试 RED->GREEN 且 style 从这三文件迁移 |
| P2 | Debug 输出分类治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 区分调试输出和用户输出，减少 debug_code 噪音 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量抽离并保持行为不变 |

## Session 2026-02-12 Round 9: Batch 7 执行结果（严格 TDD）

### RED
- 命令: `python3 -m unittest tests/test_style_regressions_batch7.py -v`
- 输出要点:
  - `FAILED (failures=3)`
  - `src/fpdev.fpc.interfaces.pas` 行尾空白: 13 处
  - `src/fpdev.cmd.package.install_local.pas` 长行: 1 处（27）
  - `src/fpdev.resource.repo.pas` 长行: 1 处（1060）

### GREEN
- 修改:
  - `src/fpdev.fpc.interfaces.pas`: 清理行尾空白
  - `src/fpdev.cmd.package.install_local.pas`: `FindSub` 单行展开（保留 `if AName <> '' then;` 语义）
  - `src/fpdev.resource.repo.pas`: `GetCrossToolchainInfo` 签名换行
- 命令: `python3 -m unittest tests/test_style_regressions_batch7.py -v`
- 输出: `Ran 3 tests in 0.001s` + `OK`

### VERIFY
- 命令: `python3 scripts/analyze_code_quality.py`
- 输出摘要:
  - `总问题数: 3`
  - `debug_code: 1`, `code_style: 1`, `hardcoded_constants: 1`
  - style 已切换到下一批文件：
    - `src/fpdev.cmd.project.template.list.pas`
    - `src/fpdev.registry.retry.pas`
    - `src/fpdev.git2.pas`
- 命令: `bash scripts/run_all_tests.sh`
- 输出摘要: `Total 176 / Passed 176 / Failed 0 / Skipped 0`

### 下一批可执行优先级
| Priority | Task | Files | Done Criteria |
|----------|------|-------|---------------|
| P1 | Style Cleanup Batch 8 | `src/fpdev.cmd.project.template.list.pas`, `src/fpdev.registry.retry.pas`, `src/fpdev.git2.pas` | 新增测试 RED->GREEN，style 项继续收敛 |
| P2 | Debug 输出治理 | `src/fpdev.fpc.binary.pas`, `src/fpdev.ui.progress.download.pas`, `src/fpdev.lazarus.source.pas` | 降低 debug_code 噪音且行为不变 |
| P3 | 硬编码常量治理 | `src/fpdev.cross.search.pas`, `src/fpdev.resource.repo.mirror.pas`, `src/fpdev.cmd.package.pas` | 常量治理后回归通过 |
