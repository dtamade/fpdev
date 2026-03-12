program test_git;
{$CODEPAGE UTF8}


{$mode objfpc}{$H+}

uses
  SysUtils, test_pause_control, Classes,
  fpdev.git, test_temp_paths;

var
  GitManager: TGitManager;
  TestDir: string;
  GTestRootDir: string = '';

function ResetTestRepoDir(const APrefix: string): string;
begin
  CleanupTempDir(GTestRootDir);
  GTestRootDir := CreateUniqueTempDir(APrefix);
  Result := GTestRootDir + PathDelim + 'repo';
end;

procedure TestGitEnvironment;
begin
  WriteLn('=== 测试Git环境 ===');
  WriteLn;

  if GitManager.ValidateGitEnvironment then
  begin
    WriteLn('Git版本: ', GitManager.GetGitVersion);
    WriteLn('✓ Git环境验证通过');
  end
  else
  begin
    WriteLn('✗ Git环境验证失败');
    WriteLn('请确保已安装Git并添加到PATH环境变量');
    Exit;
  end;
  WriteLn;
end;

procedure TestCloneRepository;
begin
  WriteLn('=== 测试仓库克隆 ===');
  WriteLn;

  // 测试克隆一个小的测试仓库
  TestDir := ResetTestRepoDir('test_repo');

  // 如果目录已存在，先删除
  if DirectoryExists(TestDir) then
  begin
    WriteLn('删除已存在的测试目录...');
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', TestDir]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', TestDir]);
    {$ENDIF}
  end;

  // 克隆一个简单的测试仓库（使用GitHub的hello-world仓库）
  if GitManager.CloneRepository('https://github.com/octocat/Hello-World.git', TestDir) then
  begin
    WriteLn('✓ 测试仓库克隆成功');

    // 测试获取当前分支
    WriteLn('当前分支: ', GitManager.GetCurrentBranch(TestDir));

    // 测试获取提交哈希
    WriteLn('最新提交: ', GitManager.GetLastCommitHash(TestDir));

  end
  else
  begin
    WriteLn('✗ 测试仓库克隆失败');
  end;
  WriteLn;
end;

procedure TestFPCRepository;
begin
  WriteLn('=== 测试FPC仓库信息 ===');
  WriteLn;

  // 这里我们只测试能否连接到FPC仓库，不实际克隆（太大了）
  WriteLn('FPC仓库URL: https://gitlab.com/freepascal.org/fpc/source.git');
  WriteLn('注意: 实际克隆FPC仓库需要较长时间和较大磁盘空间');
  WriteLn('在实际使用中，建议使用浅克隆: git clone --depth 1');
  WriteLn;
end;

procedure TestLazarusRepository;
begin
  WriteLn('=== 测试Lazarus仓库信息 ===');
  WriteLn;

  WriteLn('Lazarus仓库URL: https://gitlab.com/freepascal.org/lazarus/lazarus.git');
  WriteLn('注意: 实际克隆Lazarus仓库需要较长时间和较大磁盘空间');
  WriteLn('在实际使用中，建议使用浅克隆: git clone --depth 1');
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

begin
  try
    WriteLn('FPDev Git功能测试');
    WriteLn('==================');
    WriteLn;

    GitManager := TGitManager.Create;
    try
      TestGitEnvironment;
      TestCloneRepository;
      TestFPCRepository;
      TestLazarusRepository;
      CleanupTest;

      WriteLn('=== 测试完成 ===');
      WriteLn('如果Git环境验证通过，说明基础Git功能可以正常工作。');
      WriteLn('接下来可以实现FPC和Lazarus的源码下载功能。');

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
