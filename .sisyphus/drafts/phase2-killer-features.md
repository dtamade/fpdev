# Draft: FPDev Phase 2 - Killer Features Implementation Plan

## User Request (Original)
制定 FPDev 阶段 2（杀手级功能）的详细实施计划，包括任务分解、依赖关系、并行执行机会。

**Translation**: Create a detailed implementation plan for FPDev Phase 2 (Killer Features), including task breakdown, dependencies, and parallel execution opportunities.

## Requirements (Confirmed)

### Phase 2 Goals
1. **Week 1-2**: Project configuration file (`.fpdev.toml`)
2. **Week 3**: Automatic version switching
3. **Week 4**: Shell integration (`fpdev init -`)

### Expected Outcome
- User experience improvement: 5.0/10 → 8.5/10
- 3 killer features fully implemented
- 100% test coverage maintained
- Cross-platform compatibility (Windows/Linux/macOS)

## Context from Codebase Analysis

### Current Architecture
- **Command Pattern**: Hierarchical command registry (`fpdev.command.registry.pas`)
- **Config System**: Interface-driven design with reference counting
  - `IConfigManager` - Main coordinator
  - `IToolchainManager` - FPC versions
  - `ILazarusManager` - Lazarus versions
  - `ICrossTargetManager` - Cross-compilation
  - `IRepositoryManager` - Source repos
  - `ISettingsManager` - Global settings
- **Config Location**: `~/.fpdev/config.json` (global), `.fpdevrc` / `fpdev.toml` (project-level mentioned but not implemented)

### Existing Patterns Found
- Shell hook system exists: `fpdev.cmd.shellhook.pas` (generates bash/fish scripts)
- Project config references: `.fpdevrc` and `fpdev.toml` mentioned in multiple files but not implemented
- Version switching: `fpdev fpc use <version>` exists for global switching
- Activation scripts: `~/.fpdev/env/activate-<version>.sh` pattern exists

## Technical Decisions

### Feature 1: Project Configuration File (`.fpdev.toml`)
- **Format**: TOML (mentioned in existing code, more user-friendly than JSON)
- **Location**: Project root directory
- **Scope**: Project-specific FPC/Lazarus version overrides
- **Integration**: Extend existing `fpdev.config.project.pas` (already has PROJECT_CONFIG_FILES constant)

### Feature 2: Automatic Version Switching
- **Trigger**: Directory change (cd into project with `.fpdev.toml`)
- **Mechanism**: Shell hook integration (extend existing `fpdev.cmd.shellhook.pas`)
- **Behavior**: 
  - Search upward for `.fpdev.toml` or `.fpdevrc`
  - Parse FPC/Lazarus version requirements
  - Activate corresponding version automatically
  - Restore previous version when leaving directory

### Feature 3: Shell Integration (`fpdev init -`)
- **Purpose**: Generate shell initialization script
- **Output**: Shell-specific script (bash/zsh/fish/powershell)
- **Content**: 
  - PATH modifications
  - Environment variables
  - Auto-switching hook installation
  - Completion scripts (future enhancement)

## Research Findings

### From Codebase
1. **Shell hook infrastructure exists**: `fpdev.cmd.shellhook.pas` already generates bash/fish scripts
2. **Project config mentioned but not implemented**: References in `fpdev.config.project.pas`, `fpdev.cmd.doctor.pas`, `fpdev.cmd.show.pas`
3. **Activation pattern exists**: `fpdev.fpc.activation.pas` handles version activation
4. **TOML parsing needed**: No TOML parser in codebase currently

### Technical Requirements
1. **TOML Parser**: Need to add TOML parsing library (fpjson only handles JSON)
2. **File Watcher**: For automatic switching, need directory change detection (shell-level, not Pascal)
3. **Shell Script Generation**: Extend existing shellhook system
4. **Config Hierarchy**: Global config → Project config (override mechanism)

## Open Questions

### Q1: TOML Parser Library
**Question**: Which TOML parser should we use for Object Pascal?
**Options**:
- Write minimal TOML parser (only need basic key-value)
- Use existing library (need to research availability)
- Fall back to INI format (simpler, but less modern)

### Q2: Config Override Behavior
**Question**: How should project config override global config?
**Options**:
- Full override (project config replaces global)
- Merge strategy (project config supplements global)
- Explicit override keys only

### Q3: Shell Integration Scope
**Question**: What should `fpdev init -` output include?
**Must Have**:
- PATH modifications
- Auto-switching hook
**Nice to Have**:
- Shell completions
- Prompt customization
- Alias definitions

### Q4: Backward Compatibility
**Question**: Should we maintain `.fpdevrc` support alongside `.fpdev.toml`?
**Consideration**: Existing code references `.fpdevrc` - migration path needed?

## Scope Boundaries

### INCLUDE
- `.fpdev.toml` parsing and validation
- Project-level version override mechanism
- Automatic version switching on directory change
- Shell initialization script generation
- Test coverage for all new features
- Cross-platform support (Windows/Linux/macOS)

### EXCLUDE
- Shell completion scripts (future enhancement)
- GUI configuration editor
- Remote config synchronization
- Config migration tools (unless needed for backward compatibility)
- Performance optimization (unless blocking)

## Next Steps
1. Clarify open questions with user
2. Research TOML parsing options for Object Pascal
3. Design config hierarchy and override mechanism
4. Create detailed task breakdown with dependencies
5. Identify parallel execution opportunities
