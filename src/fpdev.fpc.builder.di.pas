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
  git2.impl;

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
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
  LGitErr: string;
  LRepo: IGitRepository;
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

  // Fallback: command-line git (shallow clone)
  ProcResult := FProcessRunner.Execute('git', ['clone', '--branch', GitTag, '--depth', '1',
    FPC_OFFICIAL_REPO, ATargetDir], '');

  if not ProcResult.Success then
  begin
    if ProcResult.StdErr <> '' then
      Result := OperationError(ecDownloadFailed, 'Git clone failed: ' + ProcResult.StdErr)
    else if LGitErr <> '' then
      Result := OperationError(ecDownloadFailed, 'Git clone failed: ' + LGitErr)
    else
      Result := OperationError(ecDownloadFailed, 'Git clone failed');
    Exit;
  end;

  // Keep DI tests deterministic.
  FFileSystem.ForceDirectories(ATargetDir);
  Result := OperationSuccess;
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
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
  LRepo: IGitRepository;
  Ext: IGitRepositoryExt;
  PullRes: TGitPullFastForwardResult;
  PullErr: string;
  LGitErr: string;
  NeedsFallback: Boolean;
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

  NeedsFallback := True;
  LGitErr := '';

  // Try libgit2 fast-forward pull first. If merge/rebase is required, fall back to CLI.
  if EnsureGitManagerInitialized(LGitErr) then
  begin
    try
      LRepo := FGitManager.OpenRepository(SourceDir);
      if Assigned(LRepo) and Supports(LRepo, IGitRepositoryExt, Ext) then
      begin
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
          gpffDirty,
          gpffError:
            begin
              NeedsFallback := True;
              if PullErr <> '' then
                LGitErr := PullErr;
            end;
        end;
      end
      else
      begin
        // Extension not available - attempt a fetch to at least refresh refs.
        if Assigned(LRepo) and LRepo.Fetch('origin') then
          Exit(OperationSuccess);
      end;
    except
      on E: Exception do
      begin
        NeedsFallback := True;
        LGitErr := 'libgit2 pull exception: ' + E.Message;
      end;
    end;
  end;

  if not NeedsFallback then
  begin
    Result := OperationError(ecDownloadFailed, 'Git update failed');
    Exit;
  end;

  // Fallback: command-line git pull
  ProcResult := FProcessRunner.Execute('git', ['pull'], SourceDir);

  if not ProcResult.Success then
  begin
    if ProcResult.StdErr <> '' then
      Result := OperationError(ecDownloadFailed, 'Git pull failed: ' + ProcResult.StdErr)
    else if LGitErr <> '' then
      Result := OperationError(ecDownloadFailed, 'Git pull failed: ' + LGitErr)
    else
      Result := OperationError(ecDownloadFailed, 'Git pull failed');
    Exit;
  end;

  Result := OperationSuccess;
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
