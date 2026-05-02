# FPDev Git Operations Guide

这份文档说明 FPDev 当前工作树里的 Git 模块边界、推荐入口，以及最小验证入口。

先看结论：

- 需要 system-git facade 时，用 `fpdev.git.operations`
- 需要 libgit2 modern interface 时，用 `git2.api + git2.impl`
- 需要 legacy concrete wrapper 时，用 `fpdev.git2`
- 需要兼容迁移说明时，看 [Git Compat Migration](GIT_COMPAT_MIGRATION.md)

## 用 `fpdev.git.operations` 作为默认 system-git 入口

`fpdev.git.operations` 是当前默认的 system-git facade。

- public facade: `src/fpdev.git.operations.pas`
- concrete implementation: `src/fpdev.git.operations.impl.pas`
- supporting helper units:
  - `src/fpdev.git.types.pas`
  - `src/fpdev.git.errors.pas`
  - `src/fpdev.git.env.pas`
  - `src/fpdev.git.operations.identityflow.pas`
  - `src/fpdev.git.operations.transportflow.pas`
  - `src/fpdev.git.operations.queryflow.pas`
  - `src/fpdev.git.operations.mutationflow.pas`
  - `src/fpdev.git.operations.syncflow.pas`
  - `src/fpdev.git.operations.probeflow.pas`
  - `src/fpdev.git.runtime.pas`
  - `src/fpdev.git.runtime.impl.pas`

这个面适合下面几类场景：

- 需要 clone / fetch / pull / checkout / push 这类仓库操作
- 需要在没有 libgit2 direct surface 的地方走统一 backend 选择
- 需要通过 `TGitOperations` 或 `IGitCliRunner` 维持现有 system-git 工作流

如果你是在新代码里接 Git backend，默认从这里开始，不要重新引入已经删除的兼容 shim。

## 用 `git2.api + git2.impl` 作为默认 libgit2 modern interface

`git2.api + git2.impl` 是当前推荐的 libgit2 modern layer。

- interfaces: `src/git2.api.pas`
- implementation adapter: `src/git2.impl.pas`
- shared backend core: `src/git2.core.pas`

这个面适合下面几类场景：

- 新的 libgit2-backed 仓库功能
- 需要接口优先、便于替换 backend 的代码
- 想直接拿 `IGitManager` / `IGitRepository` 这类 modern interface

如果你只想要一个 concrete wrapper，但又不想回退到 legacy `fpdev.git2`，可以继续用 `git2.modern`。

## 只在需要 legacy concrete wrapper 时再用 `fpdev.git2`

`fpdev.git2` 还保留在当前工作树里，但它的角色已经收窄成 legacy compatibility surface。

- unit: `src/fpdev.git2.pas`
- internal note: 它现在是 shared `git2.core` backend 的 compatibility re-export

继续使用它是安全的，但默认不推荐把新代码直接叠到这个面上。

优先级顺序可以简单记成：

1. `fpdev.git.operations`：system-git facade
2. `git2.api + git2.impl`：modern libgit2 interface
3. `fpdev.git2`：legacy concrete wrapper

## 先跑这些 focused tests 再改 Git 模块

最小验证入口分成两组。

### system-git facade focused tests

- `tests/test_git_operations.lpr`
- `tests/test_git_operations_identityflow.lpr`
- `tests/test_git_operations_transportflow.lpr`
- `tests/test_git_operations_queryflow.lpr`
- `tests/test_git_operations_mutationflow.lpr`
- `tests/test_git_operations_syncflow.lpr`
- `tests/test_git_operations_probeflow.lpr`
- `tests/test_git_env_identity.lpr`
- `tests/test_git_env_credentials.lpr`

这些测试主要锁：

- `fpdev.git.operations` 的默认 facade 语义
- internal identity/signature helper 的当前行为
- internal transport credential/options helper 的当前行为
- internal query/read helper 的当前行为
- internal mutation surface helper 的当前行为
- internal sync surface helper 的当前行为
- internal probe surface helper 的当前行为
- environment-based credential / identity resolution
- 轻量 shared helper 是否继续按当前真相工作

### libgit2 focused lanes

- `tests/fpdev.git2/`：legacy concrete-wrapper lane
- `tests/fpdev.git2.modern/`：modern interface lane

其中当前最重要的入口是：

- `tests/fpdev.git2/fpdev.git2.fpcunit.lpr`
- `tests/fpdev.git2.modern/fpdev.git2.modern.basic.lpr`

如果你只想跑单个 focused test，优先用仓库已有入口，而不是重新写临时脚本。

## 改 Git 模块时怎么选面

如果你的变更是：

- backend detection / clone / fetch / pull / checkout / push：
  - 先看 `fpdev.git.operations`
- libgit2 interface design：
  - 先看 `git2.api + git2.impl`
- 兼容旧调用方：
  - 先确认是否真的需要 `fpdev.git2`

如果你的第一反应是“先找旧 compat 入口”，那已经偏了。那个 compatibility shim 已经删除，迁移说明只保留在 [Git Compat Migration](GIT_COMPAT_MIGRATION.md)。

## 相关文档

- [Git2 Usage](GIT2_USAGE.md)
- [Git Compat Migration](GIT_COMPAT_MIGRATION.md)
- [libgit2 Integration](LIBGIT2_INTEGRATION.md)
