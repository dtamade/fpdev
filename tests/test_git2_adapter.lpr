program test_git2_adapter;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.git2, libgit2;

function NewTempRepoDir(const Prefix: string): string;
var
  Base, Suffix: string;
begin
  Base := 'bin' + PathDelim + 'tmp' + PathDelim + Prefix;
  Suffix := FormatDateTime('yyyymmddhhnnss', Now);
  Result := Base + '_' + Suffix;
  ForceDirectories(Result);
end;

var
  Adapter: TGit2Manager;
  RepoDir: string;
  Repo: git_repository;
begin
  Adapter := TGit2Manager.Create;
  try
    if not Adapter.Initialize then
    begin
      WriteLn('INIT_FAIL');
      Halt(1);
    end;

    RepoDir := NewTempRepoDir('adapter_repo');
    // 初始化一个空仓库（离线）
    if git_repository_init(Repo, PChar(RepoDir), 0) <> GIT_OK then
    begin
      WriteLn('INIT_REPO_FAIL');
      Halt(1);
    end;
    git_repository_free(Repo);

    if not Adapter.IsRepository(RepoDir) then
    begin
      WriteLn('IS_REPO_FAIL');
      Halt(1);
    end;

    Repo := Adapter.OpenRepository(RepoDir);
    if Repo = nil then
    begin
      WriteLn('OPEN_REPO_FAIL');
      Halt(1);
    end;
    git_repository_free(Repo);

    WriteLn('OK:ADAPTER_HEALTH:', RepoDir);
    Halt(0);
  finally
    Adapter.Free;
  end;
end.

