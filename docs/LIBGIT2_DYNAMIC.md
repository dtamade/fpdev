# FPDev - Windows 动态加载 libgit2 使用说明

## 目标
- 提升可用性：支持多种 DLL 命名（git2.dll, libgit2-1.dll, libgit2.dll）
- 降低部署成本：Windows 运行时只需要让 `git2.dll` 可被发现，无须把 DLL 固定到仓库内某个脚本流程
- 保持当前仓库真相：围绕统一的 `src/libgit2.pas` 绑定与现有 smoke test 记录使用方式

## 架构与开关
- 当前运行时绑定：`src/libgit2.pas` 直接声明平台库名；Windows 默认是 `git2.dll`
- 上层封装：`src/fpdev.git2.pas` 与 `src/git2.modern.pas`
- 兼容目标：部署时仍可按常见 Windows 命名准备 DLL（`git2.dll`、`libgit2-1.dll`、`libgit2.dll`），但当前仓库中维护的绑定入口是 `src/libgit2.pas`

## 部署与运行
- 将 DLL 放置于以下任一位置：
  - 与可执行文件同目录（推荐）
  - PATH 所在目录
- 若 DLL 缺失或不兼容：
  - 初始化时会抛出明确错误（EGitError），提示放置 DLL 或检查依赖（zlib 等）

## TLS/HTTP 后端（Windows）
- 默认采用 Schannel/WinHTTP（CMake: -DUSE_HTTPS=WinHTTP），免 OpenSSL 分发

## 快速冒烟
- 构建并运行：
  - 工程：`tests/fpdev.core.misc/test_dyn_loader.lpi`
  - 源码：`tests/fpdev.core.misc/test_dyn_loader.lpr`
  - 行为：
    1) 编译最小程序
    2) 调用 `TGitManager.Initialize`
    3) 若缺少 DLL，输出友好异常；放置 DLL 后再次运行即可验证初始化路径

## 常见问题
1) 提示无法加载 DLL
   - 将 git2.dll 或 libgit2-1.dll 或 libgit2.dll 放在 exe 目录
   - 检查依赖（zlib、VC 运行时等）
2) 版本不兼容
   - 在 `3rd/libgit2/` 下手动重建 libgit2
   - 确保 64/32 位与编译目标一致
