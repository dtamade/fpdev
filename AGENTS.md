# Repository Guidelines

本仓库面向 FPDev（Object Pascal / Free Pascal）贡献者，快速说明目录结构、常用命令、编码与测试约定。

## 项目结构与模块组织

- `src/`: 主程序与核心模块。入口：`src/fpdev.lpr`；单元命名：`fpdev.*`（例如 `src/fpdev.build.manager.pas`）。
- `tests/`: fpcunit 测试程序。顶层测试通常是 `tests/test_*.lpr`（部分配套 `.lpi`）。
- `scripts/`: 维护脚本（例如 `scripts/run_all_tests.sh`、`scripts/check_toolchain.sh`）。
- `docs/`、`examples/`、`test-app/`: 文档与示例。
- 构建产物：`bin/`（可执行文件）、`lib/`（编译单元）会自动生成并在 `.gitignore` 中忽略。

## 构建、测试与本地开发命令

运行：
```bash
lazbuild -B fpdev.lpi                 # 首选：Lazarus clean rebuild
lazbuild -B --build-mode=Release fpdev.lpi
./bin/fpdev system help               # 运行本地构建产物
scripts/check_toolchain.sh            # 检查 fpc/lazbuild/git 等依赖
scripts/run_all_tests.sh              # 构建并运行顶层测试集
lazbuild -B tests/test_config_management.lpi && ./bin/test_config_management
fpc -Fusrc -Fisrc -FEbin -FUlib src/fpdev.lpr   # 备选：直接用 fpc 编译
```

## 编码风格与命名约定

- 语言：Object Pascal（FPC 3.2.2+），常见编译模式为 `{$mode objfpc}{$H+}`。
- 缩进：2 空格；`uses` 列表按相邻文件习惯分组并保持稳定排序。
- 文件名小写；单元按前缀组织：
  - 命令：`src/fpdev.cmd.<domain>[.<action>].pas`（例如 `src/fpdev.cmd.fpc.install.pas`）
  - 核心模块：`src/fpdev.<area>.<thing>.pas`
- 可选质量脚本：`scripts/analyze_code_quality.py`、`scripts/fix_code_quality.py`

## 测试规范

- 框架：**fpcunit**。优先写可重复、离线测试（使用 `tests/` 下的本地夹具，避免网络依赖）。
- 命名：测试程序用 `tests/test_<area>.lpr`；生成的 `bin/`、`lib/` 产物不要提交。
- 常用跑法：
  ```bash
  scripts/run_all_tests.sh
  cd tests/fpdev.build.manager && ./run_tests.sh
  ```

## 提交与 PR 规范

- 提交信息使用 Conventional Commits：`feat:`、`fix:`、`docs:`、`refactor:`、`chore:`（常见范围：`fix(tests):`）。
- PR 建议包含：问题/方案摘要、如何验证（命令 + 期望输出）、以及平台差异说明（Windows/Linux/macOS）。
- 提交前自查（示例）：
  ```bash
  git status --porcelain=v1
  git diff --stat
  git log -n 10 --oneline
  scripts/run_all_tests.sh
  ```

## 架构提示

- FPDev 采用命令注册/分发模式：新命令通常在 `initialization` 中注册，并通过 `src/fpdev.command.imports.<domain>.pas` 聚合到 CLI bootstrap 链路。
- CLI 入口保持精简：`src/fpdev.lpr` 负责启动，`src/fpdev.cli.bootstrap.pas` + `src/fpdev.command.imports.pas` 负责装配默认命令面。
- 新代码优先使用接口化实现（例如 Git 走 `git2.api.pas` + `git2.impl.pas`）而不是全局单例。

## 新增命令的最小步骤

- 新建单元：`src/fpdev.cmd.<domain>.<action>.pas`
- 在 `initialization` 中注册路径（示例：`fpc install` / `package publish`）
- 在对应的 `src/fpdev.command.imports.<domain>.pas` 中引入该单元，确保 bootstrap 会触发注册

## 配置与本地状态

- FPDev 的用户状态目录：Linux/macOS 为 `~/.fpdev/`，Windows 为 `%APPDATA%\\.fpdev\\`；测试不要依赖真实用户配置。

## 安全与配置提示

- 不要提交包含敏感信息的日志/临时文件（例如 `logs/` 下的个人路径、token、镜像地址）。需要附带日志时请先脱敏。
- 新增会触网的行为时，在 PR 中说明原因，并尽量提供离线替代（本地 fixture、可注入的接口、mock）。
