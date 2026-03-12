program test_git_real;
{$CODEPAGE UTF8}


{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, test_pause_control, fpdev.fpc.source, test_temp_paths;

var
  FPCManager: TFPCSourceManager;
  GTestRootDir: string = '';

function ResetTestRepoDir(const APrefix: string): string;
begin
  CleanupTempDir(GTestRootDir);
  GTestRootDir := CreateUniqueTempDir(APrefix);
  Result := GTestRootDir + PathDelim + 'repo';
end;

procedure TestSmallGitClone;
var
  TestDir: string;
begin
  WriteLn('=== 测试实际Git克隆操作 ===');
  WriteLn;

  TestDir := ResetTestRepoDir('test_small_repo');

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

  WriteLn('测试克隆小型Git仓库...');
  WriteLn('URL: https://github.com/octocat/Hello-World.git');
  WriteLn('目标: ', TestDir);
  WriteLn;

  // 执行Git克隆
  if ExecuteProcess('git', ['clone', 'https://github.com/octocat/Hello-World.git', TestDir]) = 0 then
  begin
    WriteLn('✓ Git克隆成功');

    // 验证克隆结果
    if DirectoryExists(TestDir + PathDelim + '.git') then
      WriteLn('✓ Git仓库结构验证成功')
    else
      WriteLn('✗ Git仓库结构验证失败');

    // 显示仓库信息
    WriteLn;
    WriteLn('仓库信息:');
    ExecuteProcess('git', ['-C', TestDir, 'log', '--oneline', '-5']);

  end
  else
  begin
    WriteLn('✗ Git克隆失败');
  end;

  WriteLn;
end;

procedure TestFPCSourceInfo;
begin
  WriteLn('=== FPC源码仓库信息 ===');
  WriteLn;

  WriteLn('FPC主仓库信息:');
  WriteLn('URL: https://gitlab.com/freepascal.org/fpc/source.git');
  WriteLn('大小: 约200MB (浅克隆)');
  WriteLn('完整大小: 约2GB');
  WriteLn;

  WriteLn('主要分支:');
  WriteLn('- main: 开发版本 (不稳定)');
  WriteLn('- fixes_3_2: FPC 3.2.x系列 (推荐)');
  WriteLn('- fixes_3_0: FPC 3.0.x系列 (旧版)');
  WriteLn('- fixes_2_6: FPC 2.6.x系列 (旧版)');
  WriteLn;

  WriteLn('克隆建议:');
  WriteLn('- 使用浅克隆: git clone --depth 1');
  WriteLn('- 指定分支: git clone --branch fixes_3_2');
  WriteLn('- 首次克隆需要较长时间');
  WriteLn;
end;

procedure TestFPCManagerFunctions;
begin
  WriteLn('=== 测试FPC管理器功能 ===');
  WriteLn;

  WriteLn('源码根目录: ', FPCManager.SourceRoot);
  WriteLn('当前版本: ', FPCManager.CurrentVersion);
  WriteLn;

  WriteLn('版本检查:');
  WriteLn('- 3.2.2可用: ', FPCManager.IsVersionAvailable('3.2.2'));
  WriteLn('- main可用: ', FPCManager.IsVersionAvailable('main'));
  WriteLn('- 无效版本: ', FPCManager.IsVersionAvailable('invalid'));
  WriteLn;

  WriteLn('路径生成:');
  WriteLn('- 3.2.2源码路径: ', FPCManager.GetFPCSourcePath('3.2.2'));
  WriteLn('- main源码路径: ', FPCManager.GetFPCSourcePath('main'));
  WriteLn('- 3.2.2构建路径: ', FPCManager.GetFPCBuildPath('3.2.2'));
  WriteLn;
end;

procedure ShowGitEnvironment;
begin
  WriteLn('=== Git环境检查 ===');
  WriteLn;

  // 检查Git版本
  WriteLn('Git版本:');
  if ExecuteProcess('git', ['--version']) = 0 then
    WriteLn('✓ Git已安装')
  else
    WriteLn('✗ Git未安装或不在PATH中');

  WriteLn;

  // 检查网络连接
  WriteLn('网络连接测试:');
  WriteLn('测试连接到GitHub...');
  if ExecuteProcess('ping', ['-n', '1', 'github.com']) = 0 then
    WriteLn('✓ 网络连接正常')
  else
    WriteLn('⚠ 网络连接可能有问题');

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
    WriteLn('Git操作实际测试程序');
    WriteLn('====================');
    WriteLn;

    FPCManager := TFPCSourceManager.Create;
    try
      ShowGitEnvironment;
      TestFPCManagerFunctions;
      TestFPCSourceInfo;
      TestSmallGitClone;
      CleanupTest;

      WriteLn('=== 测试完成 ===');
      WriteLn('Git操作功能验证完成！');
      WriteLn('FPC源码管理功能已就绪，可以开始实际使用。');

    finally
      FPCManager.Free;
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
