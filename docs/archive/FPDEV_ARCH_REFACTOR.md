## FPDev 技术评估与架构重构摘要

本文件汇总当前项目的技术现状、发现的问题、已实施的最小安全改造，以及接下来建议的落地路线图，便于团队对齐与实施。

### 1. 现状要点
- 分层设计方向正确（CLI/命令层/核心服务/基础设施）。
- Git 集成存在三套路径：
  - src/fpdev.git.pas（系统 git 命令封装）
  - src/fpdev.git2.pas + src/fpdev.libgit2.pas（轻量 libgit2）
  - src/git2.modern.pas + src/libgit2.pas（现代接口/类型更完整）
- FPC 源码管理 TFPCSourceManager 过大：集成了克隆/更新/构建/缓存/引导/报告等，建议拆分职责。
- 安全方面：直接 shell 执行 git/make/删除目录、缺少证书与凭据回调，存在改进空间。

### 2. 本次最小改造（可回滚）

Deprecated 提示：
- fpdev.git2.pas 现为兼容适配层，建议新代码使用 git2.modern（现代接口）。
- 适配方向：逐步将 fpdev.git2 内部实现转调到 git2.modern，保持对外签名稳定。
目的：避免直接调用系统 git，优先走 libgit2 路径，同时保持项目可编译、现有测试可通过。

- 修改 src/fpdev.fpc.source.pas 中 CloneFPCSource：
  - uses 从“git2.modern”改为“fpdev.git2”（TGit2Manager），绕开 git2.modern 目前的编译问题。
  - 克隆实现改为调用 TGit2Manager.CloneRepository（基于 libgit2），不再执行外部 "git clone"。
- 验证：运行 scripts/test_simple.bat，8/8 通过。

注意：git2.modern 编译目前报错，后续作为“统一 Git 高级接口层”的目标，需要逐步修正并替换 TGit2Manager。

### 3. 风险与回滚
- 改动范围仅限 TFPCSourceManager.CloneFPCSource 的克隆路径；如有异常，可将调用恢复为原 ExecuteProcess('git', ...)。
- 目前未触碰构建/删除目录等其他外部命令路径，后续将逐步替换为安全封装。

### 4. 下一步建议（分阶段）
1) 统一 Git 访问层（第1周）
- 修复 git2.modern 的编译问题（类型补全、头定义一致性、cint 等基础类型引用），形成稳定的 GitManager/TGitRepository 高级接口。
- 引入 IVCSSource 接口，对外屏蔽底层具体实现；逐步替换 TGit2Manager 的调用。

2) 拆分 TFPCSourceManager（第2周）
- SourceLayout（路径/版本映射）、VCSProvider（Git）、BootstrapProvider（引导编译器）、BuildOrchestrator（构建流程）、CacheProvider（缓存策略）。
- 改善日志/错误处理，移除直接 shell 删除目录，使用安全的跨平台 API。

3) 安全与配置现代化（第3周）
- libgit2 证书/凭据回调；DLL 加载路径与哈希校验；参数校验（URL/分支/路径）。
- 配置改用强类型序列化与校验（Validate/Migrate），保留向后兼容。

4) 测试与CI（第4周）
- 单元/集成/端到端覆盖：VCS、配置、命令解析、构建 orchestrator。
- 避免重复克隆与长时构建，利用缓存与本地镜像；nightly 跑长测。

### 5. 测试与使用
- 快速回归：
  - scripts/test_simple.bat 负责编译与基础命令验证（已通过）。
- 建议新增：
  - 针对 libgit2 克隆与证书/凭据回调的集成测试（后续补充 mock/本地镜像以避免联网）。

### 6. 里程碑与交付
- 里程碑A：统一 Git 层打底 + TFPCSourceManager 使用统一接口（保留 fallback）
- 里程碑B：构建/缓存/引导分层完成 + 安全基线达标
- 里程碑C：测试覆盖 >80%，夜间长测稳定

本文件随改造推进持续更新，建议每周同步一次进展与风险。
