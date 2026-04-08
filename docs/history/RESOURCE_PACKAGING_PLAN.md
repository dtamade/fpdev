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
- [x] windows-x86_64
- [x] darwin-x86_64
- [x] darwin-aarch64

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

### 1.2 Windows x86_64 [已完成]
- [x] 从 SourceForge 下载 FPC 3.2.2 Windows 安装包
- [x] 提取 ppcrossx64.exe
- [x] 打包 bootstrap-3.2.2-windows-x86_64.zip
- [x] 计算 SHA256: aa9154a342ffa5d98d53c15f60a596944ea18bfffe3b8216aec7a356cd4043b6
- [x] 上传到 GitHub Releases v3.2.2
- [x] 更新 manifest.json

### 1.3 macOS x86_64 [已完成]
- [x] 从 SourceForge 下载 FPC 3.2.2 macOS 包
- [x] 提取 ppcx64
- [x] 打包 bootstrap-3.2.2-darwin-x86_64.tar.gz
- [x] 计算 SHA256: 62f786b2e464a0a048f453bf0b4194f1b2cf4a9bbb250f4100f78a3c190d0dcc
- [x] 上传到 GitHub Releases v3.2.2
- [x] 更新 manifest.json

### 1.4 macOS ARM64 [已完成]
- [x] 从 SourceForge 下载 FPC 3.2.2 macOS 包 (同 1.3，包含双架构)
- [x] 提取 ppca64
- [x] 打包 bootstrap-3.2.2-darwin-aarch64.tar.gz
- [x] 计算 SHA256: ba427f37e52983b3fad5d4c0736bffac19eaaba140062f47d000e832bf0e0c0b
- [x] 上传到 GitHub Releases v3.2.2
- [x] 更新 manifest.json

---

## Phase 2: fpdev-fpc 填充 [已完成]

### 2.1 FPC 3.2.2 [已完成]

#### Linux x86_64 [已完成]
- [x] 下载 fpc-3.2.2.x86_64-linux.tar
- [x] 重新打包为 fpc-3.2.2-linux-x86_64.tar.gz
- [x] 计算 SHA256: 46c083c7308a6fb978f0244c0e2e7c4217210200232923f777fc4f0483ca1caf
- [x] 上传到 GitHub Releases v3.2.2
- [x] 更新 manifest.json

#### Windows x86_64 [已完成]
- [x] 下载 fpc-3.2.2.win32.and.win64.exe
- [x] 提取 64-bit 部分
- [x] 打包为 fpc-3.2.2-windows-x86_64.zip
- [x] 计算 SHA256: 7182b02643594b082997f1c3af25171ffb85e89c57af1d036b26a1339f749c98
- [x] 上传到 GitHub Releases
- [x] 更新 manifest.json

#### macOS x86_64 [已完成]
- [x] 下载 fpc-3.2.2.intelarm64-macosx.dmg
- [x] 提取内容
- [x] 打包为 fpc-3.2.2-darwin-x86_64.tar.gz
- [x] 计算 SHA256: d0fab36b784273c8c5d79f03c0b5ca29ba282386e3c54a4161fbebf9796659e3
- [x] 上传到 GitHub Releases
- [x] 更新 manifest.json

#### macOS ARM64 [已完成]
- [x] 下载 fpc-3.2.2.intelarm64-macosx.dmg (同上，包含双架构)
- [x] 提取内容
- [x] 打包为 fpc-3.2.2-darwin-aarch64.tar.gz
- [x] 计算 SHA256: f3ec0009d4389633be740f8428cd08f6f2ee2381addde846d1afa5ed8b82a86f
- [x] 上传到 GitHub Releases
- [x] 更新 manifest.json

### 2.2 FPC 3.2.0 [可选，优先级低]
- [ ] 同上流程

---

## Phase 3: fpdev-lazarus 填充 [已完成]

### 3.1 Lazarus 3.6 [已完成]

#### Linux x86_64 [已完成]
- [x] 下载 lazarus DEB 包
- [x] 重新打包为 lazarus-3.6-linux-x86_64.tar.gz
- [x] 计算 SHA256: d4dea972e5fbddab52445e4d9e0ad40ef5f9c1374ef6daf48bb94fb388e74aa3
- [x] 上传到 GitHub Releases v3.6
- [x] 更新 manifest.json

#### Windows x86_64 [已完成]
- [x] 下载 lazarus-3.6-fpc-3.2.2-win64.exe
- [x] 提取内容
- [x] 打包为 lazarus-3.6-windows-x86_64.zip
- [x] 计算 SHA256: d5ff195f4c13d25edfa142a99c2e4c4eb9a681186f1fe76033538d1e7020eba0
- [x] 上传到 GitHub Releases
- [x] 更新 manifest.json

#### macOS x86_64 [已完成]
- [x] 下载 Lazarus-3.6-macosx-x86_64.pkg
- [x] 提取内容
- [x] 打包为 lazarus-3.6-darwin-x86_64.tar.gz
- [x] 计算 SHA256: 9de341c8553ea504c018c4ba1ac3a63e90f8821cee8c66b46b8d3f608a67924c
- [x] 上传到 GitHub Releases
- [x] 更新 manifest.json

#### macOS ARM64 [不可用]
- **注意**: Lazarus 3.6 没有发布 macOS ARM64 版本
- 最早的 macOS ARM64 版本是 Lazarus 3.8
- 如需 ARM64 支持，需要升级到 Lazarus 3.8+

### 3.2 Lazarus 3.4 [可选，优先级低]
- [ ] 同上流程

---

## Phase 4: fpdev-cross 填充 [已完成]

### 4.1 交叉编译 Binutils [已完成]

#### Windows 主机 → Linux 目标 [已完成]
- [x] 下载 Linux_AArch64_Linux_V241.zip
- [x] 下载 Linux_ARM_Linux_V241.zip
- [x] 下载 Linux_AMD64_Linux_V241.zip
- [x] 重命名并整理
- [x] 计算 SHA256

#### Windows 主机 → Darwin 目标 [已完成]
- [x] 下载 Darwin_All_Clang_15.zip
- [x] 计算 SHA256: d50b8e075934873fff3be7ce86714c1e1fe8c2136f43d4ab28b75d752848b141

#### Linux 主机 → Darwin 目标 [已完成]
- [x] 下载 Darwin_All_Clang_14.zip
- [x] 计算 SHA256: feb085d457009d16d7bce7d45defa8e90ed7cb02f84679fa647ad6b6714f2817

#### Linux 主机 → Linux AArch64 目标 [已完成]
- [x] 下载 Linux_AArch64_Linux_V234.zip
- [x] 计算 SHA256: 7d54a821340ae287bf2e5ffeceeb4e20d5213f3d4691144c68ee3c032261cdc6

### 4.2 交叉编译 Libraries [已完成]

#### Linux ARM/ARM64 目标库 [已完成]
- [x] 下载 Linux_AArch64_Ubuntu_1804.zip
- [x] 计算 SHA256: 3f7d776411e3f9023655c5eff900c08922fc4f8c0882624dcffdf14ecc89d158
- [x] 下载 Linux_ARMHF_Raspbian_09.zip
- [x] 计算 SHA256: 21d07ff35b59022f5390c16a1f212a358a9a5322e63aa197a8b8c112f2cce8df

#### Darwin 目标库 [已完成]
- [x] 下载 Darwin_All.zip
- [x] 计算 SHA256: 09dada9626bb15af179d08fdd9e8aae5da0e99f30b17e8e42ed48eec70dc4677

#### Android 目标库 [已完成]
- [x] 下载 Android_AArch64_API_21.zip
- [x] 计算 SHA256: ee3a300bef42ef2de5b7e437418b801612885f8adcec65c4a6a06735e45e4993

### 4.3 文件清单

| 文件名 | 大小 | SHA256 |
|--------|------|--------|
| binutils-linux-aarch64-windows-x86_64.zip | 9.4MB | a7ad5e459df018307e1165d2be62d62cee24ba4a6c7bdc3396426f311ff7ceaf |
| binutils-linux-arm-windows-x86_64.zip | 7.6MB | c6086f6b58c40f57d9dce0b5027bfc103e9b306531c0ec65c46d2e217b7b40b5 |
| binutils-linux-x86_64-windows-x86_64.zip | 8.7MB | be7f575c4383c98f4a14d22cd939c58c9d8a458b8e3fc2125348eca5e9826733 |
| binutils-darwin-all-windows-x86_64.zip | 62MB | d50b8e075934873fff3be7ce86714c1e1fe8c2136f43d4ab28b75d752848b141 |
| binutils-darwin-all-linux-x86_64.zip | 10MB | feb085d457009d16d7bce7d45defa8e90ed7cb02f84679fa647ad6b6714f2817 |
| binutils-linux-aarch64-linux-x86_64.zip | 31MB | 7d54a821340ae287bf2e5ffeceeb4e20d5213f3d4691144c68ee3c032261cdc6 |
| libs-linux-aarch64.zip | 48MB | 3f7d776411e3f9023655c5eff900c08922fc4f8c0882624dcffdf14ecc89d158 |
| libs-linux-armhf.zip | 41MB | 21d07ff35b59022f5390c16a1f212a358a9a5322e63aa197a8b8c112f2cce8df |
| libs-darwin-all.zip | 78MB | 09dada9626bb15af179d08fdd9e8aae5da0e99f30b17e8e42ed48eec70dc4677 |
| libs-android-aarch64.zip | 3.2MB | ee3a300bef42ef2de5b7e437418b801612885f8adcec65c4a6a06735e45e4993 |

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
| 1.2 | Bootstrap Windows x86_64 | 完成 | 2026-01-14 |
| 1.3 | Bootstrap macOS x86_64 | 完成 | 2026-01-14 |
| 1.4 | Bootstrap macOS ARM64 | 完成 | 2026-01-14 |
| 2.1 | FPC 3.2.2 全平台 | 完成 | 2026-01-14 |
| 3.1 | Lazarus 3.6 (3平台) | 完成 | 2026-01-14 |
| 4.1 | Cross Binutils | 完成 | 2026-01-14 |
| 4.2 | Cross Libraries | 完成 | 2026-01-14 |

**注意**:
- Lazarus 3.6 没有 macOS ARM64 版本，最早的 ARM64 版本是 Lazarus 3.8
- 所有交叉编译工具链来源于 fpcupdeluxe releases

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
