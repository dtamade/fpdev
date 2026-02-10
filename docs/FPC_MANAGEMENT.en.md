# FPC Version Management Documentation

## Overview

FPDev's FPC version management provides complete FreePascal compiler lifecycle management, including version installation, switching, uninstallation, and more.

## Features

### Version Management
- **Multiple versions**: Support for installing multiple FPC versions simultaneously
- **Version switching**: Quickly switch the default FPC version
- **Version info**: View detailed version information and installation status

### Installation Methods
- **Source install**: Automatically download source code from Git repositories and compile
- **Pre-built packages**: Support for pre-built binary package installation
- **Custom repositories**: Support installation from custom Git repositories

### Build System
- **Parallel compilation**: Multi-core parallel compilation for faster builds
- **Dependency management**: Automatic build dependency and environment configuration
- **Error handling**: Comprehensive error handling and recovery mechanisms

## Supported Versions

| Version | Status | Release Date | Git Branch | Notes |
|---------|--------|-------------|------------|-------|
| 3.2.2 | Stable | 2021-05-19 | fixes_3_2 | Current recommended version |
| 3.2.0 | Stable | 2020-06-08 | fixes_3_2 | Long-term support version |
| 3.0.4 | Stable | 2017-11-30 | fixes_3_0 | Legacy support |
| 3.0.2 | Stable | 2017-01-15 | fixes_3_0 | Legacy support |
| main | Development | Continuously updated | main | Latest development version |

## Command Reference

### Basic Commands

```bash
# Show help
fpdev fpc

# List installed versions
fpdev fpc list

# List all available versions
fpdev fpc list --all

# Show current default version
fpdev fpc current
```

### Installation Management

```bash
# Install FPC 3.2.2 from source
fpdev fpc install 3.2.2 --from-source

# Install development version
fpdev fpc install main --from-source

# Uninstall a specific version
fpdev fpc uninstall 3.2.2
```

### Version Switching

```bash
# Set default version
fpdev fpc default 3.2.2

# View version information
fpdev fpc info 3.2.2

# Test installation
fpdev fpc test 3.2.2
```

### Source Management

```bash
# Update source code
fpdev fpc update 3.2.2

# Clean source artifacts
fpdev fpc clean 3.2.2
```

## Installation Workflow

### Building from Source

1. **Download source code**
   ```bash
   git clone --depth 1 --branch <tag> https://gitlab.com/freepascal.org/fpc/source.git
   ```

2. **Compile source**
   ```bash
   make all install PREFIX=<install_path> -j<parallel_jobs>
   ```

3. **Configure environment**
   - Update configuration file
   - Set environment variables
   - Verify installation

### Directory Structure

```
~/.fpdev/
├── config.json          # Configuration file
├── fpc/                  # FPC installation directory
│   ├── 3.2.2/           # FPC 3.2.2 installation
│   │   ├── bin/         # Executables
│   │   ├── lib/         # Libraries
│   │   └── units/       # Unit files
│   └── main/            # Development version installation
└── sources/             # Source code directory
    ├── fpc-3.2.2/       # FPC 3.2.2 source
    └── fpc-main/        # Development version source
```

## Configuration Management

### Toolchain Configuration

FPC version information is stored in the configuration file:

```json
{
  "toolchains": {
    "fpc-3.2.2": {
      "type": "release",
      "version": "3.2.2",
      "install_path": "/home/user/.fpdev/fpc/3.2.2",
      "source_url": "https://gitlab.com/freepascal.org/fpc/source.git",
      "branch": "fixes_3_2",
      "installed": true,
      "install_date": "2024-01-15T10:30:00Z"
    }
  },
  "default_toolchain": "fpc-3.2.2"
}
```

### Environment Variables

After installation, FPDev automatically configures the following environment variables:

- `FPCDIR`: FPC installation directory
- `PATH`: Adds FPC executable path
- `FPCVERSION`: Current FPC version

## Error Handling

### Common Issues

1. **Build failure**
   - Check system dependencies (make, git, gcc)
   - Ensure sufficient disk space
   - Check network connectivity

2. **Permission issues**
   - Ensure write access to the installation directory
   - Administrator privileges may be required on Windows

3. **Version conflicts**
   - Use `fpdev fpc list` to check installed versions
   - Use `fpdev fpc default` to switch versions

### Logging and Diagnostics

- Build logs are saved in the temporary directory
- Use `fpdev fpc test <version>` to verify installation
- Check the configuration file at `~/.fpdev/config.json`

## Best Practices

### Version Selection

1. **Production**: Use stable versions (e.g., 3.2.2)
2. **Development/Testing**: Development versions (main) are acceptable
3. **Compatibility**: Choose the appropriate version based on project requirements

### Disk Management

1. **Regular cleanup**: Remove unneeded versions
2. **Source management**: Use `--keep-sources=false` to save space
3. **Parallel builds**: Set `parallel_jobs` based on CPU core count

### Security Considerations

1. **Source verification**: Only download source from official repositories
2. **Permission control**: Use minimum necessary permissions
3. **Backup configuration**: Regularly back up the configuration file

## API Interface

### TFPCManager Class

```pascal
TFPCManager = class
  // Version management
  function InstallVersion(const AVersion: string; const AFromSource: Boolean = False): Boolean;
  function UninstallVersion(const AVersion: string): Boolean;
  function ListVersions(const AShowAll: Boolean = False): Boolean;
  function SetDefaultVersion(const AVersion: string): Boolean;
  function GetCurrentVersion: string;

  // Source management
  function UpdateSources(const AVersion: string = ''): Boolean;
  function CleanSources(const AVersion: string = ''): Boolean;

  // Toolchain operations
  function ShowVersionInfo(const AVersion: string): Boolean;
  function TestInstallation(const AVersion: string): Boolean;
end;
```

### Usage Example

```pascal
var
  ConfigManager: TFPDevConfigManager;
  FPCManager: TFPCManager;
begin
  ConfigManager := TFPDevConfigManager.Create;
  try
    FPCManager := TFPCManager.Create(ConfigManager);
    try
      // Install FPC 3.2.2
      if FPCManager.InstallVersion('3.2.2', True) then
        WriteLn('Installation successful');

      // Set as default version
      FPCManager.SetDefaultVersion('3.2.2');

      // Test installation
      FPCManager.TestInstallation('3.2.2');

    finally
      FPCManager.Free;
    end;
  finally
    ConfigManager.Free;
  end;
end;
```

## Extension Development

### Adding New Versions

1. Update the `FPC_RELEASES` constant array
2. Add corresponding Git tags and branch information
3. Test the installation and build workflow

### Custom Repositories

1. Modify the `FPC_OFFICIAL_REPO` constant
2. Or add a custom repository in the configuration file
3. Ensure the repository structure is compatible

### Platform Support

1. Add platform-specific compilation options
2. Handle platform-related paths and permissions
3. Test cross-platform compatibility

## Future Plans

- [ ] Pre-built package support
- [ ] Incremental update mechanism
- [ ] GUI interface integration
- [ ] Cloud synchronization
- [ ] Plugin system support
