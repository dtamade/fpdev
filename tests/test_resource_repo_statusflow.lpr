program test_resource_repo_statusflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.utils.process,
  fpdev.resource.repo.statusflow;

type
  TRepoStatusHarness = class
  public
    IsRepo: Boolean;
    CommitHash: string;
    ProcessResult: TProcessResult;
    ProcessCalls: Integer;
    LastWorkDir: string;
    function IsGitRepository: Boolean;
    function GetLastCommitHash: string;
    function QueryShortHead(const AWorkDir: string): TProcessResult;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

function TRepoStatusHarness.IsGitRepository: Boolean;
begin
  Result := IsRepo;
end;

function TRepoStatusHarness.GetLastCommitHash: string;
begin
  Result := CommitHash;
end;

function TRepoStatusHarness.QueryShortHead(const AWorkDir: string): TProcessResult;
begin
  Inc(ProcessCalls);
  LastWorkDir := AWorkDir;
  Result := ProcessResult;
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TestGetLastCommitHashCoreReturnsUnknownWhenNotRepo;
var
  Harness: TRepoStatusHarness;
  Hash: string;
begin
  Harness := TRepoStatusHarness.Create;
  try
    Harness.IsRepo := False;
    Hash := GetResourceRepoLastCommitHashCore('/tmp/repo', @Harness.IsGitRepository, @Harness.QueryShortHead);
    Check('commit hash returns unknown when repo missing', Hash = 'unknown', 'got=' + Hash);
    Check('commit hash skips process when repo missing', Harness.ProcessCalls = 0,
      'calls=' + IntToStr(Harness.ProcessCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestGetLastCommitHashCoreUsesTrimmedStdout;
var
  Harness: TRepoStatusHarness;
  Hash: string;
begin
  Harness := TRepoStatusHarness.Create;
  try
    Harness.IsRepo := True;
    Harness.ProcessResult.Success := True;
    Harness.ProcessResult.StdOut := 'abc123' + LineEnding;
    Hash := GetResourceRepoLastCommitHashCore('/tmp/repo', @Harness.IsGitRepository, @Harness.QueryShortHead);
    Check('commit hash returns trimmed stdout', Hash = 'abc123', 'got=' + Hash);
    Check('commit hash passes workdir to query', Harness.LastWorkDir = '/tmp/repo', 'workdir=' + Harness.LastWorkDir);
  finally
    Harness.Free;
  end;
end;

procedure TestGetLastCommitHashCoreReturnsUnknownOnQueryFailure;
var
  Harness: TRepoStatusHarness;
  Hash: string;
begin
  Harness := TRepoStatusHarness.Create;
  try
    Harness.IsRepo := True;
    Harness.ProcessResult.Success := False;
    Hash := GetResourceRepoLastCommitHashCore('/tmp/repo', @Harness.IsGitRepository, @Harness.QueryShortHead);
    Check('commit hash returns unknown on query failure', Hash = 'unknown', 'got=' + Hash);
  finally
    Harness.Free;
  end;
end;

procedure TestBuildResourceRepoStatusCoreReportsNotInitialized;
var
  Harness: TRepoStatusHarness;
  StatusText: string;
begin
  Harness := TRepoStatusHarness.Create;
  try
    Harness.IsRepo := False;
    StatusText := BuildResourceRepoStatusCore('/tmp/repo', 0, @Harness.IsGitRepository, @Harness.GetLastCommitHash);
    Check('status reports not initialized', StatusText = 'Not initialized', 'got=' + StatusText);
  finally
    Harness.Free;
  end;
end;

procedure TestBuildResourceRepoStatusCoreFormatsThreeLines;
var
  Harness: TRepoStatusHarness;
  StatusText: string;
  Stamp: TDateTime;
begin
  Harness := TRepoStatusHarness.Create;
  try
    Harness.IsRepo := True;
    Harness.CommitHash := 'abc123';
    Stamp := EncodeDate(2026, 3, 9) + EncodeTime(23, 5, 6, 0);
    StatusText := BuildResourceRepoStatusCore('/tmp/repo', Stamp, @Harness.IsGitRepository, @Harness.GetLastCommitHash);
    Check('status includes initialized path', Pos('Initialized at: /tmp/repo', StatusText) > 0, StatusText);
    Check('status includes commit hash', Pos('Commit: abc123', StatusText) > 0, StatusText);
    Check('status includes last update prefix', Pos('Last update check: ', StatusText) > 0, StatusText);
    Check('status keeps three lines', Length(StatusText.Split([LineEnding])) >= 3, StatusText);
  finally
    Harness.Free;
  end;
end;

procedure TestBuildResourceRepoStatusCoreShowsNeverWhenNotChecked;
var
  Harness: TRepoStatusHarness;
  StatusText: string;
begin
  Harness := TRepoStatusHarness.Create;
  try
    Harness.IsRepo := True;
    Harness.CommitHash := 'abc123';
    StatusText := BuildResourceRepoStatusCore('/tmp/repo', 0, @Harness.IsGitRepository, @Harness.GetLastCommitHash);
    Check('status shows never when last check missing',
      Pos('Last update check: never', StatusText) > 0, StatusText);
    Check('status does not show epoch date when last check missing',
      Pos('1899', StatusText) = 0, StatusText);
  finally
    Harness.Free;
  end;
end;

begin
  TestGetLastCommitHashCoreReturnsUnknownWhenNotRepo;
  TestGetLastCommitHashCoreUsesTrimmedStdout;
  TestGetLastCommitHashCoreReturnsUnknownOnQueryFailure;
  TestBuildResourceRepoStatusCoreReportsNotInitialized;
  TestBuildResourceRepoStatusCoreFormatsThreeLines;
  TestBuildResourceRepoStatusCoreShowsNeverWhenNotChecked;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
