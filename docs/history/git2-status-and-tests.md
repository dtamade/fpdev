# git2 状态 API 与测试说明

## 状态 API（概览）
- 接口：
  - fpdev.git2：
    - TGitRepository.Status: TStringArray  // 变更文件路径列表
    - TGitRepository.StatusEntries(Filter: TGitStatusFilter): TGitStatusEntryArray // 含标志与过滤
    - TGitRepository.IsClean: Boolean
    - TGitRepository.HasUncommittedChanges: Boolean
  - git2.api + git2.impl：
    - IGitRepository.Status / StatusEntries / IsClean / HasUncommittedChanges

- 当前说明：
  - 若未提供 libgit2.dll，则仅可使用不依赖 libgit2 的函数（如 DiscoverRepository 回退）

## 离线测试
- 路径：tests/fpdev.git2/
- 构建与运行：
  - Windows：
    - 双击 `buildOrTest.bat`：串行编译/运行 basic status focused runners
    - 双击 `buildOrTest.fpcunit.bat`：运行 fpcunit 聚合套件
  - 或命令行：
    - `fpc -Fu..\..\src -Fu..\..\src\git2 -Fu. -obin\fpdev.git2.test.exe fpdev.git2.test.lpr`
    - `bin\fpdev.git2.test.exe`
    - `fpc -Fu..\..\src -Fu..\..\src\git2 -Fu. -obin\fpdev.git2.fpcunit.exe fpdev.git2.fpcunit.lpr`
    - `bin\fpdev.git2.fpcunit.exe --all --format=plain`

## 状态测试（离线，默认启用 -gh/-gl，无泄漏为准）
- 路径：tests/fpdev.git2/
- 用例：
  - fpdev.git2.test.lpr：Discover 回退与 OID 辅助
  - fpdev.git2.status_test.lpr：`Status` 路径列表、`IsClean` / `HasUncommittedChanges` 基础语义
  - fpdev.git2.status_entries_test.lpr：`StatusEntries` 基础过滤与结构化返回
  - fpdev.git2.status_ignore_test.lpr：.gitignore / IncludeIgnored 过滤
  - fpdev.git2.status_index_test.lpr：索引变更 / IndexOnly 过滤
  - fpdev.git2.status_conflict_test.lpr：真实本地 merge-conflict 仓库 + `gsConflicted` / `IndexOnly` 过滤
  - fpdev.git2.fpcunit.lpr：Discover fallback + focused `TTestCase_Git2Status`
    - `TTestCase_Git2Status：验证 StatusEntries 未跟踪过滤与冲突过滤`
- 行为：
  - 若 libgit2.Initialize 失败，相关用例打印“跳过”，退出码 0
  - `buildOrTest.bat` 当前会覆盖：
    - `fpdev.git2.test.lpr`
    - `fpdev.git2.status_test.lpr`
    - `fpdev.git2.status_entries_test.lpr`
    - `fpdev.git2.status_ignore_test.lpr`
    - `fpdev.git2.status_index_test.lpr`
    - `fpdev.git2.status_conflict_test.lpr`
  - 运行脚本自动设置 HEAPTRC 并打印日志，期望“0 memory blocks were not freed”

### 关于 merge-conflict 覆盖（真实本地冲突仓库）
- 当前用例通过本地 `git` CLI 在临时仓库里构造真实 merge-conflict，不依赖网络。
- 覆盖目标：
  - `StatusEntries(Filter)` 默认视图能返回 `gsConflicted`
  - `IndexOnly=True` 时冲突项不会被过滤掉
- 若 `git` 或 `libgit2` 不可用，用例按现有约定输出 skip，而不是把环境缺失误报成实现回归。

## 适配示例测试（默认离线）
- 路径：tests/fpdev.git2.adapter/
- buildOrTest.bat：默认设置 FPDEV_OFFLINE=1；设置 FPDEV_ONLINE=1 可联网
- test_git_basic.lpr：
  - 优先使用 libgit2 克隆，失败回退系统 git
  - 支持 --offline / --online 参数与 FPDEV_OFFLINE/FPDEV_ONLINE 环境变量
