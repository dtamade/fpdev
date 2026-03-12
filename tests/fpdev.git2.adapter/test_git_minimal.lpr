program test_git_minimal;
{$CODEPAGE UTF8}


{$mode objfpc}{$H+}

uses
  SysUtils, test_pause_control, test_temp_paths;

var
  GTestRootDir: string = '';

function ResetTestRepoDir(const APrefix: string): string;
begin
  CleanupTempDir(GTestRootDir);
  GTestRootDir := CreateUniqueTempDir(APrefix);
  Result := GTestRootDir + PathDelim + 'repo';
end;

function IsGitInstalled: Boolean;
var
  ExitCode: Integer;
begin
  WriteLn('检查Git是否安装...');
  ExitCode := ExecuteProcess('git', ['--version']);
  Result := ExitCode = 0;

  if Result then
    WriteLn('✓ Git已安装')
  else
    WriteLn('✗ Git未安装或不在PATH中');
end;

function CloneRepository(const AURL, ATargetDir: string): Boolean;
var
  ExitCode: Integer;
begin
  Result := False;

  WriteLn('正在克隆仓库...');
  WriteLn('URL: ', AURL);
  WriteLn('目标目录: ', ATargetDir);

  // 如果目标目录已存在，先删除
  if DirectoryExists(ATargetDir) then
  begin
    WriteLn('删除已存在的目录...');
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', ATargetDir]);
  end;

  WriteLn('执行: git clone ', AURL, ' ', ATargetDir);

  try
    ExitCode := ExecuteProcess('git', ['clone', AURL, ATargetDir]);
    Result := ExitCode = 0;

    if Result then
      WriteLn('✓ 仓库克隆成功')
    else
      WriteLn('✗ 仓库克隆失败，退出代码: ', ExitCode);

  except
    on E: Exception do
    begin
      WriteLn('✗ 克隆过程中发生异常: ', E.Message);
      Result := False;
    end;
  end;
end;

procedure TestGitEnvironment;
begin
  WriteLn('=== 测试Git环境 ===');
  WriteLn;

  if not IsGitInstalled then
  begin
    WriteLn('请安装Git: https://git-scm.com/download/win');
    WriteLn('或确保git.exe在系统PATH中');
    Exit;
  end;
  WriteLn;
end;

procedure TestRepositoryOperations;
var
  TestDir: string;
begin
  WriteLn('=== 测试仓库操作 ===');
  WriteLn;

  TestDir := ResetTestRepoDir('test_minimal_repo');

  // 测试克隆小仓库
  WriteLn('测试克隆GitHub测试仓库...');
  if CloneRepository('https://github.com/octocat/Hello-World.git', TestDir) then
  begin
    WriteLn('✓ 测试仓库克隆成功');

    // 检查是否真的克隆成功
    if DirectoryExists(TestDir + PathDelim + '.git') then
      WriteLn('✓ Git仓库结构验证成功')
    else
      WriteLn('✗ Git仓库结构验证失败');

  end
  else
  begin
    WriteLn('✗ 测试仓库克隆失败');
  end;

  WriteLn;
end;

procedure ShowFPCLazarusInfo;
begin
  WriteLn('=== FPC和Lazarus仓库信息 ===');
  WriteLn;

  WriteLn('FPC源码仓库:');
  WriteLn('  URL: https://gitlab.com/freepascal.org/fpc/source.git');
  WriteLn('  主要分支: main, fixes_3_2, fixes_3_0');
  WriteLn('  大小: ~200MB');
  WriteLn;

  WriteLn('Lazarus源码仓库:');
  WriteLn('  URL: https://gitlab.com/freepascal.org/lazarus/lazarus.git');
  WriteLn('  主要分支: main, lazarus_3_0, lazarus_2_2');
  WriteLn('  大小: ~500MB');
  WriteLn;

  WriteLn('克隆建议:');
  WriteLn('- 使用浅克隆减少下载时间: git clone --depth 1');
  WriteLn('- 指定特定分支: git clone --branch fixes_3_2');
  WriteLn('- 首次克隆需要较长时间，请耐心等待');
  WriteLn;

  WriteLn('示例命令:');
  WriteLn('git clone --depth 1 --branch fixes_3_2 https://gitlab.com/freepascal.org/fpc/source.git fpc-3.2');
  WriteLn('git clone --depth 1 --branch lazarus_3_0 https://gitlab.com/freepascal.org/lazarus/lazarus.git lazarus-3.0');
  WriteLn;
end;

procedure CleanupTest;
begin
  WriteLn('=== 清理测试文件 ===');

  if GTestRootDir <> '' then
  begin
    WriteLn('删除测试目录: ', GTestRootDir);
    CleanupTempDir(GTestRootDir);
    GTestRootDir := '';
    WriteLn('✓ 清理完成');
  end;
  WriteLn;
end;

procedure ShowNextSteps;
begin
  WriteLn('=== 下一步计划 ===');
  WriteLn;
  WriteLn('1. 获取git2.dll:');
  WriteLn('   - 运行: scripts\get_git2_dll.bat');
  WriteLn('   - 或安装vcpkg: vcpkg install libgit2:x64-windows');
  WriteLn;
  WriteLn('2. 测试libgit2原生功能:');
  WriteLn('   - 编译: fpc -Fusrc test_libgit2.lpr');
  WriteLn('   - 运行: test_libgit2.exe');
  WriteLn;
  WriteLn('3. 实现FPC/Lazarus源码管理:');
  WriteLn('   - 基于libgit2的高性能Git操作');
  WriteLn('   - 支持进度显示和中断');
  WriteLn('   - 分支管理和版本切换');
  WriteLn;
end;

begin
  try
    WriteLn('FPDev Git功能测试 (最小版)');
    WriteLn('==========================');
    WriteLn;

    TestGitEnvironment;
    TestRepositoryOperations;
    ShowFPCLazarusInfo;
    CleanupTest;
    ShowNextSteps;

    WriteLn('=== 测试完成 ===');
    WriteLn('如果Git环境验证通过，说明基础Git功能可以正常工作。');

  except
    on E: Exception do
    begin
      WriteLn('测试过程中发生错误: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;

  PauseIfRequested('按Enter键退出...');
end.
