# B167: cmd.cross.pas 拆分预研

## 完成日期
2026-02-10

## 现状分析

### 文件概览

| 指标 | 值 |
|------|-----|
| 文件路径 | src/fpdev.cmd.cross.pas |
| 总行数 | 1,263 行 |
| 函数/方法数 | 25 个 |
| 职责 | 交叉编译管理 |

### 职责分布

```
fpdev.cmd.cross.pas (1,263 行)
├── 类型定义 (41-62)
│   ├── TCrossTargetPlatform 枚举
│   ├── TCrossTargetInfo 记录
│   └── TCrossTargetArray 数组
│
├── TCrossCompilerManager 类 (65-1220)
│   ├── 私有辅助方法 (180-380)
│   │   ├── PlatformToString/StringToPlatform
│   │   ├── DetectSystemCrossCompiler
│   │   ├── GetPackageManagerInstructions
│   │   ├── GetTargetInstallPath
│   │   └── GetTargetInfo
│   │
│   ├── 目标查询 (381-480)
│   │   ├── GetAvailableTargets
│   │   └── GetInstalledTargets
│   │
│   ├── 下载功能 (483-580)
│   │   ├── DownloadBinutils
│   │   ├── DownloadLibraries
│   │   └── SetupCrossEnvironment
│   │
│   ├── 目标管理 (583-890)
│   │   ├── InstallTarget (130 行!)
│   │   ├── UninstallTarget
│   │   ├── ListTargets
│   │   ├── EnableTarget
│   │   └── DisableTarget
│   │
│   └── 高级功能 (894-1180)
│       ├── ShowTargetInfo
│       ├── TestTarget
│       ├── BuildTest
│       ├── ConfigureTarget
│       ├── UpdateTarget
│       └── CleanTarget
│
└── 初始化注册 (1250-1263)
```

## 拆分方案

### 方案 A: 按职责拆分 (推荐)

```
fpdev.cmd.cross.pas (保留)
├── 类型定义
├── 命令注册
└── TCrossCommand 根命令

fpdev.cross.manager.pas (新建)
├── TCrossCompilerManager 核心类
├── 目标查询方法
└── 目标管理方法

fpdev.cross.platform.pas (新建)
├── TCrossTargetPlatform 枚举
├── Platform 转换函数
├── 系统检测函数
└── 包管理器指令

fpdev.cross.downloader.pas (已存在)
└── 下载功能 (已分离)
```

**预期效果**:
- cmd.cross.pas: ~200 行 (命令入口)
- cross.manager.pas: ~600 行 (核心业务)
- cross.platform.pas: ~300 行 (平台相关)

### 方案 B: 按功能层拆分

```
fpdev.cmd.cross.pas → 命令层 (~200 行)
fpdev.cross.service.pas → 服务层 (~700 行)
fpdev.cross.types.pas → 类型层 (~100 行)
fpdev.cross.utils.pas → 工具层 (~200 行)
```

### 方案对比

| 维度 | 方案 A | 方案 B |
|------|--------|--------|
| 拆分文件数 | 3 | 4 |
| 改动量 | 中 | 大 |
| 测试影响 | 低 | 中 |
| 可维护性 | 高 | 高 |
| 推荐度 | ★★★★★ | ★★★☆☆ |

## 实施步骤 (方案 A)

### 步骤 1: 创建 fpdev.cross.platform.pas
1. 提取 TCrossTargetPlatform 枚举
2. 提取 PlatformToString/StringToPlatform
3. 提取 DetectSystemCrossCompiler
4. 提取 GetPackageManagerInstructions

### 步骤 2: 创建 fpdev.cross.manager.pas
1. 提取 TCrossCompilerManager 类
2. 保留所有公开方法
3. 私有方法改为调用 platform 单元

### 步骤 3: 精简 fpdev.cmd.cross.pas
1. 只保留 TCrossCommand 命令类
2. 引用 cross.manager 和 cross.platform
3. 保持初始化注册不变

### 步骤 4: 更新依赖
1. 更新所有引用 cmd.cross 的单元
2. 运行全量测试验证
3. 更新 CLAUDE.md 文档

## 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 循环依赖 | 中 | 高 | 仔细设计单元边界 |
| 外部引用破坏 | 低 | 中 | 保持公开接口不变 |
| 测试失败 | 低 | 低 | 逐步提取，每步测试 |

## 工作量估算

| 任务 | 时间 |
|------|------|
| 创建 platform 单元 | 1h |
| 创建 manager 单元 | 2h |
| 更新 cmd.cross | 0.5h |
| 测试验证 | 1h |
| 文档更新 | 0.5h |
| **总计** | **5h** |

## 建议

1. **当前状态可接受**: 1,263 行虽大但结构清晰，不是紧急问题
2. **如需拆分**: 采用方案 A，按职责拆分，风险最低
3. **触发条件**: 当需要添加新的交叉编译功能时再拆分
4. **优先级**: P3 (低优先级改进)
