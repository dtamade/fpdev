program fpdev_git2_status_conflict_test;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Process,
  git2.types,
  fpdev.git2;

procedure AssertTrue(const AMsg: string; ACond: Boolean);
begin
  if ACond then
    WriteLn('✓ ', AMsg)
  else
  begin
    WriteLn('✗ ', AMsg);
    Halt(2);
  end;
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

function RunGit(const ADir: string; const AArgs: array of string;
  out AStdOut, AStdErr: string): Integer;
var
  Proc: TProcess;
  OutLines: TStringList;
  ErrLines: TStringList;
  I: Integer;
begin
  Proc := TProcess.Create(nil);
  OutLines := TStringList.Create;
  ErrLines := TStringList.Create;
  try
    Proc.Executable := 'git';
    for I := Low(AArgs) to High(AArgs) do
      Proc.Parameters.Add(AArgs[I]);
    if ADir <> '' then
      Proc.CurrentDirectory := ADir;
    Proc.Options := [poWaitOnExit, poUsePipes, poNoConsole];
    Proc.Execute;
    OutLines.LoadFromStream(Proc.Output);
    ErrLines.LoadFromStream(Proc.Stderr);
    AStdOut := Trim(OutLines.Text);
    AStdErr := Trim(ErrLines.Text);
    Result := Proc.ExitStatus;
  finally
    ErrLines.Free;
    OutLines.Free;
    Proc.Free;
  end;
end;

procedure CheckGitOk(const ADir: string; const AArgs: array of string);
var
  StdOut: string;
  StdErr: string;
  ExitCode: Integer;
begin
  ExitCode := RunGit(ADir, AArgs, StdOut, StdErr);
  if ExitCode <> 0 then
    raise Exception.CreateFmt('git %s failed with code %d: %s',
      [AArgs[0], ExitCode, StdErr]);
end;

function GitInstalled: Boolean;
var
  StdOut: string;
  StdErr: string;
begin
  Result := RunGit('', ['--version'], StdOut, StdErr) = 0;
end;

function GitCurrentBranch(const ADir: string): string;
var
  StdOut: string;
  StdErr: string;
begin
  if RunGit(ADir, ['branch', '--show-current'], StdOut, StdErr) <> 0 then
    raise Exception.Create('unable to detect current branch: ' + StdErr);
  Result := Trim(StdOut);
  if Result = '' then
    raise Exception.Create('git branch --show-current returned empty output');
end;

procedure PrepareConflictedRepository(const ADir: string);
var
  MergeStdOut: string;
  MergeStdErr: string;
  DefaultBranch: string;
  MergeExitCode: Integer;
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

  MergeExitCode := RunGit(ADir, ['merge', 'feature'], MergeStdOut, MergeStdErr);
  AssertTrue('merge should stop on content conflict', MergeExitCode = 1);
  AssertTrue('merge stderr mentions conflict',
    (Pos('CONFLICT', UpperCase(MergeStdErr)) > 0) or
    (Pos('conflict', LowerCase(MergeStdOut)) > 0));
end;

procedure AssertConflictEntryPresent(const AEntries: TGitStatusEntryArray;
  const AFileName, AContext: string);
var
  I: Integer;
  Found: Boolean;
begin
  Found := False;
  for I := 0 to High(AEntries) do
    if SameText(ExtractFileName(AEntries[I].Path), AFileName) and
       (gsConflicted in AEntries[I].Flags) then
      Found := True;
  AssertTrue(AContext, Found);
end;

procedure Run;
var
  Manager: TGitManager;
  Repo: TGitRepository;
  RepoDir: string;
  Filter: TGitStatusFilter;
  Entries: TGitStatusEntryArray;
begin
  if not GitInstalled then
  begin
    WriteLn('! 跳过：未找到 git 命令');
    Exit;
  end;

  Manager := TGitManager.Create;
  try
    if not Manager.Initialize then
    begin
      WriteLn('! 跳过：未找到 libgit2（Initialize 失败）');
      Exit;
    end;

    RepoDir := GetCurrentDir + PathDelim + 'tmp_status_conflict_' +
      FormatDateTime('yyyymmddhhnnss', Now);
    RemoveTree(RepoDir);
    ForceDirectories(RepoDir);
    Repo := nil;
    try
      PrepareConflictedRepository(RepoDir);
      Repo := Manager.OpenRepository(RepoDir);

      FillByte(Filter, SizeOf(Filter), 0);
      Entries := Repo.StatusEntries(Filter);
      AssertConflictEntryPresent(Entries, 'conflict.txt',
        'default StatusEntries should include conflicted file');
      AssertTrue('repository with merge conflict is not clean', not Repo.IsClean);
      AssertTrue('repository with merge conflict has uncommitted changes',
        Repo.HasUncommittedChanges);

      FillByte(Filter, SizeOf(Filter), 0);
      Filter.IndexOnly := True;
      Entries := Repo.StatusEntries(Filter);
      AssertConflictEntryPresent(Entries, 'conflict.txt',
        'IndexOnly StatusEntries should include conflicted file');
    finally
      if Assigned(Repo) then
        Repo.Free;
      RemoveTree(RepoDir);
    end;
  finally
    Manager.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn('测试异常: ', E.Message);
      Halt(1);
    end;
  end;
end.
