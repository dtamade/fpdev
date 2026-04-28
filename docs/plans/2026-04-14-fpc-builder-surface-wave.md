# FPC Builder Surface Wave Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续削薄 `src/fpdev.fpc.builder.pas`，把 builder 侧 bootstrap/build orchestration 收进 helper，降低 builder facade 直接持有多段 sequential flow 的体量。

**Architecture:** 新增 `src/fpdev.fpc.builderflow.pas`，只承接 builder facade orchestration，不重写现有 DI/runtime/installversion helper。`src/fpdev.fpc.builder.pas` 保留 config、repo/runtime factory、真实 build 操作 callback 与异常边界。

**Tech Stack:** Object Pascal (FPC/fpcunit), Python unittest

---

### Task 1: 锁定最小切口

**Files:**
- Create: `tests/test_fpc_builder_boundary.py`
- Create: `tests/test_fpc_builderflow.lpr`
- Reuse: `tests/test_fpc_builder.lpr`
- Reuse: `tests/test_fpc_builder_bootstrapcompat.lpr`
- Reuse: `tests/test_fpc_builder_buildplan.lpr`

**Step 1: boundary 测试**

- 锁定 `src/fpdev.fpc.builder.pas` 对 `fpdev.fpc.builderflow` 的使用
- 锁定本轮目标方法只保留 callback wiring，不再内联多段顺序编排

**Step 2: direct helper 测试**

- bootstrap ensure orchestration
- source/build plan sequencing
- failure short-circuit contract

### Task 2: 实现 shared builderflow helper

**Files:**
- Create: `src/fpdev.fpc.builderflow.pas`
- Modify: `src/fpdev.fpc.builder.pas`

**Step 1: helper 最小 API**

- 面向 builder facade 的 callback record / core helpers
- 不打开低层 repo/build manager 实现

**Step 2: 最小改写 builder facade**

- 只把高重复 orchestration 移走
- 保持 public API 不变

### Task 3: Focused Verification

Run:
- `python3 -m unittest tests.test_fpc_builder_boundary -v`
- `tests/test_fpc_builderflow.lpr`
- `tests/test_fpc_builder.lpr`
- `tests/test_fpc_builder_bootstrapcompat.lpr`
- `tests/test_fpc_builder_buildplan.lpr`

Expected: 全部通过。
