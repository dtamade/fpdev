# FPDev Iterative Review And Delivery Mode

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace endless micro-fixes with a disciplined batch mode that produces visible progress, verified outcomes, and explicit next steps.

**Architecture:** Work in review-and-delivery waves, not isolated crumbs. Each wave has one theme, a fixed WIP limit, hard verification gates, and a mandatory close-out that includes what changed, what was proven, what remains, and what the next wave should be.

**Tech Stack:** Object Pascal (FPC/Lazarus), Python static contracts, shell verification, file-based planning (`task_plan.md`, `findings.md`, `progress.md`).

---

### Task 1: Define the operating model

**Files:**
- Create: `docs/plans/2026-03-24-iterative-review-delivery-mode.md`

**Step 1: Adopt wave-based execution**
- A wave is the smallest unit of meaningful progress.
- One wave must contain:
  - one clear theme
  - one bounded subsystem or defect family
  - one set of acceptance gates
- Examples:
  - "post-install temp residue cleanup"
  - "CLI exit-path cleanup bypass"
  - "shared recursive-delete defects"
- Non-example:
  - "fix whatever I find next"

**Step 2: Set WIP limits**
- Only one active wave at a time.
- One wave may contain at most:
  - 1 subsystem, or
  - 2 tightly related files, or
  - 3 tightly related defects sharing one root cause
- If new findings do not belong to the active wave, record them and defer them.

**Step 3: Require a wave charter before edits**
- Before implementation, produce a 5-line charter:
  - wave name
  - exact scope
  - out-of-scope
  - acceptance checks
  - expected user-visible result

### Task 2: Define the execution rhythm

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Use a four-checkpoint rhythm**
- Checkpoint A: Discovery
  - what is broken
  - how it was proven
  - why it matters
- Checkpoint B: Implementation plan
  - exact fix
  - exact files
  - exact risks
- Checkpoint C: Verification
  - focused tests
  - broad tests
  - residue or behavioral evidence
- Checkpoint D: Delivery
  - result
  - remaining risk
  - next wave recommendation

**Step 2: Stop sending low-value "继续" style updates**
- Do not report every tiny substep.
- Only report at the four checkpoints above, unless blocked.
- If execution takes longer, report changed understanding, not activity noise.

**Step 3: Make every wave self-contained**
- A wave is not complete until it includes:
  - code or plan changes
  - verification evidence
  - updated planning files
  - next-wave recommendation

### Task 3: Define hard acceptance gates

**Files:**
- Modify: `task_plan.md`
- Modify: `progress.md`

**Step 1: Require proof before claiming progress**
- No "fixed" claim without one of:
  - focused test passing after prior red proof
  - residue count reduced to zero
  - command output proving the behavior changed

**Step 2: Require broad regression for landed waves**
- For test-only or helper-only waves:
  - focused regression
  - relevant Python regression
  - `scripts/run_all_tests.sh`
- For product code waves:
  - focused regression
  - adjacent subsystem regression
  - `scripts/run_all_tests.sh`

**Step 3: Enforce stop conditions**
- Stop the wave when one of these is true:
  - all acceptance gates are green
  - root cause was disproven and re-scoped
  - 3-strike failure threshold reached
- Do not silently drift into a new wave.

### Task 4: Define the delivery format

**Files:**
- Modify: `progress.md`

**Step 1: End every wave with this structure**
- Outcome:
  - what was fixed or concluded
- Evidence:
  - exact commands and exact results
- Impact:
  - what user-facing or repo-health issue improved
- Remaining risk:
  - what is still not proven
- Next wave:
  - one recommended follow-up, with reason

**Step 2: Default next-wave selection rule**
- Pick the next wave by this order:
  1. reproducible real defect
  2. repeated residue or regression evidence
  3. shared helper or infrastructure root cause
  4. static hygiene only if it protects a proven live seam

### Task 5: Define the working agreement going forward

**Files:**
- Verify only

**Step 1: Execution contract**
- I will not keep asking whether to continue.
- I will not keep delivering tiny disconnected crumbs.
- I will work in waves and close one before opening another.
- I will only break the rhythm for blockers, ambiguity with real risk, or explicit user redirect.

**Step 2: First practical mode for this repository**
- Default wave size:
  - 1 defect family or 1 shared helper seam
- Default acceptance:
  - focused proof
  - focused fix
  - broader regression
  - planning-file update
- Default output:
  - short checkpoint updates during execution
  - one complete delivery at wave end

**Step 3: Recommended starting cadence**
- Phase 1: Map top 5 live defect families
- Phase 2: Execute one wave at a time from highest leverage to lowest
- Phase 3: After every 3 completed waves, produce a portfolio summary:
  - closed items
  - open items
  - systemic themes
  - reprioritized queue
