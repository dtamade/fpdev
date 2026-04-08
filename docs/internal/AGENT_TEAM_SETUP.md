# 智能体团队编排（Code / Review / Plan）

## 团队目标
建立一个最小可执行的 3 角色智能体协作机制：
- 角色 A：负责编写代码（Coder）
- 角色 B：负责审查质量（Reviewer）
- 角色 C：负责推进计划与节奏（Planner）

## 角色定义

### 1. Coder（编码智能体）
职责：
- 按任务单实现功能或修复，严格走 TDD（Red -> Green -> Refactor）
- 产出可运行代码、测试、变更说明
- 不跳过测试，不直接宣布“完成”

输入：
- Planner 下发的任务卡（范围、验收标准、测试命令）
- Reviewer 反馈

输出：
- 代码变更（diff）
- 测试命令与结果
- 风险说明（如果有）

成功标准：
- 本任务对应测试通过
- 无新增编译错误
- 变更范围符合任务卡

### 2. Reviewer（审查智能体）
职责：
- 对 Coder 提交进行技术审查：正确性、回归风险、可维护性、测试充分性
- 明确列出问题级别（High/Medium/Low）与文件定位
- 给出可执行修复建议，而不是泛泛意见

输入：
- Coder 的 diff 与测试结果

输出：
- 审查清单（按严重级别排序）
- 是否准入（Approve / Request Changes）

成功标准：
- 高风险问题被识别并阻断
- 审查意见可直接执行

### 3. Planner（计划推进智能体）
职责：
- 维护任务池、优先级、批次目标（WIP=1）
- 把大任务切成可执行任务卡（每张 15~60 分钟）
- 跟踪状态：todo -> in_progress -> review -> done
- 在每轮结束后给出下一轮任务

输入：
- 当前目标、上下文、技术债、测试状态
- Reviewer 结论

输出：
- 任务卡
- 每日/每批次进度汇报
- 阻塞项与决策建议

成功标准：
- 团队持续交付
- 优先级正确、返工率下降

## 协作协议（强约束）
1. Planner 先出任务卡，Coder 才能开始。
2. Coder 必须先提交 failing test 证据，再提交实现。
3. Reviewer 结论为 `Request Changes` 时，Coder 必须先修复再进入下一任务。
4. Planner 只有在“测试证据 + 审查通过”同时满足时，才可标记完成。

## 任务卡模板（Planner 使用）
```md
### Task: <任务名>
- Priority: P0/P1/P2
- Scope: <允许改动文件>
- Non-goals: <禁止改动>
- Acceptance:
  - [ ] 行为满足需求
  - [ ] 测试通过
  - [ ] 无新增 warning/error
- TDD Commands:
  - RED: <命令>
  - GREEN: <命令>
  - VERIFY: <命令>
```

## 审查模板（Reviewer 使用）
```md
## Findings
1. [High] <问题描述> (`path/to/file:line`)
2. [Medium] <问题描述> (`path/to/file:line`)
3. [Low] <问题描述> (`path/to/file:line`)

## Decision
- Approve / Request Changes

## Required Fixes
- <可执行修复项>
```

## 运行节奏（建议）
- 每个批次只做 1 张任务卡（WIP=1）
- 每张任务卡最多 2 次返修，超过则由 Planner 重新拆分
- 每天至少 1 次“计划盘点”：更新优先级和阻塞项

## 快速启动
1. Planner 先创建 3 张任务卡（P0, P1, P2）。
2. Coder 执行 P0，提交 TDD 证据和 diff。
3. Reviewer 审查 P0，给出结论。
4. Planner 根据审查结果推进下一轮。

