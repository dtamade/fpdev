# FPDev 资源打包计划

## 概述

将所有外部资源打包到自己的仓库，确保完全可控，不依赖外部链接。

## 资源来源

| 仓库 | 来源 | 说明 |
|------|------|------|
| fpdev-bootstrap | SourceForge FPC 官方 | 最小启动编译器 |
| fpdev-fpc | SourceForge FPC 官方 | 预编译 FPC 完整包 |
| fpdev-lazarus | SourceForge Lazarus 官方 | 预编译 Lazarus IDE |
| fpdev-cross | fpcupdeluxe releases | 交叉编译 binutils + libs |

## 平台范围

### 主机平台 (Host)
- [x] linux-x86_64
- [ ] windows-x86_64
- [ ] darwin-x86_64
- [ ] darwin-aarch64

### FPC/Lazarus 版本
- FPC: 3.2.2, 3.2.0
- Lazarus: 3.6, 3.4

### 交叉编译目标 (Target)
优先级从高到低：
1. [ ] win64 (Windows 64-bit)
2. [ ] linux-aarch64 (ARM64 Linux)
3. [ ] linux-arm (ARM32 Linux/树莓派)
4. [ ] darwin-aarch64 (Apple Silicon)
5. [ ] android-aarch64 (Android ARM64)

---

## Phase 1: fpdev-bootstrap 补全

### 1.1 Linux x86_64 [已完成]
- [x] 打包 bootstrap-3.3.1-linux-x86_64.tar.gz
- [x] 上传到 GitHub Releases v3.3.1
- [x] 更新 manifest.json

### 1.2 Windows x86_64 [待做]
- [ ] 从 SourceForge 下载 FPC 3.2.2 Windows 安装包
- [ ] 提取 ppcx64.exe 和 fpc.exe
- [ ] 打包 bootstrap-3.2.2-windows-x86_64.zip
- [ ] 计算 SHA256
- [ ] 上传到 GitHub Releases
- [ ] 更新 manifest.json

### 1.3 macOS x86_64 [待做]
- [ ] 从 SourceForge 下载 FPC 3.2.2 macOS Intel 包
- [ ] 提取 ppcx64 和 fpc
- [ ] 打包 bootstrap-3.2.2-darwin-x86_64.tar.gz
- [ ] 计算 SHA256
- [ ] 上传到 GitHub Releases
- [ ] 更新 manifest.json

### 1.4 macOS ARM64 [待做]
- [ ] 从 SourceForge 下载 FPC 3.2.2 macOS ARM64 包
- [ ] 提取 ppca64 和 fpc
- [ ] 打包 bootstrap-3.2.2-darwin-aarch64.tar.gz
- [ ] 计算 SHA256
- [ ] 上传到 GitHub Releases
- [ ] 更新 manifest.json

---

## Phase 2: fpdev-fpc 填充

### 2.1 FPC 3.2.2

#### Linux x86_64
- [ ] 下载 fpc-3.2.2.x86_64-linux.tar
- [ ] 重新打包为 fpc-3.2.2-linux-x86_64.tar.gz
- [ ] 计算 SHA256
- [ ] 上传到 GitHub Releases v3.2.2
- [ ] 更新 manifest.json

#### Windows x86_64
- [ ] 下载 fpc-3.2.2.win32.and.win64.exe
- [ ] 提取 64-bit 部分
- [ ] 打包为 fpc-3.2.2-windows-x86_64.zip
- [ ] 计算 SHA256
- [ ] 上传到 GitHub Releases
- [ ] 更新 manifest.json

#### macOS x86_64
- [ ] 下载 fpc-3.2.2.intel-macosx.dmg
- [ ] 提取内容
- [ ] 打包为 fpc-3.2.2-darwin-x86_64.tar.gz
- [ ] 计算 SHA256
- [ ] 上传到 GitHub Releases
- [ ] 更新 manifest.json

#### macOS ARM64
- [ ] 下载 fpc-3.2.2.aarch64-macosx.dmg
- [ ] 提取内容
- [ ] 打包为 fpc-3.2.2-darwin-aarch64.tar.gz
- [ ] 计算 SHA256
- [ ] 上传到 GitHub Releases
- [ ] 更新 manifest.json

### 2.2 FPC 3.2.0 [可选，优先级低]
- [ ] 同上流程

---

## Phase 3: fpdev-lazarus 填充

### 3.1 Lazarus 3.6

#### Linux x86_64
- [ ] 下载 lazarus-3.6-x86_64-linux.tar.gz
- [ ] 重新打包
- [ ] 上传到 GitHub Releases v3.6
- [ ] 更新 manifest.json

#### Windows x86_64
- [ ] 下载 lazarus-3.6-fpc-3.2.2-win64.exe
- [ ] 提取内容
- [ ] 打包为 lazarus-3.6-windows-x86_64.zip
- [ ] 上传到 GitHub Releases
- [ ] 更新 manifest.json

#### macOS
- [ ] 下载 Lazarus-3.6-macosx-x86_64.pkg
- [ ] 提取内容
- [ ] 打包
- [ ] 上传到 GitHub Releases
- [ ] 更新 manifest.json

### 3.2 Lazarus 3.4 [可选，优先级低]
- [ ] 同上流程

---

## Phase 4: fpdev-cross 填充

### 4.1 交叉编译 Binutils (从 fpcupdeluxe 下载)

#### Windows 主机 → Linux 目标
- [ ] 下载 Linux_AMD64_Linux_V241.zip
- [ ] 下载 Linux_AArch64_Linux_V241.zip
- [ ] 下载 Linux_ARM_Linux_V241.zip
- [ ] 重新打包并上传

#### Linux 主机 → Windows 目标
- [ ] 需要 mingw-w64 binutils
- [ ] 打包并上传

#### Linux 主机 → Darwin 目标
- [ ] 下载 Darwin_All_Clang_15.zip (from fpcupdeluxe)
- [ ] 重新打包并上传

### 4.2 交叉编译 Libraries (从 fpcupdeluxe 下载)

#### Windows 目标库
- [ ] 从 Windows SDK 提取或使用 mingw-w64

#### Linux ARM/ARM64 目标库
- [ ] 下载 Linux_AArch64_Ubuntu_1804.zip
- [ ] 下载 Linux_ARMHF_Raspbian_09.zip
- [ ] 重新打包并上传

#### Darwin 目标库
- [ ] 下载 Darwin_All.zip
- [ ] 重新打包并上传

#### Android 目标库
- [ ] 下载 Android_AArch64_API_21.zip
- [ ] 重新打包并上传

---

## 下载链接汇总

### SourceForge FPC
```
https://sourceforge.net/projects/freepascal/files/Linux/3.2.2/
https://sourceforge.net/projects/freepascal/files/Win32/3.2.2/
https://sourceforge.net/projects/freepascal/files/Mac%20OS%20X/3.2.2/
```

### SourceForge Lazarus
```
https://sourceforge.net/projects/lazarus/files/Lazarus%20Linux%20amd64%20DEB/
https://sourceforge.net/projects/lazarus/files/Lazarus%20Windows%2064%20bits/
https://sourceforge.net/projects/lazarus/files/Lazarus%20macOS%20x86-64/
```

### fpcupdeluxe Releases
```
https://github.com/LongDirtyAnimAlf/fpcupdeluxe/releases/tag/crosslibs_all
https://github.com/LongDirtyAnimAlf/fpcupdeluxe/releases/tag/windows_crossbins_all
https://github.com/LongDirtyAnimAlf/fpcupdeluxe/releases/tag/linux_amd64_crossbins_all
```

---

## 执行进度

| Phase | 任务 | 状态 | 完成日期 |
|-------|------|------|----------|
| 1.1 | Bootstrap Linux x86_64 | 完成 | 2026-01-14 |
| 1.2 | Bootstrap Windows x86_64 | 待做 | - |
| 1.3 | Bootstrap macOS x86_64 | 待做 | - |
| 1.4 | Bootstrap macOS ARM64 | 待做 | - |
| 2.1 | FPC 3.2.2 全平台 | 待做 | - |
| 3.1 | Lazarus 3.6 全平台 | 待做 | - |
| 4.1 | Cross Binutils | 待做 | - |
| 4.2 | Cross Libraries | 待做 | - |

---

## 注意事项

1. **文件大小限制**: GitHub Releases 单文件最大 2GB
2. **命名规范**: `{tool}-{version}-{platform}.{ext}`
   - Linux/macOS: `.tar.gz`
   - Windows: `.zip`
3. **SHA256**: 每个文件必须计算并记录 SHA256
4. **manifest.json**: 每次上传后更新对应仓库的 manifest.json

---

## 自动化脚本

后续可以创建自动化脚本来：
1. 批量下载资源
2. 重新打包
3. 计算 SHA256
4. 上传到 GitHub Releases
5. 更新 manifest.json

---

*最后更新: 2026-01-14*
