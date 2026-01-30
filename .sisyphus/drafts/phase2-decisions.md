# Phase 2 Implementation Plan - Decision Log

## Research Summary (3 Background Agents Completed)

### Agent 1: TOML Parsing Research (Librarian)
**Finding**: FPDev already has a **hand-rolled TOML parser** in `fpdev.config.project.pas`
- No external library needed (zero dependencies)
- Supports sections, key-value pairs, arrays
- Intentionally minimal (doesn't need full TOML v1.0.0 spec)
- Already handles required format

**Decision**: **Keep existing parser** - it works perfectly for the use case.

### Agent 2: Shell Integration Research (Explore)
**Finding**: Shell hooks are **fully implemented** in `fpdev.cmd.shellhook.pas`
- Bash/Zsh/Fish hook generation complete
- Directory change detection works
- Config file search implemented
- Version switching logic exists
- **Missing**: `fpdev resolve-version` command (referenced but not implemented)

**Decision**: **Extend existing system** - just add the missing `resolve-version` command.

### Agent 3: Project Config Infrastructure Research (Explore)
**Finding**: Project config system is **~80% complete**
- `TProjectConfigResolver` class fully implemented
- TOML parsing works (manual, no library)
- Config hierarchy implemented (Environment → Project → Global → Default)
- Version alias resolution works (stable, lts, trunk, latest)
- **Missing**: Integration with command execution, testing, `resolve-version` command

**Decision**: **Build on existing infrastructure** - no need to rewrite.

---

## Default Decisions (Applied Based on Research)

### Q1: Test Strategy → **Full TDD (Red-Green-Refactor)**
**Rationale**:
- FPDev uses TDD methodology with 44+ tests (100% coverage)
- User explicitly mentioned "100% test coverage maintained"
- Consistency with existing codebase standards
- Research shows existing test infrastructure in `tests/` directory

**Decision**: All new features follow Red-Green-Refactor cycle.

### Q2: resolve-version Output → **Both modes (Simple + JSON)**
**Rationale**:
- Shell hooks need simple output (just version number)
- Debugging needs detailed output (source tracking)
- Research shows `fpdev show` command already uses detailed output
- Minimal implementation cost (add `--json` flag)

**Decision**: Simple by default, `--json` flag for detailed output.

### Q3: Missing Version Handling → **Error + Suggestion**
**Rationale**:
- User experience focus (5.0/10 → 8.5/10)
- Research shows existing error messages in shell hooks
- Auto-install requires user confirmation (out of scope for Phase 2)
- Helpful guidance improves UX

**Decision**: Print error with install command suggestion.

### Q4: init - Command Design → **Auto-detect shell**
**Rationale**:
- Best user experience (no need to specify shell)
- Research shows shell detection patterns exist in codebase
- User can pipe output to their config file
- Matches industry best practices (nvm, rustup)

**Decision**: Auto-detect shell, output appropriate code.

### Q5: Scope Boundaries → **Exclude all future enhancements**
**Rationale**:
- User specified 4-week timeline (Week 1-2, Week 3, Week 4)
- Focus on 3 killer features only
- Shell completions, GUI, auto-install are complex features
- Phase 2 scope is already well-defined

**Decision**: Exclude shell completions, GUI editor, auto-install, prompt customization, remote sync.

### Q6: Backward Compatibility → **Support both .fpdevrc and fpdev.toml**
**Rationale**:
- Research shows both formats already implemented
- No migration needed
- Provides flexibility for users
- Zero additional implementation cost

**Decision**: Maintain both formats.

---

## Clearance Check Results

```
CLEARANCE CHECKLIST:
✅ Core objective clearly defined? YES - 3 killer features for Phase 2
✅ Scope boundaries established (IN/OUT)? YES - Features defined, exclusions clear
✅ No critical ambiguities remaining? YES - All decisions made with rationale
✅ Technical approach decided? YES - Extend existing infrastructure
✅ Test strategy confirmed (TDD/manual)? YES - Full TDD with Red-Green-Refactor
✅ No blocking questions outstanding? YES - All defaults applied based on research

→ ALL YES - Proceeding to plan generation
```

---

## Next Steps

1. ✅ Consult Metis for gap analysis (auto-proceed)
2. ⏳ Generate work plan to `.sisyphus/plans/phase2-killer-features.md`
3. ⏳ Self-review: classify gaps (critical/minor/ambiguous)
4. ⏳ Present summary with auto-resolved items and decisions
5. ⏳ Ask user about high accuracy mode (Momus review)
6. ⏳ If high accuracy: Submit to Momus and iterate until OKAY
7. ⏳ Delete draft file and guide user to /start-work

---

**Status**: Ready for plan generation
**Timestamp**: 2026-01-30
**Research Complete**: 3/3 agents
**Decisions Made**: 6/6 questions
