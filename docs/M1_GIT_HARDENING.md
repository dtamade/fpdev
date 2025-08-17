# M1 - Git Hardening 实施说明（摘要）

本文件汇总本里程碑对 Git 集成的硬化改动，包括动态加载、初始化错误信息增强、最小网络选项接线、CLI 对齐，以及后续步骤与测试脚本。

## 1. 动态加载与 DLL 探测
- 新增 `src/libgit2.dynamic.pas`：Windows 下按顺序探测 `git2.dll` → `libgit2-1.dll` → `libgit2.dll`
- 默认启用 `LIBGIT2_DYNAMIC`（`src/fpdev.config.inc`），可用 `-dNO_LIBGIT2_DYNAMIC` 退回 external 方式
- 初始化失败时提供清晰错误：找不到 DLL 或版本/依赖不兼容
- 相关文档：`docs/LIBGIT2_DYNAMIC.md`

## 2. 初始化/版本信息与错误改进
- `TGitManager.Initialize`：在动态加载失败/不兼容时抛出 `EGitError` 提示措施
- `TGitManager.GetVersion`：调用 `git_libgit2_version` 输出版本字符串
- `TGitManager.SetVerifySSL`：最小实现，通过 `git_config` 设置 `http.sslVerify`（回调接线前的安全默认）

## 3. 最小网络选项接线（避免 ABI 风险）
- 新增 `src/libgit2.network.pas`：仅暴露 init 函数为指针调用（`git_remote_init_callbacks`、`git_fetch_options_init`、`git_clone_options_init`、`git_checkout_options_init`）
- 在 `git2.modern.pas` 中：
  - Clone：调用 `git_clone_options_init` 初始化选项缓冲区后传入
  - Fetch：调用 `git_fetch_options_init` 初始化后传入
  - Checkout：调用 `git_checkout_options_init` 初始化后传入
- 说明：暂未直接声明复杂结构体，使用固定大小字节缓冲 + 官方 init 函数，确保跨版本字段变动不引发布局风险

## 4. 凭据/证书/进度回调（阶段1，最小接线）
- 凭据：预留事件签名；当前阶段默认不提供凭据（回退到系统配置/凭据管理器），后续小步扩展
- 证书：默认遵循 WinHTTP/Schannel 校验；`SetVerifySSL(False)` 可关闭校验（通过 http.sslVerify）
- 进度：Fetch/Clone/Checkout 统一接入“选项初始化”，后续通过专用封装追加回调桥接（下一小步提交）

## 5. CLI 对齐（隐藏/标记 Deprecated）
- `src/fpdev.cmd.project.pas`：隐藏 `project git ...` 用户侧命令，加入 `[Deprecated]` 提示（编译宏控制）
- 检索并标记 `docs/*` 中提到的 `fpdev git`/`fpdev source`，文档将在整体整理时同步更新（不影响功能）

## 6. 测试脚本与本地用例
- 动态加载冒烟：`scripts/test_dynamic_loader.bat` + `src/test_dyn_loader.lpr`
- 本地仓库 TDD 用例（后续追加）：临时目录 init→修改→add/index→commit→branch→checkout→status（无外网）

## 7. 变更清单（代码）
- 新增：
  - `src/libgit2.dynamic.pas`
  - `src/fpdev.config.inc`
  - `src/libgit2.network.pas`
  - `src/test_dyn_loader.lpr`
  - `docs/LIBGIT2_DYNAMIC.md`
  - `docs/M1_GIT_HARDENING.md`
  - `scripts/test_dynamic_loader.bat`
- 修改：
  - `src/git2.modern.pas`（接入动态加载、最小网络选项；初始化/版本/SSL 配置强化；隐藏/弃用说明）
  - `src/fpdev.cmd.project.pas`（隐藏 project git 命令 help）
  - `src/fpdev.cmd.package.pas`（包构建优先 lazbuild）
  - `src/libgit2.pas`（新增 options init 与 credentials 外部声明）

## 8. 后续计划（M1 余项 → M2）
- 小步扩展：把凭据/证书回调桥接到 `TGitManager` 的事件（credentials/certificate_check/transfer_progress）
- 完成本地 TDD 测试程序与脚本
- M2：FPC/Lazarus Manager 加固（缓存/失败回滚/幂等/离线）

