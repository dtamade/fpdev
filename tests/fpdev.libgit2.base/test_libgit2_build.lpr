program test_libgit2_build;
{$CODEPAGE UTF8}


{$mode objfpc}{$H+}

uses
  SysUtils, test_pause_control, fpdev.git2, test_temp_paths;

var
  GitManager: TGit2Manager;
  GTestRootDir: string = '';

function ResetTestRepoDir(const APrefix: string): string;
begin
  CleanupTempDir(GTestRootDir);
  GTestRootDir := CreateUniqueTempDir(APrefix);
  Result := GTestRootDir + PathDelim + 'repo';
end;

function GetTestRepoDir: string;
begin
  if GTestRootDir = '' then
    Exit('');
  Result := GTestRootDir + PathDelim + 'repo';
end;

procedure TestLibGit2Build;
begin
  WriteLn('=== 测试构建的libgit2库 ===');
  WriteLn;

  WriteLn('检查库文件:');

  {$IFDEF MSWINDOWS}
  if FileExists('3rd\libgit2\install\bin\git2.dll') then
    WriteLn('✓ 动态库: 3rd\libgit2\install\bin\git2.dll')
  else
    WriteLn('✗ 动态库未找到: 3rd\libgit2\install\bin\git2.dll');

  if FileExists('3rd\libgit2\install\lib\git2.lib') then
    WriteLn('✓ 导入库: 3rd\libgit2\install\lib\git2.lib')
  else
    WriteLn('✗ 导入库未找到: 3rd\libgit2\install\lib\git2.lib');

  if FileExists('3rd\libgit2\install\lib\git2_static.lib') then
    WriteLn('✓ 静态库: 3rd\libgit2\install\lib\git2_static.lib')
  else
    WriteLn('✗ 静态库未找到: 3rd\libgit2\install\lib\git2_static.lib');
  {$ENDIF}

  {$IFDEF LINUX}
  if FileExists('3rd/libgit2/install/lib/libgit2.so') then
    WriteLn('✓ 动态库: 3rd/libgit2/install/lib/libgit2.so')
  else
    WriteLn('✗ 动态库未找到: 3rd/libgit2/install/lib/libgit2.so');

  if FileExists('3rd/libgit2/install/lib/libgit2.a') then
    WriteLn('✓ 静态库: 3rd/libgit2/install/lib/libgit2.a')
  else
    WriteLn('✗ 静态库未找到: 3rd/libgit2/install/lib/libgit2.a');
  {$ENDIF}

  if FileExists('3rd' + PathDelim + 'libgit2' + PathDelim + 'install' + PathDelim + 'include' + PathDelim + 'git2.h') then
    WriteLn('✓ 头文件: 3rd' + PathDelim + 'libgit2' + PathDelim + 'install' + PathDelim + 'include' + PathDelim + 'git2.h')
  else
    WriteLn('✗ 头文件未找到');

  WriteLn;
end;

procedure TestLibGit2Loading;
begin
  WriteLn('=== 测试libgit2库加载 ===');
  WriteLn;

  // 首先复制DLL到当前目录 (Windows)
  {$IFDEF MSWINDOWS}
  if FileExists('3rd\libgit2\install\bin\git2.dll') and not FileExists('git2.dll') then
  begin
    WriteLn('复制git2.dll到当前目录...');
    if ExecuteProcess('copy', ['3rd\libgit2\install\bin\git2.dll', 'git2.dll']) = 0 then
      WriteLn('✓ DLL复制成功')
    else
      WriteLn('✗ DLL复制失败');
  end;
  {$ENDIF}

  try
    if GitManager.Initialize then
    begin
      WriteLn('✓ libgit2初始化成功');
      WriteLn('可以开始使用Git功能了!');
    end
    else
    begin
      WriteLn('✗ libgit2初始化失败');
      WriteLn('请检查库文件是否正确构建和放置');
    end;
  except
    on E: Exception do
    begin
      WriteLn('✗ libgit2加载异常: ', E.Message);
      WriteLn('可能的原因:');
      WriteLn('- 库文件未找到或损坏');
      WriteLn('- 依赖库缺失');
      WriteLn('- 架构不匹配 (32位/64位)');
    end;
  end;

  WriteLn;
end;

procedure TestSimpleGitOperation;
var
  TestDir: string;
begin
  WriteLn('=== 测试简单Git操作 ===');
  WriteLn;

  if not GitManager.Initialize then
  begin
    WriteLn('✗ libgit2未初始化，跳过Git操作测试');
    Exit;
  end;

  TestDir := ResetTestRepoDir('test_libgit2_clone');

  WriteLn('测试克隆小仓库...');
  if GitManager.CloneRepository('https://github.com/octocat/Hello-World.git', TestDir) then
  begin
    WriteLn('✓ 使用libgit2克隆成功!');

    // 验证仓库
    if GitManager.IsRepository(TestDir) then
      WriteLn('✓ 仓库验证成功')
    else
      WriteLn('✗ 仓库验证失败');

  end
  else
  begin
    WriteLn('✗ 克隆失败');
  end;

  WriteLn;
end;

procedure CleanupTest;
begin
  if GTestRootDir <> '' then
  begin
    WriteLn('清理测试目录: ', GTestRootDir);
    CleanupTempDir(GTestRootDir);
    GTestRootDir := '';
  end;
  WriteLn;
end;

procedure ShowNextSteps;
begin
  WriteLn('=== 下一步计划 ===');
  WriteLn;
  WriteLn('如果libgit2构建和测试成功，您可以:');
  WriteLn;
  WriteLn('1. 集成到FPDev主程序:');
  WriteLn('   - 更新fpdev.libgit2.pas中的库路径');
  WriteLn('   - 在主程序中使用TGit2Manager');
  WriteLn;
  WriteLn('2. 实现FPC/Lazarus源码管理:');
  WriteLn('   - 克隆FPC源码: https://gitlab.com/freepascal.org/fpc/source.git');
  WriteLn('   - 克隆Lazarus源码: https://gitlab.com/freepascal.org/lazarus/lazarus.git');
  WriteLn('   - 实现分支切换和版本管理');
  WriteLn;
  WriteLn('3. 添加高级功能:');
  WriteLn('   - 进度显示和中断支持');
  WriteLn('   - 增量更新和缓存');
  WriteLn('   - 多线程下载');
  WriteLn;
  WriteLn('4. 跨平台部署:');
  WriteLn('   - 在Linux上构建: ./scripts/build_libgit2_linux.sh');
  WriteLn('   - 在macOS上构建类似的脚本');
  WriteLn('   - 创建发布包');
  WriteLn;
end;

begin
  try
    WriteLn('libgit2 构建测试程序');
    WriteLn('=====================');
    WriteLn;

    GitManager := TGit2Manager.Create;
    try
      TestLibGit2Build;
      TestLibGit2Loading;
      TestSimpleGitOperation;
      CleanupTest;
      ShowNextSteps;

      WriteLn('=== 测试完成 ===');

    finally
      GitManager.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn('测试过程中发生错误: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;

  PauseIfRequested('按Enter键退出...');
end.
