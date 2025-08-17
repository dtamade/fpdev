unit fpdev.git2.adapter.basic.testcase;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, Process, Classes;

function IsGitInstalled_CLI: Boolean;
function GetGitVersion_CLI: string;

procedure GitLocal_InitAndCommit(const ADir: string);

implementation

function IsGitInstalled_CLI: Boolean;
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

function GetGitVersion_CLI: string;
var
  LProcess: TProcess;
  LOut, LErr: TStringList;
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
procedure RunGit(const ADir: string; const Args: array of string);
var
  P: TProcess;
  i: Integer;
begin
  P := TProcess.Create(nil);
  try
    P.Executable := 'git';
    for i := Low(Args) to High(Args) do
      P.Parameters.Add(Args[i]);
    if ADir <> '' then
      P.CurrentDirectory := ADir;
    P.Options := [poWaitOnExit, poUsePipes, poNoConsole];
    P.Execute;
    if P.ExitStatus <> 0 then
      raise Exception.CreateFmt('git %s failed with code %d', [Args[0], P.ExitStatus]);
  finally
    P.Free;
  end;
end;

procedure TTestCase_GitCli.Test_LocalRepo_InitAndCommit_Offline;
var
  LRoot, LRepo: string;
begin
  AssertTrue('git should be installed', IsGitInstalled_CLI);
  LRoot := 'bin' + PathDelim + 'tmp';
  if not DirectoryExists(LRoot) then
    ForceDirectories(LRoot);
  LRepo := IncludeTrailingPathDelimiter(LRoot) + 'fixture_repo_' + FormatDateTime('yyyymmddhhnnss', Now);
  GitLocal_InitAndCommit(LRepo);
  AssertTrue('repo .git exists', DirectoryExists(IncludeTrailingPathDelimiter(LRepo)+'.git'));
  // verify last commit exists
  RunGit(LRepo, ['rev-parse', 'HEAD']);
end;

procedure GitLocal_InitAndCommit(const ADir: string);
var
  F: Text;
begin
  if not DirectoryExists(ADir) then
    if not ForceDirectories(ADir) then
      raise Exception.Create('mkdir failed: ' + ADir);
  // git init
  RunGit(ADir, ['init']);
  // config user (avoid global pollution)
  RunGit(ADir, ['config', 'user.name', 'tester']);
  RunGit(ADir, ['config', 'user.email', 'tester@example.com']);
  // write a file
  AssignFile(F, IncludeTrailingPathDelimiter(ADir) + 'README.md');
  Rewrite(F);
  Writeln(F, '# fixture');
  CloseFile(F);
  // add & commit
  RunGit(ADir, ['add', '.']);
  RunGit(ADir, ['commit', '-m', 'init']);
end;

    LProcess.Free;
  end;
end;

type
  TTestCase_GitCli = class(TTestCase)
  published
    procedure Test_IsGitInstalled;
    procedure Test_GetGitVersion;
    procedure Test_LocalRepo_InitAndCommit_Offline;
  end;

procedure TTestCase_GitCli.Test_IsGitInstalled;
begin
  AssertTrue('git should be installed on PATH', IsGitInstalled_CLI);
end;

procedure TTestCase_GitCli.Test_GetGitVersion;
var
  LVer: string;
begin
  LVer := GetGitVersion_CLI;
  AssertTrue('git version should not be empty', LVer <> '');
end;

initialization
  RegisterTest(TTestCase_GitCli);

end.

