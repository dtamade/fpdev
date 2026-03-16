# FPC 版本管理功能文档

## 概述

FPDev 的 FPC 版本管理功能提供了完整的 FreePascal 编译器生命周期管理，包括版本安装、切换、卸载等操作。

## 功能特性

### 🔧 版本管理
- **多版本并存**: 支持同时安装多个 FPC 版本
- **版本切换**: 快速切换默认 FPC 版本
- **版本信息**: 查看详细的版本信息和安装状态

### 📦 安装方式
- **源码安装**: 从 Git 仓库自动下载源码并编译安装
- **预编译包**: 支持预编译二进制包安装（规划中）
- **自定义仓库**: 支持从自定义 Git 仓库安装

### 🛠️ 构建系统
- **并行编译**: 支持多核并行编译，提高构建速度
- **依赖管理**: 自动处理编译依赖和环境配置
- **错误处理**: 完善的错误处理和恢复机制

## 支持的版本

| 版本 | 状态 | 发布日期 | Git分支 | 说明 |
|------|------|----------|---------|------|
| 3.2.2 | 稳定版 | 2021-05-19 | fixes_3_2 | 当前推荐版本 |
| 3.2.0 | 稳定版 | 2020-06-08 | fixes_3_2 | 长期支持版本 |
| 3.0.4 | 稳定版 | 2017-11-30 | fixes_3_0 | 旧版本支持 |
| 3.0.2 | 稳定版 | 2017-01-15 | fixes_3_0 | 旧版本支持 |
| main | 开发版 | 持续更新 | main | 最新开发版本 |

## 命令参考

### 基本命令

```bash
# 显示帮助信息
fpdev fpc

# 列出已安装的版本
fpdev fpc list

# 列出所有可用版本
fpdev fpc list --all

# 显示当前默认版本
fpdev fpc current
```

### 安装管理

```bash
# 从源码安装 FPC 3.2.2
fpdev fpc install 3.2.2 --from-source

# 安装开发版本
fpdev fpc install main --from-source

# 卸载指定版本
fpdev fpc uninstall 3.2.2
```

### 版本切换

```bash
# 设置默认版本
fpdev fpc use 3.2.2

# 查看版本信息
fpdev fpc info 3.2.2

# 测试安装
fpdev fpc test 3.2.2
```

### 源码管理

```bash
# 更新源码
fpdev fpc update 3.2.2

# 清理源码构建产物
fpdev fpc clean 3.2.2
```

- `fpdev fpc update <version>` 会使用 FPDev 的 Git 运行时更新源码仓库。
- 如果源码目录是本地仓库且没有配置 remote，命令会报告 local-only，并保持成功退出。
- `fpdev fpc clean <version>` 只清理构建产物，保留源码仓库本身。

## 安装流程

### 从源码安装

1. **下载源码**
   ```bash
   git clone --depth 1 --branch <tag> https://gitlab.com/freepascal.org/fpc/source.git
   ```

2. **编译源码**
   ```bash
   make all install PREFIX=<install_path> -j<parallel_jobs>
   ```

3. **配置环境**
   - 更新配置文件
   - 设置环境变量
   - 验证安装

### 目录结构

```
~/.fpdev/
├── config.json          # 配置文件
├── fpc/                  # FPC 安装目录
│   ├── 3.2.2/           # FPC 3.2.2 安装
│   │   ├── bin/         # 可执行文件
│   │   ├── lib/         # 库文件
│   │   └── units/       # 单元文件
│   └── main/            # 开发版本安装
└── sources/             # 源码目录
    ├── fpc-3.2.2/       # FPC 3.2.2 源码
    └── fpc-main/        # 开发版本源码
```

## 配置管理

### 工具链配置

FPC 版本信息存储在配置文件中：

```json
{
  "toolchains": {
    "fpc-3.2.2": {
      "type": "release",
      "version": "3.2.2",
      "install_path": "/home/user/.fpdev/fpc/3.2.2",
      "source_url": "https://gitlab.com/freepascal.org/fpc/source.git",
      "branch": "fixes_3_2",
      "installed": true,
      "install_date": "2024-01-15T10:30:00Z"
    }
  },
  "default_toolchain": "fpc-3.2.2"
}
```

### 环境变量

安装完成后，FPDev 会自动配置以下环境变量：

- `FPCDIR`: FPC 安装目录
- `PATH`: 添加 FPC 可执行文件路径
- `FPCVERSION`: 当前 FPC 版本

## 错误处理

### 常见问题

1. **编译失败**
   - 检查系统依赖（make, git, gcc）
   - 确保有足够的磁盘空间
   - 检查网络连接

2. **权限问题**
   - 确保对安装目录有写权限
   - 在 Windows 上可能需要管理员权限

3. **版本冲突**
   - 使用 `fpdev fpc list` 检查已安装版本
   - 使用 `fpdev fpc use` 切换版本

### 日志和诊断

- 编译日志保存在临时目录
- 使用 `fpdev fpc test <version>` 验证安装
- 检查配置文件 `~/.fpdev/config.json`

## 最佳实践

### 版本选择

1. **生产环境**: 使用稳定版本（如 3.2.2）
2. **开发测试**: 可以使用开发版本（main）
3. **兼容性**: 根据项目需求选择合适版本

### 磁盘管理

1. **定期清理**: 删除不需要的版本
2. **源码管理**: 使用 `--keep-sources=false` 节省空间
3. **并行编译**: 根据 CPU 核心数设置 `parallel_jobs`

### 安全考虑

1. **源码验证**: 仅从官方仓库下载源码
2. **权限控制**: 使用最小必要权限
3. **备份配置**: 定期备份配置文件

## API 接口

### TFPCManager 类

```pascal
TFPCManager = class
  // 版本管理
  function InstallVersion(const AVersion: string; const AFromSource: Boolean = False): Boolean;
  function UninstallVersion(const AVersion: string): Boolean;
  function ListVersions(const AShowAll: Boolean = False): Boolean;
  function SetDefaultVersion(const AVersion: string): Boolean;
  function GetCurrentVersion: string;
  
  // 源码管理
  function UpdateSources(const AVersion: string = ''): Boolean;
  function CleanSources(const AVersion: string = ''): Boolean;
  
  // 工具链操作
  function ShowVersionInfo(const AVersion: string): Boolean;
  function TestInstallation(const AVersion: string): Boolean;
end;
```

### 使用示例

```pascal
var
  ConfigManager: TFPDevConfigManager;
  FPCManager: TFPCManager;
begin
  ConfigManager := TFPDevConfigManager.Create;
  try
    FPCManager := TFPCManager.Create(ConfigManager);
    try
      // 安装 FPC 3.2.2
      if FPCManager.InstallVersion('3.2.2', True) then
        WriteLn('安装成功');
      
      // 设置为默认版本
      FPCManager.SetDefaultVersion('3.2.2');
      
      // 测试安装
      FPCManager.TestInstallation('3.2.2');
      
    finally
      FPCManager.Free;
    end;
  finally
    ConfigManager.Free;
  end;
end;
```

## 扩展开发

### 添加新版本

1. 更新 `FPC_RELEASES` 常量数组
2. 添加对应的 Git 标签和分支信息
3. 测试安装和构建流程

### 自定义仓库

1. 修改 `FPC_OFFICIAL_REPO` 常量
2. 或在配置文件中添加自定义仓库
3. 确保仓库结构兼容

### 平台支持

1. 添加平台特定的编译选项
2. 处理平台相关的路径和权限
3. 测试跨平台兼容性

## 未来规划

- [ ] 预编译包支持
- [ ] 增量更新机制
- [ ] GUI 界面集成
- [ ] 云端同步功能
- [ ] 插件系统支持
