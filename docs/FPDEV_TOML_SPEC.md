# .fpdev.toml Configuration Format Specification

## Overview

`.fpdev.toml` is a project-level configuration file that defines the FreePascal toolchain, components, and build settings for a project. It enables automatic version switching and reproducible builds across different environments.

## File Location

- **Project root**: `.fpdev.toml` (recommended)
- **Alternative**: `fpdev.toml` (without leading dot)

## Format

TOML (Tom's Obvious, Minimal Language) - https://toml.io/

## Schema

### [toolchain] Section

Defines the FPC toolchain version and installation source.

```toml
[toolchain]
version = "3.2.2"           # Required: FPC version (semantic version)
source = "binary"           # Optional: "binary" (default) or "source"
channel = "stable"          # Optional: "stable" (default), "fixes", "main"
```

**Fields**:
- `version` (string, required): FPC version in semantic versioning format (major.minor.patch)
- `source` (string, optional): Installation source
  - `"binary"`: Install from pre-built binaries (default, fast)
  - `"source"`: Build from source (slower, customizable)
- `channel` (string, optional): Release channel
  - `"stable"`: Official stable releases (default)
  - `"fixes"`: Bug fix branch (e.g., fixes_3_2)
  - `"main"`: Development branch (bleeding edge)

### [components] Section

Defines FPC components to install.

```toml
[components]
rtl = true                  # Runtime Library (always required)
fcl = true                  # Free Component Library
packages = ["synapse", "indy", "zeos"]  # Additional packages
```

**Fields**:
- `rtl` (boolean, optional): Runtime Library (default: true, always installed)
- `fcl` (boolean, optional): Free Component Library (default: true)
- `packages` (array of strings, optional): Additional FPC packages to install

**Available packages**: See `fpdev package list --all` for full list.

### [targets] Section

Defines cross-compilation targets.

```toml
[targets]
cross = ["win64", "linux-arm", "darwin-x86_64"]
```

**Fields**:
- `cross` (array of strings, optional): Cross-compilation target platforms

**Available targets**: See `fpdev cross list --all` for full list.

**Common targets**:
- `win32`, `win64` - Windows 32/64-bit
- `linux-x86_64`, `linux-arm`, `linux-aarch64` - Linux variants
- `darwin-x86_64`, `darwin-aarch64` - macOS Intel/Apple Silicon

### [build] Section

Defines build settings and compiler options.

```toml
[build]
mode = "release"            # Build mode: "debug" or "release"
optimization = "2"          # Optimization level: "0", "1", "2", "3"
target-cpu = "x86_64"       # Target CPU architecture
custom-options = ["-dUSE_FEATURE_X", "-Fu/path/to/units"]
```

**Fields**:
- `mode` (string, optional): Build mode
  - `"debug"`: Debug build with symbols (default)
  - `"release"`: Optimized release build
- `optimization` (string, optional): Optimization level (0-3, default: "2" for release, "0" for debug)
- `target-cpu` (string, optional): Target CPU architecture (default: host CPU)
- `custom-options` (array of strings, optional): Additional FPC compiler options

### [lazarus] Section

Defines Lazarus IDE integration settings.

```toml
[lazarus]
version = "3.0"             # Lazarus version
auto-configure = true       # Auto-configure IDE on version switch
```

**Fields**:
- `version` (string, optional): Lazarus IDE version
- `auto-configure` (boolean, optional): Automatically configure IDE when switching FPC versions (default: false)

### [project] Section

Defines project metadata.

```toml
[project]
name = "myapp"              # Project name
type = "console"            # Project type: "console", "gui", "library"
main = "src/myapp.lpr"      # Main program file
```

**Fields**:
- `name` (string, optional): Project name (default: directory name)
- `type` (string, optional): Project type
  - `"console"`: Console application (default)
  - `"gui"`: GUI application
  - `"library"`: Dynamic library
- `main` (string, optional): Main program file path (default: `<name>.lpr`)

## Complete Example

```toml
# .fpdev.toml - FPDev Project Configuration

[toolchain]
version = "3.2.2"
source = "binary"
channel = "stable"

[components]
rtl = true
fcl = true
packages = ["synapse", "indy", "fcl-json"]

[targets]
cross = ["win64", "linux-arm"]

[build]
mode = "release"
optimization = "2"
target-cpu = "x86_64"
custom-options = ["-dUSE_SSL", "-Fu../lib"]

[lazarus]
version = "3.0"
auto-configure = true

[project]
name = "myapp"
type = "console"
main = "src/myapp.lpr"
```

## Minimal Example

```toml
# Minimal .fpdev.toml

[toolchain]
version = "3.2.2"
```

## Usage Workflow

1. **Create configuration**:
   ```bash
   # Manual creation
   echo '[toolchain]\nversion = "3.2.2"' > .fpdev.toml
   
   # Or use fpdev init (future feature)
   fpdev init --fpc=3.2.2
   ```

2. **Auto-install toolchain**:
   ```bash
   fpdev fpc auto-install
   # Reads .fpdev.toml and installs FPC 3.2.2 with specified components
   ```

3. **Auto-switch on directory change**:
   ```bash
   cd myproject
   # Shell hook detects .fpdev.toml and switches to FPC 3.2.2
   ```

4. **Verify configuration**:
   ```bash
   fpdev fpc current
   # Output: FPC 3.2.2 (from .fpdev.toml)
   ```

## Validation Rules

1. **Required fields**:
   - `[toolchain].version` is mandatory

2. **Version format**:
   - Must be semantic version: `major.minor.patch` (e.g., "3.2.2")
   - No "v" prefix

3. **Source values**:
   - Must be "binary" or "source"

4. **Channel values**:
   - Must be "stable", "fixes", or "main"

5. **Build mode values**:
   - Must be "debug" or "release"

6. **Optimization values**:
   - Must be "0", "1", "2", or "3"

7. **Package names**:
   - Must match available packages in registry
   - Case-insensitive

8. **Cross targets**:
   - Must match available targets in manifest
   - Format: `<os>-<arch>` or `<os><bits>` (e.g., "linux-arm", "win64")

## Error Handling

When `.fpdev.toml` is invalid:

1. **Parse errors**: Show line number and TOML syntax error
2. **Validation errors**: Show field name and expected format
3. **Missing version**: Error with suggestion to add `[toolchain].version`
4. **Unknown package**: Warning with suggestion to run `fpdev package search`
5. **Unknown target**: Warning with suggestion to run `fpdev cross list --all`

## Future Extensions

Potential future additions (not in initial implementation):

```toml
[dependencies]
# Package dependencies (Week 8 integration)
mylib = "1.0.0"
otherlib = { version = "2.0", source = "git", url = "https://..." }

[scripts]
# Custom build scripts
prebuild = "scripts/prebuild.sh"
postbuild = "scripts/postbuild.sh"

[env]
# Environment variables
PATH = "/custom/path:$PATH"
FPC_CONFIG = "/custom/fpc.cfg"
```

## Implementation Notes

1. **Parser**: Use existing TOML parser library or implement minimal parser
2. **Validation**: Validate on load, fail fast with clear error messages
3. **Defaults**: Apply sensible defaults for optional fields
4. **Backward compatibility**: Ignore unknown sections/fields (forward compatibility)
5. **File watching**: Detect changes to `.fpdev.toml` for auto-reload (future feature)

## Related Commands

- `fpdev fpc auto-install` - Install toolchain from `.fpdev.toml`
- `fpdev auto-switch` - Switch version based on `.fpdev.toml`
- `fpdev init -` - Generate shell hook for auto-switching
- `fpdev system config validate` - Validate `.fpdev.toml` syntax and values (future)

---

**Version**: 1.0
**Last Updated**: 2026-01-30
**Status**: Draft Specification
