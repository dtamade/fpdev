program fpdev_git2_status_ignore_test;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  git2.types,
  git2.api, git2.impl,
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

procedure Run;
var
  LMgr: IGitManager;
  LHasDll: Boolean;
  LRepoDir, LIgnoreFile, LIgnored: string;
  LRepo: TGitRepository;
  LFilter: TGitStatusFilter;
  LEntries: TGitStatusEntryArray;
  LFoundIgnored: Boolean;
  i: Integer;
begin
  LHasDll := False;
  try
    LMgr := NewGitManager;
    LHasDll := LMgr.Initialize;
  except
    LHasDll := False;
  end;
  if not LHasDll then
  begin
    WriteLn('! 跳过：未找到 libgit2（Initialize 失败）');
    Exit;
  end
  else
    WriteLn('✓ 检测到 libgit2，可运行忽略文件测试');

  // 创建临时仓库
  LRepoDir := GetCurrentDir + PathDelim + 'tmp_status_ignore_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LRepoDir);

  LRepo := nil;
  try
    LRepo := GitManager.InitRepository(LRepoDir, False);

    // 写 .gitignore 和被忽略文件
    LIgnoreFile := LRepoDir + PathDelim + '.gitignore';
    LIgnored := LRepoDir + PathDelim + 'ignored.txt';
    with TStringList.Create do
    try
      Text := 'ignored.txt' + LineEnding;
      SaveToFile(LIgnoreFile);
    finally
      Free;
    end;
    with TStringList.Create do
    try
      Text := 'ignored content';
      SaveToFile(LIgnored);
    finally
      Free;
    end;

    // 仅工作区 + 包含 ignored
    FillByte(LFilter, SizeOf(LFilter), 0);
    LFilter.WorkingTreeOnly := True;
    LFilter.IncludeIgnored := True;
    LEntries := LRepo.StatusEntries(LFilter);
    LFoundIgnored := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'ignored.txt') and (gsIgnored in LEntries[i].Flags) then
        LFoundIgnored := True;
    AssertTrue('应检测到被忽略文件（IncludeIgnored=True）', LFoundIgnored);

    // 关闭包含 ignored，应排除
    LFilter.IncludeIgnored := False;
    LEntries := LRepo.StatusEntries(LFilter);
    LFoundIgnored := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'ignored.txt') then
        LFoundIgnored := True;
    AssertTrue('不应包含被忽略文件（IncludeIgnored=False）', not LFoundIgnored);
  finally
    if Assigned(LRepo) then LRepo.Free;
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', LRepoDir]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', LRepoDir]);
    {$ENDIF}
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

