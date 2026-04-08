## 本地仓库集成测试计划（最小版）

目标：在完全离线的环境验证 git2.modern 的基础功能，不引入额外 libgit2 API。

当前阶段范围：
- Initialize 成功（git_libgit2_init >= 1）
- InitRepository 成功（生成空仓库）
- 不执行 GetHead/GetCurrentBranch（空仓库无 HEAD）
- 不执行 CheckoutBranch（空仓库缺提交/树，待后续 API 补齐）

落地内容：
- tests/test_git2_local_repo.lpr：当前 focused runner 的测试入口
- tests/test_git2_local_repo.lpi：当前仓库中的 Lazarus 项目入口
- `bash scripts/run_single_test.sh tests/test_git2_local_repo.lpr`：当前可用的单测编译/运行入口

后续扩展（待批示）：
- 增补 index/tree/commit API，创建最小提交后，覆盖 GetCurrentBranch/CheckoutBranch
- 加入 fpcunit 测试套件，结构化断言与清理逻辑
