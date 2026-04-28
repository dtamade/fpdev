# B171: 大文件监控报告

## 报告日期

2026-02-10

## 2026-04-11 更新

本报告正文保留 2026-02-10 的历史快照。
截至当前工作树，`src/fpdev.cmd.project.pas` 与 `src/fpdev.cmd.lazarus.pas` 已收缩为兼容层，不再是 1000+ 行的大文件或当前命令分发实现中心。
对应实现重心已转移到 `src/fpdev.project.manager.pas`、`src/fpdev.lazarus.manager.pas` 以及各自的 `src/fpdev.cmd.<domain>.<action>.pas` 单元。
其中 Lazarus 侧在 2026-04-11 继续切出：

- `src/fpdev.lazarus.metadataflow.pas`
- `src/fpdev.lazarus.pathflow.pas`
- `src/fpdev.lazarus.installcallbacks.pas`
- `src/fpdev.lazarus.runtimeactions.pas`
- `src/fpdev.lazarus.types.pas`

这些 helper 现在分别承接 metadata/version inventory、install path/install-state、install callbacks 与 runtime/IDE actions 的纯逻辑或薄执行逻辑。
同日，FPC 侧也开始从 manager 热点继续下沉：

- `src/fpdev.fpc.statusflow.pas`

该 helper 现在承接 `fpdev fpc status` 所需的默认值初始化、install path 解析、metadata 映射与缺失 executable 错误收口。

## 2026-04-12 更新

`src/fpdev.fpc.manager.pas` 在 statusflow 之后继续切出 versionflow：

- `src/fpdev.fpc.versionflow.pas`

该 helper 当前承接：

- default toolchain version normalization
- managed version list rendering
- activate-then-set-default orchestration

这让 manager 进一步回收到 facade/orchestration 边界，版本列表输出与 activation glue 不再继续堆在同一文件里。

## 2026-04-11 当前工作树补充

下表只补充当前工作树里最容易被这份旧报告误读的几个关键单元行数，用于区分“历史大文件”与“当前兼容层/当前实现中心”：

| 文件                                     | 当前行数 | 当前定位                                                                      |
| ---------------------------------------- | -------- | ----------------------------------------------------------------------------- |
| `src/fpdev.cmd.fpc.pas`                  | 22       | 兼容层                                                                        |
| `src/fpdev.cmd.cross.pas`                | 22       | 兼容层                                                                        |
| `src/fpdev.cmd.project.pas`              | 23       | 兼容层                                                                        |
| `src/fpdev.cmd.lazarus.pas`              | 24       | 兼容层                                                                        |
| `src/fpdev.fpc.manager.pas`              | 1046     | 当前最高优先级的 FPC facade/orchestration 热点，已切出 statusflow/versionflow |
| `src/fpdev.fpc.statusflow.pas`           | 159      | FPC status orchestration helper                                               |
| `src/fpdev.fpc.versionflow.pas`          | 174      | FPC version list/default/activation orchestration helper                      |
| `src/fpdev.project.manager.pas`          | 824      | 当前 Project 实现重心                                                         |
| `src/fpdev.lazarus.manager.pas`          | 841      | 当前 Lazarus facade/orchestration 中心（已切出 metadata/path/runtime）        |
| `src/fpdev.lazarus.metadataflow.pas`     | 162      | Lazarus metadata/version inventory helper                                     |
| `src/fpdev.lazarus.pathflow.pas`         | 75       | Lazarus install path/install-state helper                                     |
| `src/fpdev.lazarus.installcallbacks.pas` | 222      | Lazarus install callback helper                                               |
| `src/fpdev.lazarus.runtimeactions.pas`   | 211      | Lazarus runtime/IDE action helper                                             |

因此，下面各节继续保留 2026-02-10 的扫描表述，仅作为历史观察，不代表当前工作树的实时大文件统计。

### 当前工作树补充结论（2026-04-11）

`project` / `lazarus` 的“壳层文件变大”问题已经收口。当前仍需继续关注的主要是 manager 级 facade/orchestration 重心，其中 `src/fpdev.fpc.manager.pas` 已开始继续向 `src/fpdev.fpc.statusflow.pas` 与 `src/fpdev.fpc.versionflow.pas` 外移状态查询、版本列表和 activation 编排；Lazarus 的 metadata、path/install-state、install callbacks 与 runtime/IDE actions 也已明显从 manager 向 helper 单元外移。

## 2026-02-10 历史快照正文

### 当时的大文件列表 (>1000 行)

| 文件                      | 行数  | 状态           | 备注                      |
| ------------------------- | ----- | -------------- | ------------------------- |
| fpdev.cmd.package.pas     | 1,890 | ✅ 已有 helper | 有 18 个 helper 单元      |
| fpdev.resource.repo.pas   | 1,669 | ✅ 已有 helper | 有 6 个 helper 单元       |
| fpdev.i18n.strings.pas    | 1,537 | ⚪ 无需拆分    | 纯数据文件                |
| fpdev.config.managers.pas | 1,365 | ⚪ 可接受      | 接口实现集合              |
| fpdev.build.cache.pas     | 1,355 | ✅ 已有 helper | 有 14 个 helper 单元      |
| fpdev.build.manager.pas   | 1,255 | ✅ 已接口化    | 有 IBuildManager 等       |
| fpdev.fpc.installer.pas   | 1,253 | ⚪ 可接受      | 安装流程逻辑              |
| fpdev.cmd.fpc.pas         | 1,119 | ⚪ 可接受      | 命令分发器                |
| fpdev.cmd.cross.pas       | 1,099 | ✅ 已拆分      | B167 拆分出 platform 单元 |
| fpdev.git2.pas            | 1,074 | ⚪ 可接受      | Git 封装层                |
| fpdev.fpc.source.pas      | 1,063 | ⚪ 可接受      | 源码管理                  |
| fpdev.cmd.lazarus.pas     | 1,042 | ⚪ 可接受      | 命令分发器                |
| fpdev.cmd.project.pas     | 1,025 | ⚪ 可接受      | 命令分发器                |

### 统计

| 指标             | 值                   |
| ---------------- | -------------------- |
| 大文件数量       | 13 个                |
| 总行数           | 65,958 行            |
| 已有 helper 单元 | 4 个                 |
| 已接口化         | 1 个                 |
| 纯数据文件       | 1 个                 |
| 本周拆分         | 1 个 (cmd.cross.pas) |

### 趋势

| 时间点      | cmd.cross.pas 行数 |
| ----------- | ------------------ |
| B161 扫描   | 1,263 行           |
| B167 拆分后 | 1,099 行 (-164)    |

### 改进历史

1. **fpdev.cmd.package.pas** (1,890行) - 已有 18 个 helper 单元
2. **fpdev.resource.repo.pas** (1,669行) - 已有 6 个 helper 单元
3. **fpdev.build.cache.pas** (1,355行) - 已有 14 个 helper 单元
4. **fpdev.cmd.cross.pas** (1,099行) - B167 新增 platform 单元

## 2026-02-10 建议

### 不建议继续拆分的文件

| 文件                  | 原因                     |
| --------------------- | ------------------------ |
| i18n.strings.pas      | 纯翻译字符串，拆分无意义 |
| config.managers.pas   | 接口实现需要集中管理     |
| git2.pas              | FFI 绑定层，保持完整性   |
| cmd.\*.pas 命令分发器 | 职责已分散到子命令       |

### 可选的未来改进

| 优先级 | 文件              | 潜在改进                |
| ------ | ----------------- | ----------------------- |
| P3     | fpc.installer.pas | 可抽离下载/解压辅助函数 |
| P3     | fpc.source.pas    | 可抽离 Git 操作辅助函数 |

## 2026-02-10 结论

### 历史观察结论（2026-02-10）

当时的大文件状态被评估为健康，主要大文件已有 helper 单元或已接口化；这条结论仅对应 2026-02-10 的那次扫描。
不建议进一步强制拆分当时列出的多数大文件，但这并不代表 2026-04-11 的当前工作树仍保持相同的大文件分布。
