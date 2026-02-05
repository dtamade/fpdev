# BuildManager 设计与使用

## 目标
- 将构建/安装/配置职责从 TFPCSourceManager 中解耦
- 保持默认安全、离线、可回滚：不写系统目录、不下载、不安装外部依赖
- 提供可替换的实现（占位 -> 渐进接入 make 实际构建）

## 关键点
- 最小执行：在源码目录调用 make（若系统无 make，则温和跳过并返回 True）
- 并行策略：-jN（限定 1..16）
- 检查：TestResults 仅检查目录是否存在（占位）
- 配置：Configure 目前为占位，不写系统 fpc.cfg

## 接口
- 单元：src/fpdev.build.manager.pas
- 类：TBuildManager
  - Create(ASourceRoot, AParallelJobs, AVerbose)
  - SetSandboxRoot(Path)
  - SetAllowInstall(Enable)
  - property LogFileName: string（每次运行生成独立日志）
  - BuildCompiler(Version): Boolean
  - BuildRTL(Version): Boolean
  - Install(Version): Boolean
  - Configure(Version): Boolean
  - TestResults(Version): Boolean

## 使用举例
- 在 TFPCSourceManager 内部：
  - BuildFPCCompiler/BuildFPCRTL/InstallFPCBinaries/ConfigureFPCEnvironment/TestBuildResults
  - 现已改为委托至 TBuildManager，日志输出保持一致

- 直接使用（演示）：
  - plays/fpdev.build.manager.demo/buildOrTest.bat
  - 关键代码：
    - SetSandboxRoot('sandbox_demo')：设置沙箱输出根目录
    - SetAllowInstall(True)：允许安装（默认禁止，安全）
    - SetLogVerbosity(1)：开启详细日志（记录 make 命令行等）
    - 可选：SetStrictResults(True) 开启严格校验
    - 可选：--no-install（或环境变量 NO_INSTALL=1）跳过安装
    - BuildCompiler/BuildRTL/Install/Configure/TestResults 顺序执行

### 示例：沙箱安装 + 详细日志
- 初始化并开启安装到沙箱；打印日志文件路径；调用结果校验
- 关键片段（demo.lpr）：

    LBM.SetSandboxRoot('sandbox_demo');
    LBM.SetAllowInstall(True);
    LBM.SetLogVerbosity(1);
    if LBM.BuildCompiler(LVer) then WriteLn('BuildCompiler OK');
    if LBM.BuildRTL(LVer) then WriteLn('BuildRTL OK');
    if LBM.Install(LVer) then WriteLn('Install OK');
    if LBM.Configure(LVer) then WriteLn('Configure OK');
    WriteLn('Log file: ', LBM.LogFileName);
    if LBM.TestResults(LVer) then WriteLn('TestResults OK');

- 参数与环境变量（buildOrTest.bat）：
  - 参数：strict/-s → 等同 --strict --verbose；还支持 --no-install / --verbose / --preflight / --dry-run
  - 环境变量：DEMO_STRICT=1、DEMO_VERBOSE=1、NO_INSTALL=1、PREFLIGHT=1、DRY_RUN=1（等价于追加对应参数）

## 安全默认
- 无 make 时：打印提示并返回 True（不阻塞流程）
- 不写系统目录、不修改全局配置
- 不触发网络下载

## 日志文件与定位
- 每次运行生成独立日志：logs/build_yyyymmdd_hhnnss_zzz.log
- 代码与演示会打印 LogFileName，便于定位

## 沙箱校验
- SetAllowInstall(True) 时，Install 会尝试将安装输出定向至 sandbox/fpc-<version>
- TestResults 在允许安装时优先校验沙箱：至少存在 bin/ 或 lib/ 之一即通过
- 未允许安装时，回退校验源码目录的 compiler/ 与 rtl/ 是否存在

### 严格模式（可选）
- 启用：SetStrictResults(True)
- 校验规则（若不满足则 FAIL）：
  - bin/ 或 lib/ 目录为空
  - lib/ 下没有子目录（通常应包含 fpc/<version> 等）
  - bin/ 下找不到类似编译器可执行（前缀 fpc/ppc，扩展 .exe/.sh/无扩展）
- 仍为沙箱范围内的结构校验，不触及系统目录

#### 成功日志示例（SetLogVerbosity(1)）

    == BuildCompiler START version=main src=sources\fpc\fpc-main
    env: OS=Windows
    env: PATH[0]=C:\Windows\system32
    env: PATH[1]=C:\Windows
    env: PATH[2]=C:\Windows\System32\Wbem
    == BuildCompiler END OK
    == BuildRTL START version=main src=sources\fpc\fpc-main
    == BuildRTL END OK
    == Install START version=main src=sources\fpc\fpc-main dest=sandbox_demo\fpc-main
    sample of sandbox/bin:
    - fpc.exe
    - ppcx64.exe
    sample of sandbox/lib:
    - fpc
    TestResults: sandbox OK at sandbox_demo\fpc-main

#### 失败日志示例（StrictResults=True & SetLogVerbosity(1)）
- bin 为空：

    == Install START version=... src=... dest=...
    sample of sandbox/bin:
    FAIL: sandbox bin empty under strict mode: sandbox/fpc-<ver>/bin

- 缺少编译器可执行：

    sample of sandbox/bin:
    - readme.txt
    - tools-helper.bat
    FAIL: sandbox bin missing expected compiler executable

## CI/GitHub Actions 示例（自托管 Windows 运行器）
- 场景：Windows 自托管 Runner（已安装 FPC/Lazarus），直接调用 demo 并收集日志产物
- 文件：.github/workflows/build-manager-demo.yml（示例）

- 场景：Linux 自托管 Runner（已安装 FPC），调用 shell 脚本并收集日志产物
- 文件：.github/workflows/build-manager-demo-linux.yml（示例）

```yaml
name: BuildManager Demo (Self-hosted Windows)
on:
  workflow_dispatch:
  push:
    paths:
      - 'plays/fpdev.build.manager.demo/**'
      - 'src/**'
      - 'docs/build-manager.md'

jobs:
  demo:
    runs-on: [self-hosted, Windows]
    steps:
      - uses: actions/checkout@v4
      - name: Run demo (strict + verbose)
        shell: cmd
        run: |
          cd plays\fpdev.build.manager.demo
          set DEMO_STRICT=1
          set DEMO_VERBOSE=1
          buildOrTest.bat strict
      - name: Upload logs (Windows)
        uses: actions/upload-artifact@v4
        with:
          name: build-manager-logs-win
          path: plays/fpdev.build.manager.demo/logs/*.log
```

```yaml
name: BuildManager Demo (Self-hosted Linux)
on:
  workflow_dispatch:
  push:
    paths:
      - 'plays/fpdev.build.manager.demo/**'
      - 'src/**'
      - 'docs/build-manager.md'

jobs:
  demo-linux:
    runs-on: [self-hosted, Linux]
    steps:
      - uses: actions/checkout@v4
      - name: Run demo (strict + verbose)
        shell: bash
        run: |
          cd plays/fpdev.build.manager.demo
          STRICT=1 VERBOSE=1 bash ./buildOrTest.sh
      - name: Upload logs (Linux)
        uses: actions/upload-artifact@v4
        with:
          name: build-manager-logs-linux
          path: plays/fpdev.build.manager.demo/logs/*.log
```

```yaml
name: BuildManager Demo (Self-hosted macOS)
on:
  workflow_dispatch:
  push:
    paths:
      - 'plays/fpdev.build.manager.demo/**'
      - 'src/**'
      - 'docs/build-manager.md'

jobs:
  demo-macos:
    runs-on: [self-hosted, macOS]
    steps:
      - uses: actions/checkout@v4
      - name: Ensure tools (optional)
        shell: bash
        run: |
          brew list fpc || brew install fpc
          command -v gmake || brew install make # provides gmake
      - name: Run demo (strict + verbose)
        shell: bash
        run: |
          cd plays/fpdev.build.manager.demo
          STRICT=1 VERBOSE=1 bash ./buildOrTest.sh
      - name: Upload logs (macOS)
        uses: actions/upload-artifact@v4
        with:
          name: build-manager-logs-macos
          path: plays/fpdev.build.manager.demo/logs/*.log
```

- 若使用 GitHub 托管的 windows-latest，请先在步骤中安装/配置 FPC 环境（不在本示例覆盖）。

## 严格模式：可配置产物清单（模板与设计）
- 目标：让严格模式可按项目需求自定义“必需产物清单”，提升验证精度
- 配置建议（示例格式）：

```ini
# 文件：build-manager.strict.ini（位于项目根、plays/demo 或沙箱目录）
# 所有相对路径均以 sandbox/fpc-<version> 为根

[bin]
required_prefix=fpc,ppc
required_ext=.exe,.sh,
min_count=1

[lib]
require_subdir=true
min_count=1
# 可选：具体子目录名约束，如 fpc/<version>
; required_subdir=fpc

[share]
required=false
min_count=0
require_subdir=false
# 可选：指定必须存在的子目录名
; required_subdir=fpcdoc

[fpc]
require_cfg=false
# 多候选相对路径（按顺序尝试）
cfg_relative_list=etc/fpc.cfg,lib/fpc/fpc.cfg

[include]
# 可选：相对目录（默认 include）
relative_dir=include
required=false
min_count=0
require_subdir=false
; required_subdir=rtl

[doc]
# 可选：相对目录（默认 doc）
relative_dir=doc
required=false
min_count=0
require_subdir=false
; required_subdir=html
```

- 行为：
  - 当 SetStrictResults(True) 且检测到配置文件时，按清单规则执行验证；否则沿用内置规则
  - 配置文件搜索顺序（先命中者优先）：
    1) SetStrictConfigPath 指定的路径
    2) 项目根目录的 build-manager.strict.ini
    3) plays/fpdev.build.manager.demo/build-manager.strict.ini（模板已提供）
    4) 沙箱目录下 ASandboxDest/build-manager.strict.ini
  - 初期仅记录日志并返回 FAIL/OK，不做破坏性操作

- 下一步（可选）：
  - 在 docs 中提供示例清单与开启步骤
  - 未来在严格模式中增加“详细失败报告”，逐项列出缺失项

## 跨平台注意事项（Linux/macOS）
- PATH 分隔符：
  - Windows 使用分号 `;`
  - Linux/macOS 使用冒号 `:`
  - BuildManager 在详细日志模式下会按平台解析 PATH 并仅打印前若干项
- make 行为差异：
  - `-jN` 并行参数跨平台可用，但上游 Makefile 对 DESTDIR/PREFIX 支持程度可能不同
  - 如安装阶段出现路径前缀不生效，请检查上游 Makefile 的安装变量命名（如 INSTALL_*、PREFIX 等）
- 建议：
  - 在非 Windows 平台使用 `sh -lc` 的脚本环境运行 demo，确保环境变量与 PATH 一致
  - 如需更详细平台特定诊断，可将日志级别设为 1 并附加更多环境输出

### Linux/macOS 安装 FPC 参考
- 官方下载与说明：
  - https://www.freepascal.org/download.html
- 常见发行版包管理器（示例）：
  - Debian/Ubuntu：`sudo apt-get update && sudo apt-get install -y fpc`
  - Fedora/RHEL：`sudo dnf install -y fpc`
  - Arch/Manjaro：`sudo pacman -S --noconfirm fpc`
  - openSUSE：`sudo zypper install -y fpc`
  - macOS（Homebrew）：`brew install fpc`
- 验证安装：
  - 查看版本：`fpc -iV`
  - 查看路径：`which fpc`（Linux/macOS）或 `command -v fpc`
- 备注：
  - macOS 的 `make` 为 BSD make，上游 Makefile 若依赖 GNU make，需安装 `gmake` 并在环境中可用
  - 若构建/安装依赖外部工具，请在 CI/Runner 上预安装并将其加入 PATH

## 日志字段说明
- Start/End 标记：
  - 形如 `== BuildCompiler START version=... src=...` 与 `== BuildCompiler END OK/FAIL elapsed_ms=...`
  - BuildRTL/Install 同理；elapsed_ms 为该阶段耗时（毫秒）
- env 快照（仅在详细日志模式 SetLogVerbosity(1)）：
  - `env: OS=...`、`env: PATH[i]=...`（仅打印 PATH 前若干项）
- make 命令行（仅在详细日志模式）：
  - 以 `make ...` 记录完整参数（可能包含 DESTDIR/PREFIX 等变量），便于复现
- 目录样本（仅在详细日志模式）：
  - `sample of sandbox/bin:`、`sample of sandbox/lib:`，打印若干文件/子目录用于诊断
- WARN 与 FAIL：
  - 非严格模式下（StrictResults=False）：如 bin/lib 为空，仅 WARN，不中断
  - 严格模式（StrictResults=True）：同场景将视为 FAIL，并终止 TestResults
- hint 提示（严格模式 + 详细日志，失败时）：
  - [bin]：`required_prefix=...`、`required_ext=...` 与目录样本
  - [lib]：`expected a subdirectory (e.g. fpc/<ver>)` 与目录样本
  - [share]：`expected dir/subdir` 与目录样本
  - [fpc]：`tried list=...` 与 `root=...`，便于检查 cfg 路径
- 严格配置文件：
  - `Strict config detected: <path>` 表明已加载 build-manager.strict.ini（搜索顺序见上文）
- 日志文件命名与定位：
  - 每次执行生成独立文件：`logs/build_yyyymmdd_hhnnss_zzz.log`；demo 与上层会打印路径
- Summary 汇总：
  - 形如 `Summary: version=<ver> context=<stage> result=OK|FAIL elapsed_ms=<ms>`
  - TestResults 与 Preflight 在成功/失败收尾处都会输出 Summary，便于在 CI 控制台快速扫描
- 日志级别：
  - 0（默认）：仅关键流程与结果
  - 1（详细）：env 快照、make 命令、目录样本、hint 提示

## 严格清单推荐配置表（快速参考）
- 适用范围：FPC 常见布局，Windows/Linux/macOS 通用；如与实际布局不符，请以模板为准微调
- 通用建议
  - [bin]
    - required_prefix: fpc,ppc
    - required_ext: Windows 建议 `.exe,`；Linux/macOS 建议 `.sh,` 或保留空扩展（模板默认 `.exe,.sh,` 覆盖三者）
    - min_count: 1
  - [lib]
    - require_subdir: true（常见有 fpc/<version> 子目录）
    - required_subdir: fpc（可选，更严格）
    - min_count: 1
  - [share]
    - required: false（按需启用，文档/示例常放此目录）
    - required_subdir: fpcdoc（可选）
  - [fpc]
    - require_cfg: true
    - cfg_relative_list: etc/fpc.cfg,lib/fpc/fpc.cfg（按顺序尝试）
  - [include]
    - relative_dir: include；required: false（如需头文件可开启）
  - [doc]
    - relative_dir: doc；required: false（如需文档可开启）
- Windows 专项
  - [bin].required_ext: `.exe,`
- Linux/macOS 专项
  - [bin].required_ext: `.sh,` 或保留空扩展（可执行无扩展名），模板已包含
- 开启与验证
  - 严格模式：命令行 `--strict` 或代码 `SetStrictResults(True)`
  - 配置来源（先命中者优先）：`SetStrictConfigPath` → 项目根 → demo 目录（模板已提供）→ 沙箱目录
  - 推荐搭配 `--verbose` 查看 hint 与目录样本；失败时日志会标注 FAIL 与具体原因

## 本地运行测试程序（可选）
- Windows
  - `tests\fpdev.build.manager\run_tests.bat`
- Linux/macOS
  - `bash tests/fpdev.build.manager/run_tests.sh`
- 这些脚本会：
  - 编译并运行三个最小测试：
    - `test_build_manager.lpr`（源码回退 + 沙箱）
    - `test_build_manager_strict_fail.lpr`（严格模式，期望 FAIL）
    - `test_build_manager_strict_pass.lpr`（严格模式，期望 PASS）
  - 打印最新日志（logs/build_*.log），可查看 Summary/hint/样本

## 预检与演练模式（Preflight / Dry‑run）
- 预检（Preflight）：不执行构建，快速检查环境与路径是否就绪
  - 检查项：make 可用性、源码路径是否存在、sandbox 与 logs 是否可写、允许安装时版本安装根可创建/可写
  - 日志：`== Preflight START/END`，失败时逐条输出 `issue: ...`
  - 返回：全部检查通过返回 True，否则 False
  - 使用示例：
    - Windows：`plays\fpdev.build.manager.demo\buildOrTest.bat --preflight --dry-run --no-install` 或 `set PREFLIGHT=1 & set DRY_RUN=1 & set NO_INSTALL=1 & set TEST_ONLY=1 & buildOrTest.bat`
    - Linux/macOS：`PREFLIGHT=1 DRY_RUN=1 NO_INSTALL=1 TEST_ONLY=1 bash plays/.../buildOrTest.sh`
- 演练（Dry‑run）：不执行 make，只打印将要执行的命令
  - 行为：`RunMake` 仅记录 `make ...` 行并输出 `dry-run: skipped make execution`，返回 True
  - 适用：在 CI 或本地先审阅将要执行的命令与变量（DESTDIR/PREFIX 等），避免误操作
  - 使用示例：
    - Windows：`set DRY_RUN=1 & plays\fpdev.build.manager.demo\buildOrTest.bat strict`
    - Linux/macOS：`DRY_RUN=1 STRICT=1 bash plays/.../buildOrTest.sh`
- 提示：演练模式不会验证命令执行是否成功；建议结合 `--verbose` 查看完整参数与环境快照

### Preflight 常见失败原因与处理
- source not found: sources\fpc\fpc-<ver>
  - 处理：确保 sources\fpc 目录存在且包含对应版本（如 fpc-main 或 fpc-3.2.2）；或调整 demo 中的 LRoot/LVer
- make not available
  - 处理：Windows 安装 MSYS2/MinGW 并添加 mingw32-make/make 到 PATH；Linux/macOS 安装 gmake/make
- sandbox/logs not writable
  - 处理：确认 plays/demo 下的 sandbox_demo 与 logs 可创建/可写；必要时以管理员身份或更改权限
- sandbox dest not writable / cannot create sandbox dest
  - 处理：当允许安装时，确认 sandbox_demo\fpc-<ver> 目录可写或可创建
- toolchain check failed（开启 ToolchainStrict 时）
  - 处理：先运行 scripts\check_toolchain.bat / .sh，按日志中的缺项逐一安装补齐


## 真实构建开关设计（草案，安全默认）
- 目标：在保持“默认安全”的前提下，允许用户显式启用更接近真实的构建/安装流程
- 原则：
  - 默认关闭；需要显式开启（如 SetAllowInstall(True) + SetRealBuild(True)/`--real-build`）
  - 仅写入沙箱，不触及系统目录
  - 开启前建议先执行 Preflight + Dry‑run
- 建议开关（计划实现）：
  - 代码：`LBM.SetRealBuild(True)`（默认 False）
  - CLI：`--real-build`，环境变量 `REAL_BUILD=1`
  - 依赖：Preflight() 必须通过；可选要求 `StrictResults=True`
- 执行策略：
  - make 阶段：在当前 RunMake 基础上执行 `clean all`（按上游 Makefile 兼容情况渐进接入）
  - install 阶段：继续仅使用 `DESTDIR/PREFIX/INSTALL_PREFIX` 指向沙箱
  - configure 阶段：仍不写系统 fpc.cfg，按严格清单验证 etc/fpc.cfg 或 lib/fpc/fpc.cfg
- 回滚与审计：
  - 日志包含 Start/End、elapsed_ms、完整命令、样本与 hint，便于核查
  - 沙箱产物可整体删除以回滚；不留系统级状态
- 推荐流程：
  1) `--preflight`（或 PREFLIGHT=1）
  2) `--dry-run --strict --verbose`
  3) `--real-build --strict --verbose`（必要时）

## 后续路线
- 在 Build/Install/Configure 关键步骤记录 Start/End 标记，提升可读性
- 逐步细化沙箱结构检查清单（如 share/、fpc.cfg 等）
- 可选：引入配置以启用真实构建（用户显式允许时）




## 全工具链真实演练 Runbook（快速上手）

本项目默认以“干跑 + 沙箱安装”保障安全；当工具链齐备时，可按如下步骤进行真实演练：

1) 工具链体检（必选）
- Windows: `scripts\check_toolchain.bat`
- Unix: `bash scripts/check_toolchain.sh`
- 输出：`logs/check/toolchain_*.txt`，缺项返回非零并提示缺失工具

2) 干跑示例（推荐先执行）
- Windows: `scripts\run_examples.bat`
- Unix: `bash scripts/run_examples.sh`
- 行为：仅编译并运行示例程序；示例内部默认 FDryRun=True，不执行 make；日志：`logs/examples/`

3) 真实演练（仅沙箱内写入，无系统污染）
- Windows: `scripts\run_examples_real.bat`
- Unix: `bash scripts/run_examples_real.sh`
- 行为：脚本导出 `REAL=1`，示例自动切换到非 Dry-Run；安装目标固定在 `plays/.sandbox`；日志：`logs/examples/real/`

4) 观察与收敛
- 详见示例日志与 `TBuildManager` 日志（`logs/build_*.log`）
- 严格模式：示例 `example_strict_validate.lpr` 会按 `plays/fpdev.build.manager.demo/build-manager.strict.ini` 校验产物（可自定义）

## API 参考与高级配置

### 核心方法

**SetMakeCmd(const ACmd: string)** - 自定义 make 命令
- 参数: `ACmd` - make 命令名称(如 `mingw32-make`, `gmake`, `make`)
- 用途: 覆盖默认的 make 命令检测
- 示例:
  ```pascal
  BM.SetMakeCmd('mingw32-make');  // Windows MinGW
  BM.SetMakeCmd('gmake');         // macOS GNU make
  ```

**SetTarget(const ACPU, AOS: string)** - 设置交叉编译目标
- 参数:
  - `ACPU` - 目标 CPU 架构(如 `x86_64`, `aarch64`, `i386`)
  - `AOS` - 目标操作系统(如 `linux`, `win64`, `darwin`)
- 用途: 配置交叉编译目标平台
- 示例:
  ```pascal
  BM.SetTarget('x86_64', 'linux');   // Linux x86_64
  BM.SetTarget('aarch64', 'linux');  // Linux ARM64
  BM.SetTarget('x86_64', 'win64');   // Windows 64-bit
  ```

**SetPrefix(const APrefix, AInstallPrefix: string)** - 设置安装前缀
- 参数:
  - `APrefix` - 编译时前缀路径
  - `AInstallPrefix` - 安装时前缀路径
- 用途: 控制安装目录结构
- 示例:
  ```pascal
  BM.SetPrefix('/usr/local', '/usr/local');
  BM.SetPrefix('C:\FPC', 'C:\FPC');
  ```

### 交叉编译示例

#### 示例 1: Windows → Linux (x86_64)

```pascal
program CrossCompileWinToLinux;

uses
  fpdev.build.manager;

var
  BM: TBuildManager;
begin
  BM := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
  try
    BM.SetSandboxRoot('sandbox_linux');
    BM.SetAllowInstall(True);
    BM.SetLogVerbosity(1);
    BM.SetMakeCmd('mingw32-make');
    
    // 设置交叉编译目标
    BM.SetTarget('x86_64', 'linux');
    BM.SetPrefix('/usr/local', '/usr/local');
    
    WriteLn('Building cross-compiler for Linux x86_64...');
    if not BM.Preflight('main') then Exit;
    if not BM.BuildCompiler('main') then Exit;
    if not BM.BuildRTL('main') then Exit;
    if not BM.Install('main') then Exit;
    
    WriteLn('Cross-compiler built successfully!');
    WriteLn('Log: ', BM.LogFileName);
  finally
    BM.Free;
  end;
end.
```

#### 示例 2: Linux → ARM (aarch64)

```pascal
program CrossCompileLinuxToARM;

uses
  fpdev.build.manager;

var
  BM: TBuildManager;
begin
  BM := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
  try
    BM.SetSandboxRoot('sandbox_arm');
    BM.SetAllowInstall(True);
    BM.SetLogVerbosity(1);
    
    // 设置交叉编译目标
    BM.SetTarget('aarch64', 'linux');
    BM.SetPrefix('/opt/fpc-arm', '/opt/fpc-arm');
    
    WriteLn('Building cross-compiler for ARM aarch64...');
    if not BM.Preflight('main') then Exit;
    if not BM.BuildCompiler('main') then Exit;
    if not BM.BuildRTL('main') then Exit;
    if not BM.Install('main') then Exit;
    
    WriteLn('Cross-compiler built successfully!');
    WriteLn('Sandbox: sandbox_arm/fpc-main');
  finally
    BM.Free;
  end;
end.
```

#### 示例 3: macOS → Windows (x86_64)

```pascal
program CrossCompileMacToWin;

uses
  fpdev.build.manager;

var
  BM: TBuildManager;
begin
  BM := TBuildManager.Create('sources/fpc/fpc-main', 4, True);
  try
    BM.SetSandboxRoot('sandbox_win64');
    BM.SetAllowInstall(True);
    BM.SetLogVerbosity(1);
    BM.SetMakeCmd('gmake');  // macOS 使用 GNU make
    
    // 设置交叉编译目标
    BM.SetTarget('x86_64', 'win64');
    BM.SetPrefix('C:\FPC', 'C:\FPC');
    
    WriteLn('Building cross-compiler for Windows x86_64...');
    if not BM.Preflight('main') then Exit;
    if not BM.BuildCompiler('main') then Exit;
    if not BM.BuildRTL('main') then Exit;
    if not BM.Install('main') then Exit;
    
    WriteLn('Cross-compiler built successfully!');
  finally
    BM.Free;
  end;
end.
```

### 常见配置组合

| 场景 | SetMakeCmd | SetTarget | SetPrefix | 说明 |
|------|-----------|-----------|-----------|------|
| Windows 本地 | `mingw32-make` | - | - | MinGW 环境 |
| Linux 本地 | `make` | - | - | 系统 make |
| macOS 本地 | `gmake` | - | - | GNU make |
| Win→Linux | `mingw32-make` | `x86_64, linux` | `/usr/local` | 交叉编译 |
| Linux→ARM | `make` | `aarch64, linux` | `/opt/fpc-arm` | 交叉编译 |
| macOS→Win | `gmake` | `x86_64, win64` | `C:\FPC` | 交叉编译 |

注意：
- Windows 日志时间戳可能含空格（小时 < 10）；如需可改为零填充格式（见 todos）
- 上游 Makefile 对 DESTDIR/PREFIX 等变量的支持程度可能不同，必要时请查看上游文档或在日志中审阅完整 make 命令行
- 交叉编译需要目标平台的工具链（如交叉编译器、链接器）已安装并在 PATH 中
