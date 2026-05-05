unit fpdev.fpc.builder;

{
================================================================================
  fpdev.fpc.builder - FPC Source Builder Service
================================================================================

  Provides FPC source code download and compilation capabilities:
  - Download FPC source from GitLab
  - Manage bootstrap compilers
  - Build FPC from source
  - Handle build dependencies

  This service is extracted from TFPCManager as part of the Facade pattern
  refactoring to reduce god class complexity.

  Usage:
    Builder := TFPCSourceBuilder.Create(ConfigManager);
    try
      if Builder.EnsureBootstrapCompiler('3.2.2') then
        if Builder.DownloadSource('3.2.2', SourceDir) then
          if Builder.BuildFromSource(SourceDir, InstallDir) then
            WriteLn('Build complete');
    finally
      Builder.Free;
    end;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.fs,
  fpdev.utils.process, fpdev.git.types, fpdev.git.runtime, fpdev.resource.repo, fpdev.constants,
  fpdev.build.toolchain, fpdev.fpc.builderflow,
  fpdev.fpc.types, fpdev.config, fpdev.paths,
  fpdev.fpc.builder.downloadflow,
  fpdev.fpc.builder.bootstrapresolveflow,
  fpdev.fpc.builder.hotpatchflow;

type
  TFPCSourceBuildArgs = array of string;

  TFPCSourceBuildPlan = record
    MakeCommand: string;
    Params: TFPCSourceBuildArgs;
  end;

  { TFPCBuilder is now in fpdev.fpc.builder.di unit for testability }
  { Re-exported for backward compatibility }

  { TFPCSourceBuilder - FPC source compilation service }
  TFPCSourceBuilder = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;
    FResourceRepo: TResourceRepository;
    FOut: IOutput;
    FErr: IOutput;

    { Gets the installation path for a given FPC version. }
    function GetVersionInstallPath(const AVersion: string): string;
    function GetCompilerVersion(const AExecutable: string): string;
    function TryResolveInstalledBootstrapCompiler(
      const ATargetVersion, ARequiredVersion: string;
      out AResolvedVersion, AResolvedCompiler: string
    ): Boolean;
    function EnsureResourceRepository: Boolean;
    function GetResourceRepoRequiredBootstrapVersionCallback(const AFPCVersion: string): string;
    function HasResourceRepositoryBootstrapCompiler(
      const AVersion, APlatform: string
    ): Boolean;
    function FindBestResourceRepositoryBootstrapVersion(
      const AFPCVersion, APlatform: string
    ): string;
    function InstallBootstrapFromResourceRepository(
      const AVersion, APlatform, ADestDir: string
    ): Boolean;
    function SourceDirectoryExists(const APath: string): Boolean;
    procedure PrepareSourceTree(const ASourceDir: string);
    procedure EnsureInstallDirectoryExists(const APath: string);
    function ResolveBuildPlan(
      const AInstallDir, ABootstrapFPC: string;
      const AParallelJobs: Integer
    ): TFPCBuilderBuildPlan;
    function ExecuteBuildPlan(
      const ABuildPlan: TFPCBuilderBuildPlan;
      const ASourceDir: string
    ): TProcessResult;

  public
    constructor Create(AConfigManager: IConfigManager;
      AOut: IOutput = nil; AErr: IOutput = nil);
    destructor Destroy; override;

    { Gets the current FPC version from system PATH. }
    function GetCurrentFPCVersion: string;

    { Gets path to bootstrap compiler for a version. }
    function GetBootstrapCompilerPath(const AVersion: string): string;

    { Checks if bootstrap compiler is locally available. }
    function IsBootstrapAvailable(const AVersion: string): Boolean;

    { Gets the required bootstrap compiler version for building a target version.
      ATargetVersion: FPC version to build
      Returns: Required bootstrap version or empty string if none required }
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;

    { Ensures a bootstrap compiler is available for building the target version.
      Downloads from fpdev-repo if needed.
      ATargetVersion: FPC version to build
      Returns: True if bootstrap compiler is available }
    function EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;

    { Downloads FPC source code from GitLab.
      AVersion: FPC version to download
      ATargetDir: Directory to clone to
      Returns: True if download succeeded }
    function DownloadSource(const AVersion, ATargetDir: string): Boolean;

    { Builds FPC from source code.
      ASourceDir: Directory containing FPC source
      AInstallDir: Installation destination
      Returns: True if build succeeded }
    function BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;

    { Resource repository accessor for external coordination. }
    property ResourceRepo: TResourceRepository read FResourceRepo;
  end;

function CreateFPCSourceBuildPlanCore(
  const AInstallDir, ABootstrapFPC: string;
  const AParallelJobs: Integer;
  const AMakeCommand: string;
  const AIsWindows: Boolean
): TFPCSourceBuildPlan;

implementation

uses
  fpdev.i18n, fpdev.i18n.strings, fpdev.output.console,
  fpdev.version.registry, fpdev.fpc.installversionflow,
  fpdev.resource.repo.bootstrap;

{ TFPCSourceBuilder }

constructor TFPCSourceBuilder.Create(AConfigManager: IConfigManager;
  AOut: IOutput; AErr: IOutput);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;
  FResourceRepo := nil;

  FOut := AOut;
  if FOut = nil then
    FOut := TConsoleOutput.Create(False) as IOutput;

  FErr := AErr;
  if FErr = nil then
    FErr := TConsoleOutput.Create(True) as IOutput;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
    FInstallRoot := GetDataRoot;
end;

destructor TFPCSourceBuilder.Destroy;
begin
  if Assigned(FResourceRepo) then
    FResourceRepo.Free;
  inherited Destroy;
end;

function ResolveFPCSourceBuildTargetVersion(const ASourceDir, AInstallDir: string): string;
var
  SourceLeaf: string;
  InstallLeaf: string;
begin
  SourceLeaf := ExtractFileName(ExcludeTrailingPathDelimiter(Trim(ASourceDir)));
  if Pos('fpc-', LowerCase(SourceLeaf)) = 1 then
    Exit(Copy(SourceLeaf, 5, MaxInt));

  InstallLeaf := ExtractFileName(ExcludeTrailingPathDelimiter(Trim(AInstallDir)));
  if Pos('fpc-', LowerCase(InstallLeaf)) = 1 then
    Exit(Copy(InstallLeaf, 5, MaxInt));

  Result := InstallLeaf;
end;

function CreateFPCSourceBuildPlanCore(
  const AInstallDir, ABootstrapFPC: string;
  const AParallelJobs: Integer;
  const AMakeCommand: string;
  const AIsWindows: Boolean
): TFPCSourceBuildPlan;
var
  EffectiveJobs: Integer;
  ParamIndex: Integer;
begin
  Result := Default(TFPCSourceBuildPlan);
  if Trim(AMakeCommand) <> '' then
    Result.MakeCommand := AMakeCommand
  else
    Result.MakeCommand := 'make';

  EffectiveJobs := AParallelJobs;
  if EffectiveJobs <= 0 then
    EffectiveJobs := 1;

  SetLength(Result.Params, 5);
  if Trim(ABootstrapFPC) <> '' then
    SetLength(Result.Params, Length(Result.Params) + 1);
  if not AIsWindows then
    SetLength(Result.Params, Length(Result.Params) + 1);

  ParamIndex := 0;
  Result.Params[ParamIndex] := 'all';
  Inc(ParamIndex);
  Result.Params[ParamIndex] := 'install';
  Inc(ParamIndex);
  Result.Params[ParamIndex] := 'PREFIX=' + AInstallDir;
  Inc(ParamIndex);
  if Trim(ABootstrapFPC) <> '' then
  begin
    Result.Params[ParamIndex] := 'PP=' + ABootstrapFPC;
    Inc(ParamIndex);
  end;
  Result.Params[ParamIndex] := 'OVERRIDEVERSIONCHECK=1';
  Inc(ParamIndex);
  if not AIsWindows then
  begin
    Result.Params[ParamIndex] := 'GINSTALL=/usr/bin/install';
    Inc(ParamIndex);
  end;
  Result.Params[ParamIndex] := '-j' + IntToStr(EffectiveJobs);
end;

function TFPCSourceBuilder.GetVersionInstallPath(const AVersion: string): string;
begin
  Result := BuildFPCInstallDirFromInstallRoot(FInstallRoot, AVersion);
end;

function TFPCSourceBuilder.GetCompilerVersion(const AExecutable: string): string;
var
  LResult: fpdev.utils.process.TProcessResult;
begin
  Result := '';
  if Trim(AExecutable) = '' then
    Exit;

  try
    LResult := TProcessExecutor.Execute(AExecutable, ['-iV'], '');
    if LResult.Success then
      Result := Trim(LResult.StdOut);
  except
    Result := '';
  end;
end;

function TFPCSourceBuilder.TryResolveInstalledBootstrapCompiler(
  const ATargetVersion, ARequiredVersion: string;
  out AResolvedVersion, AResolvedCompiler: string
): Boolean;
var
  Callbacks: TFPCBuilderBootstrapResolveCallbacks;
begin
  Callbacks := Default(TFPCBuilderBootstrapResolveCallbacks);
  Callbacks.GetVersionInstallPath := @GetVersionInstallPath;
  Callbacks.GetCompilerVersion := @GetCompilerVersion;
  Result := TryResolveInstalledBootstrapCompilerCore(
    ATargetVersion, ARequiredVersion, Callbacks, AResolvedVersion, AResolvedCompiler);
end;

function TFPCSourceBuilder.EnsureResourceRepository: Boolean;
begin
  if not Assigned(FResourceRepo) then
  begin
    FResourceRepo := TResourceRepository.Create(CreateDefaultConfig);
    if not FResourceRepo.Initialize then
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_FPC_REPO_INIT_FAILED));
      FResourceRepo.Free;
      FResourceRepo := nil;
    end;
  end;

  Result := Assigned(FResourceRepo);
end;

function TFPCSourceBuilder.GetResourceRepoRequiredBootstrapVersionCallback(const AFPCVersion: string): string;
begin
  if Assigned(FResourceRepo) then
    Result := FResourceRepo.GetRequiredBootstrapVersion(AFPCVersion)
  else
    Result := '';
end;

function TFPCSourceBuilder.HasResourceRepositoryBootstrapCompiler(
  const AVersion, APlatform: string
): Boolean;
begin
  Result := Assigned(FResourceRepo) and
    FResourceRepo.HasBootstrapCompiler(AVersion, APlatform);
end;

function TFPCSourceBuilder.FindBestResourceRepositoryBootstrapVersion(
  const AFPCVersion, APlatform: string
): string;
begin
  if Assigned(FResourceRepo) then
    Result := FResourceRepo.FindBestBootstrapVersion(AFPCVersion, APlatform)
  else
    Result := '';
end;

function TFPCSourceBuilder.InstallBootstrapFromResourceRepository(
  const AVersion, APlatform, ADestDir: string
): Boolean;
begin
  Result := Assigned(FResourceRepo) and
    FResourceRepo.InstallBootstrap(AVersion, APlatform, ADestDir);
end;

function TFPCSourceBuilder.SourceDirectoryExists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

procedure TFPCSourceBuilder.PrepareSourceTree(const ASourceDir: string);
begin
  FPCBuilderInvalidateCompilerMessageIncludesCore(ASourceDir);
  FPCBuilderApplyFCLWebJWTSourcePathHotpatchCore(ASourceDir);
end;

procedure TFPCSourceBuilder.EnsureInstallDirectoryExists(const APath: string);
begin
  if not DirectoryExists(APath) then
    EnsureDir(APath);
end;

function TFPCSourceBuilder.ResolveBuildPlan(
  const AInstallDir, ABootstrapFPC: string;
  const AParallelJobs: Integer
): TFPCBuilderBuildPlan;
var
  BuildPlan: TFPCSourceBuildPlan;
  ToolchainChecker: TBuildToolchainChecker;
  I: Integer;
begin
  ToolchainChecker := TBuildToolchainChecker.Create(False);
  try
    BuildPlan := CreateFPCSourceBuildPlanCore(
      AInstallDir,
      ABootstrapFPC,
      AParallelJobs,
      ToolchainChecker.ResolveMakeCmd,
      {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
    );
  finally
    ToolchainChecker.Free;
  end;

  Result.MakeCommand := BuildPlan.MakeCommand;
  SetLength(Result.Params, Length(BuildPlan.Params));
  for I := 0 to High(BuildPlan.Params) do
    Result.Params[I] := BuildPlan.Params[I];
end;

function TFPCSourceBuilder.ExecuteBuildPlan(
  const ABuildPlan: TFPCBuilderBuildPlan;
  const ASourceDir: string
): TProcessResult;
var
  BuildArgs: TFPCSourceBuildArgs;
  I: Integer;
begin
  BuildArgs := nil;
  SetLength(BuildArgs, Length(ABuildPlan.Params));
  for I := 0 to High(ABuildPlan.Params) do
    BuildArgs[I] := ABuildPlan.Params[I];

  Result := TProcessExecutor.RunDirect(
    ABuildPlan.MakeCommand,
    BuildArgs,
    ASourceDir
  );
end;

function TFPCSourceBuilder.GetCurrentFPCVersion: string;
begin
  Result := GetCompilerVersion('fpc');
end;

function TFPCSourceBuilder.GetBootstrapCompilerPath(const AVersion: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataRoot) + 'bootstrap' +
    PathDelim + 'fpc-' + AVersion + PathDelim + 'bin' + PathDelim;
  {$IFDEF MSWINDOWS}
  Result := Result + 'fpc.exe';
  {$ELSE}
  Result := Result + 'fpc';
  {$ENDIF}
end;

function TFPCSourceBuilder.IsBootstrapAvailable(const AVersion: string): Boolean;
var
  BootstrapPath: string;
begin
  BootstrapPath := GetBootstrapCompilerPath(AVersion);
  Result := FileExists(BootstrapPath);
end;

function TFPCSourceBuilder.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
var
  Callbacks: TFPCBuilderBootstrapResolveCallbacks;
begin
  Callbacks := Default(TFPCBuilderBootstrapResolveCallbacks);
  Callbacks.GetResourceRepoRequiredBootstrapVersion := @GetResourceRepoRequiredBootstrapVersionCallback;
  Result := GetRequiredBootstrapVersionCore(ATargetVersion, FInstallRoot, FResourceRepo, Callbacks);
end;

function TFPCSourceBuilder.EnsureBootstrapCompiler(const ATargetVersion: string): Boolean;
var
  BootstrapState: TFPCBuilderBootstrapState;
  BootstrapCallbacks: TFPCBuilderBootstrapCallbacks;
begin
  BootstrapState := Default(TFPCBuilderBootstrapState);
  BootstrapCallbacks := Default(TFPCBuilderBootstrapCallbacks);
  BootstrapState.TargetVersion := ATargetVersion;
  BootstrapState.Platform := GetCurrentPlatform;

  BootstrapCallbacks.GetRequiredBootstrapVersion := @GetRequiredBootstrapVersion;
  BootstrapCallbacks.GetCurrentCompilerVersion := @GetCurrentFPCVersion;
  BootstrapCallbacks.CanUseSystemCompiler := @FPCBuilderCanUseSystemCompilerAsBootstrapCore;
  BootstrapCallbacks.TryResolveInstalledBootstrapCompiler := @TryResolveInstalledBootstrapCompiler;
  BootstrapCallbacks.IsBootstrapAvailable := @IsBootstrapAvailable;
  BootstrapCallbacks.GetBootstrapCompilerPath := @GetBootstrapCompilerPath;
  BootstrapCallbacks.EnsureResourceRepository := @EnsureResourceRepository;
  BootstrapCallbacks.HasResourceRepositoryBootstrapCompiler := @HasResourceRepositoryBootstrapCompiler;
  BootstrapCallbacks.FindBestResourceRepositoryBootstrapVersion := @FindBestResourceRepositoryBootstrapVersion;
  BootstrapCallbacks.InstallBootstrapFromResourceRepository := @InstallBootstrapFromResourceRepository;

  Result := ExecuteFPCBuilderEnsureBootstrapCore(
    BootstrapState,
    FOut,
    FErr,
    BootstrapCallbacks
  );
end;

function TFPCSourceBuilder.DownloadSource(const AVersion, ATargetDir: string): Boolean;
var
  GitTag: string;
begin
  GitTag := TVersionRegistry.Instance.GetFPCGitTag(AVersion);
  Result := DownloadFPCSourceWithGitRuntimeCore(AVersion, ATargetDir, GitTag, FOut, FErr);
end;

function TFPCSourceBuilder.BuildFromSource(const ASourceDir, AInstallDir: string): Boolean;
var
  BuildState: TFPCBuilderBuildState;
  BuildCallbacks: TFPCBuilderBuildCallbacks;
  Settings: TFPDevSettings;
begin
  Settings := FConfigManager.GetSettingsManager.GetSettings;
  BuildState := Default(TFPCBuilderBuildState);
  BuildCallbacks := Default(TFPCBuilderBuildCallbacks);
  BuildState.SourceDir := ASourceDir;
  BuildState.InstallDir := AInstallDir;
  BuildState.TargetVersion := ResolveFPCSourceBuildTargetVersion(ASourceDir, AInstallDir);
  BuildState.ParallelJobs := Settings.ParallelJobs;

  BuildCallbacks.SourceDirectoryExists := @SourceDirectoryExists;
  BuildCallbacks.PrepareSourceTree := @PrepareSourceTree;
  BuildCallbacks.EnsureInstallDirectory := @EnsureInstallDirectoryExists;
  BuildCallbacks.GetRequiredBootstrapVersion := @GetRequiredBootstrapVersion;
  BuildCallbacks.GetCurrentCompilerVersion := @GetCurrentFPCVersion;
  BuildCallbacks.CanUseSystemCompiler := @FPCBuilderCanUseSystemCompilerAsBootstrapCore;
  BuildCallbacks.TryResolveInstalledBootstrapCompiler := @TryResolveInstalledBootstrapCompiler;
  BuildCallbacks.ResolveBuildPlan := @ResolveBuildPlan;
  BuildCallbacks.ExecuteBuildPlan := @ExecuteBuildPlan;

  try
    Result := ExecuteFPCBuilderBuildFromSourceCore(BuildState, FOut, FErr, BuildCallbacks);
  except
    on E: Exception do
    begin
      FErr.WriteLn(_(MSG_ERROR) + ': BuildFromSource failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

{ TFPCBuilder has been moved to fpdev.fpc.builder.di unit }

end.
