# FPDev v2.1.0 发布说明

## 发布摘要

`v2.1.0` 是 FPDev 的收口版本：当前范围内的功能清单已经关闭，这一版把发布验收、文档同步和跨平台 public CI release proof 固化成可执行流程，方便一次性完成发布落地。

## 本版重点

### 1. 工具链管理已形成完整闭环

- FPC 命令面覆盖 `install/use/current/show/verify/test/update/update-manifest/cache/policy`
- Lazarus 命令面覆盖 `install/use/current/show/run/configure/test/update/doctor`
- `system help` / namespace help / shell completion 与命令注册表保持一致

### 2. 项目与包生态已经可用

- 项目模板支持 `list/install/remove/update`
- 项目工作流支持 `new/build/run/test/clean`
- 包管理支持 `install/install-local/list/search/info/publish/deps/why`

### 3. 交叉编译与环境诊断已纳入主干

- 交叉编译目标管理、配置、doctor、build/test 路径完整
- `system toolchain check`、`fpc doctor`、`lazarus doctor` 可用于环境基线体检

### 4. 发布收口文件已经补齐

- Linux 自动发布验收入口：`bash scripts/release_acceptance_linux.sh`
- Cross-platform release-proof workflow：`docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`
- 安装文档、README、ROADMAP、CHANGELOG 已同步到 `v2.1.0`

## 已发布基线

```text
[INFO] Feature checklist: closed for v2.1.0 scope
[INFO] Linux release evidence: recorded
[INFO] Discoverable test programs: 275 (same inventory rules as CI)
[INFO] Published release assets: linux/windows/macos archives + SHA256SUMS
[INFO] Release sign-off: public CI release-proof bundle and RELEASE_EVIDENCE.md published with v2.1.0
```

## 已发布资产

- `fpdev-linux-x64.tar.gz`
- `fpdev-windows-x64.zip`
- `fpdev-macos-x64.tar.gz`
- `fpdev-macos-arm64.tar.gz`
- `SHA256SUMS.txt`

## 本地验收

```bash
# Linux 发布基线
bash scripts/release_acceptance_linux.sh

# 如需额外验证隔离数据根中的真实二进制安装
bash scripts/release_acceptance_linux.sh --with-install
```

## 从源码构建

```bash
git clone https://github.com/dtamade/fpdev.git
cd fpdev
bash scripts/build_release.sh
./bin/fpdev system version
```

## 已发布的发布证明

1. GitHub Actions 已产出并验证 `release-ready-bundle`
2. GitHub Release 已发布 `RELEASE_EVIDENCE.md`、`SHA256SUMS.txt` 与四个计划发布资产
3. owner-proof transcript 由 public CI 工件保留，若后续需要补录可继续使用本地 fallback recorder

## 参考文档

- `README.md`
- `docs/INSTALLATION.md`
- `docs/MVP_ACCEPTANCE_CRITERIA.md`
- `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`

---

**FPDev v2.1.0** - 让 FreePascal 开发的安装、切换、诊断和发布更可控。
