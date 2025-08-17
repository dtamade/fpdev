program test_libgit2;
{$CODEPAGE UTF8}


{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.git2;

var
  GitManager: TGit2Manager;

procedure TestLibGit2Environment;
begin
  WriteLn('=== 测试libgit2环境 ===');
  WriteLn;

  if GitManager.Initialize then
  begin
    WriteLn('✓ libgit2初始化成功');
  end
  else
  begin
    WriteLn('✗ libgit2初始化失败');
    WriteLn('请确保已安装libgit2库');
    WriteLn('Windows: 需要git2.dll');
    WriteLn('Linux: 需要libgit2.so');
    WriteLn('macOS: 需要libgit2.dylib');
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

  TestDir := 'test_libgit2_repo';

  // 清理已存在的测试目录
  if DirectoryExists(TestDir) then
  begin
    WriteLn('删除已存在的测试目录...');
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', TestDir]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', TestDir]);
    {$ENDIF}
  end;

  // 测试克隆小仓库
  WriteLn('测试克隆GitHub测试仓库...');
  if GitManager.CloneRepository('https://github.com/octocat/Hello-World.git', TestDir) then
  begin
    WriteLn('✓ 测试仓库克隆成功');

    // 测试仓库检查
    if GitManager.IsRepository(TestDir) then
      WriteLn('✓ 仓库验证成功')
    else
      WriteLn('✗ 仓库验证失败');

  end
  else
  begin
    WriteLn('✗ 测试仓库克隆失败');
  end;

  WriteLn;
end;

procedure TestFPCLazarusInfo;
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

  WriteLn('注意事项:');
  WriteLn('- 首次克隆需要较长时间');
  WriteLn('- 建议使用浅克隆减少下载时间');
  WriteLn('- 可以指定特定分支进行克隆');
  WriteLn;
end;

procedure CleanupTest;
var
  TestDir: string;
begin
  WriteLn('=== 清理测试文件 ===');

  TestDir := 'test_libgit2_repo';
  if DirectoryExists(TestDir) then
  begin
    WriteLn('删除测试目录: ', TestDir);
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', TestDir]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', TestDir]);
    {$ENDIF}
    WriteLn('✓ 清理完成');
  end;
  WriteLn;
end;

begin
  try
    WriteLn('FPDev libgit2功能测试');
    WriteLn('======================');
    WriteLn;

    GitManager := TGit2Manager.Create;
    try
      TestLibGit2Environment;
      TestRepositoryOperations;
      TestFPCLazarusInfo;
      CleanupTest;

      WriteLn('=== 测试完成 ===');
      WriteLn('如果libgit2环境验证通过，说明可以使用原生Git功能。');
      WriteLn('接下来可以实现FPC和Lazarus的源码管理功能。');

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

  WriteLn;
  WriteLn('按Enter键退出...');
  ReadLn;
end.
