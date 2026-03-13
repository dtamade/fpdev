unit fpdev.utils.git;

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
  SysUtils, Classes, git2.api, git2.types;

type
  TGitBackend = (gbLibgit2, gbCommandLine, gbNone);

  { TGitOperations - Unified Git operations with libgit2 + CLI fallback }
  TGitOperations = class
  private
    FBackend: TGitBackend;
    FLastError: string;
    FVerbose: Boolean;
    FGitManager: IGitManager;
    FCommandLineChecked: Boolean;
    FCommandLineAvailable: Boolean;

    function TryInitLibgit2: Boolean;
    function CommandLineGitAvailable: Boolean;
    function ExecuteGitCommand(const AParams: array of string; const AWorkDir: string = ''): Boolean;

    // libgit2 backend functions (use instance FGitManager)
    function CloneWithLibgit2(const AURL, ALocalPath: string; out AError: string): Boolean;
    function FetchWithLibgit2(const ARepoPath, ARemote: string; out AError: string): Boolean;
    function PullWithLibgit2(const ARepoPath: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
    function GetBranchWithLibgit2(const ARepoPath: string): string;
    function CheckoutWithLibgit2(const ARepoPath, AName: string; const Force: Boolean; out AError: string): Boolean;
    function AddAllWithLibgit2(const ARepoPath: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
    function CommitWithLibgit2(const ARepoPath, AMessage: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
    function PushWithLibgit2(const ARepoPath, ARemote, ABranch: string; out AError: string; out ANeedsFallback: Boolean): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    // Core operations
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function GetCurrentBranch(const ARepoPath: string): string;
    function GetShortHeadHash(const ARepoPath: string; const ALength: Integer = 7): string;
    function Add(const ARepoPath, APathSpec: string): Boolean;
    function Commit(const ARepoPath, AMessage: string): Boolean;
    function Push(const ARepoPath: string; const ARemote: string = 'origin'; const ABranch: string = ''): Boolean;
    function GetVersion: string;
    function ListRemoteBranches(const ARepoPath: string; const ARemote: string = 'origin'): TStringArray;

    property Backend: TGitBackend read FBackend;
    property LastError: string read FLastError;
    property Verbose: Boolean read FVerbose write FVerbose;
  end;

// Helper function to get backend name
function GitBackendToString(ABackend: TGitBackend): string;

implementation

uses
  fpdev.utils.process, git2.impl, libgit2, ctypes;

var
  Libgit2Available: Boolean = False;
  Libgit2Checked: Boolean = False;

type
  PGitAddAllStatusPayload = ^TGitAddAllStatusPayload;
  TGitAddAllStatusPayload = record
    Paths: TStringList;
    NeedsFallback: Boolean;
    HadError: Boolean;
    ErrorText: string;
  end;

// Forward declaration for standalone function
function IsRepositoryWithLibgit2(const APath: string): Boolean; forward;

function GitBackendToString(ABackend: TGitBackend): string;
begin
  case ABackend of
    gbLibgit2: Result := 'libgit2';
    gbCommandLine: Result := 'git (command-line)';
    gbNone: Result := 'none';
  end;
end;

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
  LPath: string;
begin
  Result := 0;
  P := PGitAddAllStatusPayload(APayload);
  if (P = nil) or (P^.Paths = nil) then
    Exit(0);
  if P^.HadError then
    Exit(-1);

  try
    if (AFlags and GIT_STATUS_IGNORED) <> 0 then
      Exit(0);

    UnsupportedMask :=
      GIT_STATUS_WT_DELETED or GIT_STATUS_INDEX_DELETED or
      GIT_STATUS_WT_RENAMED or GIT_STATUS_INDEX_RENAMED or
      GIT_STATUS_WT_TYPECHANGE or GIT_STATUS_INDEX_TYPECHANGE or
      GIT_STATUS_CONFLICTED or GIT_STATUS_WT_UNREADABLE;

    if (AFlags and UnsupportedMask) <> 0 then
    begin
      P^.NeedsFallback := True;
      Exit(0);
    end;

    if (AFlags <> GIT_STATUS_CURRENT) and (APath <> nil) then
    begin
      LPath := string(APath);
      if Trim(LPath) <> '' then
        P^.Paths.Add(LPath);
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

{ TGitOperations }

constructor TGitOperations.Create;
begin
  inherited Create;
  FLastError := '';
  FVerbose := False;
  FGitManager := nil;
  FCommandLineChecked := False;
  FCommandLineAvailable := False;

  // Try to use libgit2 first
  if TryInitLibgit2 then
    FBackend := gbLibgit2
  else
  begin
    // Check if command-line git is available
    FCommandLineChecked := True;
    FCommandLineAvailable := TProcessExecutor.Run('git', ['--version'], '');
    if FCommandLineAvailable then
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
begin
  if not FCommandLineChecked then
  begin
    FCommandLineChecked := True;
    FCommandLineAvailable := TProcessExecutor.Run('git', ['--version'], '');
  end;
  Result := FCommandLineAvailable;
end;

function TGitOperations.ExecuteGitCommand(const AParams: array of string; const AWorkDir: string): Boolean;
var
  LResult: TProcessResult;
begin
  LResult := TProcessExecutor.Execute('git', AParams, AWorkDir);
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

function TGitOperations.Clone(const AURL, ALocalPath: string; const ABranch: string): Boolean;
begin
  Result := False;
  FLastError := '';

  if FBackend = gbNone then
  begin
    FLastError := 'No Git backend available (neither libgit2 nor git command found)';
    Exit;
  end;

  // Try libgit2 first
  if FBackend = gbLibgit2 then
  begin
    try
      Result := CloneWithLibgit2(AURL, ALocalPath, FLastError);
      if Result then
      begin
        if ABranch <> '' then
          Result := Checkout(ALocalPath, ABranch, False);
        Exit(Result);
      end;

      // Fallback to command-line on libgit2 failure
      if FVerbose then
        WriteLn('libgit2 clone failed, falling back to git command-line');
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('libgit2 exception: ', E.Message, ', falling back to git command-line');
      end;
    end;
  end;

  // Command-line fallback
  if not CommandLineGitAvailable then
  begin
    if FLastError = '' then
      FLastError := 'No command-line git available';
    Exit(False);
  end;

  // Clear libgit2 error details on successful fallback path.
  FLastError := '';

  if ABranch <> '' then
    Result := ExecuteGitCommand(['clone', '--depth', '1', '--branch', ABranch, AURL, ALocalPath], '')
  else
    Result := ExecuteGitCommand(['clone', '--depth', '1', AURL, ALocalPath], '');
end;

function TGitOperations.Fetch(const ARepoPath: string; const ARemote: string): Boolean;
begin
  Result := False;
  FLastError := '';

  if FBackend = gbNone then
  begin
    FLastError := 'No Git backend available';
    Exit;
  end;

  // Try libgit2 first
  if FBackend = gbLibgit2 then
  begin
    try
      Result := FetchWithLibgit2(ARepoPath, ARemote, FLastError);
      if Result then Exit;
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('libgit2 fetch exception: ', E.Message, ', falling back to git command-line');
      end;
    end;
  end;

  // Command-line fallback
  if not CommandLineGitAvailable then
  begin
    FLastError := 'No command-line git available';
    Exit(False);
  end;
  FLastError := '';
  Result := ExecuteGitCommand(['fetch', ARemote], ARepoPath);
end;

function TGitOperations.Pull(const ARepoPath: string): Boolean;
var
  NeedsFallback: Boolean;
begin
  Result := False;
  FLastError := '';

  if FBackend = gbNone then
  begin
    FLastError := 'No Git backend available';
    Exit;
  end;

  // Try libgit2 fast-forward pull first. If a merge/rebase is required, fall back to CLI.
  if FBackend = gbLibgit2 then
  begin
    try
      NeedsFallback := False;
      Result := PullWithLibgit2(ARepoPath, FLastError, NeedsFallback);
      if Result then Exit;

      if (not NeedsFallback) then
        Exit(False);

      if not CommandLineGitAvailable then
      begin
        if FLastError = '' then
          FLastError := 'Non-fast-forward update requires command-line git; please install git';
        Exit(False);
      end;
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('libgit2 pull exception: ', E.Message, ', falling back to git command-line');
      end;
    end;
  end;

  if not CommandLineGitAvailable then
  begin
    FLastError := 'No command-line git available';
    Exit(False);
  end;

  FLastError := '';
  Result := ExecuteGitCommand(['pull'], ARepoPath);
end;

function TGitOperations.Checkout(const ARepoPath, AName: string; const Force: Boolean): Boolean;
var
  LError: string;
begin
  Result := False;
  FLastError := '';

  if Trim(AName) = '' then
    Exit(True);

  if FBackend = gbNone then
  begin
    FLastError := 'No Git backend available';
    Exit(False);
  end;

  if FBackend = gbLibgit2 then
  begin
    try
      LError := '';
      Result := CheckoutWithLibgit2(ARepoPath, AName, Force, LError);
      if Result then
        Exit(True);
      if LError <> '' then
        FLastError := LError;
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('libgit2 checkout exception: ', E.Message, ', falling back to git command-line');
      end;
    end;
  end;

  if not CommandLineGitAvailable then
  begin
    if FLastError = '' then
      FLastError := 'No command-line git available';
    Exit(False);
  end;

  FLastError := '';
  if Force then
    Result := ExecuteGitCommand(['checkout', '-f', AName], ARepoPath)
  else
    Result := ExecuteGitCommand(['checkout', AName], ARepoPath);
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
var
  Repo: IGitRepository;
  Ext: IGitRepositoryExt;
  Remotes: TStringArray;
  LResult: TProcessResult;
begin
  Result := False;

  if (FBackend = gbLibgit2) and (FGitManager <> nil) then
  begin
    try
      Repo := FGitManager.OpenRepository(ARepoPath);
      if (Repo <> nil) and Supports(Repo, IGitRepositoryExt, Ext) then
      begin
        Remotes := Ext.ListRemotes;
        Result := Length(Remotes) > 0;
        Exit;
      end;
    except
      // Fall back to command-line when libgit2 query fails.
    end;
  end;

  if not CommandLineGitAvailable then
    Exit(False);

  LResult := TProcessExecutor.Execute('git', ['remote'], ARepoPath);
  if LResult.Success then
    Result := Trim(LResult.StdOut) <> '';
end;

function TGitOperations.GetCurrentBranch(const ARepoPath: string): string;
var
  LResult: TProcessResult;
begin
  Result := '';

  // Try libgit2 first
  if FBackend = gbLibgit2 then
  begin
    try
      Result := GetBranchWithLibgit2(ARepoPath);
      if Result <> '' then Exit;
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('libgit2 get branch exception: ', E.Message, ', falling back to command-line');
      end;
    end;
  end;

  // Command-line fallback
  if not CommandLineGitAvailable then
    Exit('');
  LResult := TProcessExecutor.Execute('git', ['rev-parse', '--abbrev-ref', 'HEAD'], ARepoPath);
  if LResult.Success then
    Result := Trim(LResult.StdOut);
end;

function TGitOperations.GetShortHeadHash(const ARepoPath: string; const ALength: Integer): string;
var
  Repo: IGitRepository;
  HeadCommit: IGitCommit;
  FullHash: string;
  LLen: Integer;
  LResult: TProcessResult;
begin
  Result := '';
  FLastError := '';
  if ALength <= 0 then
    Exit;

  if (FBackend = gbLibgit2) and (FGitManager <> nil) then
  begin
    try
      Repo := FGitManager.OpenRepository(ARepoPath);
      if Repo <> nil then
      begin
        HeadCommit := Repo.HeadCommit;
        if HeadCommit <> nil then
        begin
          FullHash := HeadCommit.OIDString;
          LLen := ALength;
          if LLen > Length(FullHash) then
            LLen := Length(FullHash);
          Result := Copy(FullHash, 1, LLen);
          Exit;
        end;
      end;
    except
      // Fall back to command-line
    end;
  end;

  if not CommandLineGitAvailable then
  begin
    FLastError := 'No command-line git available';
    Exit('');
  end;

  if ALength >= 40 then
    LResult := TProcessExecutor.Execute('git', ['rev-parse', 'HEAD'], ARepoPath)
  else
    LResult := TProcessExecutor.Execute('git', ['rev-parse', '--short=' + IntToStr(ALength), 'HEAD'], ARepoPath);

  if LResult.Success then
    Result := Trim(LResult.StdOut)
  else if LResult.StdErr <> '' then
    FLastError := Trim(LResult.StdErr)
  else if LResult.ErrorMessage <> '' then
    FLastError := Trim(LResult.ErrorMessage)
  else
    FLastError := 'git rev-parse failed (exit code ' + IntToStr(LResult.ExitCode) + ')';
end;

function TGitOperations.AddAllWithLibgit2(const ARepoPath: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
var
  RepoHandle: git_repository;
  IndexHandle: git_index;
  Paths: TStringList;
  Payload: TGitAddAllStatusPayload;
  RC: cint;
  i: Integer;

begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  RepoHandle := nil;
  IndexHandle := nil;
  Paths := TStringList.Create;
  try
    Payload.Paths := Paths;
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

    if Paths.Count > 0 then
    begin
      for i := 0 to Paths.Count - 1 do
      begin
        RC := git_index_add_bypath(IndexHandle, PChar(Paths[i]));
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
    Paths.Free;
    if IndexHandle <> nil then
      git_index_free(IndexHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function TGitOperations.CommitWithLibgit2(const ARepoPath, AMessage: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
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
  UpdateRef: string;
  SymTargetP: PChar;
  TargetOID: Pgit_oid;
  RC: cint;
  LErr: string;

  function ConfigGetString(ACfg: git_config; const AKey: string): string;
  var
    P: PChar;
  begin
    Result := '';
    P := nil;
    if (ACfg <> nil) and (git_config_get_string(P, ACfg, PChar(AKey)) = GIT_OK) and (P <> nil) then
      Result := string(P);
  end;

  function TryLoadUserFromConfig(out AName, AEmail: string): Boolean;
  var
    Cfg: git_config;
  begin
    Result := False;
    AName := '';
    AEmail := '';

    Cfg := nil;
    if git_repository_config(Cfg, RepoHandle) = GIT_OK then
    begin
      try
        AName := Trim(ConfigGetString(Cfg, 'user.name'));
        AEmail := Trim(ConfigGetString(Cfg, 'user.email'));
        Result := (AName <> '') and (AEmail <> '');
      finally
        git_config_free(Cfg);
      end;
      if Result then
        Exit(True);
    end;

    Cfg := nil;
    if git_config_open_default(Cfg) = GIT_OK then
    begin
      try
        AName := Trim(ConfigGetString(Cfg, 'user.name'));
        AEmail := Trim(ConfigGetString(Cfg, 'user.email'));
        Result := (AName <> '') and (AEmail <> '');
      finally
        git_config_free(Cfg);
      end;
    end;
  end;

var
  AuthorName: string;
  AuthorEmail: string;
  CommitterName: string;
  CommitterEmail: string;
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

    AuthorName := '';
    AuthorEmail := '';
    if not TryLoadUserFromConfig(AuthorName, AuthorEmail) then
    begin
      AuthorName := Trim(GetEnvironmentVariable('GIT_AUTHOR_NAME'));
      AuthorEmail := Trim(GetEnvironmentVariable('GIT_AUTHOR_EMAIL'));
    end;

    CommitterName := Trim(GetEnvironmentVariable('GIT_COMMITTER_NAME'));
    CommitterEmail := Trim(GetEnvironmentVariable('GIT_COMMITTER_EMAIL'));
    if CommitterName = '' then
      CommitterName := AuthorName;
    if CommitterEmail = '' then
      CommitterEmail := AuthorEmail;

    if (AuthorName = '') or (AuthorEmail = '') or (CommitterName = '') or (CommitterEmail = '') then
    begin
      AError := 'Git identity not configured (user.name/user.email)';
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_signature_now(AuthorSig, PChar(AuthorName), PChar(AuthorEmail));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 signature creation failed: ' + LErr
      else
        AError := 'libgit2 signature creation failed';
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_signature_now(CommitterSig, PChar(CommitterName), PChar(CommitterEmail));
    if RC <> GIT_OK then
    begin
      LErr := Libgit2LastErrorText;
      if LErr <> '' then
        AError := 'libgit2 signature creation failed: ' + LErr
      else
        AError := 'libgit2 signature creation failed';
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

    FillChar(CommitOid, SizeOf(CommitOid), 0);
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

function TGitOperations.PushWithLibgit2(const ARepoPath, ARemote, ABranch: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
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

    RC := git_remote_push(RemoteHandle, @RefSpecs, nil);
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
var
  RepoHandle: git_repository;
  IndexHandle: git_index;
  WorkDirP: PChar;
  WorkDir: string;
  PathSpecAbs: string;
  WorkDirAbs: string;
  RelPath: string;
  RC: Integer;
  LErr: string;
  LNeedsFallback: Boolean;
  LPathSpec: string;
begin
  Result := False;
  FLastError := '';

  if FBackend = gbNone then
  begin
    FLastError := 'No Git backend available';
    Exit(False);
  end;

  if Trim(ARepoPath) = '' then
  begin
    FLastError := 'Repository path is empty';
    Exit(False);
  end;

  if Trim(APathSpec) = '' then
  begin
    FLastError := 'Pathspec is empty';
    Exit(False);
  end;

  LPathSpec := Trim(APathSpec);

  // Try libgit2 first for add-all ('.'). Fallback to CLI when deletions/renames/etc are present.
  if (LPathSpec = '.') and (FBackend = gbLibgit2) and (FGitManager <> nil) then
  begin
    LErr := '';
    LNeedsFallback := False;
    Result := AddAllWithLibgit2(ARepoPath, LErr, LNeedsFallback);
    if Result then
      Exit(True);
    if not LNeedsFallback then
    begin
      if LErr <> '' then
        FLastError := LErr
      else
        FLastError := 'libgit2 add-all failed';
      Exit(False);
    end;
    if LErr <> '' then
      FLastError := LErr;
  end;

  // Try libgit2 first for simple file path specs
  if (FBackend = gbLibgit2) and (FGitManager <> nil) and
     (Pos('*', APathSpec) = 0) and (Pos('?', APathSpec) = 0) and (LPathSpec <> '.') then
  begin
    RepoHandle := nil;
    IndexHandle := nil;
    try
      RC := git_repository_open(RepoHandle, PChar(ARepoPath));
      if RC = GIT_OK then
      begin
        WorkDir := '';
        WorkDirP := git_repository_workdir(RepoHandle);
        if WorkDirP <> nil then
          WorkDir := string(WorkDirP);

        RelPath := APathSpec;

        // Convert absolute file path to repo-relative when possible.
        // libgit2 uses '/' in index paths even on Windows.
        if (WorkDir <> '') then
        begin
          PathSpecAbs := ExpandFileName(APathSpec);
          WorkDirAbs := ExpandFileName(IncludeTrailingPathDelimiter(WorkDir));
          {$IFDEF MSWINDOWS}
          if (Pos(AnsiLowerCase(WorkDirAbs), AnsiLowerCase(PathSpecAbs)) = 1) then
          {$ELSE}
          if (Pos(WorkDirAbs, PathSpecAbs) = 1) then
          {$ENDIF}
            RelPath := Copy(PathSpecAbs, Length(WorkDirAbs) + 1, MaxInt);
        end;

        RelPath := StringReplace(RelPath, '\', '/', [rfReplaceAll]);

        RC := git_repository_index(IndexHandle, RepoHandle);
        if RC = GIT_OK then
        begin
          RC := git_index_add_bypath(IndexHandle, PChar(RelPath));
          if RC = GIT_OK then
          begin
            RC := git_index_write(IndexHandle);
            if RC = GIT_OK then
            begin
              Result := True;
              Exit;
            end;
          end;
        end;

        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          FLastError := 'libgit2 add failed: ' + LErr
        else
          FLastError := 'libgit2 add failed';
      end
      else
      begin
        LErr := Libgit2LastErrorText;
        if LErr <> '' then
          FLastError := 'libgit2 open repository failed: ' + LErr
        else
          FLastError := 'libgit2 open repository failed';
      end;
    finally
      if IndexHandle <> nil then
        git_index_free(IndexHandle);
      if RepoHandle <> nil then
        git_repository_free(RepoHandle);
    end;
  end;

  // Command-line fallback
  if not CommandLineGitAvailable then
  begin
    if FLastError = '' then
      FLastError := 'No command-line git available';
    Exit(False);
  end;

  FLastError := '';
  if LPathSpec = '.' then
    Result := ExecuteGitCommand(['add', '-A'], ARepoPath)
  else
    Result := ExecuteGitCommand(['add', APathSpec], ARepoPath);
end;

function TGitOperations.Commit(const ARepoPath, AMessage: string): Boolean;
var
  LErr: string;
  LNeedsFallback: Boolean;
begin
  Result := False;
  FLastError := '';

  if FBackend = gbNone then
  begin
    FLastError := 'No Git backend available';
    Exit(False);
  end;

  if Trim(ARepoPath) = '' then
  begin
    FLastError := 'Repository path is empty';
    Exit(False);
  end;

  if Trim(AMessage) = '' then
  begin
    FLastError := 'Commit message is empty';
    Exit(False);
  end;

  if (FBackend = gbLibgit2) and (FGitManager <> nil) then
  begin
    LErr := '';
    LNeedsFallback := False;
    Result := CommitWithLibgit2(ARepoPath, AMessage, LErr, LNeedsFallback);
    if Result then
      Exit(True);
    if not LNeedsFallback then
    begin
      if LErr <> '' then
        FLastError := LErr
      else
        FLastError := 'libgit2 commit failed';
      Exit(False);
    end;
    if LErr <> '' then
      FLastError := LErr;
  end;

  if not CommandLineGitAvailable then
  begin
    if FLastError = '' then
      FLastError := 'Command-line git is required for commit; please install git';
    Exit(False);
  end;

  FLastError := '';
  Result := ExecuteGitCommand(['commit', '-m', AMessage], ARepoPath);
end;

function TGitOperations.Push(const ARepoPath: string; const ARemote: string; const ABranch: string): Boolean;
var
  BranchParam: string;
  LErr: string;
  LNeedsFallback: Boolean;
begin
  Result := False;
  FLastError := '';

  if FBackend = gbNone then
  begin
    FLastError := 'No Git backend available';
    Exit(False);
  end;

  if Trim(ARepoPath) = '' then
  begin
    FLastError := 'Repository path is empty';
    Exit(False);
  end;

  BranchParam := ABranch;
  if Trim(BranchParam) = '' then
    BranchParam := GetCurrentBranch(ARepoPath);
  if Trim(BranchParam) = '' then
    BranchParam := 'HEAD';

  if (FBackend = gbLibgit2) and (FGitManager <> nil) then
  begin
    LErr := '';
    LNeedsFallback := False;
    Result := PushWithLibgit2(ARepoPath, ARemote, BranchParam, LErr, LNeedsFallback);
    if Result then
      Exit(True);
    if not LNeedsFallback then
    begin
      if LErr <> '' then
        FLastError := LErr
      else
        FLastError := 'libgit2 push failed';
      Exit(False);
    end;
    if LErr <> '' then
      FLastError := LErr;
  end;

  if not CommandLineGitAvailable then
  begin
    FLastError := 'Command-line git is required for push; please install git';
    Exit(False);
  end;

  Result := ExecuteGitCommand(['push', ARemote, BranchParam], ARepoPath);
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

  LResult := TProcessExecutor.Execute('git', ['--version'], '');
  if LResult.Success then
    Result := Trim(LResult.StdOut)
  else if LResult.StdErr <> '' then
    FLastError := Trim(LResult.StdErr)
  else if LResult.ErrorMessage <> '' then
    FLastError := Trim(LResult.ErrorMessage)
  else
    FLastError := 'git --version failed (exit code ' + IntToStr(LResult.ExitCode) + ')';
end;

function TGitOperations.ListRemoteBranches(const ARepoPath: string; const ARemote: string): TStringArray;
var
  Repo: IGitRepository;
  BranchRefs: TStringArray;
  Prefix: string;
  Line: string;
  i: Integer;
  List: TStringList;
  LResult: TProcessResult;
begin
  Result := nil;
  FLastError := '';

  if Trim(ARemote) = '' then
    Exit(nil);

  // Try libgit2 first
  if (FBackend = gbLibgit2) and (FGitManager <> nil) then
  begin
    try
      Repo := FGitManager.OpenRepository(ARepoPath);
      if Repo <> nil then
      begin
        BranchRefs := Repo.ListBranches(gbRemote);
        Prefix := 'refs/remotes/' + ARemote + '/';

        List := TStringList.Create;
        try
          for i := 0 to High(BranchRefs) do
          begin
            Line := Trim(BranchRefs[i]);
            if (Line = '') or (Pos(Prefix, Line) <> 1) then
              Continue;
            Line := Copy(Line, Length(Prefix) + 1, MaxInt);
            if (Line = '') or SameText(Line, 'HEAD') then
              Continue;
            List.Add(Line);
          end;

          SetLength(Result, List.Count);
          for i := 0 to List.Count - 1 do
            Result[i] := List[i];
          Exit;
        finally
          List.Free;
        end;
      end;
    except
      // Fall back to command-line
    end;
  end;

  // Command-line fallback
  if not CommandLineGitAvailable then
  begin
    FLastError := 'No command-line git available';
    Exit(nil);
  end;

  LResult := TProcessExecutor.Execute('git', ['branch', '-r'], ARepoPath);
  if not LResult.Success then
  begin
    if LResult.StdErr <> '' then
      FLastError := Trim(LResult.StdErr)
    else if LResult.ErrorMessage <> '' then
      FLastError := Trim(LResult.ErrorMessage)
    else
      FLastError := 'git branch -r failed (exit code ' + IntToStr(LResult.ExitCode) + ')';
    Exit(nil);
  end;

  List := TStringList.Create;
  try
    BranchRefs := LResult.StdOut.Split([#10, #13]);
    Prefix := ARemote + '/';
    for i := 0 to High(BranchRefs) do
    begin
      Line := Trim(BranchRefs[i]);
      if (Line = '') then
        Continue;
      if Pos('->', Line) > 0 then
        Continue;
      if Pos(Prefix, Line) <> 1 then
        Continue;
      Line := Copy(Line, Length(Prefix) + 1, MaxInt);
      if (Line = '') or SameText(Line, 'HEAD') then
        Continue;
      List.Add(Line);
    end;

    SetLength(Result, List.Count);
    for i := 0 to List.Count - 1 do
      Result[i] := List[i];
  finally
    List.Free;
  end;
end;

// ============================================================================
// libgit2 backend instance methods
// ============================================================================

function TGitOperations.CloneWithLibgit2(const AURL, ALocalPath: string; out AError: string): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  AError := '';

  if FGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  try
    // CloneRepository returns IGitRepository interface
    Repo := FGitManager.CloneRepository(AURL, ALocalPath);

    if Repo <> nil then
      Result := True
    else
      AError := 'libgit2 clone returned nil repository';
  except
    on E: Exception do
      AError := 'libgit2 clone exception: ' + E.Message;
  end;
end;

function TGitOperations.FetchWithLibgit2(const ARepoPath, ARemote: string; out AError: string): Boolean;
var
  Repo: IGitRepository;
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
    if Repo <> nil then
    begin
      Result := Repo.Fetch(ARemote);
      if not Result then
        AError := 'libgit2 fetch failed';
      // No manual Free needed - interface reference counting
    end
    else
      AError := 'libgit2 could not open repository: ' + ARepoPath;
  except
    on E: Exception do
      AError := 'libgit2 fetch exception: ' + E.Message;
  end;
end;

function TGitOperations.PullWithLibgit2(const ARepoPath: string; out AError: string; out ANeedsFallback: Boolean): Boolean;
var
  Repo: IGitRepository;
  Ext: IGitRepositoryExt;
  PullRes: TGitPullFastForwardResult;
  ErrText: string;
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

    if not Supports(Repo, IGitRepositoryExt, Ext) then
    begin
      AError := 'libgit2 repository extension not available';
      ANeedsFallback := True;
      Exit;
    end;

    ErrText := '';
    PullRes := Ext.PullFastForward('origin', ErrText);

    case PullRes of
      gpffUpToDate,
      gpffFastForwarded:
        Exit(True);
      gpffNoRemote:
        begin
          AError := ErrText;
          if AError = '' then
            AError := 'No remote configured';
          ANeedsFallback := False;
          Exit(False);
        end;
      gpffNeedsMerge:
        begin
          AError := ErrText;
          if AError = '' then
            AError := 'Non-fast-forward update requires merge/rebase';
          ANeedsFallback := True;
          Exit(False);
        end;
      gpffDetachedHead:
        begin
          AError := ErrText;
          if AError = '' then
            AError := 'Detached HEAD';
          ANeedsFallback := True;
          Exit(False);
        end;
      gpffDirty:
        begin
          AError := ErrText;
          if AError = '' then
            AError := 'Working tree has local changes';
          ANeedsFallback := True;
          Exit(False);
        end;
      gpffError:
        begin
          AError := ErrText;
          if AError = '' then
            AError := 'libgit2 pull failed';
          ANeedsFallback := True;
          Exit(False);
        end;
    end;
  except
    on E: Exception do
    begin
      AError := 'libgit2 pull exception: ' + E.Message;
      ANeedsFallback := True;
      Result := False;
    end;
  end;
end;

function TGitOperations.CheckoutWithLibgit2(const ARepoPath, AName: string; const Force: Boolean; out AError: string): Boolean;
var
  Repo: IGitRepository;
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

    if Repo.CheckoutBranchEx('refs/tags/' + AName, Force) then
      Exit(True);

    if Repo.CheckoutBranchEx('refs/remotes/origin/' + AName, Force) then
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

function TGitOperations.GetBranchWithLibgit2(const ARepoPath: string): string;
var
  Repo: IGitRepository;
begin
  Result := '';

  if FGitManager = nil then
    Exit;

  try
    Repo := FGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      Result := Repo.CurrentBranch;
      // No manual Free needed - interface reference counting
    end;
  except
    Result := '';
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
