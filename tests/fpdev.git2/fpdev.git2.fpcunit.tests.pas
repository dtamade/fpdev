unit fpdev.git2.fpcunit.tests;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process,
  fpcunit, testregistry,
  git2.types, git2.api, git2.impl, fpdev.git2;

type
  { TTestCase_Global }
  TTestCase_Global = class(TTestCase)
  published
    procedure Test_DiscoverRepository_Fallback;
  end;

  { TTestCase_Git2Status }
  TTestCase_Git2Status = class(TTestCase)
  private
    function Libgit2Available: Boolean;
  published
    procedure Test_StatusEntries_Untracked_Filtered;
    procedure Test_StatusEntries_Conflict_Filtered;
  end;

implementation

procedure RemoveTree(const APath: string);
begin
  if not DirectoryExists(APath) then
    Exit;
  {$IFDEF MSWINDOWS}
  ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', APath]);
  {$ELSE}
  ExecuteProcess('/bin/rm', ['-rf', APath]);
  {$ENDIF}
end;

procedure WriteTextFile(const APath, AText: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

function RunGit(const ADir: string; const AArgs: array of string): Integer;
var
  Proc: TProcess;
  I: Integer;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := 'git';
    for I := Low(AArgs) to High(AArgs) do
      Proc.Parameters.Add(AArgs[I]);
    if ADir <> '' then
      Proc.CurrentDirectory := ADir;
    Proc.Options := [poWaitOnExit, poUsePipes, poNoConsole];
    Proc.Execute;
    Result := Proc.ExitStatus;
  finally
    Proc.Free;
  end;
end;

procedure CheckGitOk(const ADir: string; const AArgs: array of string);
begin
  if RunGit(ADir, AArgs) <> 0 then
    raise Exception.CreateFmt('git %s failed', [AArgs[0]]);
end;

function GitCliAvailable: Boolean;
begin
  Result := RunGit('', ['--version']) = 0;
end;

function GitCurrentBranch(const ADir: string): string;
var
  Proc: TProcess;
  Lines: TStringList;
begin
  Proc := TProcess.Create(nil);
  Lines := TStringList.Create;
  try
    Proc.Executable := 'git';
    Proc.Parameters.Add('branch');
    Proc.Parameters.Add('--show-current');
    Proc.CurrentDirectory := ADir;
    Proc.Options := [poWaitOnExit, poUsePipes, poNoConsole];
    Proc.Execute;
    if Proc.ExitStatus <> 0 then
      raise Exception.Create('git branch --show-current failed');
    Lines.LoadFromStream(Proc.Output);
    Result := Trim(Lines.Text);
    if Result = '' then
      raise Exception.Create('git branch --show-current returned empty output');
  finally
    Lines.Free;
    Proc.Free;
  end;
end;

procedure PrepareConflictedRepository(const ADir: string);
var
  DefaultBranch: string;
begin
  ForceDirectories(ADir);
  CheckGitOk(ADir, ['init']);
  CheckGitOk(ADir, ['config', 'user.name', 'tester']);
  CheckGitOk(ADir, ['config', 'user.email', 'tester@example.com']);

  WriteTextFile(ADir + PathDelim + 'conflict.txt', 'base' + LineEnding);
  CheckGitOk(ADir, ['add', 'conflict.txt']);
  CheckGitOk(ADir, ['commit', '-m', 'base']);

  DefaultBranch := GitCurrentBranch(ADir);
  CheckGitOk(ADir, ['checkout', '-b', 'feature']);
  WriteTextFile(ADir + PathDelim + 'conflict.txt', 'feature' + LineEnding);
  CheckGitOk(ADir, ['commit', '-am', 'feature change']);

  CheckGitOk(ADir, ['checkout', DefaultBranch]);
  WriteTextFile(ADir + PathDelim + 'conflict.txt', 'mainline' + LineEnding);
  CheckGitOk(ADir, ['commit', '-am', 'mainline change']);

  if RunGit(ADir, ['merge', 'feature']) <> 1 then
    raise Exception.Create('git merge did not stop on conflict');
end;

procedure TTestCase_Global.Test_DiscoverRepository_Fallback;
var
  LMgr: IGitManager;
  LTmp, LGitDir, LFound: string;
begin
  LTmp := GetCurrentDir + PathDelim + 'tmp_discover_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LTmp);
  LGitDir := IncludeTrailingPathDelimiter(LTmp) + '.git';
  ForceDirectories(LGitDir);
  try
    LMgr := NewGitManager; // 不依赖 Initialize，即走回退实现
    LFound := LMgr.DiscoverRepository(LTmp);
    AssertTrue('Discover 应返回临时仓库根',
      (LFound <> '') and
      (ExtractFileName(ExcludeTrailingPathDelimiter(LFound)) = ExtractFileName(LTmp)));
  finally
    RemoveTree(LTmp);
  end;
end;

function TTestCase_Git2Status.Libgit2Available: Boolean;
var
  LMgr: IGitManager;
begin
  Result := False;
  try
    LMgr := NewGitManager;
    Result := LMgr.Initialize;
  except
    Result := False;
  end;
end;

procedure TTestCase_Git2Status.Test_StatusEntries_Untracked_Filtered;
var
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LDir, LFileUntracked: string;
  LFilter: TGitStatusFilter;
  LEntries: array of TGitStatusEntry;
  LFound: Boolean;
  i: Integer;
begin
  if not Libgit2Available then
  begin
    AssertTrue('libgit2 不可用，跳过', True);
    Exit;
  end;
  LMgr := NewGitManager;
  LDir := GetCurrentDir + PathDelim + 'tmp_status_unit_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LDir);
  try
    LRepo := LMgr.InitRepository(LDir, False);
    LFileUntracked := LDir + PathDelim + 'u.txt';
    with TStringList.Create do
    try
      Text := 'hello';
      SaveToFile(LFileUntracked);
    finally
      Free;
    end;
    FillByte(LFilter, SizeOf(LFilter), 0);
    LFilter.WorkingTreeOnly := True;
    LFilter.IncludeUntracked := True;
    LEntries := LRepo.StatusEntries(LFilter);
    LFound := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'u.txt') then
        LFound := True;
    AssertTrue('应包含未跟踪文件', LFound);

    // 关闭未跟踪包含，应排除
    LFilter.IncludeUntracked := False;
    LEntries := LRepo.StatusEntries(LFilter);
    LFound := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'u.txt') then
        LFound := True;
    AssertTrue('不应包含未跟踪文件（过滤生效）', not LFound);
  finally
    RemoveTree(LDir);
  end;
end;

procedure TTestCase_Git2Status.Test_StatusEntries_Conflict_Filtered;
var
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LDir: string;
  LFilter: TGitStatusFilter;
  LEntries: array of TGitStatusEntry;
  LFound: Boolean;
  I: Integer;
begin
  if (not GitCliAvailable) or (not Libgit2Available) then
  begin
    AssertTrue('git/libgit2 不可用，跳过', True);
    Exit;
  end;

  LMgr := NewGitManager;
  LDir := GetCurrentDir + PathDelim + 'tmp_status_conflict_unit_' +
    FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LDir);
  try
    PrepareConflictedRepository(LDir);
    LRepo := LMgr.OpenRepository(LDir);

    FillByte(LFilter, SizeOf(LFilter), 0);
    LEntries := LRepo.StatusEntries(LFilter);
    LFound := False;
    for I := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[I].Path), 'conflict.txt') and
         (gsConflicted in LEntries[I].Flags) then
        LFound := True;
    AssertTrue('默认视图应包含冲突项', LFound);

    FillByte(LFilter, SizeOf(LFilter), 0);
    LFilter.IndexOnly := True;
    LEntries := LRepo.StatusEntries(LFilter);
    LFound := False;
    for I := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[I].Path), 'conflict.txt') and
         (gsConflicted in LEntries[I].Flags) then
        LFound := True;
    AssertTrue('IndexOnly 视图应保留冲突项', LFound);
  finally
    RemoveTree(LDir);
  end;
end;

initialization
  RegisterTest(TTestCase_Global);
  RegisterTest(TTestCase_Git2Status);

end.
