program test_git_simple;
{$CODEPAGE UTF8}


{$mode objfpc}{$H+}

uses
  SysUtils, Classes;

// 简化的Git操作类，不依赖libgit2
type
  { TSimpleGitManager }
  TSimpleGitManager = class
  private
    function ExecuteCommand(const ACommand: string): Boolean;
    function GetCommandOutput(const ACommand: string): string;

  public
    constructor Create;
    destructor Destroy; override;

    // 基本Git操作（使用命令行git）
    function IsGitInstalled: Boolean;
    function GetGitVersion: string;
    function CloneRepository(const AURL, ATargetDir: string; const ABranch: string = ''): Boolean;
    function IsGitRepository(const APath: string): Boolean;
    function UpdateRepository(const ARepoPath: string): Boolean;
    function GetCurrentBranch(const ARepoPath: string): string;
    function GetLastCommitHash(const ARepoPath: string): string;
  end;

{ TSimpleGitManager }

constructor TSimpleGitManager.Create;
begin
  inherited Create;
end;

destructor TSimpleGitManager.Destroy;
begin
  inherited Destroy;
end;

function TSimpleGitManager.ExecuteCommand(const ACommand: string): Boolean;
var
  ExitCode: Integer;
begin
  WriteLn('执行: ', ACommand);
  ExitCode := ExecuteProcess('cmd', ['/c', ACommand]);
  Result := ExitCode = 0;
  if not Result then
    WriteLn('命令执行失败，退出代码: ', ExitCode);
end;

function TSimpleGitManager.GetCommandOutput(const ACommand: string): string;
var
  Output: TStringList;
  TempFile: string;
begin
  Result := '';
  TempFile := 'temp_git_output.txt';

  try
    if ExecuteProcess('cmd', ['/c', ACommand + ' > "' + TempFile + '" 2>&1']) = 0 then
    begin
      Output := TStringList.Create;
      try
        if FileExists(TempFile) then
        begin
          Output.LoadFromFile(TempFile);
          Result := Trim(Output.Text);
        end;
      finally
        Output.Free;
      end;
    end;
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

function TSimpleGitManager.IsGitInstalled: Boolean;
var
  Version: string;
begin
  Version := GetCommandOutput('git --version');
  Result := (Version <> '') and (Pos('git version', LowerCase(Version)) > 0);
end;

function TSimpleGitManager.GetGitVersion: string;
begin
  Result := GetCommandOutput('git --version');
  if Result = '' then
    Result := 'Git not found';
end;

function TSimpleGitManager.IsGitRepository(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath + PathDelim + '.git');
end;

function TSimpleGitManager.CloneRepository(const AURL, ATargetDir: string; const ABranch: string): Boolean;
var
  Command: string;
  ParentDir: string;
begin
  Result := False;

  if not IsGitInstalled then
  begin
    WriteLn('✗ Git未安装或不在PATH中');
    Exit;
  end;

  WriteLn('正在克隆仓库...');
  WriteLn('URL: ', AURL);
  WriteLn('目标目录: ', ATargetDir);
  if ABranch <> '' then
    WriteLn('分支: ', ABranch);

  // 确保父目录存在
  ParentDir := ExtractFileDir(ATargetDir);
  if not DirectoryExists(ParentDir) then
  begin
    WriteLn('创建目录: ', ParentDir);
    if not ForceDirectories(ParentDir) then
    begin
      WriteLn('✗ 无法创建目录: ', ParentDir);
      Exit;
    end;
  end;

  // 如果目标目录已存在且是Git仓库，则更新
  if IsGitRepository(ATargetDir) then
  begin
    WriteLn('目标目录已存在Git仓库，尝试更新...');
    Result := UpdateRepository(ATargetDir);
    Exit;
  end;

  // 构建克隆命令
  Command := 'git clone';
  if ABranch <> '' then
    Command := Command + ' --branch ' + ABranch;
  Command := Command + ' "' + AURL + '" "' + ATargetDir + '"';

  Result := ExecuteCommand(Command);

  if Result then
    WriteLn('✓ 仓库克隆成功')
  else
    WriteLn('✗ 仓库克隆失败');
end;

function TSimpleGitManager.UpdateRepository(const ARepoPath: string): Boolean;
var
  Command: string;
  OldDir: string;
begin
  Result := False;

  if not IsGitRepository(ARepoPath) then
  begin
    WriteLn('✗ ', ARepoPath, ' 不是Git仓库');
    Exit;
  end;

  WriteLn('正在更新仓库: ', ARepoPath);

  // 切换到仓库目录
  OldDir := GetCurrentDir;
  try
    if SetCurrentDir(ARepoPath) then
    begin
      Command := 'git pull';
      Result := ExecuteCommand(Command);

      if Result then
        WriteLn('✓ 仓库更新成功')
      else
        WriteLn('✗ 仓库更新失败');
    end
    else
    begin
      WriteLn('✗ 无法切换到目录: ', ARepoPath);
    end;
  finally
    SetCurrentDir(OldDir);
  end;
end;

function TSimpleGitManager.GetCurrentBranch(const ARepoPath: string): string;
var
  OldDir: string;
begin
  Result := '';

  if not IsGitRepository(ARepoPath) then
    Exit;

  OldDir := GetCurrentDir;
  try
    if SetCurrentDir(ARepoPath) then
    begin
      Result := Trim(GetCommandOutput('git rev-parse --abbrev-ref HEAD'));
    end;
  finally
    SetCurrentDir(OldDir);
  end;
end;

function TSimpleGitManager.GetLastCommitHash(const ARepoPath: string): string;
var
  OldDir: string;
begin
  Result := '';

  if not IsGitRepository(ARepoPath) then
    Exit;

  OldDir := GetCurrentDir;
  try
    if SetCurrentDir(ARepoPath) then
    begin
      Result := Trim(GetCommandOutput('git rev-parse HEAD'));
    end;
  finally
    SetCurrentDir(OldDir);
  end;
end;

// 主程序
var
  GitManager: TSimpleGitManager;
  TestDir: string;

procedure TestGitEnvironment;
begin
  WriteLn('=== 测试Git环境 ===');
  WriteLn;

  if GitManager.IsGitInstalled then
  begin
    WriteLn('✓ Git已安装');
    WriteLn('版本: ', GitManager.GetGitVersion);
  end
  else
  begin
    WriteLn('✗ Git未安装或不在PATH中');
    WriteLn('请安装Git: https://git-scm.com/download/win');
    Exit;
  end;
  WriteLn;
end;

procedure TestRepositoryOperations;
begin
  WriteLn('=== 测试仓库操作 ===');
  WriteLn;

  TestDir := 'test_simple_repo';

  // 清理已存在的测试目录
  if DirectoryExists(TestDir) then
  begin
    WriteLn('删除已存在的测试目录...');
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', TestDir]);
  end;

  // 测试克隆小仓库
  WriteLn('测试克隆GitHub测试仓库...');
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

  WriteLn('克隆建议:');
  WriteLn('- 使用浅克隆: git clone --depth 1');
  WriteLn('- 指定分支: git clone --branch fixes_3_2');
  WriteLn('- 首次克隆需要较长时间');
  WriteLn;
end;

procedure CleanupTest;
begin
  WriteLn('=== 清理测试文件 ===');

  if DirectoryExists(TestDir) then
  begin
    WriteLn('删除测试目录: ', TestDir);
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', TestDir]);
    WriteLn('✓ 清理完成');
  end;
  WriteLn;
end;

begin
  try
    WriteLn('FPDev Git功能测试 (简化版)');
    WriteLn('============================');
    WriteLn;

    GitManager := TSimpleGitManager.Create;
    try
      TestGitEnvironment;
      TestRepositoryOperations;
      TestFPCLazarusInfo;
      CleanupTest;

      WriteLn('=== 测试完成 ===');
      WriteLn('如果Git环境验证通过，说明基础Git功能可以正常工作。');
      WriteLn('接下来可以获取git2.dll并测试libgit2原生功能。');

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
