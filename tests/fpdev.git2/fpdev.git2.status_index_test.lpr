program fpdev_git2_status_index_test;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  git2.types,
  git2.api, git2.impl,
  fpdev.git2, libgit2;

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
  LRepoDir, LTracked: string;
  LRepo: TGitRepository;
  LFilter: TGitStatusFilter;
  LEntries: TGitStatusEntryArray;
  LFoundIndex: Boolean;
  LIndex: git_index;
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
    WriteLn('✓ 检测到 libgit2，可运行索引变更测试');

  // 创建临时仓库
  LRepoDir := GetCurrentDir + PathDelim + 'tmp_status_index_' + FormatDateTime('yyyymmddhhnnss', Now);
  ForceDirectories(LRepoDir);

  LRepo := nil;
  try
    LRepo := GitManager.InitRepository(LRepoDir, False);

    // 创建并写入一个文件，加入索引
    LTracked := LRepoDir + PathDelim + 'tracked.txt';
    with TStringList.Create do
    try
      Text := 'v1';
      SaveToFile(LTracked);
    finally
      Free;
    end;

    CheckGitResult(git_repository_index(LIndex, LRepo.FHandle), 'Open index');
    try
      CheckGitResult(git_index_add_bypath(LIndex, PChar('tracked.txt')), 'Index add');
      CheckGitResult(git_index_write(LIndex), 'Index write');
    finally
      git_index_free(LIndex);
    end;

    // 仅索引
    FillByte(LFilter, SizeOf(LFilter), 0);
    LFilter.IndexOnly := True;
    LEntries := LRepo.StatusEntries(LFilter);
    LFoundIndex := False;
    for i := 0 to High(LEntries) do
      if SameText(ExtractFileName(LEntries[i].Path), 'tracked.txt') and
         ((gsIndexNew in LEntries[i].Flags) or (gsIndexModified in LEntries[i].Flags)) then
        LFoundIndex := True;
    AssertTrue('应检测到索引变更（IndexOnly=True）', LFoundIndex);
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

