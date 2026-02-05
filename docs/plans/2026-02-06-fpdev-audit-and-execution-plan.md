# FPDev 项目审计与落地执行计划（自动驾驶）

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** 让仓库在 Windows/Linux/macOS 上具备“可构建、可全测、可贡献”的稳定基线，并输出可持续迭代的中长期路线图（含里程碑与验收标准）。

**Architecture:** 以“稳定性与可复现性”为第一优先级：先保证离线测试/构建链条一致，再逐步收敛架构债务（去单例、接口化注入、降低弃用 API 使用），最后推进新增能力与发布流程。

**Tech Stack:** Object Pascal (FPC 3.2.2+), Lazarus (`lazbuild`), fpcunit, libgit2.

---

## 项目现状（快速审计）

- 入口：`src/fpdev.lpr`（命令注册/分发，`uses` 强制引用子命令单元以触发 `initialization` 注册）。
- 测试：`tests/` 下大量 `tests/test_*.lpr`，仓库提供 `scripts/run_all_tests.sh` 跑顶层测试集。
- 文档：`README.md`、`docs/`、`docs/plans/`（已有历史设计文档）。
- 风险点：
  - 网络依赖测试会导致不稳定（需离线默认）。
  - 个别测试会写入仓库根目录或覆盖 tracked fixture（需隔离到 temp）。
  - 存在未完成/不一致的接口化工作（例如错误注册表、弃用 Git API）。

---

## Task 1: 建立“可重复”的验证基线（证据优先）

**Files:** none (commands only)

**Step 1: 工具链检查**

Run: `scripts/check_toolchain.sh`  
Expected: 缺失项会明确打印（允许缺交叉编译器；主链必须有 `fpc`、`lazbuild`、`git`）。

**Step 2: 构建主程序**

Run: `lazbuild -B fpdev.lpi`  
Expected: exit 0；warnings/hints 允许但需记录数量。

**Step 3: 运行顶层测试集**

Run: `scripts/run_all_tests.sh`  
Expected: exit 0；`Total`、`Passed`、`Failed` 记录在 `progress.md`（或 CI 日志）。

---

## Task 2: 修复失败测试 + 强化离线默认（已落地）

**Files:**
- Modify: `src/fpdev.errors.pas`
- Modify: `tests/test_bootstrap_downloader.lpr`
- Modify: `tests/test_toml_parser.lpr`
- Modify: `tests/test_package_repo_integration.lpr`
- Modify: `tests/test_package_index_validation.lpr`

**Step 1: 修复 `src/fpdev.errors.pas` 无法编译问题**
- 补齐 `IErrorRegistry`（占位接口）
- 实现 `TErrorRegistry.Instance` 单例 + `TErrorCode` 友好 API（满足 `tests/test_errors*.lpr` 与 `src/fpdev.errors.recovery.pas`）
- `NewError(...)` 改为走单例，避免每次创建 registry

Verify:
```bash
fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_errors.lpr && ./bin/test_errors
fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_errors_recovery.lpr && ./bin/test_errors_recovery
```

**Step 2: 网络测试改为默认跳过**
- `tests/test_bootstrap_downloader.lpr`：默认 skip，需显式 `FPDEV_RUN_NETWORK_TESTS=1` 才跑网络下载。

Verify:
```bash
fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_bootstrap_downloader.lpr && ./bin/test_bootstrap_downloader
```

**Step 3: fpcunit 控制台 runner 默认运行全部**
- `tests/test_toml_parser.lpr`：设置 `DefaultRunAllTests := True`，保证无参数执行仍会跑测试并返回 0。

Verify:
```bash
fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_toml_parser.lpr && ./bin/test_toml_parser
```

**Step 4: 修复测试覆盖写入 tracked fixture**
- `tests/test_package_repo_integration.lpr` / `tests/test_package_index_validation.lpr`：改用 temp config 文件（`GetTempDir`），避免覆盖 `tests_repo_config*.json`。

Verify:
```bash
fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_repo_integration.lpr && ./bin/test_package_repo_integration
fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_package_index_validation.lpr && ./bin/test_package_index_validation
```

---

## Task 3: 统一测试入口与文档（已落地）

**Files:**
- Add: `docs/testing.md`
- Add: `scripts/run_all_tests.bat`
- Modify: `README.md`

**Step 1: 新增测试指南**
- 说明单测/全测/离线默认与网络测试开关。

**Step 2: 补齐 Windows 全测脚本**
- `scripts/run_all_tests.bat`：遍历 `tests\\test_*.lpr`，构建并运行，输出摘要。

**Step 3: README 文档导航补链**
- 增加 `docs/testing.md` 与 `docs/build-manager.md` 的入口。

Verify:
```bash
scripts/run_all_tests.sh
```

---

## Task 4: 提升贡献者可读性（已落地）

**Files:**
- Add: `AGENTS.md`
- Modify: `docs/build-manager.md`

**Step 1: 新增 `AGENTS.md`**
- 简短说明结构、命令、风格、测试、PR 规范与安全提示。

**Step 2: 完善 BuildManager 高级 API 文档**
- 增补 `SetMakeCmd/SetTarget/SetPrefix` 参考与跨编译示例。

Verify:
```bash
lazbuild -B fpdev.lpi
```

---

## Task 5: 收敛弃用 Git 单例的使用（已落地一处，后续继续）

**Files:**
- Modify: `src/fpdev.utils.git.pas`

**Step 1: `IsRepositoryWithLibgit2` 避免使用 deprecated `SharedGitManager`**
- 改为 `NewGitManager()` + `Initialize` 的临时实例（接口化）。

Verify:
```bash
lazbuild -B fpdev.lpi
scripts/run_all_tests.sh
```

---

## 下一步（中长期路线图建议）

### Milestone A: 清理测试副作用（1–2 天）
- 目标：顶层测试运行后仓库根目录不产生未忽略的临时文件/目录（优先把“写根目录”的测试改为写 temp）。
- 验收：`git status --porcelain=v1` 仅出现预期的构建产物（`bin/`/`lib/`）且被 `.gitignore` 忽略。

### Milestone B: 去弃用 API / 降警告（2–4 天）
- 目标：减少主程序构建时的 deprecation warnings，推动统一 `IGitManager` 注入模式。
- 验收：`lazbuild -B fpdev.lpi` 的 warnings 数量显著下降（记录基线与目标值）。

### Milestone C: 文档与版本信息一致性（0.5–1 天）
- 目标：`README.md`、`docs/ROADMAP.md`、`CHANGELOG.md` 中的测试数量/状态/更新时间一致。
- 验收：README 中测试统计与 `scripts/run_all_tests.sh` 输出一致（或明确区分“顶层集 vs 全量集”）。

