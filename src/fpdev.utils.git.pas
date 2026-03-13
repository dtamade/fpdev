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

    property Backend: TGitBackend read FBackend;
    property LastError: string read FLastError;
    property Verbose: Boolean read FVerbose write FVerbose;
  end;

// Helper function to get backend name
function GitBackendToString(ABackend: TGitBackend): string;

implementation

uses
  fpdev.utils.process, git2.impl;

var
  Libgit2Available: Boolean = False;
  Libgit2Checked: Boolean = False;

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
  Commit: IGitCommit;
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
        Commit := Repo.HeadCommit;
        if Commit <> nil then
        begin
          FullHash := Commit.OIDString;
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
