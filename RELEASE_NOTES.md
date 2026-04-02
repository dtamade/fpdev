# FPDev v2.1.0 发布说明

## 发布摘要

`v2.1.0` 是 FPDev 的收口版本：功能路线图已经完成，这一版把发布验收、文档同步和跨平台 owner checkpoint 固化成可执行流程，方便一次性完成发布落地。

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
- Windows/macOS owner checkpoint：`docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`
- 安装文档、README、ROADMAP、CHANGELOG 已同步到 `v2.1.0`

## 当前发布基线

```text
Roadmap checklist: 121/121 complete
Test inventory: 273 discoverable test_*.lpr programs (same inventory rules as CI)
Primary release gate: Linux automated acceptance passed
Remaining publish-time proof: Windows/macOS owner checkpoints + SHA256SUMS + RELEASE_EVIDENCE.md
```

## 计划发布资产

- `fpdev-linux-x64.tar.gz`
- `fpdev-windows-x64.zip`
- `fpdev-macos-x64.tar.gz`
- `fpdev-macos-arm64.tar.gz`
- `SHA256SUMS.txt`
- `RELEASE_EVIDENCE.md`

## 本地验收

```bash
# Linux 发布基线
bash scripts/release_acceptance_linux.sh

# 如需额外验证隔离数据根中的真实二进制安装
bash scripts/release_acceptance_linux.sh --with-install
```

## 从源码构建

```bash
git clone https://github.com/fpdev/fpdev.git
cd fpdev
lazbuild -B --build-mode=Release fpdev.lpi
./bin/fpdev system version
```

## 发布前仍需 owner 执行的动作

1. Windows x64 解压资产后，使用标准 recorder：`pwsh ./scripts/record_owner_smoke.ps1 -Lane windows-x64 -ExecutablePath .\\fpdev-windows-x64\\fpdev.exe -OutputDir .\\owner-proof`
2. macOS x64 / arm64 解压资产后，使用标准 recorder：`bash ./scripts/record_owner_smoke.sh macos-<arch> ./fpdev-macos-<arch>/fpdev ./owner-proof`
3. 生成并上传 `SHA256SUMS.txt`：`python3 scripts/generate_release_checksums.py <asset-dir> --require-planned-assets`
4. 生成并上传 `RELEASE_EVIDENCE.md`：`python3 scripts/generate_release_evidence.py --baseline-summary logs/release_acceptance/<baseline-run>/summary.txt --asset-dir <asset-dir> --owner-proof-dir <owner-proof-dir> --output <asset-dir>/RELEASE_EVIDENCE.md`（若执行了 network-gated install lane，再追加 `--install-summary logs/release_acceptance/<install-run>/summary.txt`）
5. 在 owner checkpoint ledger 中填写 owner、日期和证据

## 参考文档

- `README.md`
- `docs/INSTALLATION.md`
- `docs/MVP_ACCEPTANCE_CRITERIA.md`
- `docs/plans/2026-03-25-v2.1.0-release-owner-checkpoints.md`

---

**FPDev v2.1.0** - 让 FreePascal 开发的安装、切换、诊断和发布更可控。
