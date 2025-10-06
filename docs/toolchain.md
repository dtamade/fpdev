# 工具链体检与策略（fpdev.toolchain）

本模块提供“纯代码、零副作用”的工具链体检与 FPC 版本策略校验能力，支持外部策略 JSON 覆盖，且已与 BuildManager 的 Preflight 严格模式集成。

## 快速开始

- 直接体检（JSON）：
  - `fpdev --check-toolchain`
- 策略校验（FPC 版本是否满足源码版本要求）：
  - `fpdev --check-policy main`
  - `fpdev --check-policy 3.2.2`

- 示例：
  - `examples/fpdev.toolchain/buildOrTest.bat`（Windows）
  - `bash examples/fpdev.toolchain/buildOrTest.sh`（Unix）

## 主 API（供代码使用）

- `function BuildToolchainReportJSON: string;`
  - 构建 HostReady 场景体检报告（fpc/make/lazbuild/git/openssl），返回 JSON 字符串；不落盘，不修改系统

- `function CheckFPCVersionPolicy(const ASourceVersion: string;
  out AStatus, AReason, AMin, ARec, AFPCVersion: string): boolean;`
  - 读取当前 FPC 版本（fpc -iV）并对照策略判断是否满足源码版本要求
  - 返回 True 表示 >= min 可继续；AStatus=OK|WARN|FAIL，Reason 说明原因，并输出阈值与当前版本

- `function LoadPolicyAuto: boolean;`
  - 按顺序加载外部策略 JSON（先命中优先）：
    1) 环境变量 `FPDEV_POLICY_FILE`
    2) `src/fpdev.toolchain.policy.json`
    3) `plays/fpdev.toolchain.policy.json`
    4) `./fpdev.toolchain.policy.json`
  - 若均未加载成功，回退内置保守策略

## BuildManager 集成（严格模式）

- `TBuildManager.SetToolchainStrict(True)` 后，Preflight 顺序：
  1) 调用 `CheckFPCVersionPolicy(AVersion, ...)`（不满足直接 FAIL）
  2) 体检 JSON `BuildToolchainReportJSON`（level=FAIL 直接 FAIL）
- 宽松模式：仅检查 make 存在

## 体检 JSON 结构（HostReady）

示例：
```json
{
  "hostOS": "Windows",
  "hostCPU": "x86_64",
  "pathHead": ["C:\\Windows\\system32", "C:\\Windows", "..."],
  "tools": [
    {"name":"fpc","found":true,"version":"3.2.2","path":"C:\\...\\fpc.exe","notes":""},
    {"name":"mingw32-make","found":true,"version":"GNU Make 4.4","path":"C:\\...\\mingw32-make.exe","notes":""},
    {"name":"lazbuild","found":false,"version":"","path":"","notes":"optional"},
    {"name":"git","found":true,"version":"git version 2.x","path":"C:\\...\\git.exe","notes":""},
    {"name":"openssl","found":false,"version":"","path":"","notes":"optional for HTTPS"}
  ],
  "issues": [],
  "level": "OK"
}
```

字段说明：
- hostOS/hostCPU：宿主信息
- pathHead：PATH 前若干段（便于诊断）
- tools：关键工具的探测结果
- issues：缺项列表（例如缺失 fpc/make）
- level：OK/WARN/FAIL（缺 fpc/make → FAIL；建议项缺失 → WARN）

## 策略 JSON（外部覆盖）

最小格式（仅 fpc 策略）：
```json
{
  "fpc": {
    "trunk": { "min": "3.2.2", "rec": "3.2.2" },
    "main":  { "min": "3.2.2", "rec": "3.2.2" },
    "3.3.":  { "min": "3.2.2", "rec": "3.2.2" },
    "3.2.2": { "min": "3.0.4", "rec": "3.2.0" },
    "3.2.":  { "min": "3.0.4", "rec": "3.2.2" },
    "3.0.":  { "min": "2.6.4", "rec": "3.0.4" }
  }
}
```
说明：
- 键支持别名/前缀：`trunk`、`main`、`3.3.`、`3.2.2`、`3.2.`、`3.0.`
- 匹配优先：完整版本 > 前缀 > 别名；未命中回退内置保守策略

## 版本比较规则

- 仅比较数字与点号（忽略尾随标签）
- `CmpVersion(A,B)` 返回 -1/0/1（A<B/A=B/A>B）

## 常见问题与建议

- Windows 平台推荐优先使用 `mingw32-make`；Unix/BSD 推荐 `gmake`
- HTTPS 下载建议携带 OpenSSL 动态库；缺失时将降级或提示
- 体检 JSON 不落盘，若需保存，可在上层程序自行写入文件

## 后续规划

- 体检范围扩展：binutils（as/ld/ar/strip/nm/objdump）
- 将策略结果合并到体检 JSON（policy 段）
- 按需拉取框架：manifest/mirror/fetcher 设计与实现（GitHub/GitLab/Gitee 镜像）



## 离线模式与本地来源（.fpdev 数据根）

- 数据根：默认使用仓库根下的 `.fpdev/`，可通过环境变量 `FPDEV_DATA_ROOT` 改为任意路径。
  - 缓存：`.fpdev/cache/`
  - 沙箱：`.fpdev/sandbox/`
  - 日志：`.fpdev/logs/`
  - 锁文件：`.fpdev/locks/`

- 本地目录作为源码来源
  - `fpdev --ensure-source fpc-src 3.2.2 --local D:\\kits\\fpc-3.2.2-src --strict`
  - 行为：结构校验 → 复制到 `.fpdev/sandbox/sources/fpc-src/3.2.2/` → 写锁文件

- 本地 zip 作为源码来源
  - `fpdev --ensure-source lazarus-src 3.4.0 --local D:\\kits\\lazarus-3.4.0.zip --sha256 <64hex> --strict`
  - 行为：SHA-256 校验 → 解压 → 严格结构校验 → 写锁文件

- 导入离线捆绑包目录
  - `fpdev --import-bundle D:\\kits\\fpdev-bundle-2025-08-18\\`
  - 行为：扫描该目录 `*.zip + .sha256`，校验通过后导入 `.fpdev/cache/toolchain/`

说明：
- 严格模式（--strict）下，目录仅做结构校验；zip 必须提供 sha256。
- 建议使用离线捆绑包（含 manifest.json 与 sha256）在团队内/内网分发，保证可复现。
