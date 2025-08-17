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
  - Windows：双击 buildOrTest.bat
  - 或命令行：
    - 构建：fpc -Fu..\..\src -Fu..\..\src\git2 -Fu. -obin\fpdev.git2.test.exe fpdev.git2.test.lpr
    - 运行：bin\fpdev.git2.test.exe

## 状态测试（离线，默认启用 -gh/-gl，无泄漏为准）
- 路径：tests/fpdev.git2/
- 用例：
  - fpdev.git2.test.lpr：Discover 回退与 OID 辅助
  - fpdev.git2.status_ignore_test.lpr：.gitignore / IncludeIgnored 过滤
  - fpdev.git2.status_index_test.lpr：索引变更 / IndexOnly 过滤
- 行为：
  - 若 libgit2.Initialize 失败，相关用例打印“跳过”，退出码 0
  - 运行脚本自动设置 HEAPTRC 并打印日志，期望“0 memory blocks were not freed”

### 关于 merge-conflict 覆盖（暂缓）
- 纯离线环境下构造可靠冲突场景较为复杂（需多分支与合并操作）
- 当前选择：暂缓此用例，后续视需要引入最小仓库流程或在线仓库模拟
- 若需此覆盖，请提出具体场景与约束，我会设计最小可控方案

## 适配示例测试（默认离线）
- 路径：tests/fpdev.git2.adapter/
- buildOrTest.bat：默认设置 FPDEV_OFFLINE=1；设置 FPDEV_ONLINE=1 可联网
- test_git_basic.lpr：
  - 优先使用 libgit2 克隆，失败回退系统 git
  - 支持 --offline / --online 参数与 FPDEV_OFFLINE/FPDEV_ONLINE 环境变量

