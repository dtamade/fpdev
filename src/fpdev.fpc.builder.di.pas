unit fpdev.fpc.builder.di;

{
================================================================================
  fpdev.fpc.builder.di - FPC Builder with Dependency Injection
================================================================================

  Provides a testable FPC builder implementation using dependency injection:
  - IFileSystem for file operations
  - IProcessRunner for process execution
  - TFPCVersionManager for version validation

  This class is designed for unit testing with mock dependencies.
  For production use, see TFPCSourceBuilder in fpdev.fpc.builder.pas.

  Extracted from fpdev.fpc.builder.pas for better separation of concerns.

  Usage:
    Builder := TFPCBuilder.Create(VersionMgr, ConfigMgr, FileSystem, ProcessRunner);
    try
      Result := Builder.DownloadSource('3.2.2', '/tmp/fpc-src');
      if Result.Success then
        Result := Builder.BuildFromSource('/tmp/fpc-src', '/opt/fpc');
    finally
      Builder.Free;
    end;

  Testing with mocks:
    MockFS := TMockFileSystem.Create;
    MockProc := TMockProcessRunner.Create;
    Builder := TFPCBuilder.Create(VersionMgr, ConfigMgr, MockFS, MockProc);
    // Test without real file/process operations

  Author: FPDev Team
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  git2.api, git2.types,
  fpdev.config, fpdev.fpc.version, fpdev.fpc.interfaces, fpdev.fpc.types,
  fpdev.constants;

type
  { TFPCBuilder - FPC builder with dependency injection for testing }
  TFPCBuilder = class
  private
    FVersionManager: TFPCVersionManager;
    FConfigManager: TFPDevConfigManager;
    FFileSystem: IFileSystem;
    FProcessRunner: IProcessRunner;
    FGitManager: IGitManager;
    FOwnsGitManager: Boolean;

    function GetSourceDir(const AVersion: string): string;
    function EnsureGitManagerInitialized(out AError: string): Boolean;
    function CheckoutRefWithLibgit2(const ARepo: IGitRepository; const ARefName: string; out AError: string): Boolean;
  public
    constructor Create(AVersionManager: TFPCVersionManager;
      AConfigManager: TFPDevConfigManager;
      AFileSystem: IFileSystem;
      AProcessRunner: IProcessRunner);
    constructor Create(AVersionManager: TFPCVersionManager;
      AConfigManager: TFPDevConfigManager;
      AFileSystem: IFileSystem;
      AProcessRunner: IProcessRunner;
      AGitManager: IGitManager);
    destructor Destroy; override;

    { Downloads FPC source code from official repository.
      AVersion: FPC version to download
      ATargetDir: Directory to clone into
      Returns: TOperationResult with success/error status }
    function DownloadSource(const AVersion, ATargetDir: string): TOperationResult;

    { Builds FPC from source using make.
      ASourceDir: Directory containing FPC source
      AInstallDir: Installation prefix directory
      Returns: TOperationResult with success/error status }
    function BuildFromSource(const ASourceDir, AInstallDir: string): TOperationResult;

    { Updates FPC sources from repository using git pull.
      AVersion: FPC version to update
      Returns: TOperationResult with success/error status }
    function UpdateSources(const AVersion: string): TOperationResult;

    { Cleans FPC source directory using make clean.
      AVersion: FPC version to clean
      Returns: TOperationResult with success/error status }
    function CleanSources(const AVersion: string): TOperationResult;

    { Read-only properties for testing inspection }
    property VersionManager: TFPCVersionManager read FVersionManager;
    property ConfigManager: TFPDevConfigManager read FConfigManager;
    property FileSystem: IFileSystem read FFileSystem;
    property ProcessRunner: IProcessRunner read FProcessRunner;
  end;

implementation

uses
  fpdev.utils.git, fpdev.utils.process, git2.impl;

type
  TGitCliRunnerFromProcessRunner = class(TInterfacedObject, IGitCliRunner)
  private
    FProcessRunner: IProcessRunner;
  public
    constructor Create(const AProcessRunner: IProcessRunner);
    function Execute(const AParams: array of string; const AWorkDir: string = ''): fpdev.utils.process.TProcessResult;
  end;

constructor TGitCliRunnerFromProcessRunner.Create(const AProcessRunner: IProcessRunner);
begin
  inherited Create;
  FProcessRunner := AProcessRunner;
end;

function TGitCliRunnerFromProcessRunner.Execute(const AParams: array of string;
  const AWorkDir: string): fpdev.utils.process.TProcessResult;
var
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
begin
  ProcResult := FProcessRunner.Execute('git', AParams, AWorkDir);
  Result.Success := ProcResult.Success;
  Result.ExitCode := ProcResult.ExitCode;
  Result.StdOut := ProcResult.StdOut;
  Result.StdErr := ProcResult.StdErr;
  Result.ErrorMessage := '';
end;

function FastForwardOnlyPullError(const APullResult: TGitPullFastForwardResult;
  const APullError: string): string;
begin
  if Trim(APullError) <> '' then
    Exit(APullError);

  case APullResult of
    gpffNeedsMerge:
      Result := 'Fast-forward-only update blocked because branches diverged; reconcile manually before retrying.';
    gpffDetachedHead:
      Result := 'Fast-forward-only update blocked because the repository is in detached HEAD state; switch to a branch before retrying.';
    gpffDirty:
      Result := 'Fast-forward-only update blocked because the working tree has local changes; commit or stash them before retrying.';
    gpffNoRemote:
      Result := 'No remote configured';
  else
    Result := 'Git update failed';
  end;
end;

{ TFPCBuilder }

constructor TFPCBuilder.Create(AVersionManager: TFPCVersionManager;
  AConfigManager: TFPDevConfigManager;
  AFileSystem: IFileSystem;
  AProcessRunner: IProcessRunner);
begin
  inherited Create;
  FVersionManager := AVersionManager;
  FConfigManager := AConfigManager;
  FFileSystem := AFileSystem;
  FProcessRunner := AProcessRunner;
  FGitManager := nil;
  FOwnsGitManager := False;
end;

constructor TFPCBuilder.Create(AVersionManager: TFPCVersionManager;
  AConfigManager: TFPDevConfigManager;
  AFileSystem: IFileSystem;
  AProcessRunner: IProcessRunner;
  AGitManager: IGitManager);
begin
  Create(AVersionManager, AConfigManager, AFileSystem, AProcessRunner);
  FGitManager := AGitManager;
  FOwnsGitManager := False;
end;

destructor TFPCBuilder.Destroy;
begin
  if FOwnsGitManager and (FGitManager <> nil) then
  begin
    try
      if FGitManager.Initialized then
        FGitManager.Finalize;
    except
      // Best-effort cleanup only (DI builder must not raise in Destroy)
    end;
    FGitManager := nil;
  end;
  inherited Destroy;
end;

function TFPCBuilder.GetSourceDir(const AVersion: string): string;
var
  Settings: TFPDevSettings;
begin
  Settings := FConfigManager.GetSettings;
  Result := Settings.InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-' + AVersion;
end;

function TFPCBuilder.EnsureGitManagerInitialized(out AError: string): Boolean;
begin
  Result := False;
  AError := '';

  try
    if FGitManager = nil then
    begin
      FGitManager := NewGitManager();
      FOwnsGitManager := True;
    end;

    if (not FGitManager.Initialized) and (not FGitManager.Initialize) then
    begin
      AError := 'libgit2 init failed';
      Exit(False);
    end;

    Result := True;
  except
    on E: Exception do
    begin
      AError := 'libgit2 exception: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TFPCBuilder.CheckoutRefWithLibgit2(const ARepo: IGitRepository; const ARefName: string; out AError: string): Boolean;
var
  LName: string;
begin
  Result := False;
  AError := '';

  if ARepo = nil then
  begin
    AError := 'libgit2 repository is nil';
    Exit(False);
  end;

  LName := Trim(ARefName);
  if LName = '' then
    Exit(True);

  try
    // Keep behavior aligned with fpdev.utils.git: try plain name first, then tags, then remote tracking refs.
    if Pos('refs/', LName) = 1 then
      Exit(ARepo.CheckoutBranchEx(LName, False));

    if ARepo.CheckoutBranchEx(LName, False) then
      Exit(True);

    if ARepo.CheckoutBranchEx('refs/tags/' + LName, False) then
      Exit(True);

    if ARepo.CheckoutBranchEx('refs/remotes/origin/' + LName, False) then
      Exit(True);

    AError := 'libgit2 checkout failed: ' + LName;
    Result := False;
  except
    on E: Exception do
    begin
      AError := 'libgit2 checkout exception: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TFPCBuilder.DownloadSource(const AVersion, ATargetDir: string): TOperationResult;
var
  GitTag: string;
  LGitErr: string;
  LRepo: IGitRepository;
  GitOps: TGitOperations;
begin
  // Validate version
  if not FVersionManager.ValidateVersion(AVersion) then
  begin
    Result := OperationError(ecVersionNotFound, 'Version not found: ' + AVersion);
    Exit;
  end;

  // Get Git tag for version
  GitTag := FVersionManager.GetGitTag(AVersion);
  if GitTag = '' then
  begin
    Result := OperationError(ecVersionNotFound, 'No Git tag found for version: ' + AVersion);
    Exit;
  end;

  // Ensure parent directory exists (avoid creating ATargetDir before clone)
  if not FFileSystem.ForceDirectories(ExtractFileDir(ATargetDir)) then
  begin
    Result := OperationError(ecFileSystemError, 'Failed to create directory: ' + ATargetDir);
    Exit;
  end;

  // Prefer libgit2; fall back to command-line git only when needed.
  LGitErr := '';
  if EnsureGitManagerInitialized(LGitErr) then
  begin
    try
      LRepo := FGitManager.CloneRepository(FPC_OFFICIAL_REPO, ATargetDir);
      if Assigned(LRepo) and CheckoutRefWithLibgit2(LRepo, GitTag, LGitErr) then
      begin
        // Keep DI tests deterministic: mock FS doesn't observe external side effects.
        FFileSystem.ForceDirectories(ATargetDir);
        Exit(OperationSuccess);
      end;
    except
      on E: Exception do
        LGitErr := 'libgit2 clone exception: ' + E.Message;
    end;
  end;

  // Fallback: command-line git through TGitOperations with injected CLI runner.
  GitOps := TGitOperations.Create(TGitCliRunnerFromProcessRunner.Create(FProcessRunner), True);
  try
    if GitOps.Clone(FPC_OFFICIAL_REPO, ATargetDir, GitTag) then
    begin
      FFileSystem.ForceDirectories(ATargetDir);
      Exit(OperationSuccess);
    end;

    if GitOps.LastError <> '' then
      LGitErr := GitOps.LastError;
  finally
    GitOps.Free;
  end;

  if LGitErr <> '' then
    Result := OperationError(ecDownloadFailed, 'Git clone failed: ' + LGitErr)
  else
  begin
    Result := OperationError(ecDownloadFailed, 'Git clone failed');
  end;
end;

function TFPCBuilder.BuildFromSource(const ASourceDir, AInstallDir: string): TOperationResult;
var
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
  Settings: TFPDevSettings;
begin
  // Check source directory exists
  if not FFileSystem.DirectoryExists(ASourceDir) then
  begin
    Result := OperationError(ecBuildFailed, 'Source directory does not exist: ' + ASourceDir);
    Exit;
  end;

  // Create install directory
  if not FFileSystem.ForceDirectories(AInstallDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Failed to create install directory: ' + AInstallDir);
    Exit;
  end;

  // Get parallel jobs setting
  Settings := FConfigManager.GetSettings;

  // Execute make
  ProcResult := FProcessRunner.Execute('make', ['all', 'install',
    'PREFIX=' + AInstallDir, '-j' + IntToStr(Settings.ParallelJobs)], ASourceDir);

  if not ProcResult.Success then
  begin
    Result := OperationError(ecBuildFailed, 'Build failed with exit code: ' + IntToStr(ProcResult.ExitCode));
    Exit;
  end;

  Result := OperationSuccess;
end;

function TFPCBuilder.UpdateSources(const AVersion: string): TOperationResult;
var
  SourceDir, GitDir: string;
  LRepo: IGitRepository;
  Ext: IGitRepositoryExt;
  PullRes: TGitPullFastForwardResult;
  PullErr: string;
  LGitErr: string;
begin
  SourceDir := GetSourceDir(AVersion);

  // Check if source directory exists
  if not FFileSystem.DirectoryExists(SourceDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Source directory does not exist: ' + SourceDir);
    Exit;
  end;

  // Check if it's a git repository
  GitDir := SourceDir + PathDelim + '.git';
  if not FFileSystem.DirectoryExists(GitDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Source directory is not a git repository: ' + SourceDir);
    Exit;
  end;

  LGitErr := '';

  if not EnsureGitManagerInitialized(LGitErr) then
  begin
    if LGitErr <> '' then
      Result := OperationError(ecDownloadFailed, LGitErr)
    else
      Result := OperationError(ecDownloadFailed, 'Git update failed');
    Exit;
  end;

  try
    LRepo := FGitManager.OpenRepository(SourceDir);
    if not Assigned(LRepo) then
    begin
      Result := OperationError(ecDownloadFailed, 'Failed to open git repository: ' + SourceDir);
      Exit;
    end;

    if not Supports(LRepo, IGitRepositoryExt, Ext) then
    begin
      Result := OperationError(ecDownloadFailed,
        'Fast-forward-only update requires libgit2 fast-forward support for this repository.');
      Exit;
    end;

    PullErr := '';
    PullRes := Ext.PullFastForward('origin', PullErr);
    case PullRes of
      gpffUpToDate,
      gpffFastForwarded:
        Exit(OperationSuccess);
      gpffNoRemote:
        begin
          Result := OperationError(ecDownloadFailed, 'No remote configured');
          Exit;
        end;
      gpffNeedsMerge,
      gpffDetachedHead,
      gpffDirty:
        begin
          Result := OperationError(ecDownloadFailed, FastForwardOnlyPullError(PullRes, PullErr));
          Exit;
        end;
      gpffError:
        begin
          if PullErr <> '' then
            LGitErr := PullErr
          else
            LGitErr := 'Git update failed';
          Result := OperationError(ecDownloadFailed, LGitErr);
          Exit;
        end;
    end;
  except
    on E: Exception do
    begin
      Result := OperationError(ecDownloadFailed, 'libgit2 pull exception: ' + E.Message);
      Exit;
    end;
  end;

  if LGitErr <> '' then
    Result := OperationError(ecDownloadFailed, LGitErr)
  else
  begin
    Result := OperationError(ecDownloadFailed, 'Git update failed');
  end;
end;

function TFPCBuilder.CleanSources(const AVersion: string): TOperationResult;
var
  SourceDir: string;
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
begin
  SourceDir := GetSourceDir(AVersion);

  // Check if source directory exists
  if not FFileSystem.DirectoryExists(SourceDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Source directory does not exist: ' + SourceDir);
    Exit;
  end;

  // Execute make clean
  ProcResult := FProcessRunner.Execute('make', ['clean'], SourceDir);

  if not ProcResult.Success then
  begin
    Result := OperationError(ecBuildFailed, 'Clean failed: ' + ProcResult.StdErr);
    Exit;
  end;

  Result := OperationSuccess;
end;

end.
