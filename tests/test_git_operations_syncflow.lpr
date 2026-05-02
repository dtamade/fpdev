program test_git_operations_syncflow;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.git.types, fpdev.utils.process,
  fpdev.git.operations.syncflow;

type
  TGitSyncHarness = class
  private
    FCliResults: array of TProcessResult;
    FCliIndex: Integer;
  public
    CloneCalls: Integer;
    FetchCalls: Integer;
    PullCalls: Integer;
    CheckoutCalls: Integer;
    CliCalls: Integer;
    LastCliCommand: string;
    Libgit2CloneResult: Boolean;
    Libgit2CloneError: string;
    Libgit2FetchResult: Boolean;
    Libgit2FetchError: string;
    Libgit2PullResult: Boolean;
    Libgit2PullError: string;
    Libgit2PullNeedsFallback: Boolean;
    CheckoutAfterCloneResult: Boolean;
    CheckoutAfterCloneError: string;
    constructor Create;
    procedure AddCliResult(const AResult: TProcessResult);
    function CloneWithLibgit2(const AURL, ALocalPath: string;
      out AError: string): Boolean;
    function FetchWithLibgit2(const ARepoPath, ARemote: string;
      out AError: string): Boolean;
    function PullWithLibgit2(const ARepoPath: string; out AError: string;
      out ANeedsFallback: Boolean; const AAllowMerge: Boolean): Boolean;
    function CheckoutAfterClone(const ARepoPath, ABranch: string;
      const AForce: Boolean; out AError: string): Boolean;
    function ExecuteCli(const AParams: array of string;
      const AWorkDir: string): TProcessResult;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

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

procedure Check(const AName: string; ACondition: Boolean;
  const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function NewProcessResult(const ASuccess: Boolean; const AExitCode: Integer;
  const AStdOut: string; const AStdErr: string = '';
  const AErrorMessage: string = ''): TProcessResult;
begin
  Result.Success := ASuccess;
  Result.ExitCode := AExitCode;
  Result.StdOut := AStdOut;
  Result.StdErr := AStdErr;
  Result.ErrorMessage := AErrorMessage;
end;

function JoinParams(const AParams: array of string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(AParams) do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + AParams[i];
  end;
end;

constructor TGitSyncHarness.Create;
begin
  inherited Create;
  FCliIndex := 0;
end;

procedure TGitSyncHarness.AddCliResult(const AResult: TProcessResult);
var
  L: Integer;
begin
  L := Length(FCliResults);
  SetLength(FCliResults, L + 1);
  FCliResults[L] := AResult;
end;

function TGitSyncHarness.CloneWithLibgit2(const AURL, ALocalPath: string;
  out AError: string): Boolean;
begin
  Inc(CloneCalls);
  if AURL = '' then;
  if ALocalPath = '' then;
  AError := Libgit2CloneError;
  Result := Libgit2CloneResult;
end;

function TGitSyncHarness.FetchWithLibgit2(const ARepoPath, ARemote: string;
  out AError: string): Boolean;
begin
  Inc(FetchCalls);
  if ARepoPath = '' then;
  if ARemote = '' then;
  AError := Libgit2FetchError;
  Result := Libgit2FetchResult;
end;

function TGitSyncHarness.PullWithLibgit2(const ARepoPath: string;
  out AError: string; out ANeedsFallback: Boolean;
  const AAllowMerge: Boolean): Boolean;
begin
  Inc(PullCalls);
  if ARepoPath = '' then;
  if AAllowMerge then;
  AError := Libgit2PullError;
  ANeedsFallback := Libgit2PullNeedsFallback;
  Result := Libgit2PullResult;
end;

function TGitSyncHarness.CheckoutAfterClone(const ARepoPath, ABranch: string;
  const AForce: Boolean; out AError: string): Boolean;
begin
  Inc(CheckoutCalls);
  if ARepoPath = '' then;
  if ABranch = '' then;
  if AForce then;
  AError := CheckoutAfterCloneError;
  Result := CheckoutAfterCloneResult;
end;

function TGitSyncHarness.ExecuteCli(const AParams: array of string;
  const AWorkDir: string): TProcessResult;
begin
  Inc(CliCalls);
  LastCliCommand := JoinParams(AParams) + ' [cwd=' + AWorkDir + ']';
  if FCliIndex < Length(FCliResults) then
  begin
    Result := FCliResults[FCliIndex];
    Inc(FCliIndex);
  end
  else
    Result := NewProcessResult(False, 1, '', '', 'missing cli result');
end;

procedure TestCloneLibgit2SuccessChecksOutRequestedBranch;
var
  Harness: TGitSyncHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitSyncHarness.Create;
  try
    Harness.Libgit2CloneResult := True;
    Harness.CheckoutAfterCloneResult := True;
    Err := '';
    OK := ExecuteGitCloneSurfaceCore(
      'https://example.invalid/repo.git',
      '/tmp/repo',
      'release',
      gbLibgit2,
      True,
      @Harness.CloneWithLibgit2,
      @Harness.CheckoutAfterClone,
      @Harness.ExecuteCli,
      Err
    );
    Check('syncflow clone libgit2 success returns true', OK, 'expected true');
    Check('syncflow clone libgit2 success triggers checkout once', Harness.CheckoutCalls = 1,
      'checkout calls=' + IntToStr(Harness.CheckoutCalls));
    Check('syncflow clone libgit2 success skips CLI', Harness.CliCalls = 0,
      'cli calls=' + IntToStr(Harness.CliCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestCloneFallsBackToCliWithBranchCommand;
var
  Harness: TGitSyncHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitSyncHarness.Create;
  try
    Harness.Libgit2CloneError := 'clone failed';
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Err := '';
    OK := ExecuteGitCloneSurfaceCore(
      'https://example.invalid/repo.git',
      '/tmp/repo',
      'release_3_2_2',
      gbLibgit2,
      True,
      @Harness.CloneWithLibgit2,
      @Harness.CheckoutAfterClone,
      @Harness.ExecuteCli,
      Err
    );
    Check('syncflow clone falls back to CLI', OK, 'expected true');
    Check('syncflow clone uses branch clone command',
      Pos('clone --depth 1 --branch release_3_2_2 https://example.invalid/repo.git /tmp/repo [cwd=]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

procedure TestFetchFallsBackToCli;
var
  Harness: TGitSyncHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitSyncHarness.Create;
  try
    Harness.Libgit2FetchError := 'fetch failed';
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Err := '';
    OK := ExecuteGitFetchSurfaceCore(
      '/tmp/repo',
      'origin',
      gbLibgit2,
      True,
      @Harness.FetchWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('syncflow fetch falls back to CLI', OK, 'expected true');
    Check('syncflow fetch uses fetch remote command',
      Pos('fetch origin [cwd=/tmp/repo]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

procedure TestPullFallsBackToCliWhenMergeAllowed;
var
  Harness: TGitSyncHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitSyncHarness.Create;
  try
    Harness.Libgit2PullNeedsFallback := True;
    Harness.Libgit2PullError := 'Non-fast-forward update requires merge/rebase';
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Err := '';
    OK := ExecuteGitPullSurfaceCore(
      '/tmp/repo',
      gbLibgit2,
      True,
      @Harness.PullWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('syncflow pull falls back to CLI when merge allowed', OK, 'expected true');
    Check('syncflow pull uses git pull command',
      Pos('pull [cwd=/tmp/repo]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

procedure TestPullFastForwardOnlyKeepsKnownFailureWithoutCliFallback;
var
  Harness: TGitSyncHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitSyncHarness.Create;
  try
    Harness.Libgit2PullNeedsFallback := True;
    Harness.Libgit2PullError := 'working tree has local changes';
    Err := '';
    OK := ExecuteGitPullFastForwardOnlySurfaceCore(
      '/tmp/repo',
      gbLibgit2,
      True,
      @Harness.PullWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('syncflow ff-only pull keeps known failure', not OK, 'expected false');
    Check('syncflow ff-only pull skips CLI on known classified failure', Harness.CliCalls = 0,
      'cli calls=' + IntToStr(Harness.CliCalls));
    Check('syncflow ff-only pull preserves error text',
      Err = 'working tree has local changes', 'err=' + Err);
  finally
    Harness.Free;
  end;
end;

procedure TestPullFastForwardOnlyFallsBackToCliForUnknownFailure;
var
  Harness: TGitSyncHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitSyncHarness.Create;
  try
    Harness.Libgit2PullNeedsFallback := True;
    Harness.Libgit2PullError := 'plain network timeout';
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Err := '';
    OK := ExecuteGitPullFastForwardOnlySurfaceCore(
      '/tmp/repo',
      gbLibgit2,
      True,
      @Harness.PullWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('syncflow ff-only pull falls back to CLI for unknown failure', OK, 'expected true');
    Check('syncflow ff-only pull uses git pull --ff-only command',
      Pos('pull --ff-only [cwd=/tmp/repo]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

begin
  TestCloneLibgit2SuccessChecksOutRequestedBranch;
  TestCloneFallsBackToCliWithBranchCommand;
  TestFetchFallsBackToCli;
  TestPullFallsBackToCliWhenMergeAllowed;
  TestPullFastForwardOnlyKeepsKnownFailureWithoutCliFallback;
  TestPullFastForwardOnlyFallsBackToCliForUnknownFailure;

  WriteLn('');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
