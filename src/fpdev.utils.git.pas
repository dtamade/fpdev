unit fpdev.utils.git;

{$mode objfpc}{$H+}

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
  SysUtils, Classes;

type
  TGitBackend = (gbLibgit2, gbCommandLine, gbNone);

  { TGitOperations - Unified Git operations with libgit2 + CLI fallback }
  TGitOperations = class
  private
    FBackend: TGitBackend;
    FLastError: string;
    FVerbose: Boolean;

    function TryInitLibgit2: Boolean;
    function ExecuteGitCommand(const AParams: array of string; const AWorkDir: string = ''): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    // Core operations
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function GetCurrentBranch(const ARepoPath: string): string;

    property Backend: TGitBackend read FBackend;
    property LastError: string read FLastError;
    property Verbose: Boolean read FVerbose write FVerbose;
  end;

// Helper function to get backend name
function GitBackendToString(ABackend: TGitBackend): string;

implementation

uses
  fpdev.utils.process, fpdev.git2, git2.api, git2.impl;

var
  Libgit2Available: Boolean = False;
  Libgit2Checked: Boolean = False;
  
  { @deprecated Internal implementation detail. Use git2.api.pas + git2.impl.pas directly.
    This global singleton will be removed in Phase 2 Wave 4.
    
    Migration example:
      uses git2.api, git2.impl;
      var Mgr: IGitManager;
      Mgr := NewGitManager();
      Mgr.Initialize;
      // Use Mgr...
  }
  SharedGitManager: IGitManager = nil;

// Forward declarations for libgit2 backend functions
function CloneWithLibgit2(const AURL, ALocalPath, ABranch: string; out AError: string): Boolean; forward;
function FetchWithLibgit2(const ARepoPath, ARemote: string; out AError: string): Boolean; forward;
function IsRepositoryWithLibgit2(const APath: string): Boolean; forward;
function GetBranchWithLibgit2(const ARepoPath: string): string; forward;

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

  // Try to use libgit2 first
  if TryInitLibgit2 then
    FBackend := gbLibgit2
  else
  begin
    // Check if command-line git is available
    if TProcessExecutor.Run('git', ['--version'], '') then
      FBackend := gbCommandLine
    else
      FBackend := gbNone;
  end;
end;

destructor TGitOperations.Destroy;
begin
  // Cleanup libgit2 if we initialized it
  if FBackend = gbLibgit2 then
  begin
    try
      // Note: GitManager singleton handles shutdown
    except
      on E: Exception do
      begin
        if FVerbose then
          WriteLn('Error during Git cleanup: ', E.Message);
      end;
    end;
  end;
  inherited Destroy;
end;

function TGitOperations.TryInitLibgit2: Boolean;
begin
  // Only check once per process
  if not Libgit2Checked then
  begin
    Libgit2Checked := True;
    Libgit2Available := False;

    try
      // Create and initialize GitManager (using modern interface)
      if SharedGitManager = nil then
        SharedGitManager := NewGitManager();

      // Try to initialize libgit2
      if SharedGitManager.Initialize then
        Libgit2Available := True
      else
      begin
        // Initialization failed, release the interface
        SharedGitManager := nil;
      end;
    except
      on E: Exception do
      begin
        // libgit2 library not available or initialization failed
        if FVerbose then
          WriteLn('libgit2 initialization failed: ', E.Message);
        SharedGitManager := nil;
        Libgit2Available := False;
      end;
    end;
  end;

  Result := Libgit2Available;
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
      Result := CloneWithLibgit2(AURL, ALocalPath, ABranch, FLastError);
      if Result then Exit;

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
  Result := ExecuteGitCommand(['fetch', ARemote], ARepoPath);
end;

function TGitOperations.Pull(const ARepoPath: string): Boolean;
begin
  Result := False;
  FLastError := '';

  if FBackend = gbNone then
  begin
    FLastError := 'No Git backend available';
    Exit;
  end;

  // libgit2 doesn't have a direct "pull" - it's fetch + merge
  // For simplicity, always use command-line for pull
  Result := ExecuteGitCommand(['pull'], ARepoPath);
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
  LResult: TProcessResult;
begin
  Result := False;

  // Use command-line for this - simpler
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
  LResult := TProcessExecutor.Execute('git', ['rev-parse', '--abbrev-ref', 'HEAD'], ARepoPath);
  if LResult.Success then
    Result := Trim(LResult.StdOut);
end;

// ============================================================================
// libgit2 backend functions
// ============================================================================

function CloneWithLibgit2(const AURL, ALocalPath, ABranch: string; out AError: string): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  AError := '';

  if SharedGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  try
    // CloneRepository returns IGitRepository interface
    Repo := SharedGitManager.CloneRepository(AURL, ALocalPath);

    if Repo <> nil then
    begin
      // Checkout branch if specified
      if ABranch <> '' then
      begin
        if not Repo.CheckoutBranch(ABranch) then
        begin
          AError := 'libgit2 clone succeeded but branch checkout failed: ' + ABranch;
          // Still return true as clone succeeded
        end;
      end;
      Result := True;
      // No manual Free needed - interface reference counting
    end
    else
      AError := 'libgit2 clone returned nil repository';
  except
    on E: Exception do
      AError := 'libgit2 clone exception: ' + E.Message;
  end;
end;

function FetchWithLibgit2(const ARepoPath, ARemote: string; out AError: string): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  AError := '';

  if SharedGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  try
    Repo := SharedGitManager.OpenRepository(ARepoPath);
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

function IsRepositoryWithLibgit2(const APath: string): Boolean;
begin
  Result := False;

  if SharedGitManager = nil then
    Exit;

  try
    Result := SharedGitManager.IsRepository(APath);
  except
    on E: Exception do
    begin
      // Silent failure - return false
      Result := False;
    end;
  end;
end;

function GetBranchWithLibgit2(const ARepoPath: string): string;
var
  Repo: IGitRepository;
begin
  Result := '';

  if SharedGitManager = nil then
    Exit;

  try
    Repo := SharedGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      Result := Repo.CurrentBranch;
      // No manual Free needed - interface reference counting
    end;
  except
    Result := '';
  end;
end;

finalization
  // Cleanup shared git manager on unit finalization
  if SharedGitManager <> nil then
  begin
    try
      SharedGitManager.Finalize;
    except
      // Ignore cleanup errors
    end;
    SharedGitManager := nil;
  end;

end.
