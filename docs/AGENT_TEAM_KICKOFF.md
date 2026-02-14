# Agent Team Kickoff (Sprint 1)

## Team Roster
- `Agent-Coder`: 编码实现与测试落地（TDD）
- `Agent-Reviewer`: 代码审查与准入把关
- `Agent-Planner`: 任务拆分、优先级、状态推进

## Board
| ID | Priority | Owner | Status | Task |
|----|----------|-------|--------|------|
| T1 | P0 | Agent-Coder | done | 实现 `TGitHubClient` 非 GET 请求通路并补测试 |
| T2 | P1 | Agent-Coder | done | 实现 `TGitLabClient` 非 GET 请求通路并补测试 |
| T3 | P2 | Agent-Coder | todo | 清理低风险质量项（debug/style/hardcoded） |

## Task Cards

### T1 - GitHub API non-GET support
- Scope:
  - `src/fpdev.github.api.pas`
  - `tests/test_github_api_remote.lpr` (new)
- Non-goals:
  - 不改命令注册，不改 CLI 行为
- Acceptance:
  - [ ] `CreateRepository/CreateRelease/UploadReleaseAsset/DeleteReleaseAsset` 不再返回硬编码 `not yet implemented`
  - [ ] 新测试完成 Red -> Green
  - [ ] 无新增编译错误
- TDD Commands:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_github_api_remote.lpr && ./bin/test_github_api_remote`
  - GREEN: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_github_api_remote.lpr && ./bin/test_github_api_remote`
  - VERIFY: `bash scripts/run_all_tests.sh`

### T2 - GitLab API non-GET support
- Scope:
  - `src/fpdev.gitlab.api.pas`
  - `tests/test_gitlab_api_remote.lpr` (new)
- Non-goals:
  - 不做 API 语义扩展，仅打通请求路径
- Acceptance:
  - [ ] `CreateProject/UploadPackage/DeletePackage/CreateRelease` 不再返回硬编码 `not yet implemented`
  - [ ] 新测试完成 Red -> Green
  - [ ] 无新增编译错误
- TDD Commands:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_gitlab_api_remote.lpr && ./bin/test_gitlab_api_remote`
  - GREEN: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_gitlab_api_remote.lpr && ./bin/test_gitlab_api_remote`
  - VERIFY: `bash scripts/run_all_tests.sh`

### T3 - Code quality cleanup (low risk)
- Scope:
  - `src/fpdev.fpc.binary.pas`
  - 其余由 `scripts/analyze_code_quality.py` 指定的低风险文件
- Acceptance:
  - [ ] 质量脚本问题数下降
  - [ ] 行为保持不变
  - [ ] 回归通过
- Commands:
  - `python3 scripts/analyze_code_quality.py`
  - `bash scripts/run_all_tests.sh`

## Workflow (Execution Order)
1. `Agent-Planner` 将 `T1` 置为 `in_progress` 并下发给 `Agent-Coder`
2. `Agent-Coder` 提交 TDD 证据（先失败，再通过）
3. `Agent-Reviewer` 审查并给出 `Approve/Request Changes`
4. `Agent-Planner` 根据审查结果推进 `T2`，重复流程

## Handoff Template
```md
## Handoff
- Task: <ID>
- Status: review
- Changed files:
  - <path>
- TDD Evidence:
  - RED command + key output
  - GREEN command + key output
- Risks:
  - <risk>
```

## Completed Handoffs
### T1
- Status: done
- Changed files:
  - `src/fpdev.github.api.pas`
  - `tests/test_github_api_remote.lpr`
- TDD Evidence:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_github_api_remote.lpr && ./bin/test_github_api_remote`
  - RED output: `Failed: 4`（均为 `not yet implemented` 硬编码错误）
  - GREEN: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_github_api_remote.lpr && ./bin/test_github_api_remote`
  - GREEN output: `Passed: 8, Failed: 0`
- Reviewer Verification:
  - `bash scripts/run_all_tests.sh` => `Total: 175, Passed: 175, Failed: 0`
- Risks:
  - 仅打通 HTTP method 通路；未引入 API 语义增强（分页、限流、重试策略细化）

### T2
- Status: done
- Changed files:
  - `src/fpdev.gitlab.api.pas`
  - `tests/test_gitlab_api_remote.lpr`
- TDD Evidence:
  - RED: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_gitlab_api_remote.lpr && ./bin/test_gitlab_api_remote`
  - RED output: `Failed: 4`（均为 `not yet implemented` 硬编码错误）
  - GREEN: `fpc -Fusrc -Fisrc -FEbin -FUlib tests/test_gitlab_api_remote.lpr && ./bin/test_gitlab_api_remote`
  - GREEN output: `Passed: 8, Failed: 0`
- Reviewer Verification:
  - `bash scripts/run_all_tests.sh` => `Total: 176, Passed: 176, Failed: 0`
- Risks:
  - 仅打通 HTTP method 通路；未引入 API 语义增强（分页、限流、重试策略细化）
