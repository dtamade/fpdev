# FPDev - Windows 动态加载 libgit2 使用说明（历史快照）

> 2026-04-05 更新：本文记录一轮历史性的 Windows 动态加载 libgit2 方案草稿。
> 当前工作树中 `src/libgit2.dynamic.pas`、`scripts/test_dynamic_loader.bat` 与 `scripts/build_libgit2_windows.bat` 并不是现行交付物，请以 `src/libgit2.pas`、`src/git2.modern.pas`、`docs/GIT2_USAGE.md` 和 `docs/FAQ.md` 为当前边界。

## 2026-04-05 当前工作树补充

- `src/fpdev.config.inc` 仍保留 `LIBGIT2_DYNAMIC` 宏定义，但当前 `src/` 下没有配套的 `src/libgit2.dynamic.pas` 实现文件。
- 当前仓库中也没有本文历史正文提到的 `scripts/test_dynamic_loader.bat` 或 `scripts/build_libgit2_windows.bat`。
- 当前公开运行时说明以 `src/libgit2.pas` 为准：
  - Windows：`git2.dll`
  - Linux：`libgit2.so`
  - macOS：`libgit2.1.dylib`
- 若需要当前的 Git/libgit2 使用与排障入口，请优先阅读 `docs/GIT2_USAGE.md` 和 `docs/FAQ.md`。

## 历史快照正文

## 目标
- 提升可用性：支持多种 DLL 命名（git2.dll, libgit2-1.dll, libgit2.dll）
- 降低部署成本：Windows 默认在运行时延迟加载（LIBGIT2_DYNAMIC），无须固定名称/路径
- 可回退：-dNO_LIBGIT2_DYNAMIC 一键回到 external 方式

## 架构与开关
- 配置包含文件：src/fpdev.config.inc（Windows 默认启用 LIBGIT2_DYNAMIC）
- modern 封装：src/git2.modern.pas 按宏切换 uses libgit2.dynamic 或 libgit2
- 动态加载器：src/libgit2.dynamic.pas，探测顺序：
  1) git2.dll
  2) libgit2-1.dll
  3) libgit2.dll

回退开关（编译时）：
- 禁用动态加载：添加 -dNO_LIBGIT2_DYNAMIC

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
  - 脚本：scripts/test_dynamic_loader.bat
  - 行为：
    1) 编译最小程序
    2) 运行一次（若缺少 DLL，给出友好提示；放置 DLL 后再运行可成功）

## 常见问题
1) 提示无法加载 DLL
   - 将 git2.dll 或 libgit2-1.dll 或 libgit2.dll 放在 exe 目录
   - 检查依赖（zlib、VC 运行时等）
2) 版本不兼容
   - 升级/重建 libgit2（scripts/build_libgit2_windows.bat / mingw 版本）
   - 确保 64/32 位与编译目标一致

