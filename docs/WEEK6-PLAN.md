# Week 6 计划：完成 Manifest 系统集成测试和文档

**日期**: 2026-01-18
**状态**: 🚧 规划中
**目标**: 完成 Week 5 遗留的集成测试和用户文档

---

## 目标概述

Week 6 将完成 Week 5 遗留的任务，包括：
1. 完整的安装流程测试
2. 多镜像 fallback 实际测试
3. 离线模式测试
4. 用户使用指南文档

---

## 任务列表

### 1. 完整安装流程测试 (优先级: 高)

**目标**: 验证从 manifest 安装 FPC 的完整流程

**测试步骤**:
1. 测试安装 FPC 3.2.0（未安装版本）
2. 验证 manifest 加载
3. 验证平台检测
4. 验证下载流程
5. 验证 hash 校验
6. 验证解压和安装
7. 验证安装后的文件结构

**测试命令**:
```bash
# 1. 清理已有安装（如果存在）
rm -rf ~/.fpdev/fpc/3.2.0

# 2. 测试安装
./bin/fpdev fpc install 3.2.0

# 3. 验证安装
./bin/fpdev fpc list
./bin/fpdev fpc verify 3.2.0

# 4. 测试已安装版本的重新安装
./bin/fpdev fpc install 3.2.0
```

**预期结果**:
- ✅ Manifest 成功加载
- ✅ 平台正确检测（linux-x86_64）
- ✅ 下载成功（从 GitHub 或 Gitee）
- ✅ Hash 校验通过
- ✅ 解压成功
- ✅ 安装成功
- ✅ 文件结构正确

**验收标准**:
- 安装流程无错误
- 所有日志信息清晰
- 安装后的 FPC 可以正常使用

---

### 2. 多镜像 Fallback 测试 (优先级: 高)

**目标**: 验证多镜像 fallback 机制在实际场景中的工作情况

**测试场景**:

#### 场景 2.1: 第一个镜像失败，自动切换到第二个镜像

**测试步骤**:
1. 修改 manifest 中的第一个 URL 为无效 URL
2. 运行安装命令
3. 观察是否自动切换到第二个镜像
4. 验证安装成功

**测试命令**:
```bash
# 1. 备份原始 manifest
cp ~/.fpdev/cache/manifests/fpc.json ~/.fpdev/cache/manifests/fpc.json.bak

# 2. 修改 manifest（将第一个 URL 改为无效）
# 使用 jq 修改 manifest
jq '.pkg.fpc.targets["linux-x86_64"].url[0] = "https://invalid-url.example.com/fpc-3.2.2.tar.gz"' \
  ~/.fpdev/cache/manifests/fpc.json > ~/.fpdev/cache/manifests/fpc.json.tmp
mv ~/.fpdev/cache/manifests/fpc.json.tmp ~/.fpdev/cache/manifests/fpc.json

# 3. 清理已有安装
rm -rf ~/.fpdev/fpc/3.2.2

# 4. 测试安装（应该自动切换到第二个镜像）
./bin/fpdev fpc install 3.2.2

# 5. 恢复原始 manifest
mv ~/.fpdev/cache/manifests/fpc.json.bak ~/.fpdev/cache/manifests/fpc.json
```

**预期结果**:
- ✅ 第一个镜像下载失败
- ✅ 自动切换到第二个镜像
- ✅ 第二个镜像下载成功
- ✅ 安装成功

#### 场景 2.2: Hash 校验失败，自动切换到下一个镜像

**测试步骤**:
1. 修改 manifest 中的 hash 值为错误值
2. 运行安装命令
3. 观察是否检测到 hash 不匹配
4. 验证错误处理

**测试命令**:
```bash
# 1. 备份原始 manifest
cp ~/.fpdev/cache/manifests/fpc.json ~/.fpdev/cache/manifests/fpc.json.bak

# 2. 修改 manifest（将 hash 改为错误值）
jq '.pkg.fpc.targets["linux-x86_64"].hash = "sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  ~/.fpdev/cache/manifests/fpc.json > ~/.fpdev/cache/manifests/fpc.json.tmp
mv ~/.fpdev/cache/manifests/fpc.json.tmp ~/.fpdev/cache/manifests/fpc.json

# 3. 清理已有安装
rm -rf ~/.fpdev/fpc/3.2.2

# 4. 测试安装（应该检测到 hash 不匹配）
./bin/fpdev fpc install 3.2.2

# 5. 恢复原始 manifest
mv ~/.fpdev/cache/manifests/fpc.json.bak ~/.fpdev/cache/manifests/fpc.json
```

**预期结果**:
- ✅ 下载完成
- ✅ Hash 校验失败
- ✅ 尝试下一个镜像
- ✅ 所有镜像都失败后报错

**验收标准**:
- Fallback 机制正常工作
- 错误日志清晰
- 用户能够理解发生了什么

---

### 3. 离线模式测试 (优先级: 中)

**目标**: 验证离线模式（`--offline` 标志）的工作情况

**测试场景**:

#### 场景 3.1: 缓存存在时的离线安装

**测试步骤**:
1. 确保 manifest 缓存存在
2. 使用 `--offline` 标志安装
3. 验证不进行网络请求
4. 验证使用缓存的 manifest

**测试命令**:
```bash
# 1. 确保 manifest 缓存存在
./bin/fpdev fpc update-manifest

# 2. 测试离线模式（应该使用缓存）
./bin/fpdev fpc install 3.2.0 --offline

# 3. 验证
./bin/fpdev fpc list
```

**预期结果**:
- ✅ 使用缓存的 manifest
- ✅ 不进行网络请求
- ✅ 安装成功（如果二进制包已缓存）

#### 场景 3.2: 缓存不存在时的离线模式

**测试步骤**:
1. 删除 manifest 缓存
2. 使用 `--offline` 标志安装
3. 验证错误提示

**测试命令**:
```bash
# 1. 删除 manifest 缓存
rm ~/.fpdev/cache/manifests/fpc.json

# 2. 测试离线模式（应该失败）
./bin/fpdev fpc install 3.2.0 --offline

# 3. 恢复 manifest 缓存
./bin/fpdev fpc update-manifest
```

**预期结果**:
- ✅ 检测到缓存不存在
- ✅ 提示用户运行 `update-manifest`
- ✅ 安装失败（友好的错误信息）

**验收标准**:
- 离线模式正常工作
- 错误提示清晰友好
- 用户知道如何解决问题

---

### 4. 用户使用指南文档 (优先级: 中)

**目标**: 创建 MANIFEST-USAGE.md 用户使用指南

**文档内容**:

#### 4.1 Manifest 系统概述
- 什么是 manifest 系统
- 为什么需要 manifest
- Manifest 的优势

#### 4.2 基本使用
- 更新 manifest
- 查看可用版本
- 安装 FPC

#### 4.3 高级功能
- 多镜像支持
- 离线模式
- 缓存管理
- 强制刷新

#### 4.4 故障排除
- 常见问题
- 错误信息解释
- 解决方案

#### 4.5 技术细节
- Manifest 格式
- Hash 验证
- 缓存机制
- TTL 策略

**文档结构**:
```markdown
# FPDev Manifest 系统使用指南

## 概述
## 快速开始
## 基本使用
## 高级功能
## 故障排除
## 技术细节
## 常见问题
```

---

### 5. 命令帮助文档更新 (优先级: 低)

**目标**: 更新命令帮助文档，提供更详细的说明

**更新内容**:

#### 5.1 update-manifest 命令
- 添加详细的选项说明
- 添加使用示例
- 添加常见问题

#### 5.2 install 命令
- 添加 manifest 相关选项说明
- 添加离线模式说明
- 添加缓存相关说明

#### 5.3 list 命令
- 添加 `--remote` 选项说明
- 添加 manifest 相关说明

---

## 时间线

### Day 1-2: 完整安装流程测试
- 测试 FPC 3.2.0 安装
- 验证所有步骤
- 记录测试结果

### Day 3-4: 多镜像 Fallback 测试
- 测试镜像切换
- 测试 hash 校验失败
- 记录测试结果

### Day 5: 离线模式测试
- 测试离线安装
- 测试缓存不存在场景
- 记录测试结果

### Day 6-7: 文档编写
- 创建 MANIFEST-USAGE.md
- 更新命令帮助文档
- 审查和完善文档

---

## 验收标准

### 测试完成标准
- ✅ 所有测试场景通过
- ✅ 所有错误情况有友好提示
- ✅ 测试结果记录完整

### 文档完成标准
- ✅ MANIFEST-USAGE.md 创建完成
- ✅ 命令帮助文档更新完成
- ✅ 文档清晰易懂
- ✅ 包含所有必要信息

---

## 风险和缓解措施

### 风险 1: 实际二进制包不存在
**影响**: 无法完成完整安装流程测试

**缓解措施**:
- 使用 curl 验证 URL 可访问性
- 如果二进制包不存在，创建测试用的二进制包
- 或者使用已知存在的版本进行测试

### 风险 2: 网络问题影响测试
**影响**: 多镜像 fallback 测试可能受影响

**缓解措施**:
- 使用本地 HTTP 服务器模拟镜像
- 使用 manifest 修改模拟失败场景
- 记录网络状态，在稳定网络环境下测试

### 风险 3: 时间不足
**影响**: 无法完成所有任务

**缓解措施**:
- 优先完成高优先级任务
- 将低优先级任务推迟到 Week 7
- 保持灵活的时间安排

---

## 成功指标

### 测试指标
- 完整安装流程测试通过率: 100%
- 多镜像 fallback 测试通过率: 100%
- 离线模式测试通过率: 100%

### 文档指标
- MANIFEST-USAGE.md 完成度: 100%
- 命令帮助文档更新完成度: 100%
- 文档可读性评分: 优秀

### 整体完成度
- Week 5 遗留任务完成度: 100%
- Week 6 目标完成度: 100%

---

## 下一步

Week 6 完成后，将进入 Week 7，可能的方向：
1. 性能优化
2. 增强功能（签名验证、增量更新）
3. 其他工具链管理（Lazarus, Cross-compilation）
4. 用户反馈收集和改进

---

**维护者**: FPDev 开发团队
**创建日期**: 2026-01-18
**最后更新**: 2026-01-18
