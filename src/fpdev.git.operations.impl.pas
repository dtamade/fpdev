unit fpdev.git.operations.impl;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file

{
  Unified Git operations wrapper.
  Priority: libgit2 -> command-line git fallback

  Usage:
    var Git: TGitOperations;
    Git := TGitOperations.Create;
    try
      if Git.Clone('https://...', '/path/to/dest', 'branch') then
        WriteLn('Cloned successfully');
    finally
      Git.Free;
    end;
}

interface

uses
  SysUtils, Classes, fpdev.utils.process, fpdev.git.types,
  git2.api, git2.types;

type
  IGitCliRunner = interface
    ['{7D40CB2F-5C75-4B33-98D7-9E7138A50A8B}']
    function Execute(const AParams: array of string; const AWorkDir: string = ''): TProcessResult;
  end;

  { TGitOperations - Unified Git operations with libgit2 + CLI fallback }
  TGitOperations = class
  private
    FBackend: fpdev.git.types.TGitBackend;
    FLastError: string;
    FVerbose: Boolean;
    FGitManager: IGitManager;
    FCliRunner: IGitCliRunner;
    FCliOnly: Boolean;
    FCommandLineChecked: Boolean;
    FCommandLineAvailable: Boolean;
    FCommandLineCheckedPath: string;

    function TryInitLibgit2: Boolean;
    function CommandLineGitAvailable: Boolean;
    function ExecuteGitCli(const AParams: array of string; const AWorkDir: string = ''): TProcessResult;
    function ExecuteGitCommand(const AParams: array of string; const AWorkDir: string = ''): Boolean;
    function CheckoutAfterClone(const ARepoPath, ABranch: string;
      const AForce: Boolean; out AError: string): Boolean;
    function DirectoryExistsForProbe(const APath: string): Boolean;
    function TryIsRepositoryWithLibgit2(const APath: string): Boolean;
    function TryGetVersionWithLibgit2(out AVersion: string): Boolean;

    // libgit2 backend wrappers (delegate to libgit2backendflow)
    function CloneWithLibgit2(const AURL, ALocalPath: string; out AError: string): Boolean;
    function FetchWithLibgit2(const ARepoPath, ARemote: string; out AError: string): Boolean;
    function PullWithLibgit2(const ARepoPath: string; out AError: string;
      out ANeedsFallback: Boolean; const AAllowMerge: Boolean = True): Boolean;
    function TryHasRemoteWithLibgit2(const ARepoPath: string; out AHasRemote: Boolean): Boolean;
    function TryGetRemoteURLWithLibgit2(const ARepoPath, ARemote: string; out AURL: string): Boolean;
    function TryGetCurrentBranchWithLibgit2(const ARepoPath: string; out ABranch: string): Boolean;
    function TryGetShortHeadHashWithLibgit2(const ARepoPath: string; out AFullHash: string): Boolean;
    function TryListBranchesWithLibgit2(const ARepoPath: string; out ARefs: TStringArray): Boolean;
    function TryListRemoteBranchesWithLibgit2(const ARepoPath, ARemote: string; out ARefs: TStringArray): Boolean;
    function CheckoutWithLibgit2(const ARepoPath, AName: string; const Force: Boolean; out AError: string): Boolean;
    function AddAllWithLibgit2(const ARepoPath: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
    function AddPathspecWithLibgit2(const ARepoPath, APathSpec: string;
      out AError: string; out ANeedsFallback: Boolean): Boolean;
    function CommitWithLibgit2(
      const ARepoPath, AMessage: string;
      out AError: string;
      out ANeedsFallback: Boolean
    ): Boolean;
    function PushWithLibgit2(
      const ARepoPath, ARemote, ABranch: string;
      out AError: string;
      out ANeedsFallback: Boolean
    ): Boolean;

  public
    constructor Create; overload;
    constructor Create(const ACliRunner: IGitCliRunner; const ACliOnly: Boolean = False); overload;
    destructor Destroy; override;

    // Core operations
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function PullFastForwardOnly(const ARepoPath: string): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function GetRemoteURL(const ARepoPath: string; const ARemote: string = 'origin'): string;
    function GetCurrentBranch(const ARepoPath: string): string;
    function GetShortHeadHash(const ARepoPath: string; const ALength: Integer = 7): string;
    function ListBranches(const ARepoPath: string): TStringArray;
    function Add(const ARepoPath, APathSpec: string): Boolean;
    function Commit(const ARepoPath, AMessage: string): Boolean;
    function Push(const ARepoPath: string; const ARemote: string = 'origin'; const ABranch: string = ''): Boolean;
    function GetVersion: string;
    function ListRemoteBranches(const ARepoPath: string; const ARemote: string = 'origin'): TStringArray;

    property Backend: fpdev.git.types.TGitBackend read FBackend;
    property LastError: string read FLastError;
    property Verbose: Boolean read FVerbose write FVerbose;
  end;

// Concrete implementation behind fpdev.git.operations.

implementation

uses
  git2.impl, fpdev.git.operations.coreflow,
  fpdev.git.operations.identityflow,
  fpdev.git.operations.mutationflow, fpdev.git.operations.queryflow,
  fpdev.git.operations.probeflow, fpdev.git.operations.syncflow,
  fpdev.git.operations.transportflow,
  fpdev.git.operations.libgit2backendflow;

var
  Libgit2Available: Boolean = False;
  Libgit2Checked: Boolean = False;

type
  TDefaultGitCliRunner = class(TInterfacedObject, IGitCliRunner)
  public
    function Execute(const AParams: array of string; const AWorkDir: string = ''): TProcessResult;
  end;

{ TGitOperations }

function TDefaultGitCliRunner.Execute(const AParams: array of string; const AWorkDir: string): TProcessResult;
begin
  Result := TProcessExecutor.Execute('git', AParams, AWorkDir);
end;

constructor TGitOperations.Create;
begin
  Create(nil, False);
end;

constructor TGitOperations.Create(const ACliRunner: IGitCliRunner; const ACliOnly: Boolean);
begin
  inherited Create;
  FLastError := '';
  FVerbose := False;
  FGitManager := nil;
  FCliOnly := ACliOnly;
  FCommandLineChecked := False;
  FCommandLineAvailable := False;
  FCommandLineCheckedPath := '';
  if ACliRunner <> nil then
    FCliRunner := ACliRunner
  else
    FCliRunner := TDefaultGitCliRunner.Create;

  if FCliOnly then
  begin
    if CommandLineGitAvailable then
      FBackend := gbCommandLine
    else
      FBackend := gbNone;
    Exit;
  end;

  if TryInitLibgit2 then
    FBackend := gbLibgit2
  else
  begin
    if CommandLineGitAvailable then
      FBackend := gbCommandLine
    else
      FBackend := gbNone;
  end;
end;

destructor TGitOperations.Destroy;
begin
  if (FBackend = gbLibgit2) and (FGitManager <> nil) then
  begin
    try
      FGitManager.Finalize;
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('Error during Git cleanup: ', E.Message);
      end;
    end;
    FGitManager := nil;
  end;
  inherited Destroy;
end;

function TGitOperations.TryInitLibgit2: Boolean;
begin
  if not Libgit2Checked then
  begin
    Libgit2Checked := True;
    Libgit2Available := False;

    try
      FGitManager := NewGitManager();

      if FGitManager.Initialize then
        Libgit2Available := True
      else
      begin
        FGitManager := nil;
      end;
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('libgit2 initialization failed: ', E.Message);
        FGitManager := nil;
        Libgit2Available := False;
      end;
    end;
  end
  else if Libgit2Available and (FGitManager = nil) then
  begin
    try
      FGitManager := NewGitManager();
      if not FGitManager.Initialize then
        FGitManager := nil;
    except
      FGitManager := nil;
    end;
  end;

  Result := Libgit2Available and (FGitManager <> nil);
end;

function TGitOperations.CommandLineGitAvailable: Boolean;
var
  CurrentPath: string;
  LResult: TProcessResult;
begin
  CurrentPath := GetEnvironmentVariable('PATH');
  if (not FCommandLineChecked) or (CurrentPath <> FCommandLineCheckedPath) then
  begin
    FCommandLineChecked := True;
    FCommandLineCheckedPath := CurrentPath;
    LResult := ExecuteGitCli(['--version'], '');
    FCommandLineAvailable := LResult.Success;
  end;
  Result := FCommandLineAvailable;
end;

function TGitOperations.ExecuteGitCli(const AParams: array of string; const AWorkDir: string): TProcessResult;
begin
  if FCliRunner <> nil then
    Result := FCliRunner.Execute(AParams, AWorkDir)
  else
    Result := TProcessExecutor.Execute('git', AParams, AWorkDir);
end;

function TGitOperations.ExecuteGitCommand(const AParams: array of string; const AWorkDir: string): Boolean;
var
  LResult: TProcessResult;
begin
  LResult := ExecuteGitCli(AParams, AWorkDir);
  Result := LResult.Success;
  if not Result then
  begin
    if LResult.StdErr <> '' then
      FLastError := LResult.StdErr
    else if LResult.ErrorMessage <> '' then
      FLastError := LResult.ErrorMessage
    else
      FLastError := 'git command failed with exit code ' + IntToStr(LResult.ExitCode);
  end;
end;

function TGitOperations.CheckoutAfterClone(const ARepoPath, ABranch: string;
  const AForce: Boolean; out AError: string): Boolean;
begin
  Result := Checkout(ARepoPath, ABranch, AForce);
  AError := FLastError;
end;

function TGitOperations.DirectoryExistsForProbe(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

function TGitOperations.TryIsRepositoryWithLibgit2(const APath: string): Boolean;
begin
  Result := IsRepositoryWithLibgit2(APath);
end;

function TGitOperations.TryGetVersionWithLibgit2(out AVersion: string): Boolean;
begin
  Result := False;
  AVersion := '';

  if (FBackend <> gbLibgit2) or (FGitManager = nil) then
    Exit(False);

  try
    AVersion := FGitManager.Version;
    Result := True;
  except
    AVersion := '';
    Result := False;
  end;
end;

// libgit2 backend wrappers: thin delegates to libgit2backendflow

function TGitOperations.CloneWithLibgit2(const AURL, ALocalPath: string; out AError: string): Boolean;
begin
  Result := CloneWithLibgit2Core(FGitManager, AURL, ALocalPath, AError);
end;

function TGitOperations.FetchWithLibgit2(const ARepoPath, ARemote: string; out AError: string): Boolean;
begin
  Result := FetchWithLibgit2Core(FGitManager, ARepoPath, ARemote, AError);
end;

function TGitOperations.PullWithLibgit2(const ARepoPath: string; out AError: string;
  out ANeedsFallback: Boolean; const AAllowMerge: Boolean): Boolean;
begin
  Result := PullWithLibgit2Core(FGitManager, ARepoPath, AError, ANeedsFallback, AAllowMerge);
end;

function TGitOperations.CheckoutWithLibgit2(const ARepoPath, AName: string;
  const Force: Boolean; out AError: string): Boolean;
begin
  Result := CheckoutWithLibgit2Core(FGitManager, ARepoPath, AName, Force, AError);
end;

function TGitOperations.TryHasRemoteWithLibgit2(const ARepoPath: string; out AHasRemote: Boolean): Boolean;
begin
  Result := TryHasRemoteWithLibgit2Core(FGitManager, ARepoPath, AHasRemote);
end;

function TGitOperations.TryGetRemoteURLWithLibgit2(const ARepoPath, ARemote: string; out AURL: string): Boolean;
begin
  Result := TryGetRemoteURLWithLibgit2Core(FGitManager, ARepoPath, ARemote, AURL);
end;

function TGitOperations.TryGetCurrentBranchWithLibgit2(const ARepoPath: string; out ABranch: string): Boolean;
begin
  Result := TryGetCurrentBranchWithLibgit2Core(FGitManager, ARepoPath, ABranch);
end;

function TGitOperations.TryGetShortHeadHashWithLibgit2(const ARepoPath: string; out AFullHash: string): Boolean;
begin
  Result := TryGetShortHeadHashWithLibgit2Core(FGitManager, ARepoPath, AFullHash);
end;

function TGitOperations.TryListBranchesWithLibgit2(const ARepoPath: string; out ARefs: TStringArray): Boolean;
begin
  Result := TryListBranchesWithLibgit2Core(FGitManager, ARepoPath, ARefs);
end;

function TGitOperations.TryListRemoteBranchesWithLibgit2(const ARepoPath, ARemote: string; out ARefs: TStringArray): Boolean;
begin
  Result := TryListRemoteBranchesWithLibgit2Core(FGitManager, ARepoPath, ARemote, ARefs);
end;

function TGitOperations.AddAllWithLibgit2(const ARepoPath: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
begin
  Result := AddAllWithLibgit2Core(FGitManager, ARepoPath, AError, ANeedsFallback);
end;

function TGitOperations.AddPathspecWithLibgit2(const ARepoPath, APathSpec: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
begin
  Result := AddPathspecWithLibgit2Core(FGitManager, ARepoPath, APathSpec, AError, ANeedsFallback);
end;

function TGitOperations.CommitWithLibgit2(
  const ARepoPath, AMessage: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
begin
  Result := CommitWithLibgit2Core(FGitManager, ARepoPath, AMessage, AError, ANeedsFallback);
end;

function TGitOperations.PushWithLibgit2(
  const ARepoPath, ARemote, ABranch: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
begin
  Result := PushWithLibgit2Core(FGitManager, ARepoPath, ARemote, ABranch, AError, ANeedsFallback);
end;

// Public facade methods

function TGitOperations.Clone(const AURL, ALocalPath: string; const ABranch: string): Boolean;
begin
  FLastError := '';
  Result := ExecuteGitCloneSurfaceCore(
    AURL,
    ALocalPath,
    ABranch,
    FBackend,
    CommandLineGitAvailable,
    @CloneWithLibgit2,
    @CheckoutAfterClone,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.Fetch(const ARepoPath: string; const ARemote: string): Boolean;
begin
  FLastError := '';
  Result := ExecuteGitFetchSurfaceCore(
    ARepoPath,
    ARemote,
    FBackend,
    CommandLineGitAvailable,
    @FetchWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.Pull(const ARepoPath: string): Boolean;
begin
  FLastError := '';
  Result := ExecuteGitPullSurfaceCore(
    ARepoPath,
    FBackend,
    CommandLineGitAvailable,
    @PullWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.PullFastForwardOnly(const ARepoPath: string): Boolean;
begin
  FLastError := '';
  Result := ExecuteGitPullFastForwardOnlySurfaceCore(
    ARepoPath,
    FBackend,
    CommandLineGitAvailable,
    @PullWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.Checkout(const ARepoPath, AName: string; const Force: Boolean): Boolean;
begin
  FLastError := '';
  Result := ExecuteGitCheckoutSurfaceCore(
    ARepoPath,
    AName,
    Force,
    FBackend,
    CommandLineGitAvailable,
    @CheckoutWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.IsRepository(const APath: string): Boolean;
begin
  Result := ExecuteGitIsRepositorySurfaceCore(
    APath,
    FBackend,
    @DirectoryExistsForProbe,
    @TryIsRepositoryWithLibgit2
  );
end;

function TGitOperations.HasRemote(const ARepoPath: string): Boolean;
begin
  Result := ExecuteGitHasRemoteSurfaceCore(
    ARepoPath,
    FBackend,
    CommandLineGitAvailable,
    @TryHasRemoteWithLibgit2,
    @ExecuteGitCli
  );
end;

function TGitOperations.GetRemoteURL(const ARepoPath: string; const ARemote: string): string;
begin
  FLastError := '';
  Result := ExecuteGitRemoteURLSurfaceCore(
    ARepoPath,
    ARemote,
    FBackend,
    CommandLineGitAvailable,
    @TryGetRemoteURLWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.GetCurrentBranch(const ARepoPath: string): string;
begin
  Result := ExecuteGitCurrentBranchSurfaceCore(
    ARepoPath,
    FBackend,
    CommandLineGitAvailable,
    @TryGetCurrentBranchWithLibgit2,
    @ExecuteGitCli
  );
end;

function TGitOperations.GetShortHeadHash(const ARepoPath: string; const ALength: Integer): string;
begin
  FLastError := '';
  Result := ExecuteGitShortHeadHashSurfaceCore(
    ARepoPath,
    ALength,
    FBackend,
    CommandLineGitAvailable,
    @TryGetShortHeadHashWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.Add(const ARepoPath, APathSpec: string): Boolean;
begin
  FLastError := '';
  Result := ExecuteGitAddSurfaceCore(
    ARepoPath,
    APathSpec,
    FBackend,
    CommandLineGitAvailable,
    @AddAllWithLibgit2,
    @AddPathspecWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.Commit(const ARepoPath, AMessage: string): Boolean;
begin
  FLastError := '';
  Result := ExecuteGitCommitSurfaceCore(
    ARepoPath,
    AMessage,
    FBackend,
    CommandLineGitAvailable,
    @CommitWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.Push(const ARepoPath: string; const ARemote: string; const ABranch: string): Boolean;
begin
  FLastError := '';
  Result := ExecuteGitPushSurfaceCore(
    ARepoPath,
    ARemote,
    ABranch,
    FBackend,
    CommandLineGitAvailable,
    @PushWithLibgit2,
    @GetCurrentBranch,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.GetVersion: string;
begin
  FLastError := '';
  Result := ExecuteGitVersionSurfaceCore(
    FBackend,
    CommandLineGitAvailable,
    @TryGetVersionWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.ListBranches(const ARepoPath: string): TStringArray;
begin
  FLastError := '';
  Result := ExecuteGitListBranchesSurfaceCore(
    ARepoPath,
    FBackend,
    CommandLineGitAvailable,
    @TryListBranchesWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

function TGitOperations.ListRemoteBranches(const ARepoPath: string; const ARemote: string): TStringArray;
begin
  FLastError := '';
  Result := ExecuteGitListRemoteBranchesSurfaceCore(
    ARepoPath,
    ARemote,
    FBackend,
    CommandLineGitAvailable,
    @TryListRemoteBranchesWithLibgit2,
    @ExecuteGitCli,
    FLastError
  );
end;

end.
