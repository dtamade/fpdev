program test_git_operations_queryflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.git.types, fpdev.utils.process,
  fpdev.git.operations.queryflow;

type
  TGitQueryHarness = class
  private
    FCliResults: array of TProcessResult;
    FCliIndex: Integer;
  public
    HasRemoteCalls: Integer;
    RemoteURLCalls: Integer;
    CurrentBranchCalls: Integer;
    HeadHashCalls: Integer;
    BranchListCalls: Integer;
    RemoteBranchListCalls: Integer;
    CliCalls: Integer;
    LastCliCommand: string;
    Libgit2HasRemoteHandled: Boolean;
    Libgit2HasRemoteValue: Boolean;
    Libgit2RemoteURLHandled: Boolean;
    Libgit2RemoteURLValue: string;
    Libgit2CurrentBranchHandled: Boolean;
    Libgit2CurrentBranchValue: string;
    Libgit2HeadHashHandled: Boolean;
    Libgit2HeadHashValue: string;
    Libgit2BranchListHandled: Boolean;
    Libgit2BranchRefs: TStringArray;
    Libgit2RemoteBranchListHandled: Boolean;
    Libgit2RemoteBranchRefs: TStringArray;
    constructor Create;
    procedure AddCliResult(const AResult: TProcessResult);
    function QueryHasRemote(const ARepoPath: string; out AValue: Boolean): Boolean;
    function QueryRemoteURL(const ARepoPath, ARemote: string; out AValue: string): Boolean;
    function QueryCurrentBranch(const ARepoPath: string; out AValue: string): Boolean;
    function QueryHeadHash(const ARepoPath: string; out AValue: string): Boolean;
    function QueryBranchRefs(const ARepoPath: string; out AValues: TStringArray): Boolean;
    function QueryRemoteBranchRefs(const ARepoPath, ARemote: string; out AValues: TStringArray): Boolean;
    function ExecuteCli(const AParams: array of string; const AWorkDir: string): TProcessResult;
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

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
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

constructor TGitQueryHarness.Create;
begin
  inherited Create;
  FCliIndex := 0;
end;

procedure TGitQueryHarness.AddCliResult(const AResult: TProcessResult);
var
  L: Integer;
begin
  L := Length(FCliResults);
  SetLength(FCliResults, L + 1);
  FCliResults[L] := AResult;
end;

function TGitQueryHarness.QueryHasRemote(const ARepoPath: string; out AValue: Boolean): Boolean;
begin
  Inc(HasRemoteCalls);
  if ARepoPath = '' then;
  AValue := Libgit2HasRemoteValue;
  Result := Libgit2HasRemoteHandled;
end;

function TGitQueryHarness.QueryRemoteURL(const ARepoPath, ARemote: string; out AValue: string): Boolean;
begin
  Inc(RemoteURLCalls);
  if ARepoPath = '' then;
  if ARemote = '' then;
  AValue := Libgit2RemoteURLValue;
  Result := Libgit2RemoteURLHandled;
end;

function TGitQueryHarness.QueryCurrentBranch(const ARepoPath: string; out AValue: string): Boolean;
begin
  Inc(CurrentBranchCalls);
  if ARepoPath = '' then;
  AValue := Libgit2CurrentBranchValue;
  Result := Libgit2CurrentBranchHandled;
end;

function TGitQueryHarness.QueryHeadHash(const ARepoPath: string; out AValue: string): Boolean;
begin
  Inc(HeadHashCalls);
  if ARepoPath = '' then;
  AValue := Libgit2HeadHashValue;
  Result := Libgit2HeadHashHandled;
end;

function TGitQueryHarness.QueryBranchRefs(const ARepoPath: string; out AValues: TStringArray): Boolean;
begin
  Inc(BranchListCalls);
  if ARepoPath = '' then;
  AValues := Copy(Libgit2BranchRefs);
  Result := Libgit2BranchListHandled;
end;

function TGitQueryHarness.QueryRemoteBranchRefs(const ARepoPath, ARemote: string; out AValues: TStringArray): Boolean;
begin
  Inc(RemoteBranchListCalls);
  if ARepoPath = '' then;
  if ARemote = '' then;
  AValues := Copy(Libgit2RemoteBranchRefs);
  Result := Libgit2RemoteBranchListHandled;
end;

function TGitQueryHarness.ExecuteCli(const AParams: array of string; const AWorkDir: string): TProcessResult;
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

procedure TestHasRemotePrefersLibgit2;
var
  Harness: TGitQueryHarness;
  OK: Boolean;
begin
  Harness := TGitQueryHarness.Create;
  try
    Harness.Libgit2HasRemoteHandled := True;
    Harness.Libgit2HasRemoteValue := True;
    OK := ExecuteGitHasRemoteSurfaceCore(
      '/tmp/repo',
      gbLibgit2,
      True,
      @Harness.QueryHasRemote,
      @Harness.ExecuteCli
    );
    Check('queryflow has-remote returns libgit2 result', OK, 'expected true');
    Check('queryflow has-remote skips CLI on libgit2 success', Harness.CliCalls = 0,
      'cli calls=' + IntToStr(Harness.CliCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestHasRemoteFallsBackToCli;
var
  Harness: TGitQueryHarness;
  OK: Boolean;
begin
  Harness := TGitQueryHarness.Create;
  try
    Harness.AddCliResult(NewProcessResult(True, 0, 'origin' + LineEnding, ''));
    OK := ExecuteGitHasRemoteSurfaceCore(
      '/tmp/repo',
      gbCommandLine,
      True,
      @Harness.QueryHasRemote,
      @Harness.ExecuteCli
    );
    Check('queryflow has-remote falls back to CLI output', OK, 'expected true');
    Check('queryflow has-remote records remote CLI command',
      Pos('remote [cwd=/tmp/repo]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

procedure TestRemoteURLReportsCliFailure;
var
  Harness: TGitQueryHarness;
  Value: string;
  Err: string;
begin
  Harness := TGitQueryHarness.Create;
  try
    Harness.AddCliResult(NewProcessResult(False, 2, '', 'no such remote', ''));
    Err := '';
    Value := ExecuteGitRemoteURLSurfaceCore(
      '/tmp/repo',
      'origin',
      gbCommandLine,
      True,
      @Harness.QueryRemoteURL,
      @Harness.ExecuteCli,
      Err
    );
    Check('queryflow remote-url returns empty on CLI failure', Value = '', 'value=' + Value);
    Check('queryflow remote-url keeps stderr as error', Err = 'no such remote', 'err=' + Err);
  finally
    Harness.Free;
  end;
end;

procedure TestCurrentBranchNormalizesSymbolicRef;
var
  Harness: TGitQueryHarness;
  Value: string;
begin
  Harness := TGitQueryHarness.Create;
  try
    Harness.AddCliResult(NewProcessResult(True, 0, 'refs/heads/main' + LineEnding, ''));
    Value := ExecuteGitCurrentBranchSurfaceCore(
      '/tmp/repo',
      gbCommandLine,
      True,
      @Harness.QueryCurrentBranch,
      @Harness.ExecuteCli
    );
    Check('queryflow current-branch strips refs/heads prefix', Value = 'main', 'value=' + Value);
    Check('queryflow current-branch only needs symbolic-ref when it succeeds', Harness.CliCalls = 1,
      'cli calls=' + IntToStr(Harness.CliCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestShortHeadHashTruncatesLibgit2Oid;
var
  Harness: TGitQueryHarness;
  Value: string;
  Err: string;
begin
  Harness := TGitQueryHarness.Create;
  try
    Harness.Libgit2HeadHashHandled := True;
    Harness.Libgit2HeadHashValue := '0123456789abcdef0123456789abcdef01234567';
    Err := '';
    Value := ExecuteGitShortHeadHashSurfaceCore(
      '/tmp/repo',
      7,
      gbLibgit2,
      True,
      @Harness.QueryHeadHash,
      @Harness.ExecuteCli,
      Err
    );
    Check('queryflow short-hash truncates libgit2 OID', Value = '0123456', 'value=' + Value);
    Check('queryflow short-hash leaves error empty on success', Err = '', 'err=' + Err);
    Check('queryflow short-hash skips CLI on libgit2 success', Harness.CliCalls = 0,
      'cli calls=' + IntToStr(Harness.CliCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestListBranchesNormalizesAndDedupesRefs;
var
  Harness: TGitQueryHarness;
  Values: TStringArray;
  Err: string;
begin
  Harness := TGitQueryHarness.Create;
  try
    Harness.Libgit2BranchListHandled := True;
    SetLength(Harness.Libgit2BranchRefs, 4);
    Harness.Libgit2BranchRefs[0] := 'refs/heads/main';
    Harness.Libgit2BranchRefs[1] := 'refs/remotes/origin/main';
    Harness.Libgit2BranchRefs[2] := 'refs/remotes/origin/HEAD';
    Harness.Libgit2BranchRefs[3] := 'refs/heads/release';

    Values := ExecuteGitListBranchesSurfaceCore(
      '/tmp/repo',
      gbLibgit2,
      True,
      @Harness.QueryBranchRefs,
      @Harness.ExecuteCli,
      Err
    );
    Check('queryflow list-branches returns two normalized names', Length(Values) = 2,
      'count=' + IntToStr(Length(Values)));
    if Length(Values) >= 2 then
    begin
      Check('queryflow list-branches keeps main once', Values[0] = 'main', Values[0]);
      Check('queryflow list-branches keeps release branch', Values[1] = 'release', Values[1]);
    end;
    Check('queryflow list-branches leaves error empty on libgit2 success', Err = '', 'err=' + Err);
  finally
    Harness.Free;
  end;
end;

procedure TestListRemoteBranchesFiltersCliOutput;
var
  Harness: TGitQueryHarness;
  Values: TStringArray;
  Err: string;
begin
  Harness := TGitQueryHarness.Create;
  try
    Harness.AddCliResult(NewProcessResult(
      True,
      0,
      '  origin/HEAD -> origin/main' + LineEnding +
      '  origin/main' + LineEnding +
      '  origin/release' + LineEnding +
      '  upstream/dev' + LineEnding,
      ''
    ));
    Err := '';
    Values := ExecuteGitListRemoteBranchesSurfaceCore(
      '/tmp/repo',
      'origin',
      gbCommandLine,
      True,
      @Harness.QueryRemoteBranchRefs,
      @Harness.ExecuteCli,
      Err
    );
    Check('queryflow list-remote-branches filters matching remote refs', Length(Values) = 2,
      'count=' + IntToStr(Length(Values)));
    if Length(Values) >= 2 then
    begin
      Check('queryflow list-remote-branches keeps main', Values[0] = 'main', Values[0]);
      Check('queryflow list-remote-branches keeps release', Values[1] = 'release', Values[1]);
    end;
    Check('queryflow list-remote-branches leaves error empty on success', Err = '', 'err=' + Err);
  finally
    Harness.Free;
  end;
end;

begin
  TestHasRemotePrefersLibgit2;
  TestHasRemoteFallsBackToCli;
  TestRemoteURLReportsCliFailure;
  TestCurrentBranchNormalizesSymbolicRef;
  TestShortHeadHashTruncatesLibgit2Oid;
  TestListBranchesNormalizesAndDedupesRefs;
  TestListRemoteBranchesFiltersCliOutput;

  WriteLn('');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
