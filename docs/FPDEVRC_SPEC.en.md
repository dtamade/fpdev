# .fpdevrc Project Configuration File Specification v1.0

## Overview

`.fpdevrc` is the project-level configuration file for fpdev, used to lock the toolchain versions required by a project, ensuring consistency across team collaboration and CI environments.

**Design Goals**:
- Experience similar to `rust-toolchain.toml` and `.nvmrc`
- Support automatic version switching (detected on `cd`)
- Support version aliases (stable/lts/trunk)
- Minimal configuration with sensible defaults

## File Location

fpdev searches for configuration files in the following order (highest to lowest priority):

1. `.fpdevrc` in the current directory
2. `fpdev.toml` in the current directory
3. Recursive parent directory search for `.fpdevrc` or `fpdev.toml` (up to 10 levels)
4. Global configuration `~/.fpdev/config.json`

## File Format

### Simple Format (Version Number Only)

The simplest `.fpdevrc` requires only a single line with the version number:

```
3.2.2
```

This is equivalent to:
```toml
[toolchain]
fpc = "3.2.2"
```

### TOML Format (Full Configuration)

```toml
# fpdev.toml or .fpdevrc (TOML format)

[toolchain]
# FPC version (required)
fpc = "3.2.2"

# Lazarus version (optional)
lazarus = "3.8"

# Version channel (optional, overrides specific version)
# Possible values: stable, lts, trunk
channel = "stable"

[cross]
# Cross-compilation targets (optional)
targets = ["aarch64-linux", "x86_64-windows"]

[settings]
# Mirror source (optional)
# Possible values: auto, github, gitee, <custom-url>
mirror = "auto"

# Whether to auto-install missing versions (optional, default false)
auto_install = false
```

## Version Aliases

The following version aliases are supported:

| Alias | Description |
|-------|-------------|
| `stable` | Latest stable release (currently 3.2.2) |
| `lts` | Long-term support release (currently 3.2.0) |
| `trunk` | Development version (main branch) |
| `latest` | Same as stable |

Example:
```toml
[toolchain]
fpc = "stable"
lazarus = "lts"
```

## Configuration Priority

fpdev resolves configuration in the following priority order (highest to lowest):

1. **Environment variables** - `FPDEV_FPC_VERSION`, `FPDEV_LAZARUS_VERSION`
2. **Command-line arguments** - `--fpc-version`, `--lazarus-version`
3. **Project configuration** - `.fpdevrc` or `fpdev.toml`
4. **Global default** - `default_toolchain` in `~/.fpdev/config.json`
5. **System default** - Hardcoded `DEFAULT_FPC_VERSION`

## Shell Integration

### Automatic Version Switching

After enabling the shell hook, entering a directory containing `.fpdevrc` will automatically switch versions:

**Bash** (`~/.bashrc`):
```bash
eval "$(fpdev shell-hook bash)"
```

**Zsh** (`~/.zshrc`):
```zsh
eval "$(fpdev shell-hook zsh)"
```

**Fish** (`~/.config/fish/config.fish`):
```fish
fpdev shell-hook fish | source
```

### Manual Switching

```bash
# Use project configuration
fpdev use

# Use a specific version
fpdev use 3.2.2

# Temporary override (current shell only)
fpdev override 3.0.4

# Clear override
fpdev override --unset
```

## Example Scenarios

### Scenario 1: Simple Project

```
# .fpdevrc
3.2.2
```

### Scenario 2: Lazarus GUI Project

```toml
# fpdev.toml
[toolchain]
fpc = "3.2.2"
lazarus = "3.8"
```

### Scenario 3: Cross-Compilation Project

```toml
# fpdev.toml
[toolchain]
fpc = "3.2.2"

[cross]
targets = ["aarch64-linux", "arm-linux"]

[settings]
auto_install = true
```

### Scenario 4: CI Environment

```toml
# fpdev.toml
[toolchain]
channel = "stable"

[settings]
mirror = "gitee"
auto_install = true
```

## Relationship with config.json

| Item | .fpdevrc | config.json |
|------|----------|-------------|
| Scope | Project-level | User-level / Global |
| Version locking | Yes | No |
| Default version | No | Yes |
| Mirror settings | Yes | Yes |
| Installed versions | No | Yes |
| Repository configuration | No | Yes |

## Error Handling

When the version specified in `.fpdevrc` is not installed:

1. **auto_install = true**: Automatically downloads and installs
2. **auto_install = false**: Prompts the user to install
   ```
   Error: FPC 3.2.2 is not installed.

   To install it, run:
     fpdev fpc install 3.2.2

   Or enable auto-install in .fpdevrc:
     [settings]
     auto_install = true
   ```

## Version History

- v1.0 (2026-01-15): Initial version

---

*Document version: 1.0*
*Created: 2026-01-15*
