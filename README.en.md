<div align="center">

![FPDev Logo](https://via.placeholder.com/200x100/4CAF50/FFFFFF?text=FPDev)

**Modern FreePascal and Lazarus Development Environment Manager**

[![Release](https://img.shields.io/badge/release-v2.1.0-blue.svg)](https://github.com/fpdev/fpdev/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

<!-- TEST-INVENTORY-BADGE:BEGIN -->
[![Tests](https://img.shields.io/badge/tests-274%20discoverable-brightgreen.svg)](#testing)
<!-- TEST-INVENTORY-BADGE:END -->

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](#installation)

[Quick Start](#-quick-start) • [Installation](docs/INSTALLATION.en.md) • [FAQ](docs/FAQ.en.md) • [Documentation](docs/QUICKSTART.en.md)

</div>

---

## 🎯 Overview

**FPDev** is a modern FreePascal development environment manager similar to Rust's `rustup`, providing a complete toolchain management solution for FreePascal and Lazarus developers.

### ✨ Key Features

- 🔧 **Multi-version Management**: FPC and Lazarus multi-version coexistence with one-click switching
- 🌐 **Cross-compilation**: Support for 12 mainstream platform cross-compilation toolchains
- 📦 **Package Management**: npm/cargo-like package management experience
- 🚀 **Project Templates**: 7 built-in project templates for quick standardized project creation
- ⚙️ **Unified Configuration**: JSON format configuration files with type-safe access
- 🏗️ **Source Building**: Automatic download and compilation from Git repositories

### 📊 Project Status

```
[INFO] Feature checklist: closed for v2.1.0 scope
[INFO] Linux release evidence: recorded
[INFO] Discoverable test programs: 274 (same inventory rules as CI)
[INFO] Documentation set: published user and developer docs
[INFO] Platform targets: Windows, Linux, macOS
[INFO] Release sign-off: public CI release-proof bundle required before publish
```

---

## 🚀 Quick Start

### 1. Install FPDev

```bash
# Build from source (recommended)
git clone https://github.com/fpdev/fpdev.git
cd fpdev
bash scripts/build_release.sh
./bin/fpdev system version
```

### 2. Install FPC Compiler

```bash
# Install FPC 3.2.2 (binary installation, fast)
fpdev fpc install 3.2.2

# Or compile from source (customizable, takes 10-30 minutes)
fpdev fpc install 3.2.2 --from-source

# Set as default version
fpdev fpc use 3.2.2
```

### 3. Create Your First Project

```bash
# Create console application
fpdev project new console hello-world
cd hello-world

# Build project
fpdev project build

# Run project
./hello-world        # Linux/macOS
hello-world.exe      # Windows
```

**That's it!** 🎉

---

## 🛠️ Core Features

### FPC Version Management

```bash
fpdev fpc install 3.2.2              # Install version
fpdev fpc list                       # List installed versions
fpdev fpc list --json                # JSON output
fpdev fpc use 3.2.2                  # Switch version
fpdev fpc current                    # Show current version
fpdev fpc status                     # Show managed status
fpdev fpc verify 3.2.2               # Verify installation
```

### Lazarus IDE Management

```bash
fpdev lazarus install 3.0 --from-source  # Install Lazarus
fpdev lazarus run                         # Launch IDE
fpdev lazarus configure 3.0               # Configure IDE
```

### Cross-compilation

```bash
fpdev cross list --all                # List supported platforms
fpdev cross install x86_64-win64      # Install cross-compilation target
fpdev cross configure x86_64-win64 --binutils=/path --libraries=/path
fpdev cross list --json               # JSON output
```

### Package Management

```bash
fpdev package install synapse         # Install package
fpdev package list --all              # List packages
fpdev package search json --json      # Search packages (JSON)
```

### Project Management

```bash
fpdev project new console myapp       # Create console app
fpdev project new gui myapp           # Create GUI app
fpdev project list --json             # List templates (JSON)
fpdev project build                   # Build project
```

### System Diagnostics

```bash
fpdev system doctor                   # Run diagnostics
fpdev system doctor --json            # JSON output
fpdev system doctor --quick           # Quick check
```

---

## 📦 Shell Completion

### Bash

```bash
source scripts/completions/fpdev.bash
```

### Zsh

```bash
fpath=(~/.zsh/completions $fpath)
cp scripts/completions/_fpdev ~/.zsh/completions/
autoload -Uz compinit && compinit
```

---

## 🎯 Why FPDev?

| Feature               | FPDev                      | Traditional                |
| --------------------- | -------------------------- | -------------------------- |
| **Multi-version**     | ✅ One-click switch        | ❌ Manual PATH config      |
| **Source build**      | ✅ Auto download & compile | ❌ Manual steps            |
| **Cross-compile**     | ✅ Auto toolchain setup    | ❌ Manual binutils install |
| **Package mgmt**      | ✅ npm/cargo-like          | ❌ Manual download         |
| **Project templates** | ✅ 7 built-in              | ❌ Start from scratch      |
| **Configuration**     | ✅ JSON, type-safe         | ❌ Scattered files         |

---

## 🧪 Testing

FPDev follows **TDD (Test-Driven Development)** and keeps the test inventory aligned with repo docs and CI:

<!-- TEST-INVENTORY-SUMMARY:BEGIN -->
✅ 274 discoverable test_*.lpr programs (same rules as CI)
<!-- TEST-INVENTORY-SUMMARY:END -->

Run tests:

```bash
bash scripts/run_all_tests.sh
```

Check the full test layout and sync workflow in [the testing guide](docs/testing.md).

Check release gates, owner checkpoints, and close-out status in [Release Acceptance Criteria](docs/MVP_ACCEPTANCE_CRITERIA.en.md).

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

See [CLAUDE.md](CLAUDE.md) for coding guidelines and architecture.

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file.

---

## 🙏 Acknowledgements

- [FreePascal](https://www.freepascal.org/) - Excellent Pascal compiler
- [Lazarus](https://www.lazarus-ide.org/) - Powerful IDE
- [libgit2](https://libgit2.org/) - Git operations library
- All contributors and users

---

<div align="center">

**FPDev** - Making FreePascal Development Simpler and More Modern

[⭐ Star](https://github.com/fpdev/fpdev) • [🐛 Report Bug](https://github.com/fpdev/fpdev/issues) • [💡 Request Feature](https://github.com/fpdev/fpdev/issues)

</div>
