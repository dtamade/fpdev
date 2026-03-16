# FPDev Frequently Asked Questions (FAQ)

This document answers common questions about using FPDev.

---

## 📦 Installation

### Q: How do I install FPDev?

**A**: Build from source:

```bash
git clone https://github.com/fpdev/fpdev.git
cd fpdev
lazbuild -B fpdev.lpi
./bin/fpdev system help
```

### Q: What dependencies are required?

**A**:
- **Building FPDev**: FPC 3.2.2+, Lazarus (optional)
- **Using FPDev**: No special dependencies
- **Installing FPC from source**: Git, Make, Bootstrap compiler (auto-downloaded)

### Q: What if binary installation fails?

**A**: Use source installation:

```bash
fpdev fpc install 3.2.2 --from-source
```

Binary installation depends on the manifest system. If unavailable, source installation is the most reliable method.

---

## 🔧 FPC Management

### Q: How do I install FPC?

**A**: Source installation is recommended:

```bash
# Install from source (recommended)
fpdev fpc install 3.2.2 --from-source

# Activate version
fpdev fpc use 3.2.2

# Verify installation
fpdev fpc verify 3.2.2
```

### Q: How do I switch FPC versions?

**A**: Use the `use` command:

```bash
fpdev fpc use 3.2.2
```

This generates activation scripts:
- Windows: `.fpdev\env\activate.cmd`
- Linux/macOS: `.fpdev/env/activate.sh`

### Q: How do I check the current FPC version?

**A**:

```bash
fpdev fpc current
```

### Q: How long does source installation take?

**A**:
- **First installation**: 20-40 minutes (download source + compile)
- **Subsequent installations**: 10-20 minutes (reuse downloaded source)

Time depends on:
- Network speed (downloading source)
- CPU performance (compilation speed)
- Number of parallel jobs (`--jobs` parameter)

### Q: How can I speed up source compilation?

**A**: Use the `--jobs` parameter:

```bash
# Use 4 parallel jobs
fpdev fpc install 3.2.2 --from-source --jobs=4
```

---

## 📁 Project Management

### Q: How do I create a new project?

**A**:

```bash
# Console application
fpdev project new console myapp

# GUI application
fpdev project new gui myapp

# Dynamic library
fpdev project new library mylib
```

### Q: Can project names contain hyphens?

**A**: Yes, but they are automatically converted to underscores:

```bash
fpdev project new console hello-world
# Generated program name: hello_world
```

This is because Pascal identifiers don't allow hyphens.

### Q: How do I build a project?

**A**:

```bash
# Compile directly with FPC
fpc myapp.lpr

# Or use lazbuild
lazbuild myapp.lpi

# Or use fpdev (future version)
fpdev project build
```

### Q: How do I clean build artifacts?

**A**:

```bash
fpdev project clean
```

This removes:
- `*.o` - Object files
- `*.ppu` - Compiled units
- `*.exe` / executables
- `*.a`, `*.so` - Library files

---

## 🐛 Troubleshooting

### Q: What if the install command times out?

**A**: This is usually a network issue. Solutions:

1. **Use source installation** (doesn't depend on binary download):
   ```bash
   fpdev fpc install 3.2.2 --from-source
   ```

2. **Check network connection**

3. **Use a proxy** (if behind a firewall)

### Q: Compilation error: unit not found

**A**: Check FPC configuration:

```bash
# Verify FPC installation
fpdev fpc verify 3.2.2

# View FPC configuration
fpc -vut
```

### Q: git2.dll not found on Windows

**A**: Ensure `git2.dll` is in one of these locations:
- FPDev executable directory
- A directory in the PATH environment variable

### Q: Permission errors

**A**:
- **Linux/macOS**: Use `sudo` or install to user directory
- **Windows**: Run as administrator

---

## 🔍 Advanced Usage

### Q: How do I customize the installation path?

**A**: Use the `--prefix` parameter:

```bash
fpdev fpc install 3.2.2 --from-source --prefix=/custom/path
```

### Q: How do I use project-scoped installation?

**A**: Run the install command in the project directory:

```bash
cd myproject
fpdev fpc install 3.2.2
# Installs to .fpdev/toolchains/
```

### Q: How do I clean FPC source build artifacts?

**A**:

```bash
fpdev fpc clean 3.2.2
```

This removes compiled artifacts but keeps the source repository.

### Q: How do I update FPC source code?

**A**:

```bash
fpdev fpc update 3.2.2
```

This updates the source repository through FPDev's Git runtime.

If that source repository has no remote configured, the command reports it as local-only and still exits successfully.

---

## 📚 More Resources

- [Quick Start Guide](QUICKSTART.en.md)
- [Full Documentation](../README.en.md)
- [Architecture Documentation](ARCHITECTURE.en.md)
- [GitHub Issues](https://github.com/fpdev/fpdev/issues)
- [Community Discussions](https://github.com/fpdev/fpdev/discussions)

---

## 💬 Getting Help

If your question isn't answered here:

1. Check [GitHub Issues](https://github.com/fpdev/fpdev/issues)
2. Search [Community Discussions](https://github.com/fpdev/fpdev/discussions)
3. Submit a new Issue or Discussion

---

**Last Updated**: 2026-02-10
