# FPDev Quick Start Guide

## 🚀 Get Started in 5 Minutes

This guide will help you set up FPDev and create your first project in just 5 minutes.

## 📋 Prerequisites

Make sure you have completed [installation](INSTALLATION.md) and can run:
```bash
fpdev system version
```

## 🎯 Step 1: Verify Installation

```bash
# Show help information
fpdev system help

# List available FPC versions
fpdev fpc list --all

# List available Lazarus versions
fpdev lazarus list --all
```

## 🔧 Step 2: Install Development Environment

### Install FPC (FreePascal Compiler)

```bash
# Install recommended version FPC 3.2.2 (binary-first)
fpdev fpc install 3.2.2

# Use source builds when needed
fpdev fpc install 3.2.2 --from-source

# Set as default version
fpdev fpc use 3.2.2

# Verify installation
fpdev fpc current
```

**Note**: Binary installation is usually faster; building from source may take 10-30 minutes, so use it only when needed.

### Install Lazarus IDE (Optional)

```bash
# Install Lazarus 3.0
fpdev lazarus install 3.0 --from-source

# Set as default version
fpdev lazarus use 3.0

# Verify installation
fpdev lazarus current
```

## 🚀 Step 3: Create Your First Project

### Create a Console Application

```bash
# Create a new console project
fpdev project new console hello-world

# Enter project directory
cd hello-world

# View generated files
ls -la
# Should see: hello-world.lpr
```

### View Generated Code

```pascal
// hello-world.lpr
program hello_world;

{$mode objfpc}{$H+}

uses
  SysUtils;

begin
  WriteLn('Hello from hello-world!');
end.
```

### Build and Run Project

```bash
# Build project
fpdev project build

# Run project (if build successful)
./hello-world        # Linux/macOS
# or
hello-world.exe      # Windows
```

## 🎨 Step 4: Try Other Project Types

### GUI Application

```bash
# Create GUI project
fpdev project new gui my-gui-app
cd my-gui-app

# View project structure
ls -la
# Should see: my-gui-app.lpr, my-gui-app.lpi
```

### Web Application

```bash
# Create web application
fpdev project new webapp my-web-app
cd my-web-app
```

### View All Available Templates

```bash
# List all project templates
fpdev project list

# View specific template info
fpdev project info console
fpdev project info gui
```

## 📦 Step 5: Package Management

### Install Packages

```bash
# List installed packages
fpdev package list

# Search packages
fpdev package search synapse

# Install package
fpdev package install synapse
```

### Manage Repositories

```bash
# Add package repository
fpdev package repo add custom https://example.com/packages

# List repositories
fpdev package repo list
```

## 🌐 Step 6: Cross-Compilation (Advanced)

### Install Cross-Compilation Target

```bash
# List available cross-compilation targets
fpdev cross list --all

# Install Windows 64-bit target (on Linux/macOS)
fpdev cross install x86_64-win64

# Configure toolchain paths (requires manual toolchain installation)
fpdev cross configure x86_64-win64 \
  --binutils=/usr/x86_64-w64-mingw32/bin \
  --libraries=/usr/x86_64-w64-mingw32/lib
```

### Cross-Compile Project

```bash
# Build for specific target
fpdev project build . win64
```

## 🛠️ Command Quick Reference

### FPC Management
```bash
fpdev fpc install <version> [--from-source]    # Install version
fpdev fpc list [--all]                         # List versions
fpdev fpc use <version>                        # Switch to a version
fpdev fpc current                              # Current version
fpdev fpc uninstall <version>                  # Uninstall version
```

### Lazarus Management
```bash
fpdev lazarus install <version> [--from-source]  # Install version
fpdev lazarus run [version]                      # Launch IDE
fpdev lazarus list [--all]                       # List versions
fpdev lazarus use <version>                    # Switch to a version
```

### Project Management
```bash
fpdev project new <template> <name> [dir]        # Create project
fpdev project list                               # List templates
fpdev project build [dir] [target]               # Build project
fpdev project info <template>                    # Template info
```

### Package Management
```bash
fpdev package install <package>                  # Install package
fpdev package list [--all]                       # List packages
fpdev package repo add <name> <url>              # Add repository
```

### Cross-Compilation
```bash
fpdev cross install <target>                     # Install target
fpdev cross list [--all]                         # List targets
fpdev cross configure <target> --binutils=<path> --libraries=<path>
```

## 📁 Project Structure Best Practices

### Recommended Project Structure

```
my-project/
├── src/                    # Source code
│   ├── my-project.lpr     # Main program
│   ├── units/             # Unit files
│   └── forms/             # Form files (GUI projects)
├── tests/                 # Test code
├── docs/                  # Documentation
├── bin/                   # Compiled output
├── lib/                   # Library files
└── README.md              # Project description
```

### Configuration Files

FPDev stores its configuration file as `config.json` under the active data root:
- **Default portable release location**: `<install-dir>/data/config.json`
- **If `FPDEV_DATA_ROOT` is set explicitly**: `$FPDEV_DATA_ROOT/config.json`

In other words, for the quick-start portable setup you will usually edit `data/config.json` next to the `fpdev` executable.

## 🔧 Configuration Optimization

### Performance Optimization

```bash
# Move config, cache, and logs onto faster storage if needed
export FPDEV_DATA_ROOT=/fast/ssd/fpdev-data
mkdir -p "$FPDEV_DATA_ROOT"

# Enable source caching (speed up repeated installations)
fpdev system config set keep_sources true
```

To change the parallel build count, edit `settings.parallel_jobs` in the active `config.json` instead of relying on an extra environment variable.

### Network Optimization

```bash
# Set proxy (if needed)
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# Use mirror source (for users in China)
fpdev system config set mirror gitee
```

## 🐛 Common Issues

### Q: Build failed, what should I do?
A: Check the following:
1. Ensure necessary build tools are installed (gcc, make, etc.)
2. Check network connection
3. Re-run `fpdev fpc install 3.2.2 --from-source` and inspect the active data root's `logs/` directory

### Q: How to switch FPC versions?
A: Use `fpdev fpc use <version>` command

### Q: How to launch a specific Lazarus version?
A: Use `fpdev lazarus run <version>` command

### Q: Project build failed?
A: Ensure:
1. Current directory contains project files (.lpr or .lpi)
2. Corresponding FPC version is installed
3. Project code syntax is correct

## 📚 Next Steps

Now that you've mastered the basics of FPDev, you can:

1. 📖 Read [full documentation](API.md) to learn all features
2. 🏗️ Check [architecture docs](ARCHITECTURE.md) to understand internal design
3. 🤝 Join [community discussions](https://discord.gg/fpdev)
4. 🐛 [Report issues](https://github.com/fpdev/fpdev/issues) or suggestions

## 💡 Tips

1. **Use Tab completion**: Most shells support command completion
2. **View help**: Add `--help` after any command for detailed help
3. **Stay updated**: Use `fpdev system version` to check your local version, and review release notes regularly
4. **Backup config**: Important projects should back up the active data root, such as the portable release `data/` directory or the path pointed to by `FPDEV_DATA_ROOT`

---

🎉 Congratulations! You're now ready to use FPDev. Enjoy the modern FreePascal development experience!
