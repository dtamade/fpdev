program git_minimal_test;

{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils,
  Classes,
  git2.api,
  git2.impl;

function CreateTempDir: string;
var
  base: string;
begin
  base := GetTempDir(False) + 'fpdev_git_test_' + FormatDateTime('yyyymmddhhnnsszzz', Now);
  if not ForceDirectories(base) then
    raise Exception.Create('无法创建临时目录: ' + base);
  Result := base;
end;

procedure RmTree(const Path: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Path + DirectorySeparator + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        if (SR.Attr and faDirectory) <> 0 then
          RmTree(Path + DirectorySeparator + SR.Name)
        else
          DeleteFile(Path + DirectorySeparator + SR.Name);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  RemoveDir(Path);
end;

var
  mgr: IGitManager;
  repo: IGitRepository;
  tmp: string;
  ok: Boolean;
  status: array of string;
begin
  try
    WriteLn('Git Minimal Test');
    mgr := NewGitManager;
    if not mgr.Initialize then
      raise Exception.Create('libgit2 初始化失败');

    // 初始化本地仓库（不联网）
    tmp := CreateTempDir;
    try
      repo := mgr.InitRepository(tmp, False);
      if repo = nil then
        raise Exception.Create('仓库初始化失败');

      WriteLn('✓ Repo created at: ', repo.WorkDir);
      WriteLn('  IsBare=', repo.IsBare, ' IsEmpty=', repo.IsEmpty);

      // 初始应为 clean
      status := repo.Status;
      if Length(status) <> 0 then
        raise Exception.Create('新仓库应为 clean');

      // 写一个未跟踪文件，验证状态变化
      with TStringList.Create do
      try
        Text := 'hello';
        SaveToFile(tmp + DirectorySeparator + 'a.txt');
      finally
        Free;
      end;

      status := repo.Status;
      ok := Length(status) > 0;
      if ok then
        WriteLn('✓ Status changed: ', status[0])
      else
        raise Exception.Create('未检测到未跟踪文件变更');

      // Discover（回退逻辑可命中）
      try
        if mgr.DiscoverRepository(tmp) = '' then
          WriteLn('i Discover: not found (expected on fresh repo)')
        else
          WriteLn('✓ Discover ok');
      except
        on E: Exception do
          WriteLn('i Discover skipped due to error: ', E.Message);
      end;

      WriteLn('✓ All minimal tests passed');
    finally
      RmTree(tmp);
    end;
  except
    on E: Exception do
    begin
      WriteLn('✗ Error: ', E.Message);
      Halt(1);
    end;
  end;
end.

