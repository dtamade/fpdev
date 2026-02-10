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

#### Windows
1. Download the latest release:
   ```powershell
   # Using PowerShell
   Invoke-WebRequest -Uri "https://github.com/fpdev/fpdev/releases/download/v1.0.0/fpdev-windows-x64.zip" -OutFile "fpdev.zip"
   Expand-Archive -Path "fpdev.zip" -DestinationPath "C:\fpdev"
   ```

2. Add to PATH:
   ```powershell
   # Temporary (current session)
   $env:PATH += ";C:\fpdev\bin"

   # Permanent (requires administrator privileges)
   [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\fpdev\bin", "Machine")
   ```

3. Verify installation:
   ```cmd
   fpdev --version
   ```

#### Linux
1. Download and install:
   ```bash
   # Download
   wget https://github.com/fpdev/fpdev/releases/download/v1.0.0/fpdev-linux-x64.tar.gz

   # Extract
   tar -xzf fpdev-linux-x64.tar.gz

   # Install to system directory
   sudo mv fpdev /usr/local/bin/

   # Or install to user directory
   mkdir -p ~/.local/bin
   mv fpdev ~/.local/bin/
   export PATH="$HOME/.local/bin:$PATH"
   ```

2. Verify installation:
   ```bash
   fpdev --version
   ```

#### macOS
1. Download and install:
   ```bash
   # Download
   curl -L -o fpdev-macos.tar.gz https://github.com/fpdev/fpdev/releases/download/v1.0.0/fpdev-macos-x64.tar.gz

   # Extract
   tar -xzf fpdev-macos.tar.gz

   # Install
   sudo mv fpdev /usr/local/bin/
   ```

2. On first run, you may need to allow execution in "System Preferences > Security & Privacy"

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
cd src
fpc -FE../bin fpdev.lpr

# Verify
../bin/fpdev --version
```

### Method 3: Package Manager Installation (Planned)

```bash
# Homebrew (macOS)
brew install fpdev

# Chocolatey (Windows)
choco install fpdev

# Snap (Linux)
sudo snap install fpdev

# APT (Ubuntu/Debian)
sudo apt install fpdev
```

## Configuration

### Initial Configuration
```bash
# Create default configuration
fpdev help

# Config file locations:
# Windows: %USERPROFILE%\.fpdev\config.json
# Linux/macOS: ~/.fpdev/config.json
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FPDEV_HOME` | FPDev installation root directory | `~/.fpdev` |
| `FPDEV_CONFIG` | Config file path | `$FPDEV_HOME/config.json` |
| `FPDEV_PARALLEL_JOBS` | Number of parallel build jobs | Number of CPU cores |

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
fpdev --version

# Show help
fpdev help

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

#### Enable Verbose Logging
```bash
# Set environment variables
export FPDEV_DEBUG=1
export FPDEV_VERBOSE=1

# Run command
fpdev fpc install 3.2.2 --from-source
```

#### Log File Locations
- **Windows**: `%USERPROFILE%\.fpdev\logs\`
- **Linux/macOS**: `~/.fpdev/logs/`

### Getting Help

If you encounter issues, you can get help through the following channels:

1. **Documentation**: https://fpdev.github.io/docs
2. **GitHub Issues**: https://github.com/fpdev/fpdev/issues
3. **Community Forum**: https://discord.gg/fpdev
4. **Email Support**: support@fpdev.org

## Uninstallation

### Complete Uninstall
```bash
# Remove FPDev binary
sudo rm /usr/local/bin/fpdev  # Linux/macOS
# Or delete C:\fpdev\  # Windows

# Remove configuration and data (optional)
rm -rf ~/.fpdev  # Linux/macOS
# Or delete %USERPROFILE%\.fpdev  # Windows

# Remove from PATH (if manually added)
# Edit ~/.bashrc or the appropriate shell config file
```

## Performance Optimization

### Build Performance
```bash
# Set number of parallel build jobs
export FPDEV_PARALLEL_JOBS=8

# Use SSD storage
# Set FPDEV_HOME to an SSD partition
export FPDEV_HOME=/fast/ssd/fpdev
```

### Network Optimization
```bash
# Use mirror sources (for users in China)
fpdev config set mirror.fpc https://mirrors.tuna.tsinghua.edu.cn/freepascal
fpdev config set mirror.lazarus https://mirrors.tuna.tsinghua.edu.cn/lazarus
```

---

After installation, refer to the [Quick Start Guide](QUICKSTART.en.md) for basic usage instructions.
