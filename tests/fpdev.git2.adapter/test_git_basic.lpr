program test_git_basic;
{$CODEPAGE UTF8}


{$mode objfpc}{$H+}

uses
  SysUtils, test_pause_control, Process, Classes,
  git2.api, git2.impl, fpdev.git2, test_temp_paths;

var
  GTestRootDir: string = '';
  GitManager: TGitManager = nil;


function IsGitInstalled: Boolean;
var
  LProcess: TProcess;
begin
  Result := False;
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := 'git';
    LProcess.Parameters.Add('--version');
    LProcess.Options := LProcess.Options + [poWaitOnExit, poUsePipes, poNoConsole];
    try
      LProcess.Execute;
      Result := LProcess.ExitStatus = 0;
    except
      Result := False;
    end;
  finally
    LProcess.Free;
  end;
end;

function GetGitVersion: string;
var
  LProcess: TProcess;
  LOut: TStringList;
  LErr: TStringList;
  LStart: QWord;
begin
  Result := '';
  LProcess := TProcess.Create(nil);
  LOut := TStringList.Create;
  LErr := TStringList.Create;
  try
    LProcess.Executable := 'git';
    LProcess.Parameters.Add('--version');
    LProcess.Options := LProcess.Options + [poWaitOnExit, poUsePipes, poNoConsole];
    try
      LProcess.Execute;
      // 简易超时（60s）
      LStart := GetTickCount64;
      while LProcess.Running do
      begin
        if GetTickCount64 - LStart > 60000 then
        begin
          LProcess.Terminate(1);
          Result := 'Error getting version: timeout';
          Exit;
        end;
        Sleep(50);
      end;
      if LProcess.ExitStatus = 0 then
      begin
        LOut.LoadFromStream(LProcess.Output);
        if LOut.Count > 0 then
          Result := Trim(LOut[0]);
      end
      else
      begin
        LErr.LoadFromStream(LProcess.Stderr);
        if LErr.Count > 0 then
          Result := 'Error: ' + Trim(LErr.Text)
        else
          Result := 'Error getting version';
      end;
    except
      on E: Exception do
        Result := 'Error getting version: ' + E.Message;
    end;
  finally
    LErr.Free;
    LOut.Free;
    LProcess.Free;
  end;
end;

function CloneRepository(const AURL, ATargetDir: string; const ADepth: Integer = 1; const ABranch: string = ''): Boolean;
var
  LProcess: TProcess;
  LErr: TStringList;
  LStart: QWord;
  LIdx, LMax: Integer;
begin
  Result := False;

  WriteLn('正在克隆仓库...');
  WriteLn('URL: ', AURL);
  WriteLn('目标目录: ', ATargetDir);

  // 如果目标目录已存在，先删除
  if DirectoryExists(ATargetDir) then
  begin
    WriteLn('删除已存在的目录...');
    CleanupTempDir(ATargetDir);
  end;

  // 确保父目录存在
  ForceDirectories(ExtractFileDir(ATargetDir));

  LProcess := TProcess.Create(nil);
  LErr := TStringList.Create;
  try
    LProcess.Executable := 'git';
    LProcess.Parameters.Add('clone');
    // 浅克隆以提升稳定性和速度（可配置）
    if ADepth > 0 then
    begin
      LProcess.Parameters.Add('--depth');
      LProcess.Parameters.Add(IntToStr(ADepth));
    end;
    if ABranch <> '' then
    begin
      LProcess.Parameters.Add('--branch');
      LProcess.Parameters.Add(ABranch);
    end;
    LProcess.Parameters.Add(AURL);
    LProcess.Parameters.Add(ATargetDir);
    LProcess.Options := LProcess.Options + [poWaitOnExit, poUsePipes, poNoConsole];

    if ADepth > 0 then
      WriteLn('执行: git clone --depth ', ADepth, ' ', AURL, ' ', ATargetDir)
    else
      WriteLn('执行: git clone ', AURL, ' ', ATargetDir);

    try
      LProcess.Execute;
      // 简易超时（120s）
      LStart := GetTickCount64;
      while LProcess.Running do
      begin
        if GetTickCount64 - LStart > 120000 then
        begin
          LProcess.Terminate(1);
          WriteLn('✗ 克隆失败：超时');
          Exit(False);
        end;
        Sleep(50);
      end;
      Result := LProcess.ExitStatus = 0;

      if Result then
        WriteLn('✓ 仓库克隆成功')
      else
      begin
        LErr.LoadFromStream(LProcess.Stderr);
        if LErr.Count > 0 then
        begin
          LMax := LErr.Count - 1;
          if LMax > 9 then LMax := 9;
          for LIdx := 0 to LMax do
            WriteLn('[GIT] err: ', Trim(LErr[LIdx]));
        end
        else
          WriteLn('[GIT] clone failed, exit code: ', LProcess.ExitStatus);
        ExitCode := 3;
      end;

    except
      on E: Exception do
      begin
        WriteLn('✗ 克隆过程中发生异常: ', E.Message);
        Result := False;
      end;
    end;
  finally
    LErr.Free;
    LProcess.Free;
  end;
end;

procedure TestGitEnvironment;
begin
  WriteLn('=== 测试Git环境 ===');
  WriteLn;

  if IsGitInstalled then
  begin
    WriteLn('[GIT] ✓ Git已安装');
    WriteLn('[GIT] 版本: ', GetGitVersion);
  end
  else
  begin
    WriteLn('[GIT] ✗ Git未安装或不在PATH中');
    WriteLn('[GIT] 请安装Git: https://git-scm.com/download/win');
    ExitCode := 2;
    Exit;
  end;
  WriteLn;
end;

procedure TestRepositoryOperations(const AUrl, ABranch: string; const ADepth: Integer; const AOffline: Boolean);
var
  LTestDir: string;
  LUseLibgit2: Boolean;
  LRepo: TGitRepository;
begin
  WriteLn('=== 测试仓库操作 ===');
  WriteLn;

  CleanupTempDir(GTestRootDir);
  GTestRootDir := CreateUniqueTempDir('test_basic_repo');
  LTestDir := GTestRootDir + PathDelim + 'repo';

  if AOffline then
  begin
    WriteLn('跳过克隆（offline 模式）');
    Exit;
  end;

  // 优先使用 libgit2 (若可用)，否则回退到系统 git
  WriteLn('测试克隆仓库...');
  LUseLibgit2 := False;
  try
    LUseLibgit2 := GitManager.Initialize;
  except
    LUseLibgit2 := False;
  end;

  if LUseLibgit2 then
  begin
    try
      LRepo := GitManager.CloneRepository(AUrl, LTestDir);
      try
        if Assigned(LRepo) then
        begin
          WriteLn('✓ libgit2 克隆成功');
          if DirectoryExists(LTestDir + PathDelim + '.git') then
            WriteLn('✓ Git仓库结构验证成功')
          else
            WriteLn('✗ Git仓库结构验证失败');
        end
        else
          WriteLn('✗ libgit2 克隆失败');
      finally
        if Assigned(LRepo) then LRepo.Free;
      end;
    except
      on E: Exception do
      begin
        WriteLn('! libgit2 克隆异常: ', E.Message);
      end;
    end;
  end
  else
  begin
    if CloneRepository(AUrl, LTestDir, ADepth, ABranch) then
    begin
      WriteLn('✓ 测试仓库克隆成功');
      if DirectoryExists(LTestDir + PathDelim + '.git') then
        WriteLn('✓ Git仓库结构验证成功')
      else
        WriteLn('✗ Git仓库结构验证失败');
    end
    else
    begin
      WriteLn('✗ 测试仓库克隆失败');
    end;
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

  if GTestRootDir <> '' then
  begin
    CleanupTempDir(GTestRootDir);
    GTestRootDir := '';
    WriteLn('✓ 清理完成');
  end;
  WriteLn;
end;

var
  LUrl: string;
  LBranch: string;
  LDepth: Integer;
  LOffline: Boolean;
  i: Integer;
begin
  GitManager := TGitManager.Create;
  try
    try
      WriteLn('FPDev Git功能测试 (基础版)');
    WriteLn('==========================');
    WriteLn;

    // 解析轻量级 CLI 参数
    LUrl := 'https://github.com/octocat/Hello-World.git';
    LBranch := '';
    LDepth := 1;
    // 默认离线，更安全（CI 友好）；显式 --online 或 FPDEV_ONLINE=1 才联网
    LOffline := True;

    // 环境变量优先：FPDEV_ONLINE=1 覆盖；FPDEV_OFFLINE=1 强制离线
    if GetEnvironmentVariable('FPDEV_ONLINE') <> '' then
      LOffline := False;
    if GetEnvironmentVariable('FPDEV_OFFLINE') <> '' then
      LOffline := True;
    // 遍历参数：允许 --url=... --branch=... --depth=... --offline 或 --url ...
    for i := 1 to ParamCount do
    begin
      if (ParamStr(i) = '--offline') then
        LOffline := True
      else if (Pos('--url=', ParamStr(i)) = 1) then
        LUrl := Copy(ParamStr(i), 7, MaxInt)
      else if (ParamStr(i) = '--url') and (i < ParamCount) then
        LUrl := ParamStr(i+1)
      else if (Pos('--branch=', ParamStr(i)) = 1) then
        LBranch := Copy(ParamStr(i), 10, MaxInt)
      else if (ParamStr(i) = '--branch') and (i < ParamCount) then
        LBranch := ParamStr(i+1)
      else if (Pos('--depth=', ParamStr(i)) = 1) then
        LDepth := StrToIntDef(Copy(ParamStr(i), 9, MaxInt), 1)
      else if (ParamStr(i) = '--depth') and (i < ParamCount) then
        LDepth := StrToIntDef(ParamStr(i+1), 1);
    end;

    TestGitEnvironment;
    TestRepositoryOperations(LUrl, LBranch, LDepth, LOffline);
    TestFPCLazarusInfo;
    CleanupTest;

    WriteLn('=== 测试完成 ===');
    WriteLn('如果Git环境验证通过，说明基础Git功能可以正常工作。');
    WriteLn('接下来可以获取git2.dll并测试libgit2原生功能。');

    except
      on E: Exception do
      begin
        WriteLn('测试过程中发生错误: ', E.ClassName, ': ', E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    GitManager.Free;
    GitManager := nil;
  end;

  PauseIfRequested('按Enter键退出 (--pause 或 FPDEV_DEMO_PAUSE=1 控制)...');
end.
