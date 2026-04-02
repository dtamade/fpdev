# FPDev Installation Guide

Complete installation guide for FPDev - FreePascal Development Environment Manager.

## System Requirements

### Supported Operating Systems
- **Windows**: Windows 7+ / Windows 10 or later
- **Linux**: Ubuntu 18.04+, Debian 10+, CentOS 8+, Fedora 30+
- **macOS**: macOS 10.12+ / macOS 10.14 (Mojave) or later

### Hardware Requirements
- **Minimum RAM**: 512MB (2GB recommended)
- **Recommended RAM**: 4GB+
- **Disk Space**:
  - FPDev itself: 100MB
  - Per FPC version: 200-500MB
  - Full installation (including FPC/Lazarus): 5GB+
- **Network**: Internet connection for downloads (optional with cache/offline mode)

### Dependencies

#### Windows
- **Git for Windows** (for source downloads)
- **MSYS2** or **MinGW-w64** (for build tools)

#### Linux
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install git build-essential curl wget

# CentOS/RHEL/Fedora
sudo dnf install git gcc gcc-c++ make curl wget
# Or (CentOS 7)
sudo yum install git gcc gcc-c++ make curl wget
```

#### macOS
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew (recommended)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install git wget
```

## Installation Methods

### Method 1: Pre-built Binaries (Recommended)

> Keep the release layout intact: `fpdev` / `fpdev.exe` must stay next to the bundled `data/` directory so the portable release can run correctly.

#### Windows
1. Download the latest release:
   ```powershell
   # Using PowerShell
   Invoke-WebRequest -Uri "https://github.com/fpdev/fpdev/releases/download/v2.1.0/fpdev-windows-x64.zip" -OutFile "fpdev-windows-x64.zip"
   New-Item -ItemType Directory -Force -Path "C:\fpdev" | Out-Null
   Expand-Archive -Path "fpdev-windows-x64.zip" -DestinationPath "C:\fpdev" -Force
   ```

2. Add to PATH:
   ```powershell
   # Temporary (current session)
   $env:PATH += ";C:\fpdev"

   # Permanent (requires administrator privileges)
   [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\fpdev", "Machine")
   ```

3. Verify installation:
   ```cmd
   fpdev system version
   ```

#### Linux
1. Download and install:
   ```bash
   # Download
   wget https://github.com/fpdev/fpdev/releases/download/v2.1.0/fpdev-linux-x64.tar.gz

   # Keep fpdev and data/ together
   mkdir -p ~/.local/opt/fpdev
   tar -xzf fpdev-linux-x64.tar.gz -C ~/.local/opt/fpdev

   # Add the extracted directory to PATH
   export PATH="$HOME/.local/opt/fpdev:$PATH"
   ```

2. Verify installation:
   ```bash
   fpdev system version
   ```

#### macOS
1. Download and install:
   ```bash
   # Download
   curl -L -o fpdev-macos-<arch>.tar.gz https://github.com/fpdev/fpdev/releases/download/v2.1.0/fpdev-macos-<arch>.tar.gz

   # Keep fpdev and data/ together
   mkdir -p "$HOME/Applications/fpdev"
   tar -xzf fpdev-macos-<arch>.tar.gz -C "$HOME/Applications/fpdev"

   # Add the extracted directory to PATH
   export PATH="$HOME/Applications/fpdev:$PATH"
   ```

2. Replace `<arch>` with `x64` or `arm64`

3. On first run, you may need to allow execution in "System Preferences > Security & Privacy"

### Method 2: Build from Source

#### Prerequisites
- FreePascal compiler (FPC 3.2.0+)
- Git

#### Build Steps
```bash
# Clone the repository
git clone https://github.com/fpdev/fpdev.git
cd fpdev

# Build
lazbuild -B --build-mode=Release fpdev.lpi

# Verify
./bin/fpdev system version
```

### Method 3: Package Manager Channel Status

There are no published Homebrew, Chocolatey, Snap, or APT channels yet.

Until those channels exist, use one of the supported paths above:
- Method 1: GitHub Release pre-built binaries
- Method 2: Build from source

## Configuration

### Initial Configuration
```bash
# Create the default configuration file
fpdev system config show

# Default config file location for the portable release:
# <install-dir>/data/config.json
#
# If you explicitly set FPDEV_DATA_ROOT, the config file moves to:
# $FPDEV_DATA_ROOT/config.json
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FPDEV_DATA_ROOT` | Override the FPDev data root (config, cache, logs, locks) | `<install-dir>/data` for the portable release |

### Proxy Configuration
```bash
# Set HTTP proxy
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# Set Git proxy
git config --global http.proxy http://proxy.example.com:8080
```

## Verifying Installation

### Basic Functionality Test
```bash
# Check version
fpdev system version

# Show help
fpdev system help

# List available FPC versions
fpdev fpc list --all

# Create a test project
fpdev project new console test-app
cd test-app
```

### Running the Test Suite
```bash
# If installed from source, you can run tests
cd fpdev/src
fpc -Fu. ../tests/test_config_management.lpr
../tests/test_config_management
```

## Troubleshooting

### Common Issues

#### 1. "fpdev: command not found"
**Cause**: PATH environment variable not set correctly.
**Solution**:
```bash
# Check fpdev location
which fpdev

# Add to PATH
export PATH="/path/to/fpdev:$PATH"

# Permanently add to shell configuration
echo 'export PATH="/path/to/fpdev:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 2. Permission Error (Linux/macOS)
**Cause**: Missing execute permission.
**Solution**:
```bash
chmod +x /path/to/fpdev
```

#### 3. Windows Security Warning
**Cause**: Windows Defender or antivirus false positive.
**Solution**:
- Add fpdev to your antivirus whitelist
- Add an exclusion in Windows Defender

#### 4. Network Connection Issues
**Cause**: Firewall or proxy settings.
**Solution**:
```bash
# Test network connectivity
curl -I https://gitlab.com/freepascal.org/fpc/source.git

# Configure proxy (if needed)
export HTTP_PROXY=http://your-proxy:port
```

#### 5. Git-Related Errors
**Cause**: Git not installed or not configured correctly.
**Solution**:
```bash
# Check Git installation
git --version

# Configure Git (first-time use)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Logging and Debugging

#### Log File Locations
- **Portable release default**: `<install-dir>/data/logs/`
- **If `FPDEV_DATA_ROOT` is set**: `$FPDEV_DATA_ROOT/logs/`
- **Non-portable runs (for example, from source builds)**:
  - Windows: `%APPDATA%\\fpdev\\logs\\`
  - Linux/macOS: `$XDG_DATA_HOME/fpdev/logs/` or `~/.fpdev/logs/`

### Getting Help

If you encounter issues, you can get help through the following channels:

1. **Documentation**: https://fpdev.github.io/docs
2. **GitHub Issues**: https://github.com/fpdev/fpdev/issues
3. **Community Forum**: https://discord.gg/fpdev
4. **Email Support**: support@fpdev.org

## Uninstallation

### Complete Uninstall
```bash
# Remove the full portable release directory (fpdev plus the sibling data/)
rm -rf ~/.local/opt/fpdev          # Linux example
rm -rf "$HOME/Applications/fpdev"  # macOS example
# Or delete C:\fpdev\              # Windows example

# If you explicitly set FPDEV_DATA_ROOT, you can remove that directory too
rm -rf "$FPDEV_DATA_ROOT"

# Remove from PATH (if manually added)
# Edit ~/.bashrc or the appropriate shell config file
```

## Performance Optimization

### Build Performance
```bash
# Move mutable data (config, cache, logs) onto SSD storage
export FPDEV_DATA_ROOT=/fast/ssd/fpdev-data
mkdir -p "$FPDEV_DATA_ROOT"
```

To adjust the parallel build count, edit `settings.parallel_jobs` in the active `config.json` under the current data root.

### Network Optimization
```bash
# Use mirror sources (for users in China)
fpdev system config set mirror gitee
```

---

After installation, refer to the [Quick Start Guide](QUICKSTART.en.md) for basic usage instructions.
