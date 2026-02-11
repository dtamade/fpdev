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

    function GetSourceDir(const AVersion: string): string;
  public
    constructor Create(AVersionManager: TFPCVersionManager;
      AConfigManager: TFPDevConfigManager;
      AFileSystem: IFileSystem;
      AProcessRunner: IProcessRunner);
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
end;

destructor TFPCBuilder.Destroy;
begin
  inherited Destroy;
end;

function TFPCBuilder.GetSourceDir(const AVersion: string): string;
var
  Settings: TFPDevSettings;
begin
  Settings := FConfigManager.GetSettings;
  Result := Settings.InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-' + AVersion;
end;

function TFPCBuilder.DownloadSource(const AVersion, ATargetDir: string): TOperationResult;
var
  GitTag: string;
  ProcResult: fpdev.fpc.interfaces.TProcessResult;
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

  // Create target directory
  if not FFileSystem.ForceDirectories(ATargetDir) then
  begin
    Result := OperationError(ecFileSystemError, 'Failed to create directory: ' + ATargetDir);
    Exit;
  end;

  // Execute git clone
  ProcResult := FProcessRunner.Execute('git', ['clone', '--branch', GitTag, '--depth', '1',
    FPC_OFFICIAL_REPO, ATargetDir], '');

  if not ProcResult.Success then
  begin
    Result := OperationError(ecDownloadFailed, 'Git clone failed: ' + ProcResult.StdErr);
    Exit;
  end;

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

  // Execute git pull
  ProcResult := FProcessRunner.Execute('git', ['pull'], SourceDir);

  if not ProcResult.Success then
  begin
    Result := OperationError(ecDownloadFailed, 'Git pull failed: ' + ProcResult.StdErr);
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
