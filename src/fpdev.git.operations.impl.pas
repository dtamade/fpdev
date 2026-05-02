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

    // libgit2 backend functions (use instance FGitManager)
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
  git2.impl, libgit2, ctypes, fpdev.git.operations.identityflow,
  fpdev.git.operations.mutationflow, fpdev.git.operations.queryflow,
  fpdev.git.operations.syncflow, fpdev.git.operations.transportflow;

var
  Libgit2Available: Boolean = False;
  Libgit2Checked: Boolean = False;

type
  TDefaultGitCliRunner = class(TInterfacedObject, IGitCliRunner)
  public
    function Execute(const AParams: array of string; const AWorkDir: string = ''): TProcessResult;
  end;

  PGitAddAllStatusPayload = ^TGitAddAllStatusPayload;
  TGitAddAllStatusPayload = record
    AddPaths: TStringList;
    RemovePaths: TStringList;
    WorkDir: string;
    NeedsFallback: Boolean;
    HadError: Boolean;
    ErrorText: string;
  end;

  PIndexMatchPayload = ^TIndexMatchPayload;
  TIndexMatchPayload = record
    MatchCount: Integer;
  end;

// Forward declaration for standalone function
function IsRepositoryWithLibgit2(const APath: string): Boolean; forward;

function Libgit2LastErrorText: string;
var
  Err: Pgit_error_t;
begin
  Result := '';
  Err := git_error_last;
  if (Err <> nil) and (Err^.message <> nil) then
    Result := string(Err^.message);
end;

function AddAllStatusCb(const APath: PChar; AFlags: cuint; APayload: Pointer): cint; cdecl;
var
  P: PGitAddAllStatusPayload;
  UnsupportedMask: cuint;
  DeleteMask: cuint;
  TypeChangeMask: cuint;
  LPath: string;
  AbsPath: string;
begin
  Result := 0;
  P := PGitAddAllStatusPayload(APayload);
  if (P = nil) or (P^.AddPaths = nil) or (P^.RemovePaths = nil) then
    Exit(0);
  if P^.HadError then
    Exit(-1);

  try
    if (AFlags and GIT_STATUS_IGNORED) <> 0 then
      Exit(0);

    // Prefer to handle most states via libgit2-only. Only fall back for cases
    // where libgit2 cannot stage the entry reliably (e.g. unreadable files).
    UnsupportedMask := GIT_STATUS_WT_UNREADABLE;

    if (AFlags and UnsupportedMask) <> 0 then
    begin
      P^.NeedsFallback := True;
      Exit(0);
    end;

    if (AFlags = GIT_STATUS_CURRENT) or (APath = nil) then
      Exit(0);

    LPath := string(APath);
    if Trim(LPath) = '' then
      Exit(0);

    DeleteMask := GIT_STATUS_WT_DELETED or GIT_STATUS_INDEX_DELETED;
    if (AFlags and DeleteMask) <> 0 then
    begin
      P^.RemovePaths.Add(LPath);
      Exit(0);
    end;

    TypeChangeMask := GIT_STATUS_WT_TYPECHANGE or GIT_STATUS_INDEX_TYPECHANGE;
    if (AFlags and TypeChangeMask) <> 0 then
    begin
      // Type changes are handled as remove + best-effort add (skip directories).
      P^.RemovePaths.Add(LPath);

      AbsPath := '';
      if Trim(P^.WorkDir) <> '' then
        AbsPath := IncludeTrailingPathDelimiter(P^.WorkDir) + StringReplace(LPath, '/', PathDelim, [rfReplaceAll]);

      if (AbsPath = '') or (not DirectoryExists(AbsPath)) then
      begin
        if (AbsPath = '') or FileExists(AbsPath) then
          P^.AddPaths.Add(LPath);
      end;
      Exit(0);
    end;

    if (AFlags <> GIT_STATUS_CURRENT) then
    begin
      P^.AddPaths.Add(LPath);
    end;
  except
    on E: Exception do
    begin
      P^.HadError := True;
      P^.ErrorText := E.Message;
      Result := -1;
    end;
  end;
end;

function IndexMatchedCb(const APath: PChar; const AMatchedPathSpec: PChar; APayload: Pointer): cint; cdecl;
var
  P: PIndexMatchPayload;
begin
  if APath <> nil then;
  if AMatchedPathSpec <> nil then;
  Result := 0;
  P := PIndexMatchPayload(APayload);
  if P <> nil then
    Inc(P^.MatchCount);
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

  // Try to use libgit2 first
  if TryInitLibgit2 then
    FBackend := gbLibgit2
  else
  begin
    // Check if command-line git is available
    if CommandLineGitAvailable then
      FBackend := gbCommandLine
    else
      FBackend := gbNone;
  end;
end;

destructor TGitOperations.Destroy;
begin
  // Cleanup libgit2 instance manager
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
  // Only check libgit2 availability once per process
  if not Libgit2Checked then
  begin
    Libgit2Checked := True;
    Libgit2Available := False;

    try
      // Create and initialize GitManager (using modern interface)
      FGitManager := NewGitManager();

      // Try to initialize libgit2
      if FGitManager.Initialize then
        Libgit2Available := True
      else
      begin
        // Initialization failed, release the interface
        FGitManager := nil;
      end;
    except
      on E: Exception do
      begin
        // libgit2 library not available or initialization failed
        if FVerbose then
          WriteLn('libgit2 initialization failed: ', E.Message);
        FGitManager := nil;
        Libgit2Available := False;
      end;
    end;
  end
  else if Libgit2Available and (FGitManager = nil) then
  begin
    // libgit2 is available but this instance doesn't have a manager yet
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
var
  GitDir: string;
begin
  // Simple check: look for .git directory
  GitDir := IncludeTrailingPathDelimiter(APath) + '.git';
  Result := DirectoryExists(GitDir);

  // Also try libgit2 if available for more accurate check
  if (not Result) and (FBackend = gbLibgit2) then
  begin
    try
      Result := IsRepositoryWithLibgit2(APath);
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('libgit2 repository check exception: ', E.Message, ', using directory check');
      end;
    end;
  end;
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

function TGitOperations.AddAllWithLibgit2(
  const ARepoPath: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
var
  RepoHandle: git_repository;
  IndexHandle: git_index;
  AddPaths: TStringList;
  RemovePaths: TStringList;
  Payload: TGitAddAllStatusPayload;
  WorkDirP: PChar;
  RC: cint;
  i: Integer;

begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  RepoHandle := nil;
  IndexHandle := nil;
  AddPaths := TStringList.Create;
  RemovePaths := TStringList.Create;
  try
    Payload.AddPaths := AddPaths;
    Payload.RemovePaths := RemovePaths;
    Payload.WorkDir := '';
    Payload.NeedsFallback := False;
    Payload.HadError := False;
    Payload.ErrorText := '';

    RC := git_repository_open(RepoHandle, PChar(ARepoPath));
    if RC <> GIT_OK then
    begin
      AError := Libgit2LastErrorText;
      if AError <> '' then
        AError := 'libgit2 open repository failed: ' + AError
      else
        AError := 'libgit2 open repository failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    WorkDirP := git_repository_workdir(RepoHandle);
    if WorkDirP <> nil then
      Payload.WorkDir := StringReplace(string(WorkDirP), '/', PathDelim, [rfReplaceAll]);

    RC := git_repository_index(IndexHandle, RepoHandle);
    if RC <> GIT_OK then
    begin
      AError := Libgit2LastErrorText;
      if AError <> '' then
        AError := 'libgit2 open index failed: ' + AError
      else
        AError := 'libgit2 open index failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_status_foreach(RepoHandle, @AddAllStatusCb, @Payload);
    if Payload.HadError then
    begin
      AError := 'libgit2 status callback error: ' + Payload.ErrorText;
      ANeedsFallback := True;
      Exit(False);
    end;
    if RC <> GIT_OK then
    begin
      AError := Libgit2LastErrorText;
      if AError <> '' then
        AError := 'libgit2 status foreach failed: ' + AError
      else
        AError := 'libgit2 status foreach failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    if Payload.NeedsFallback then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    if (RemovePaths.Count > 0) or (AddPaths.Count > 0) then
    begin
      for i := 0 to RemovePaths.Count - 1 do
      begin
        RC := git_index_remove_bypath(IndexHandle, PChar(RemovePaths[i]));
        if (RC <> GIT_OK) and (RC <> GIT_ENOTFOUND) then
        begin
          AError := Libgit2LastErrorText;
          if AError <> '' then
            AError := 'libgit2 remove failed: ' + AError
          else
            AError := 'libgit2 remove failed';
          ANeedsFallback := True;
          Exit(False);
        end;
      end;

      for i := 0 to AddPaths.Count - 1 do
      begin
        RC := git_index_add_bypath(IndexHandle, PChar(AddPaths[i]));
        if RC <> GIT_OK then
        begin
          AError := Libgit2LastErrorText;
          if AError <> '' then
            AError := 'libgit2 add failed: ' + AError
          else
            AError := 'libgit2 add failed';
          ANeedsFallback := True;
          Exit(False);
        end;
      end;

      RC := git_index_write(IndexHandle);
      if RC <> GIT_OK then
      begin
        AError := Libgit2LastErrorText;
        if AError <> '' then
          AError := 'libgit2 index write failed: ' + AError
        else
          AError := 'libgit2 index write failed';
        ANeedsFallback := True;
        Exit(False);
      end;
    end;

    Result := True;
  finally
    RemovePaths.Free;
    AddPaths.Free;
    if IndexHandle <> nil then
      git_index_free(IndexHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function TGitOperations.AddPathspecWithLibgit2(const ARepoPath,
  APathSpec: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
var
  RepoHandle: git_repository;
  IndexHandle: git_index;
  WorkDirP: PChar;
  WorkDir: string;
  PathSpecAbs: string;
  WorkDirAbs: string;
  RelPath: string;
  RelPathFs: string;
  AbsCandidate: string;
  RC: Integer;
  LErr: string;
  PathSpecStr: AnsiString;
  PathSpecPtrs: array[0..0] of PChar;
  PathSpecs: git_strarray;
  MatchPayload: TIndexMatchPayload;
begin
  Result := False;
  AError := '';
  ANeedsFallback := True;

  if FGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit(False);
  end;

  RepoHandle := nil;
  IndexHandle := nil;
  try
    RC := git_repository_open(RepoHandle, PChar(ARepoPath));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 open repository failed: ' + LErr
      else
        AError := 'libgit2 open repository failed';
      Exit(False);
    end;

    WorkDir := '';
    WorkDirP := git_repository_workdir(RepoHandle);
    if WorkDirP <> nil then
      WorkDir := string(WorkDirP);

    RelPath := APathSpec;

    if WorkDir <> '' then
    begin
      PathSpecAbs := ExpandFileName(APathSpec);
      WorkDirAbs := ExpandFileName(IncludeTrailingPathDelimiter(WorkDir));
      {$IFDEF MSWINDOWS}
      if Pos(AnsiLowerCase(WorkDirAbs), AnsiLowerCase(PathSpecAbs)) = 1 then
      {$ELSE}
      if Pos(WorkDirAbs, PathSpecAbs) = 1 then
      {$ENDIF}
        RelPath := Copy(PathSpecAbs, Length(WorkDirAbs) + 1, MaxInt);
    end;

    RelPath := StringReplace(RelPath, '\', '/', [rfReplaceAll]);

    RC := git_repository_index(IndexHandle, RepoHandle);
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 open index failed: ' + LErr
      else
        AError := 'libgit2 open index failed';
      Exit(False);
    end;

    PathSpecStr := AnsiString(RelPath);
    PathSpecPtrs[0] := PChar(PathSpecStr);
    PathSpecs.strings := @PathSpecPtrs[0];
    PathSpecs.count := 1;

    MatchPayload.MatchCount := 0;

    RC := git_index_update_all(IndexHandle, @PathSpecs, @IndexMatchedCb, @MatchPayload);
    if RC = GIT_OK then
      RC := git_index_add_all(
        IndexHandle,
        @PathSpecs,
        GIT_INDEX_ADD_CHECK_PATHSPEC,
        @IndexMatchedCb,
        @MatchPayload
      );

    if RC = GIT_OK then
    begin
      if MatchPayload.MatchCount = 0 then
      begin
        AbsCandidate := '';
        if (Pos('*', RelPath) = 0) and (Pos('?', RelPath) = 0) and (WorkDir <> '') then
        begin
          RelPathFs := StringReplace(RelPath, '/', PathDelim, [rfReplaceAll]);
          AbsCandidate := IncludeTrailingPathDelimiter(WorkDir) + RelPathFs;
        end;

        if (AbsCandidate <> '') and DirectoryExists(AbsCandidate) then
        begin
          Result := True;
          ANeedsFallback := False;
          Exit(True);
        end;

        AError := Format('libgit2 add failed: pathspec ''%s'' did not match any files', [APathSpec]);
        Exit(False);
      end;

      RC := git_index_write(IndexHandle);
      if RC = GIT_OK then
      begin
        Result := True;
        ANeedsFallback := False;
        Exit(True);
      end;
    end;

    LErr := Libgit2LastErrorText;
    if LErr <> '' then
      AError := 'libgit2 add failed: ' + LErr
    else if AError = '' then
      AError := 'libgit2 add failed';
  finally
    if IndexHandle <> nil then
      git_index_free(IndexHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function TGitOperations.CommitWithLibgit2(
  const ARepoPath, AMessage: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
var
  RepoHandle: git_repository;
  IndexHandle: git_index;
  TreeHandle: git_tree;
  TreeOid: git_oid;
  CommitOid: git_oid;
  HeadRef: git_reference;
  BranchRef: git_reference;
  ParentCommit: git_commit;
  Parents: array[0..0] of git_commit;
  ParentsPtr: Pointer;
  ParentCount: csize_t;
  AuthorSig: git_signature;
  CommitterSig: git_signature;
  Identity: TGitOperationIdentity;
  UpdateRef: string;
  SymTargetP: PChar;
  TargetOID: Pgit_oid;
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  RepoHandle := nil;
  IndexHandle := nil;
  TreeHandle := nil;
  HeadRef := nil;
  BranchRef := nil;
  ParentCommit := nil;
  AuthorSig := nil;
  CommitterSig := nil;

  try
    RC := git_repository_open(RepoHandle, PChar(ARepoPath));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 open repository failed: ' + LErr
      else
        AError := 'libgit2 open repository failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    UpdateRef := 'HEAD';
    ParentCount := 0;
    RC := git_reference_lookup(HeadRef, RepoHandle, PChar('HEAD'));
    if RC = GIT_OK then
    begin
      SymTargetP := git_reference_symbolic_target(HeadRef);
      if SymTargetP <> nil then
      begin
        UpdateRef := string(SymTargetP);
        RC := git_reference_lookup(BranchRef, RepoHandle, SymTargetP);
        if RC = GIT_OK then
        begin
          TargetOID := git_reference_target(BranchRef);
          if TargetOID <> nil then
          begin
            RC := git_commit_lookup(ParentCommit, RepoHandle, TargetOID);
            if RC = GIT_OK then
            begin
              Parents[0] := ParentCommit;
              ParentCount := 1;
            end;
          end;
        end;
      end
      else
      begin
        TargetOID := git_reference_target(HeadRef);
        if TargetOID <> nil then
        begin
          RC := git_commit_lookup(ParentCommit, RepoHandle, TargetOID);
          if RC = GIT_OK then
          begin
            Parents[0] := ParentCommit;
            ParentCount := 1;
          end;
        end;
      end;
    end;

    if not TryResolveGitOperationIdentity(RepoHandle, ARepoPath, False, Identity) then
    begin
      AError := 'Git identity not configured (user.name/user.email)';
      ANeedsFallback := True;
      Exit(False);
    end;

    if not TryCreateGitOperationSignatures(Identity, AuthorSig, CommitterSig, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_repository_index(IndexHandle, RepoHandle);
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 open index failed: ' + LErr
      else
        AError := 'libgit2 open index failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_index_write_tree(TreeOid, IndexHandle);
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 write tree failed: ' + LErr
      else
        AError := 'libgit2 write tree failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    TreeHandle := nil;
    RC := git_tree_lookup(TreeHandle, RepoHandle, @TreeOid);
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 tree lookup failed: ' + LErr
      else
        AError := 'libgit2 tree lookup failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    ParentsPtr := nil;
    if ParentCount > 0 then
      ParentsPtr := @Parents[0];

    CommitOid := Default(git_oid);
    RC := git_commit_create(CommitOid, RepoHandle, PChar(UpdateRef),
      AuthorSig, CommitterSig, nil, PChar(AMessage),
      TreeHandle, ParentCount, ParentsPtr);
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 commit failed: ' + LErr
      else
        AError := 'libgit2 commit failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    Result := True;
  finally
    if BranchRef <> nil then
      git_reference_free(BranchRef);
    if HeadRef <> nil then
      git_reference_free(HeadRef);
    if TreeHandle <> nil then
      git_object_free(git_object(TreeHandle));
    if IndexHandle <> nil then
      git_index_free(IndexHandle);
    if ParentCommit <> nil then
      git_object_free(git_object(ParentCommit));
    if AuthorSig <> nil then
      git_signature_free(AuthorSig);
    if CommitterSig <> nil then
      git_signature_free(CommitterSig);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function TGitOperations.PushWithLibgit2(
  const ARepoPath, ARemote, ABranch: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
var
  RepoHandle: git_repository;
  RemoteHandle: git_remote;
  HeadRef: git_reference;
  SymTargetP: PChar;
  BranchParam: string;
  RemoteName: string;
  LocalRef: string;
  RemoteRef: string;
  RefSpecStr: AnsiString;
  RefSpecPtrs: array[0..0] of PChar;
  RefSpecs: git_strarray;
  PushOpts: git_push_options;
  CredPayload: TGitTransportCredentialPayload;
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  RepoHandle := nil;
  RemoteHandle := nil;
  HeadRef := nil;

  BranchParam := Trim(ABranch);
  RemoteName := Trim(ARemote);
  if RemoteName = '' then
    RemoteName := 'origin';

  try
    RC := git_repository_open(RepoHandle, PChar(ARepoPath));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 open repository failed: ' + LErr
      else
        AError := 'libgit2 open repository failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_remote_lookup(RemoteHandle, RepoHandle, PChar(RemoteName));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 remote lookup failed: ' + LErr
      else
        AError := 'libgit2 remote lookup failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    LocalRef := '';
    RemoteRef := '';

    if (BranchParam = '') or SameText(BranchParam, 'HEAD') then
    begin
      RC := git_reference_lookup(HeadRef, RepoHandle, PChar('HEAD'));
      if RC = GIT_OK then
      begin
        SymTargetP := git_reference_symbolic_target(HeadRef);
        if SymTargetP <> nil then
        begin
          LocalRef := string(SymTargetP);
          RemoteRef := LocalRef;
        end;
      end;

      if (LocalRef = '') or (RemoteRef = '') then
      begin
        AError := 'libgit2 push requires a branch (detached HEAD?)';
        ANeedsFallback := True;
        Exit(False);
      end;
    end
    else if Pos('refs/', BranchParam) = 1 then
    begin
      LocalRef := BranchParam;
      RemoteRef := BranchParam;
    end
    else
    begin
      LocalRef := 'refs/heads/' + BranchParam;
      RemoteRef := 'refs/heads/' + BranchParam;
    end;

    RefSpecStr := AnsiString(LocalRef + ':' + RemoteRef);
    RefSpecPtrs[0] := PChar(RefSpecStr);
    RefSpecs.strings := @RefSpecPtrs[0];
    RefSpecs.count := 1;

    if not TryInitGitPushTransportOptions(PushOpts, CredPayload, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_remote_push(RemoteHandle, @RefSpecs, @PushOpts);
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 push failed: ' + LErr
      else
        AError := 'libgit2 push failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    Result := True;
  finally
    if HeadRef <> nil then
      git_reference_free(HeadRef);
    if RemoteHandle <> nil then
      git_remote_free(RemoteHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
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
var
  LResult: TProcessResult;
begin
  Result := '';
  FLastError := '';

  if (FBackend = gbLibgit2) and (FGitManager <> nil) then
  begin
    try
      Result := FGitManager.Version;
      Exit;
    except
      // Fall back to command-line
    end;
  end;

  if not CommandLineGitAvailable then
  begin
    FLastError := 'No command-line git available';
    Exit('');
  end;

  LResult := ExecuteGitCli(['--version'], '');
  if LResult.Success then
    Result := Trim(LResult.StdOut)
  else if LResult.StdErr <> '' then
    FLastError := Trim(LResult.StdErr)
  else if LResult.ErrorMessage <> '' then
    FLastError := Trim(LResult.ErrorMessage)
  else
    FLastError := 'git --version failed (exit code ' + IntToStr(LResult.ExitCode) + ')';
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

// ============================================================================
// libgit2 backend instance methods
// ============================================================================

function TGitOperations.CloneWithLibgit2(const AURL, ALocalPath: string; out AError: string): Boolean;
var
  RepoHandle: git_repository;
  CloneOpts: git_clone_options;
  CredPayload: TGitTransportCredentialPayload;
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';

  if FGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  RepoHandle := nil;
  try
    try
      if not TryInitGitCloneTransportOptions(CloneOpts, CredPayload, AError) then
        Exit(False);

      RC := git_clone(RepoHandle, PChar(AURL), PChar(ALocalPath), @CloneOpts);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 clone failed: ' + LErr
        else
          AError := 'libgit2 clone failed';
        Exit(False);
      end;

      Result := True;
    except
      on E: Exception do
      begin
        AError := 'libgit2 clone exception: ' + E.Message;
        Result := False;
      end;
    end;
  finally
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function TGitOperations.FetchWithLibgit2(const ARepoPath, ARemote: string; out AError: string): Boolean;
var
  RepoHandle: git_repository;
  RemoteHandle: git_remote;
  FetchOpts: git_fetch_options;
  CredPayload: TGitTransportCredentialPayload;
  RemoteName: string;
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';

  if FGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  RemoteName := Trim(ARemote);
  if RemoteName = '' then
    RemoteName := 'origin';

  RepoHandle := nil;
  RemoteHandle := nil;
  try
    try
      RC := git_repository_open(RepoHandle, PChar(ARepoPath));
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 open repository failed: ' + LErr
        else
          AError := 'libgit2 open repository failed';
        Exit(False);
      end;

      RC := git_remote_lookup(RemoteHandle, RepoHandle, PChar(RemoteName));
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 remote lookup failed: ' + LErr
        else
          AError := 'libgit2 remote lookup failed';
        Exit(False);
      end;

      if not TryInitGitFetchTransportOptions(FetchOpts, CredPayload, AError) then
        Exit(False);

      RC := git_remote_fetch(RemoteHandle, nil, @FetchOpts, nil);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 fetch failed: ' + LErr
        else
          AError := 'libgit2 fetch failed';
        Exit(False);
      end;

      Result := True;
    except
      on E: Exception do
      begin
        AError := 'libgit2 fetch exception: ' + E.Message;
        Result := False;
      end;
    end;
  finally
    if RemoteHandle <> nil then
      git_remote_free(RemoteHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function TGitOperations.PullWithLibgit2(const ARepoPath: string; out AError: string;
  out ANeedsFallback: Boolean; const AAllowMerge: Boolean): Boolean;
var
  Repo: IGitRepository;
  Branch: string;
  RepoHandle: git_repository;
  RemoteHandle: git_remote;
  FetchOpts: git_fetch_options;
  CheckoutOpts: git_checkout_options;
  CredPayload: TGitTransportCredentialPayload;
  LocalRef: git_reference;
  RemoteRef: git_reference;
  UpdatedRef: git_reference;
  LocalRefName: string;
  RemoteRefName: string;
  Ahead: csize_t;
  Behind: csize_t;
  RemoteOid: Pgit_oid;
  RepoIndex: git_index;
  TargetCommit: git_commit;
  TargetTree: git_tree;
  OurCommit: git_commit;
  TheirCommit: git_commit;
  MergeIndex: git_index;
  MergeTree: git_tree;
  MergeTreeOid: git_oid;
  MergeCommitOid: git_oid;
  Parents: array[0..1] of git_commit;
  ParentsPtr: Pointer;
  ParentCount: csize_t;
  AuthorSig: git_signature;
  CommitterSig: git_signature;
  Identity: TGitOperationIdentity;
  MergeMessage: string;
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  if FGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    ANeedsFallback := True;
    Exit;
  end;

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if Repo = nil then
    begin
      AError := 'libgit2 could not open repository: ' + ARepoPath;
      ANeedsFallback := True;
      Exit;
    end;

    if Repo.HasUncommittedChanges then
    begin
      AError := 'Working tree has local changes';
      ANeedsFallback := True;
      Exit(False);
    end;

    Branch := Repo.CurrentBranch;
    if (Trim(Branch) = '') or SameText(Branch, 'HEAD') then
    begin
      AError := 'Detached HEAD';
      ANeedsFallback := True;
      Exit(False);
    end;
  except
    on E: Exception do
    begin
      AError := 'libgit2 pull exception: ' + E.Message;
      ANeedsFallback := True;
      Result := False;
      Exit;
    end;
  end;

  RepoHandle := nil;
  RemoteHandle := nil;
  LocalRef := nil;
  RemoteRef := nil;
  UpdatedRef := nil;
  RepoIndex := nil;
  TargetCommit := nil;
  TargetTree := nil;
  OurCommit := nil;
  TheirCommit := nil;
  MergeIndex := nil;
  MergeTree := nil;
  AuthorSig := nil;
  CommitterSig := nil;
  try
    RC := git_repository_open(RepoHandle, PChar(ARepoPath));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 open repository failed: ' + LErr
      else
        AError := 'libgit2 open repository failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_remote_lookup(RemoteHandle, RepoHandle, PChar('origin'));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'No remote configured: ' + LErr
      else
        AError := 'No remote configured';
      ANeedsFallback := False;
      Exit(False);
    end;

    if not TryInitGitFetchTransportOptions(FetchOpts, CredPayload, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_remote_fetch(RemoteHandle, nil, @FetchOpts, nil);
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 fetch failed: ' + LErr
      else
        AError := 'libgit2 fetch failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    LocalRefName := 'refs/heads/' + Branch;
    RemoteRefName := 'refs/remotes/origin/' + Branch;

    RC := git_reference_lookup(LocalRef, RepoHandle, PChar(LocalRefName));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 lookup local branch failed: ' + LErr
      else
        AError := 'libgit2 lookup local branch failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_reference_lookup(RemoteRef, RepoHandle, PChar(RemoteRefName));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 lookup remote branch failed: ' + LErr
      else
        AError := 'libgit2 lookup remote branch failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    Ahead := 0;
    Behind := 0;
    RemoteOid := git_reference_target(RemoteRef);
    if RemoteOid = nil then
    begin
      AError := 'libgit2 remote OID is empty';
      ANeedsFallback := True;
      Exit(False);
    end;
    RC := git_graph_ahead_behind(Ahead, Behind, RepoHandle, git_reference_target(LocalRef), RemoteOid);
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 ahead/behind failed: ' + LErr
      else
        AError := 'libgit2 ahead/behind failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    if (Ahead = 0) and (Behind = 0) then
      Exit(True);

    if (Ahead = 0) and (Behind > 0) then
    begin
      UpdatedRef := nil;
      RC := git_reference_set_target(UpdatedRef, LocalRef, RemoteOid, PChar('fpdev fast-forward'));
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 fast-forward failed: ' + LErr
        else
          AError := 'libgit2 fast-forward failed';
        ANeedsFallback := True;
        Exit(False);
      end;

      if UpdatedRef <> nil then
        git_reference_free(UpdatedRef);

      TargetCommit := nil;
      RC := git_commit_lookup(TargetCommit, RepoHandle, RemoteOid);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 lookup target commit failed: ' + LErr
        else
          AError := 'libgit2 lookup target commit failed';
        ANeedsFallback := True;
        Exit(False);
      end;

      TargetTree := nil;
      RC := git_commit_tree(TargetTree, TargetCommit);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 lookup target tree failed: ' + LErr
        else
          AError := 'libgit2 lookup target tree failed';
        ANeedsFallback := True;
        Exit(False);
      end;

      RepoIndex := nil;
      RC := git_repository_index(RepoIndex, RepoHandle);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 open index failed: ' + LErr
        else
          AError := 'libgit2 open index failed';
        ANeedsFallback := True;
        Exit(False);
      end;

      RC := git_index_read_tree(RepoIndex, TargetTree);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 update index failed: ' + LErr
        else
          AError := 'libgit2 update index failed';
        ANeedsFallback := True;
        Exit(False);
      end;

      RC := git_index_write(RepoIndex);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 write index failed: ' + LErr
        else
          AError := 'libgit2 write index failed';
        ANeedsFallback := True;
        Exit(False);
      end;

      CheckoutOpts := Default(git_checkout_options);
      RC := git_checkout_options_init(@CheckoutOpts, GIT_CHECKOUT_OPTIONS_VERSION);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 checkout options init failed: ' + LErr
        else
          AError := 'libgit2 checkout options init failed';
        ANeedsFallback := True;
        Exit(False);
      end;

      // The worktree was verified clean before we rewrote the branch/index.
      // Force checkout is required here so tracked files changed upstream are
      // refreshed on disk instead of being preserved as false local edits.
      // After the ref/index move, remote deletions look like untracked files,
      // so remove them as part of the fast-forward checkout as well.
      CheckoutOpts.checkout_strategy :=
        GIT_CHECKOUT_FORCE or
        GIT_CHECKOUT_RECREATE_MISSING or
        GIT_CHECKOUT_REMOVE_UNTRACKED;
      RC := git_checkout_head(RepoHandle, @CheckoutOpts);
      if RC <> GIT_OK then
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          AError := 'libgit2 checkout failed: ' + LErr
        else
          AError := 'libgit2 checkout failed';
        ANeedsFallback := True;
        Exit(False);
      end;

      Exit(True);
    end;

    // Local is ahead only: nothing to merge, already up-to-date with remote.
    if (Ahead > 0) and (Behind = 0) then
      Exit(True);

    if not AAllowMerge then
    begin
      AError := 'Non-fast-forward update requires merge/rebase';
      ANeedsFallback := True;
      Exit(False);
    end;

    // Diverged: attempt a non-conflicting merge commit via libgit2.
    if (Ahead > 0) and (Behind > 0) then
    begin
      try
        if not TryResolveGitOperationIdentity(RepoHandle, ARepoPath, True, Identity) then
        begin
          AError := 'Git identity not configured (user.name/user.email)';
          ANeedsFallback := True;
          Exit(False);
        end;

        if not TryCreateGitOperationSignatures(Identity, AuthorSig, CommitterSig, AError) then
        begin
          ANeedsFallback := True;
          Exit(False);
        end;

        RC := git_commit_lookup(OurCommit, RepoHandle, git_reference_target(LocalRef));
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 lookup HEAD commit failed: ' + LErr
          else
            AError := 'libgit2 lookup HEAD commit failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        RC := git_commit_lookup(TheirCommit, RepoHandle, RemoteOid);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 lookup remote commit failed: ' + LErr
          else
            AError := 'libgit2 lookup remote commit failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        MergeIndex := nil;
        RC := git_merge_commits(MergeIndex, RepoHandle, OurCommit, TheirCommit, nil);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 merge commits failed: ' + LErr
          else
            AError := 'libgit2 merge commits failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        if (MergeIndex <> nil) and (git_index_has_conflicts(MergeIndex) <> 0) then
        begin
          AError := 'Merge has conflicts; manual resolution required';
          ANeedsFallback := False;
          Exit(False);
        end;

        MergeTreeOid := Default(git_oid);
        RC := git_index_write_tree_to(MergeTreeOid, MergeIndex, RepoHandle);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 write merge tree failed: ' + LErr
          else
            AError := 'libgit2 write merge tree failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        MergeTree := nil;
        RC := git_tree_lookup(MergeTree, RepoHandle, @MergeTreeOid);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 merge tree lookup failed: ' + LErr
          else
            AError := 'libgit2 merge tree lookup failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        Parents[0] := OurCommit;
        Parents[1] := TheirCommit;
        ParentCount := 2;
        ParentsPtr := @Parents[0];

        MergeMessage := 'Merge origin/' + Branch + ' into ' + Branch;
        MergeCommitOid := Default(git_oid);
        RC := git_commit_create(MergeCommitOid, RepoHandle, PChar(LocalRefName),
          AuthorSig, CommitterSig, nil, PChar(MergeMessage),
          MergeTree, ParentCount, ParentsPtr);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 merge commit failed: ' + LErr
          else
            AError := 'libgit2 merge commit failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        RepoIndex := nil;
        RC := git_repository_index(RepoIndex, RepoHandle);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 open index failed: ' + LErr
          else
            AError := 'libgit2 open index failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        RC := git_index_read_tree(RepoIndex, MergeTree);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 update index failed: ' + LErr
          else
            AError := 'libgit2 update index failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        RC := git_index_write(RepoIndex);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 write index failed: ' + LErr
          else
            AError := 'libgit2 write index failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        FillChar(CheckoutOpts, SizeOf(CheckoutOpts), 0);
        RC := git_checkout_options_init(@CheckoutOpts, GIT_CHECKOUT_OPTIONS_VERSION);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 checkout options init failed: ' + LErr
          else
            AError := 'libgit2 checkout options init failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        CheckoutOpts.checkout_strategy := GIT_CHECKOUT_SAFE or GIT_CHECKOUT_RECREATE_MISSING;
        RC := git_checkout_head(RepoHandle, @CheckoutOpts);
        if RC <> GIT_OK then
        begin
          LErr := Libgit2LastErrorText;
          if LErr <> '' then
            AError := 'libgit2 checkout after merge failed: ' + LErr
          else
            AError := 'libgit2 checkout after merge failed';
          ANeedsFallback := True;
          Exit(False);
        end;

        Exit(True);
      finally
        if RepoIndex <> nil then
        begin
          git_index_free(RepoIndex);
          RepoIndex := nil;
        end;
        if CommitterSig <> nil then
        begin
          git_signature_free(CommitterSig);
          CommitterSig := nil;
        end;
        if AuthorSig <> nil then
        begin
          git_signature_free(AuthorSig);
          AuthorSig := nil;
        end;
        if MergeTree <> nil then
        begin
          git_object_free(git_object(MergeTree));
          MergeTree := nil;
        end;
        if MergeIndex <> nil then
        begin
          git_index_free(MergeIndex);
          MergeIndex := nil;
        end;
        if TheirCommit <> nil then
        begin
          git_object_free(git_object(TheirCommit));
          TheirCommit := nil;
        end;
        if OurCommit <> nil then
        begin
          git_object_free(git_object(OurCommit));
          OurCommit := nil;
        end;
      end;
    end;

    // Not reachable with the current ahead/behind logic, but keep a safe fallback.
    AError := 'Non-fast-forward update requires merge/rebase';
    ANeedsFallback := True;
    Result := False;
  finally
    if RepoIndex <> nil then
      git_index_free(RepoIndex);
    if TargetTree <> nil then
      git_object_free(git_object(TargetTree));
    if TargetCommit <> nil then
      git_object_free(git_object(TargetCommit));
    if CommitterSig <> nil then
      git_signature_free(CommitterSig);
    if AuthorSig <> nil then
      git_signature_free(AuthorSig);
    if MergeTree <> nil then
      git_object_free(git_object(MergeTree));
    if MergeIndex <> nil then
      git_index_free(MergeIndex);
    if TheirCommit <> nil then
      git_object_free(git_object(TheirCommit));
    if OurCommit <> nil then
      git_object_free(git_object(OurCommit));
    if RemoteRef <> nil then
      git_reference_free(RemoteRef);
    if LocalRef <> nil then
      git_reference_free(LocalRef);
    if RemoteHandle <> nil then
      git_remote_free(RemoteHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function TGitOperations.CheckoutWithLibgit2(
  const ARepoPath, AName: string;
  const Force: Boolean;
  out AError: string
): Boolean;
var
  Repo: IGitRepository;

  function CandidateRefs: TStringArray;
  begin
    Result := nil;
    if Pos('refs/', AName) = 1 then
    begin
      SetLength(Result, 1);
      Result[0] := AName;
      Exit;
    end;

    SetLength(Result, 3);
    Result[0] := 'refs/heads/' + AName;
    Result[1] := 'refs/tags/' + AName;
    Result[2] := 'refs/remotes/origin/' + AName;
  end;

begin
  Result := False;
  AError := '';

  if FGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if Repo = nil then
    begin
      AError := 'libgit2 could not open repository: ' + ARepoPath;
      Exit;
    end;

    if Pos('refs/', AName) = 1 then
    begin
      Result := Repo.CheckoutBranchEx(AName, Force);
      if not Result then
        AError := 'libgit2 checkout failed: ' + AName;
      Exit;
    end;

    if Repo.CheckoutBranchEx(AName, Force) then
      Exit(True);

    if Repo.CheckoutBranchEx('refs/remotes/origin/' + AName, Force) then
      Exit(True);

    if Repo.CheckoutBranchEx('refs/tags/' + AName, Force) then
      Exit(True);

    AError := 'libgit2 checkout failed: ' + AName;
    Result := False;
  except
    on E: Exception do
    begin
      AError := 'libgit2 checkout exception: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TGitOperations.TryHasRemoteWithLibgit2(const ARepoPath: string;
  out AHasRemote: Boolean): Boolean;
var
  Repo: IGitRepository;
  Ext: IGitRepositoryExt;
  Remotes: TStringArray;
begin
  Result := False;
  AHasRemote := False;

  if FGitManager = nil then
    Exit(False);

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if (Repo <> nil) and Supports(Repo, IGitRepositoryExt, Ext) then
    begin
      Remotes := Ext.ListRemotes;
      AHasRemote := Length(Remotes) > 0;
      Exit(True);
    end;
  except
    AHasRemote := False;
  end;
end;

function TGitOperations.TryGetRemoteURLWithLibgit2(const ARepoPath, ARemote: string;
  out AURL: string): Boolean;
var
  Repo: IGitRepository;
  Remote: IGitRemote;
begin
  Result := False;
  AURL := '';

  if FGitManager = nil then
    Exit(False);

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      Remote := Repo.Remote(ARemote);
      if Remote <> nil then
      begin
        AURL := Trim(Remote.URL);
        Exit(True);
      end;
    end;
  except
    AURL := '';
  end;
end;

function TGitOperations.TryGetCurrentBranchWithLibgit2(const ARepoPath: string;
  out ABranch: string): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  ABranch := '';

  if FGitManager = nil then
    Exit(False);

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      ABranch := Repo.CurrentBranch;
      Exit(True);
    end;
  except
    ABranch := '';
  end;
end;

function TGitOperations.TryGetShortHeadHashWithLibgit2(const ARepoPath: string;
  out AFullHash: string): Boolean;
var
  Repo: IGitRepository;
  HeadCommit: IGitCommit;
begin
  Result := False;
  AFullHash := '';

  if FGitManager = nil then
    Exit(False);

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      HeadCommit := Repo.HeadCommit;
      if HeadCommit <> nil then
      begin
        AFullHash := HeadCommit.OIDString;
        Exit(AFullHash <> '');
      end;
    end;
  except
    AFullHash := '';
  end;
end;

function TGitOperations.TryListBranchesWithLibgit2(const ARepoPath: string;
  out ARefs: TStringArray): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  ARefs := nil;

  if FGitManager = nil then
    Exit(False);

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      ARefs := Repo.ListBranches(gbAll);
      Exit(True);
    end;
  except
    ARefs := nil;
  end;
end;

function TGitOperations.TryListRemoteBranchesWithLibgit2(
  const ARepoPath, ARemote: string; out ARefs: TStringArray): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  ARefs := nil;
  if ARemote = '' then
    Exit(False);

  if FGitManager = nil then
    Exit(False);

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      ARefs := Repo.ListBranches(gbRemote);
      Exit(True);
    end;
  except
    ARefs := nil;
  end;
end;

// Standalone function for IsRepository (creates temporary manager)
function IsRepositoryWithLibgit2(const APath: string): Boolean;
var
  Mgr: IGitManager;
begin
  Result := False;

  try
    // Create GitManager instance
    Mgr := NewGitManager();
    if not Mgr.Initialize then
      Exit;

    Result := Mgr.IsRepository(APath);
  except
    on E: Exception do
    begin
      // Silent failure - return false
      Result := False;
    end;
  end;
end;

end.
