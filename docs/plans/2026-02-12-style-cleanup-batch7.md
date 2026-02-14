# Style Cleanup Batch 7 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 清理当前 `analyze_code_quality.py` 报告中的 Batch 7 风格问题（行尾空格 + 长行），保持行为不变并可回归验证。

**Architecture:** 采用测试先行的样式回归策略：先新增仅检查风格约束的 Python 单测触发 RED，再做最小格式化修改进入 GREEN，最后用质量扫描与全量测试做 VERIFY。

**Tech Stack:** Object Pascal (FPC), Python `unittest`, shell scripts (`scripts/analyze_code_quality.py`, `scripts/run_all_tests.sh`)

---

### Task 1: 建立 Batch 7 失败测试（RED）

**Files:**
- Create: `tests/test_style_regressions_batch7.py`
- Test: `tests/test_style_regressions_batch7.py`

**Step 1: Write the failing test**

```python
class StyleRegressionBatch7Tests(unittest.TestCase):
    def test_fpc_interfaces_has_no_trailing_whitespace(self):
        ...

    def test_cmd_package_install_local_lines_within_120_chars(self):
        ...

    def test_resource_repo_lines_within_120_chars(self):
        ...
```

**Step 2: Run test to verify it fails**

Run: `python3 -m unittest tests/test_style_regressions_batch7.py -v`
Expected: FAIL with trailing-whitespace/overlong-line offenders from current files.

### Task 2: 最小化格式修复（GREEN）

**Files:**
- Modify: `src/fpdev.fpc.interfaces.pas`
- Modify: `src/fpdev.cmd.package.install_local.pas`
- Modify: `src/fpdev.resource.repo.pas`

**Step 1: Write minimal implementation**

- 仅处理当前命中的行尾空格与长行（<= 120 chars）。
- 不改函数语义、不改控制流程、不引入新功能。

**Step 2: Run test to verify it passes**

Run: `python3 -m unittest tests/test_style_regressions_batch7.py -v`
Expected: PASS.

### Task 3: 验证与优先级更新（VERIFY）

**Files:**
- Modify: `docs/plans/2026-02-12-style-cleanup-batch7.md`
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Run quality scan**

Run: `python3 scripts/analyze_code_quality.py`
Expected: `code_style` 不再命中 Batch 7 三个文件，并显示后续待办组。

**Step 2: Run full test suite**

Run: `bash scripts/run_all_tests.sh`
Expected: All tests pass.

**Step 3: Record outputs and update next priorities**

- 在计划与 planning files 中记录 RED/GREEN/VERIFY 的命令和关键输出。
- 产出下一轮可执行优先级队列。

## Execution Log (to be filled during run)

### RED
- Pending

### GREEN
- Pending

### VERIFY
- Pending

## Execution Log (completed)

### RED
Command:
- `python3 -m unittest tests/test_style_regressions_batch7.py -v`

Output (key lines):
- `FAILED (failures=3)`
- `Overlong lines found: [(27, 123)]` (cmd.package.install_local)
- `Trailing whitespace found: [(7, '  '), (25, '    '), (28, '    '), (31, '    '), (34, '    '), (37, '    '), (40, '    '), (43, '    '), (46, '    '), (49, '    '), (71, '    '), (75, '    '), (100, '    ')]` (fpc.interfaces)
- `Overlong lines found: [(1060, 130)]` (resource.repo)

### GREEN
Code changes:
- `src/fpdev.fpc.interfaces.pas`: removed trailing whitespace, no behavior changes.
- `src/fpdev.cmd.package.install_local.pas`: expanded `FindSub` one-liner to multi-line body, no behavior changes.
- `src/fpdev.resource.repo.pas`: wrapped `GetCrossToolchainInfo` signature, no behavior changes.

Command:
- `python3 -m unittest tests/test_style_regressions_batch7.py -v`

Output:
- `Ran 3 tests in 0.001s`
- `OK`

### VERIFY
Command:
- `python3 scripts/analyze_code_quality.py`

Output (summary):
- `总问题数: 3`
- `debug_code: 1 个问题`
- `code_style: 1 个问题`
- `hardcoded_constants: 1 个问题`
- `code_style` has moved to next files:
  - `src/fpdev.cmd.project.template.list.pas`
  - `src/fpdev.registry.retry.pas`
  - `src/fpdev.git2.pas`

Command:
- `bash scripts/run_all_tests.sh`

Output (summary):
- `Total:   176`
- `Passed:  176`
- `Failed:  0`
- `Skipped: 0`
