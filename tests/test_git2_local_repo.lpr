program test_git2_local_repo;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  git2.modern;

function NewTempRepoDir: string;
var
  Base, Suffix: string;
begin
  Base := 'bin' + PathDelim + 'tmp' + PathDelim + 'git2_local_';
  Suffix := FormatDateTime('yyyymmddhhnnss', Now);
  Result := Base + Suffix;
  ForceDirectories(Result);
end;

var
  RepoDir: string;
  Repo: TGitRepository;
  Cur: string;
begin
  try
    if not GitManager.Initialize then
    begin
      WriteLn('INIT_FAIL');
      Halt(1);
    end;

    RepoDir := NewTempRepoDir;
    Repo := GitManager.InitRepository(RepoDir, False);
    try
      if not Assigned(Repo) then
      begin
        WriteLn('INIT_REPO_FAIL');
        Halt(1);
      end;

      Cur := Repo.GetCurrentBranch;
      WriteLn('OK:INIT:PATH=', RepoDir);
      Halt(0);
    finally
      Repo.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('EXC:', E.ClassName, ' ', E.Message);
      Halt(1);
    end;
  end;
end.

