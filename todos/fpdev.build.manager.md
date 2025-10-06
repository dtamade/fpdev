# fpdev.build.manager 待办与计划

## 短期（本轮后立即执行）
- [ ] 文档：docs/build-manager.md 增补“全工具链真实演练 Runbook、脚本清单与参数说明”
- [ ] 日志优化：Windows 时间戳零填充（避免空格）
- [ ] 示例增强：示例中演示 SetTarget/SetPrefix/SetMakeCmd 的用法（注释或参数）

## 中期
- [ ] 产物快照比对：支持将沙箱 bin/lib 生成清单（hash/size），便于比较不同版本构建产物
- [ ] 交叉编译示例：使用 SetTarget 组合（如 CPU_TARGET=x86_64/arm，OS_TARGET=win32/linux），视上游 Makefile 支持情况
- [ ] 更详细严格校验报告：按配置输出缺失项明细

## 可选
- [ ] CI 自托管 Runner 方案脚本化（Windows/Linux/macOS）
- [ ] REAL 模式前置“Preflight 必须通过”的强约束


