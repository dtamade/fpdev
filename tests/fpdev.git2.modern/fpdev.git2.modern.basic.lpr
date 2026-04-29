program fpdev_git2_modern_basic;

{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  git2.api, git2.impl;

// Modern Git2 lane: this focused runner must stay on git2.api + git2.impl only.

function NewTempDir(const APrefix: string): string;
begin
  Result := GetCurrentDir + PathDelim + APrefix + '_' + FormatDateTime('yyyymmddhhnnsszzz', Now);
  if not ForceDirectories(Result) then
    raise Exception.Create('Cannot create temp directory: ' + Result);
end;

procedure RemoveTree(const APath: string);
var
  SR: TSearchRec;
begin
  if not DirectoryExists(APath) then
    Exit;

  if FindFirst(APath + PathDelim + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        if (SR.Attr and faDirectory) <> 0 then
          RemoveTree(APath + PathDelim + SR.Name)
        else
          DeleteFile(APath + PathDelim + SR.Name);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  RemoveDir(APath);
end;

procedure WriteTextFile(const APath, AText: string);
var
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    LLines.SaveToFile(APath);
  finally
    LLines.Free;
  end;
end;

procedure TestDiscoverFallback;
var
  LMgr: IGitManager;
  LRepoRoot: string;
  LFound: string;
begin
  LRepoRoot := NewTempDir('tmp_git2_modern_discover');
  ForceDirectories(LRepoRoot + PathDelim + '.git');
  try
    LMgr := NewGitManager;
    LFound := LMgr.DiscoverRepository(LRepoRoot);
    if LFound = '' then
      raise Exception.Create('DiscoverRepository fallback failed');
    WriteLn('OK:DISCOVER:', LFound);
  finally
    RemoveTree(LRepoRoot);
  end;
end;

procedure TestInitRepositoryAndStatus;
var
  LMgr: IGitManager;
  LRepo: IGitRepository;
  LRepoRoot: string;
  LStatuses: TStringArray;
begin
  LMgr := NewGitManager;
  if not LMgr.Initialize then
  begin
    WriteLn('SKIP:libgit2 unavailable');
    Exit;
  end;

  LRepoRoot := NewTempDir('tmp_git2_modern_repo');
  try
    LRepo := LMgr.InitRepository(LRepoRoot, False);
    if LRepo = nil then
      raise Exception.Create('InitRepository returned nil');

    WriteTextFile(LRepoRoot + PathDelim + 'modern.txt', 'hello modern lane' + LineEnding);
    LStatuses := LRepo.Status;
    if Length(LStatuses) = 0 then
      raise Exception.Create('Status should detect the new untracked file');
    WriteLn('OK:STATUS:', LStatuses[0]);
  finally
    RemoveTree(LRepoRoot);
  end;
end;

begin
  try
    TestDiscoverFallback;
    TestInitRepositoryAndStatus;
    WriteLn('OK:DONE');
  except
    on E: Exception do
    begin
      WriteLn('FAIL:', E.ClassName, ':', E.Message);
      Halt(1);
    end;
  end;
end.
