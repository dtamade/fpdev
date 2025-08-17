# Todos：fpcunit 迁移与后续

- [x] 迁移 tests/fpdev.git2 到 fpcunit（默认离线）
  - [x] 工程文件 .lpi/.lpr、buildOrTest.fpcunit.bat
  - [x] TTestCase_Global 与 TTestCase_Git2Status

- [ ] 扩展 StatusEntries 覆盖
  - [ ] .gitignore 场景（IncludeIgnored）
  - [ ] 索引变更（git_index_add_bypath/write）
  - [ ] 冲突标志（可模拟）
  - [ ] 断言 flags 与过滤

- [ ] BuildManager 强化
  - [ ] TestResults 校验沙箱输出结构（允许安装时）
  - [ ] 日志分文件/轮转、verbosity 开关

- [ ] 文档同步
  - [ ] 在 docs/ 中补充 fpcunit 工程使用与默认离线说明

