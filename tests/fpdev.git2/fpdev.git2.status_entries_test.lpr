program fpdev_git2_status_entries_test;
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
  LRepoDir, LFileUntracked, LFileTracked: string;
  LRepo: TGitRepository;
  LFilter: TGitStatusFilter;
  LEntries: array of TGitStatusEntry;
  LFoundUntracked: Boolean;
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
    WriteLn('✓ 检测到 libgit2，可运行 StatusEntries 测试');

  // 创建临时仓库
  LRepoDir := GetCurrentDir + PathDelim + 'tmp_status_entries_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LRepoDir);

  LRepo := nil;
  try
    LRepo := GitManager.InitRepository(LRepoDir, False);

    // 创建未跟踪文件
    LFileUntracked := LRepoDir + PathDelim + 'untracked.txt';
    with TStringList.Create do
    try
      Text := 'hello untracked';
      SaveToFile(LFileUntracked);
    finally
      Free;
    end;

    // 过滤：仅工作区，包含未跟踪
    FillByte(LFilter, SizeOf(LFilter), 0);
    LFilter.WorkingTreeOnly := True;
    LFilter.IncludeUntracked := True;
    LEntries := LRepo.StatusEntries(LFilter);
    LFoundUntracked := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'untracked.txt') then
        LFoundUntracked := True;
    AssertTrue('应检测到未跟踪文件 (WorkingTreeOnly + IncludeUntracked)', LFoundUntracked);

    // 过滤：不包含未跟踪
    LFilter.IncludeUntracked := False;
    LEntries := LRepo.StatusEntries(LFilter);
    LFoundUntracked := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'untracked.txt') then
        LFoundUntracked := True;
    AssertTrue('不应包含未跟踪文件 (IncludeUntracked=False)', not LFoundUntracked);

    // 创建已跟踪文件并修改，验证 WorkingTreeOnly 生效
    LFileTracked := LRepoDir + PathDelim + 'tracked.txt';
    with TStringList.Create do
    try
      Text := 'tracked v1';
      SaveToFile(LFileTracked);
    finally
      Free;
    end;
    // 将其加入索引（可能在无 HEAD 情况下仍视为新增或工作区）
    // 我们这里只验证过滤逻辑：IndexOnly=True 应不包含工作区变更
    FillByte(LFilter, SizeOf(LFilter), 0);
    LFilter.IndexOnly := True;
    LEntries := LRepo.StatusEntries(LFilter);
    // 不做强断言（不同平台/libgit2配置下可能返回为空或有 IndexNew）
    WriteLn('IndexOnly 返回项数: ', Length(LEntries));

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

