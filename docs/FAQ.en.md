# FPDev Frequently Asked Questions (FAQ)

This document answers common questions about using FPDev.

---

## 📦 Installation

### Q: How do I install FPDev?

**A**: Build from source:

```bash
git clone https://github.com/dtamade/fpdev.git
cd fpdev
bash scripts/build_release.sh
release_bin="$(cat logs/release_build/latest-release-bin-path.txt)"
"$release_bin" system help
```

`build_release.sh` writes the resolved release binary path to `logs/release_build/latest-release-bin-path.txt`, so the documented flow still works when the repo `bin/` directory is not writable and the build falls back to a temporary workspace.

### Q: What dependencies are required?

**A**:
- **Building FPDev**: FPC 3.2.2+, Lazarus (optional)
- **Using FPDev**: No special dependencies
- **Installing FPC from source**: Git, Make, Bootstrap compiler (auto-downloaded)

### Q: What if binary installation fails?

**A**: The default command is already binary-first. Narrow the failure down in this order:

```bash
# Use cached artifacts only (fully offline)
fpdev fpc install 3.2.2 --offline

# Inspect what is currently cached
fpdev fpc cache list

# Skip cache and force a fresh binary download
fpdev fpc install 3.2.2 --no-cache

# Switch to an explicit source build only when you need to bypass the binary path entirely
fpdev fpc install 3.2.2 --from-source
```

The binary acquisition chain goes through manifest metadata first, then falls back to fpdev-repo / SourceForge style recovery. Use `--from-source` only when those paths are unavailable or when you need a source build on purpose.

---

## 🔧 FPC Management

### Q: How do I install FPC?

**A**: Prefer binary installation first for a faster setup. Fall back to source installation when you need a custom build or the binary path is unavailable:

```bash
# Default: binary-first install
fpdev fpc install 3.2.2

# Cached artifacts only
fpdev fpc install 3.2.2 --offline

# Skip cache and force a fresh binary download
fpdev fpc install 3.2.2 --no-cache

# Use source build when needed
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

# Or use fpdev
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

1. **Check whether the required version is already cached**:
   ```bash
   fpdev fpc cache list
   fpdev fpc install 3.2.2 --offline
   ```

2. **Skip cache and retry the binary path**:
   ```bash
   fpdev fpc install 3.2.2 --no-cache
   ```

3. **Switch to source mode only when needed**:
   ```bash
   fpdev fpc install 3.2.2 --from-source
   ```

4. **Check network connection**

5. **Use a proxy** (if behind a firewall)

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
fpdev fpc install 3.2.2 --prefix=/custom/path
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
- [GitHub Issues](https://github.com/dtamade/fpdev/issues)
- [Community Discussions](https://github.com/dtamade/fpdev/discussions)

---

## 💬 Getting Help

If your question isn't answered here:

1. Check [GitHub Issues](https://github.com/dtamade/fpdev/issues)
2. Search [Community Discussions](https://github.com/dtamade/fpdev/discussions)
3. Submit a new Issue or Discussion

---

**Last Updated**: 2026-02-10
