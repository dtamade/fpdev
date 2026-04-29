# fpdev.build.manager 待办与计划

## 短期（本轮后立即执行）
- [x] 文档：docs/build-manager.md 增补“全工具链真实演练 Runbook、脚本清单与参数说明”
- [x] 日志优化：Windows 时间戳零填充（避免空格）
- [x] 示例增强：示例中演示 SetTarget/SetPrefix/SetMakeCmd 的用法（注释或参数）

## 中期
- [x] 产物快照比对：TestResults 会在沙箱安装根生成 artifact-manifest.txt（relative path / size / sha256）
- [x] 交叉编译示例：docs/build-manager.md 已覆盖 SetTarget/SetPrefix/SetMakeCmd 与 CPU_TARGET/OS_TARGET 组合
- [x] 更详细严格校验报告：严格清单会聚合输出所有已配置 section 的缺失项明细

## 可选
- [x] CI 自托管 Runner 方案脚本化（Linux/macOS 脚本：scripts/build_manager_self_hosted_ci.sh；Windows 继续使用 tests/fpdev.build.manager/run_tests.bat）
- [x] REAL 模式前置“Preflight 必须通过”的强约束：FullBuild 固定以 Preflight 开始，失败时在构建阶段前中止
