# Draft: FPDev Phase 2 - Killer Features Implementation Plan

## User Request (Original Chinese)
制定 FPDev 阶段 2（杀手级功能）的详细实施计划，包括任务分解、依赖关系、并行执行机会。

**Translation**: Create a detailed implementation plan for FPDev Phase 2 (Killer Features), including task breakdown, dependencies, and parallel execution opportunities.

## Requirements Summary

### Phase 2 Goals (from user)
1. **Week 1-2**: Project configuration file (`.fpdev.toml`)
2. **Week 3**: Automatic version switching
3. **Week 4**: Shell integration (`fpdev init -`)

### Expected Outcomes
- User experience improvement: 5.0/10 → 8.5/10
- 3 killer features fully implemented
- 100% test coverage maintained
- Cross-platform compatibility (Windows/Linux/macOS)

## Initial Codebase Analysis

### Existing Infrastructure Found

#### 1. Project Config System (`fpdev.config.project.pas`)
**Status**: Partially implemented (interfaces exist, parsing logic present)

**What exists**:
- `TProjectConfigResolver` class with TOML parsing capability
- Support for both `.fpdevrc` (simple format) and `fpdev.toml` (TOML format)
- Config hierarchy: Environment → Project → Global → Default
- Version alias resolution (stable, lts, trunk, latest)
- Config search up directory tree (max 10 levels)

**What's implemented**:
- `FindProjectConfig()` - searches for config files
- `ParseProjectConfig()` - parses both simple and TOML formats
- `ParseSimpleFormat()` - handles single-line version files
- `ParseTOMLFormat()` - basic TOML parsing (manual, no library)
- `ResolveConfig()` - merges all config sources with priority

**What's missing**:
- Integration with command execution (config is parsed but not used)
- Automatic version switching based on config
- Shell hook integration for directory changes

#### 2. Shell Hook System (`fpdev.cmd.shellhook.pas`)
**Status**: Fully implemented

**What exists**:
- Bash/Zsh hook generation (PROMPT_COMMAND/chpwd)
- Fish shell hook generation (PWD variable watch)
- Directory change detection
- Config file search (`.fpdevrc` or `fpdev.toml`)
- Version resolution via `fpdev resolve-version` command
- Activation script sourcing

**Hook behavior**:
1. Detects directory change
2. Searches upward for `.fpdevrc` or `fpdev.toml`
3. Calls `fpdev resolve-version` to get version from config
4. Sources activation script: `~/.fpdev/env/activate-<version>.sh`
5. Prints switch message to user

**What's missing**:
- `fpdev resolve-version` command implementation
- `fpdev init -` command for easy shell integration setup

#### 3. Activation System (`fpdev.fpc.activation.pas`)
**Status**: Fully implemented

**What exists**:
- Project-scoped activation (`.fpdev/env/activate.sh|cmd`)
- User-scoped activation (`~/.fpdev/env/activate-<version>.sh|cmd`)
- VS Code integration (updates `settings.json`)
- Cross-platform script generation (Windows .cmd, Unix .sh)
- Scope detection (project vs user)

**What works**:
- Creates activation scripts with PATH modifications
- Detects project root by searching for `.fpdev` directory
- Generates platform-specific shell commands

## Technical Decisions

### Feature 1: Project Configuration File (`.fpdev.toml`)

**Current State**: 
- Parsing logic exists in `fpdev.config.project.pas`
- TOML format supported (manual parsing, no external library)
- Config hierarchy implemented

**What needs to be done**:
1. **Integration with commands**: Make commands respect project config
2. **Testing**: Comprehensive test coverage for config resolution
3. **Documentation**: User guide for `.fpdev.toml` format

**TOML Format Decision**:
- ✅ Use existing manual TOML parser (no external dependencies)
- ✅ Support both `.fpdevrc` (simple) and `fpdev.toml` (full)
- Format already defined in code:
  ```toml
  [toolchain]
  fpc = "3.2.2"
  lazarus = "3.0"
  channel = "stable"  # or "lts", "trunk"
  
  [cross]
  targets = ["win64", "linux-arm64"]
  
  [settings]
  mirror = "auto"  # or "github", "gitee", custom URL
  auto_install = false
  ```

### Feature 2: Automatic Version Switching

**Current State**:
- Shell hooks exist and generate correct scripts
- Activation system works
- Config parsing works

**What's missing**:
1. **`fpdev resolve-version` command**: Read project config and output version
2. **Integration testing**: End-to-end test of directory change → version switch
3. **Error handling**: What if version not installed?

**Implementation approach**:
- Create `fpdev.cmd.resolveversion.pas` command
- Read project config using `TProjectConfigResolver`
- Output version to stdout (for shell hook consumption)
- Return error code if config invalid or version not found

### Feature 3: Shell Integration (`fpdev init -`)

**Current State**:
- Shell hook generation exists (`fpdev shell-hook <shell>`)
- User must manually add to shell config

**What needs to be done**:
1. **Create `fpdev init -` command**: Alias or wrapper for `shell-hook`
2. **Auto-detection**: Detect user's shell automatically
3. **Installation instructions**: Clear guidance on adding to shell config
4. **Verification**: Command to test if shell integration is active

**Design decision**:
- `fpdev init -` outputs shell-specific integration code
- User pipes to shell config: `fpdev init - >> ~/.bashrc`
- Or evaluates directly: `eval "$(fpdev init -)"`

## Research Findings (Pending)

### Background Agents Launched
1. **Librarian**: Research TOML parsing options for Pascal
2. **Explore**: Analyze shell integration and activation patterns
3. **Explore**: Examine existing project config infrastructure

### Questions for Research
1. Should we use external TOML library or keep manual parsing?
2. What's the best pattern for `fpdev resolve-version` command?
3. How do other tools (rustup, nvm) handle shell integration?

## Open Questions for User

### Q1: TOML Parser Approach
**Current**: Manual TOML parsing in `fpdev.config.project.pas` (basic key-value)
**Options**:
- A) Keep manual parsing (no dependencies, limited features)
- B) Add external TOML library (more robust, adds dependency)
- C) Support only simple `.fpdevrc` format (single version line)

**Recommendation**: Keep manual parsing (A) - it's already implemented and sufficient for our needs.

### Q2: Backward Compatibility
**Question**: Should we maintain `.fpdevrc` support alongside `.fpdev.toml`?
**Current code**: Supports both formats
**Consideration**: Existing users may have `.fpdevrc` files

**Recommendation**: Support both (already implemented).

### Q3: Shell Integration Scope
**Question**: What should `fpdev init -` include?
**Must Have**:
- Shell hook for auto-switching
- PATH modifications

**Nice to Have**:
- Shell completions (bash/zsh/fish)
- Prompt customization (show current FPC version)
- Alias definitions

**Recommendation**: Start with must-have only (Week 4 scope).

### Q4: Error Handling for Missing Versions
**Scenario**: User enters directory with `.fpdev.toml` specifying FPC 3.2.2, but it's not installed.
**Options**:
- A) Print error message, don't switch
- B) Print error + suggest install command
- C) Auto-install if `auto_install = true` in config

**Recommendation**: Option B (error + suggestion) for Week 3, Option C as future enhancement.

### Q5: Test Strategy
**Question**: You mentioned 100% test coverage. Should we use TDD for all new features?
**Current**: FPDev uses TDD methodology (Red-Green-Refactor)
**Test infrastructure**: Lazarus test programs (`.lpr` files)

**Recommendation**: Yes, TDD for all new features. Each feature needs:
- Unit tests for core logic
- Integration tests for command execution
- Cross-platform tests (Windows/Linux/macOS)

## Scope Boundaries

### INCLUDE (Phase 2)
- `.fpdev.toml` parsing and validation
- Project-level version override mechanism
- `fpdev resolve-version` command implementation
- Automatic version switching on directory change (shell hook)
- `fpdev init -` command for shell integration
- Test coverage for all new features
- Cross-platform support (Windows/Linux/macOS)
- Documentation updates

### EXCLUDE (Future Phases)
- Shell completion scripts (Phase 3 or later)
- GUI configuration editor
- Remote config synchronization
- Config migration tools
- Auto-install feature (requires user confirmation)
- Prompt customization
- Performance optimization (unless blocking)

## Next Steps

1. ✅ Launch background agents (DONE)
2. ⏳ Wait for agent research results
3. ⏳ Clarify open questions with user
4. ⏳ Create detailed task breakdown with dependencies
5. ⏳ Identify parallel execution opportunities
6. ⏳ Generate final implementation plan

## Notes

- **Language**: Object Pascal (FPC 3.2.2+)
- **Build**: `lazbuild -B fpdev.lpi`
- **Test**: `lazbuild -B tests/test_*.lpr && ./bin/test_*`
- **Architecture**: Command pattern with hierarchical registry
- **Config**: Interface-driven design with reference counting
- **TDD**: Red-Green-Refactor cycle mandatory
