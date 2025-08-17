# fpdev Git 集成 TODO

- [x] 设计 IGit* 抽象接口（IGitManager/IGitRepository/IGitCommit/IGitReference/IGitRemote）
- [x] 整理并统一 libgit2 头文件（合并 libgit2.pas / fpdev.libgit2.pas），增加跨平台动态加载与多 SONAME 兼容（动态加载支持延后分任务）
- [x] 完善 repo 能力：最小 status/clean/回退 Discover 已接入
- [/] 制定并实现精简测试矩阵（避免构建时克隆），临时目录初始化仓库用例（已提交 git_minimal_test.lpr）
- [ ] 产出模块总结性文档（接口说明、用例、注意事项）

日志：
- 2025-08-12 初始化任务列表与规划


- 2025-08-12 加速计划：M2(Checkout强制/Status条目)与M3(CLI集成)合并推进；保持不联网最小冒烟；动态加载延后至M4
