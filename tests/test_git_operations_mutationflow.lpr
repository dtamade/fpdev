program test_git_operations_mutationflow;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.git.types, fpdev.utils.process,
  fpdev.git.operations.mutationflow;

type
  TGitMutationHarness = class
  private
    FCliResults: array of TProcessResult;
    FCliIndex: Integer;
  public
    CheckoutCalls: Integer;
    AddAllCalls: Integer;
    AddPathspecCalls: Integer;
    CommitCalls: Integer;
    PushCalls: Integer;
    CurrentBranchCalls: Integer;
    CliCalls: Integer;
    LastCliCommand: string;
    Libgit2CheckoutResult: Boolean;
    Libgit2CheckoutError: string;
    Libgit2AddAllResult: Boolean;
    Libgit2AddAllNeedsFallback: Boolean;
    Libgit2AddAllError: string;
    Libgit2AddPathspecResult: Boolean;
    Libgit2AddPathspecNeedsFallback: Boolean;
    Libgit2AddPathspecError: string;
    Libgit2CommitResult: Boolean;
    Libgit2CommitNeedsFallback: Boolean;
    Libgit2CommitError: string;
    Libgit2PushResult: Boolean;
    Libgit2PushNeedsFallback: Boolean;
    Libgit2PushError: string;
    CurrentBranchValue: string;
    constructor Create;
    procedure AddCliResult(const AResult: TProcessResult);
    function CheckoutWithLibgit2(const ARepoPath, AName: string;
      const AForce: Boolean; out AError: string): Boolean;
    function AddAllWithLibgit2(const ARepoPath: string; out AError: string;
      out ANeedsFallback: Boolean): Boolean;
    function AddPathspecWithLibgit2(const ARepoPath, APathSpec: string;
      out AError: string; out ANeedsFallback: Boolean): Boolean;
    function CommitWithLibgit2(const ARepoPath, AMessage: string;
      out AError: string; out ANeedsFallback: Boolean): Boolean;
    function PushWithLibgit2(const ARepoPath, ARemote, ABranch: string;
      out AError: string; out ANeedsFallback: Boolean): Boolean;
    function GetCurrentBranch(const ARepoPath: string): string;
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

constructor TGitMutationHarness.Create;
begin
  inherited Create;
  FCliIndex := 0;
end;

procedure TGitMutationHarness.AddCliResult(const AResult: TProcessResult);
var
  L: Integer;
begin
  L := Length(FCliResults);
  SetLength(FCliResults, L + 1);
  FCliResults[L] := AResult;
end;

function TGitMutationHarness.CheckoutWithLibgit2(const ARepoPath,
  AName: string; const AForce: Boolean; out AError: string): Boolean;
begin
  Inc(CheckoutCalls);
  if ARepoPath = '' then;
  if AName = '' then;
  if AForce then;
  AError := Libgit2CheckoutError;
  Result := Libgit2CheckoutResult;
end;

function TGitMutationHarness.AddAllWithLibgit2(const ARepoPath: string;
  out AError: string; out ANeedsFallback: Boolean): Boolean;
begin
  Inc(AddAllCalls);
  if ARepoPath = '' then;
  AError := Libgit2AddAllError;
  ANeedsFallback := Libgit2AddAllNeedsFallback;
  Result := Libgit2AddAllResult;
end;

function TGitMutationHarness.AddPathspecWithLibgit2(const ARepoPath,
  APathSpec: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
begin
  Inc(AddPathspecCalls);
  if ARepoPath = '' then;
  if APathSpec = '' then;
  AError := Libgit2AddPathspecError;
  ANeedsFallback := Libgit2AddPathspecNeedsFallback;
  Result := Libgit2AddPathspecResult;
end;

function TGitMutationHarness.CommitWithLibgit2(const ARepoPath,
  AMessage: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
begin
  Inc(CommitCalls);
  if ARepoPath = '' then;
  if AMessage = '' then;
  AError := Libgit2CommitError;
  ANeedsFallback := Libgit2CommitNeedsFallback;
  Result := Libgit2CommitResult;
end;

function TGitMutationHarness.PushWithLibgit2(const ARepoPath, ARemote,
  ABranch: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
begin
  Inc(PushCalls);
  if ARepoPath = '' then;
  if ARemote = '' then;
  if ABranch = '' then;
  AError := Libgit2PushError;
  ANeedsFallback := Libgit2PushNeedsFallback;
  Result := Libgit2PushResult;
end;

function TGitMutationHarness.GetCurrentBranch(const ARepoPath: string): string;
begin
  Inc(CurrentBranchCalls);
  if ARepoPath = '' then;
  Result := CurrentBranchValue;
end;

function TGitMutationHarness.ExecuteCli(const AParams: array of string;
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

procedure TestCheckoutEmptyNameSucceedsWithoutWork;
var
  Harness: TGitMutationHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitMutationHarness.Create;
  try
    Err := '';
    OK := ExecuteGitCheckoutSurfaceCore(
      '/tmp/repo',
      '',
      False,
      gbCommandLine,
      True,
      @Harness.CheckoutWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('mutationflow checkout empty name succeeds', OK, 'expected true');
    Check('mutationflow checkout empty name skips libgit2', Harness.CheckoutCalls = 0,
      'checkout calls=' + IntToStr(Harness.CheckoutCalls));
    Check('mutationflow checkout empty name skips CLI', Harness.CliCalls = 0,
      'cli calls=' + IntToStr(Harness.CliCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestCheckoutCreatesLocalBranchFromRemoteRef;
var
  Harness: TGitMutationHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitMutationHarness.Create;
  try
    Harness.AddCliResult(NewProcessResult(False, 1, '', '', ''));
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Err := '';
    OK := ExecuteGitCheckoutSurfaceCore(
      '/tmp/repo',
      'release',
      False,
      gbCommandLine,
      True,
      @Harness.CheckoutWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('mutationflow checkout remote branch succeeds', OK, 'expected true');
    Check('mutationflow checkout remote branch uses local branch create command',
      Pos('checkout -b release origin/release [cwd=/tmp/repo]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

procedure TestAddAllPrefersLibgit2;
var
  Harness: TGitMutationHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitMutationHarness.Create;
  try
    Harness.Libgit2AddAllResult := True;
    Err := '';
    OK := ExecuteGitAddSurfaceCore(
      '/tmp/repo',
      '.',
      gbLibgit2,
      True,
      @Harness.AddAllWithLibgit2,
      @Harness.AddPathspecWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('mutationflow add-all returns libgit2 success', OK, 'expected true');
    Check('mutationflow add-all skips CLI on libgit2 success', Harness.CliCalls = 0,
      'cli calls=' + IntToStr(Harness.CliCalls));
    Check('mutationflow add-all skips pathspec libgit2 callback', Harness.AddPathspecCalls = 0,
      'pathspec calls=' + IntToStr(Harness.AddPathspecCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestAddPathspecFallsBackToCli;
var
  Harness: TGitMutationHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitMutationHarness.Create;
  try
    Harness.Libgit2AddPathspecNeedsFallback := True;
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Err := '';
    OK := ExecuteGitAddSurfaceCore(
      '/tmp/repo',
      'dir/*.txt',
      gbLibgit2,
      True,
      @Harness.AddAllWithLibgit2,
      @Harness.AddPathspecWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('mutationflow add pathspec falls back to CLI', OK, 'expected true');
    Check('mutationflow add pathspec records CLI add command',
      Pos('add dir/*.txt [cwd=/tmp/repo]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

procedure TestCommitRejectsEmptyMessage;
var
  Harness: TGitMutationHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitMutationHarness.Create;
  try
    Err := '';
    OK := ExecuteGitCommitSurfaceCore(
      '/tmp/repo',
      '',
      gbCommandLine,
      True,
      @Harness.CommitWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('mutationflow commit empty message fails', not OK, 'expected false');
    Check('mutationflow commit empty message keeps explicit error',
      Err = 'Commit message is empty', 'err=' + Err);
  finally
    Harness.Free;
  end;
end;

procedure TestPushDefaultsRemoteAndResolvedBranch;
var
  Harness: TGitMutationHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitMutationHarness.Create;
  try
    Harness.CurrentBranchValue := 'main';
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Err := '';
    OK := ExecuteGitPushSurfaceCore(
      '/tmp/repo',
      '',
      '',
      gbCommandLine,
      True,
      @Harness.PushWithLibgit2,
      @Harness.GetCurrentBranch,
      @Harness.ExecuteCli,
      Err
    );
    Check('mutationflow push defaults remote and current branch', OK, 'expected true');
    Check('mutationflow push uses origin main command',
      Pos('push origin main [cwd=/tmp/repo]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

procedure TestPushFallsBackToHeadWithoutBranch;
var
  Harness: TGitMutationHarness;
  Err: string;
  OK: Boolean;
begin
  Harness := TGitMutationHarness.Create;
  try
    Harness.CurrentBranchValue := '';
    Harness.AddCliResult(NewProcessResult(True, 0, '', '', ''));
    Err := '';
    OK := ExecuteGitPushSurfaceCore(
      '/tmp/repo',
      'origin',
      '',
      gbCommandLine,
      True,
      @Harness.PushWithLibgit2,
      @Harness.GetCurrentBranch,
      @Harness.ExecuteCli,
      Err
    );
    Check('mutationflow push falls back to HEAD when branch unknown', OK, 'expected true');
    Check('mutationflow push uses HEAD command',
      Pos('push origin HEAD [cwd=/tmp/repo]', Harness.LastCliCommand) = 1,
      Harness.LastCliCommand);
  finally
    Harness.Free;
  end;
end;

begin
  TestCheckoutEmptyNameSucceedsWithoutWork;
  TestCheckoutCreatesLocalBranchFromRemoteRef;
  TestAddAllPrefersLibgit2;
  TestAddPathspecFallsBackToCli;
  TestCommitRejectsEmptyMessage;
  TestPushDefaultsRemoteAndResolvedBranch;
  TestPushFallsBackToHeadWithoutBranch;

  WriteLn('');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
