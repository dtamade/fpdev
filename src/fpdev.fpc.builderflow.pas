unit fpdev.fpc.builderflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.utils.process;

type
  TFPCBuilderBuildArgs = array of string;

  TFPCBuilderBuildPlan = record
    MakeCommand: string;
    Params: TFPCBuilderBuildArgs;
  end;

  TFPCBuilderCanUseSystemCompilerFunc = function(
    const ATargetVersion, ACurrentVersion, ARequiredVersion: string
  ): Boolean;

  TFPCBuilderGetRequiredBootstrapVersionFunc = function(
    const ATargetVersion: string
  ): string of object;

  TFPCBuilderGetCurrentCompilerVersionFunc = function: string of object;

  TFPCBuilderTryResolveInstalledBootstrapFunc = function(
    const ATargetVersion, ARequiredVersion: string;
    out AResolvedVersion, AResolvedCompiler: string
  ): Boolean of object;

  TFPCBuilderIsBootstrapAvailableFunc = function(
    const AVersion: string
  ): Boolean of object;

  TFPCBuilderGetBootstrapCompilerPathFunc = function(
    const AVersion: string
  ): string of object;

  TFPCBuilderEnsureResourceRepositoryFunc = function: Boolean of object;

  TFPCBuilderHasBootstrapCompilerFunc = function(
    const AVersion, APlatform: string
  ): Boolean of object;

  TFPCBuilderFindBestBootstrapVersionFunc = function(
    const AFPCVersion, APlatform: string
  ): string of object;

  TFPCBuilderInstallBootstrapFunc = function(
    const AVersion, APlatform, ADestDir: string
  ): Boolean of object;

  TFPCBuilderDirectoryExistsFunc = function(const APath: string): Boolean of object;
  TFPCBuilderPrepareSourceProc = procedure(const ASourceDir: string) of object;
  TFPCBuilderEnsureDirectoryProc = procedure(const APath: string) of object;

  TFPCBuilderResolveBuildPlanFunc = function(
    const AInstallDir, ABootstrapFPC: string;
    const AParallelJobs: Integer
  ): TFPCBuilderBuildPlan of object;

  TFPCBuilderExecuteBuildPlanFunc = function(
    const ABuildPlan: TFPCBuilderBuildPlan;
    const ASourceDir: string
  ): TProcessResult of object;

  TFPCBuilderBootstrapState = record
    TargetVersion: string;
    Platform: string;
  end;

  TFPCBuilderBootstrapCallbacks = record
    GetRequiredBootstrapVersion: TFPCBuilderGetRequiredBootstrapVersionFunc;
    GetCurrentCompilerVersion: TFPCBuilderGetCurrentCompilerVersionFunc;
    CanUseSystemCompiler: TFPCBuilderCanUseSystemCompilerFunc;
    TryResolveInstalledBootstrapCompiler: TFPCBuilderTryResolveInstalledBootstrapFunc;
    IsBootstrapAvailable: TFPCBuilderIsBootstrapAvailableFunc;
    GetBootstrapCompilerPath: TFPCBuilderGetBootstrapCompilerPathFunc;
    EnsureResourceRepository: TFPCBuilderEnsureResourceRepositoryFunc;
    HasResourceRepositoryBootstrapCompiler: TFPCBuilderHasBootstrapCompilerFunc;
    FindBestResourceRepositoryBootstrapVersion: TFPCBuilderFindBestBootstrapVersionFunc;
    InstallBootstrapFromResourceRepository: TFPCBuilderInstallBootstrapFunc;
  end;

  TFPCBuilderBuildState = record
    SourceDir: string;
    InstallDir: string;
    TargetVersion: string;
    ParallelJobs: Integer;
  end;

  TFPCBuilderBuildCallbacks = record
    SourceDirectoryExists: TFPCBuilderDirectoryExistsFunc;
    PrepareSourceTree: TFPCBuilderPrepareSourceProc;
    EnsureInstallDirectory: TFPCBuilderEnsureDirectoryProc;
    GetRequiredBootstrapVersion: TFPCBuilderGetRequiredBootstrapVersionFunc;
    GetCurrentCompilerVersion: TFPCBuilderGetCurrentCompilerVersionFunc;
    CanUseSystemCompiler: TFPCBuilderCanUseSystemCompilerFunc;
    TryResolveInstalledBootstrapCompiler: TFPCBuilderTryResolveInstalledBootstrapFunc;
    ResolveBuildPlan: TFPCBuilderResolveBuildPlanFunc;
    ExecuteBuildPlan: TFPCBuilderExecuteBuildPlanFunc;
  end;

function ExecuteFPCBuilderEnsureBootstrapCore(
  const AState: TFPCBuilderBootstrapState;
  const AOut, AErr: IOutput;
  const ACallbacks: TFPCBuilderBootstrapCallbacks
): Boolean;

function ExecuteFPCBuilderBuildFromSourceCore(
  const AState: TFPCBuilderBuildState;
  const AOut, AErr: IOutput;
  const ACallbacks: TFPCBuilderBuildCallbacks
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

procedure WriteText(const AOut: IOutput; const AText: string);
begin
  if AOut <> nil then
    AOut.Write(AText);
end;

function ResolveBootstrapCompilerPath(
  const AVersion: string;
  const ACallbacks: TFPCBuilderBootstrapCallbacks
): string;
begin
  Result := '';
  if Assigned(ACallbacks.GetBootstrapCompilerPath) then
    Result := ACallbacks.GetBootstrapCompilerPath(AVersion);
end;

function ExecuteFPCBuilderEnsureBootstrapCore(
  const AState: TFPCBuilderBootstrapState;
  const AOut, AErr: IOutput;
  const ACallbacks: TFPCBuilderBootstrapCallbacks
): Boolean;
var
  RequiredVersion: string;
  BestVersion: string;
  CurrentVersion: string;
  BootstrapPath: string;
  InstalledBootstrapVersion: string;
  InstalledBootstrapExe: string;
begin
  Result := False;

  RequiredVersion := '';
  if Assigned(ACallbacks.GetRequiredBootstrapVersion) then
    RequiredVersion := ACallbacks.GetRequiredBootstrapVersion(AState.TargetVersion);

  if RequiredVersion = '' then
  begin
    WriteLine(AOut, 'Note: No specific bootstrap compiler required for ' + AState.TargetVersion);
    Exit(True);
  end;

  WriteLine(AOut,
    'Target FPC version ' + AState.TargetVersion +
    ' requires bootstrap compiler ' + RequiredVersion
  );

  CurrentVersion := '';
  if Assigned(ACallbacks.GetCurrentCompilerVersion) then
    CurrentVersion := ACallbacks.GetCurrentCompilerVersion();

  if CurrentVersion <> '' then
  begin
    WriteLine(AOut, 'Current system FPC version: ' + CurrentVersion);

    if Assigned(ACallbacks.CanUseSystemCompiler) and
       ACallbacks.CanUseSystemCompiler(AState.TargetVersion, CurrentVersion, RequiredVersion) then
    begin
      WriteLine(AOut, 'OK: System FPC version ' + CurrentVersion + ' is bootstrap-compatible');
      Exit(True);
    end;

    WriteLine(
      AOut,
      'System FPC version ' + CurrentVersion +
      ' is not bootstrap-compatible with target ' + AState.TargetVersion
    );
  end
  else
    WriteLine(AOut, 'No system FPC compiler found');

  InstalledBootstrapVersion := '';
  InstalledBootstrapExe := '';
  if Assigned(ACallbacks.TryResolveInstalledBootstrapCompiler) and
     ACallbacks.TryResolveInstalledBootstrapCompiler(
       AState.TargetVersion,
       RequiredVersion,
       InstalledBootstrapVersion,
       InstalledBootstrapExe
     ) then
  begin
    WriteLine(AOut, 'OK: Installed bootstrap compiler available at: ' + InstalledBootstrapExe);
    Exit(True);
  end;

  if Assigned(ACallbacks.IsBootstrapAvailable) and
     ACallbacks.IsBootstrapAvailable(RequiredVersion) then
  begin
    BootstrapPath := ResolveBootstrapCompilerPath(RequiredVersion, ACallbacks);
    WriteLine(AOut, 'OK: Bootstrap compiler available at: ' + BootstrapPath);
    Exit(True);
  end;

  WriteLine(AOut, 'Bootstrap compiler ' + RequiredVersion + ' not found locally');
  WriteLine(AOut, 'Attempting to download from resource repository...');
  WriteLine(AOut);

  if Assigned(ACallbacks.EnsureResourceRepository) and
     ACallbacks.EnsureResourceRepository() then
  begin
    if Assigned(ACallbacks.HasResourceRepositoryBootstrapCompiler) and
       ACallbacks.HasResourceRepositoryBootstrapCompiler(RequiredVersion, AState.Platform) then
    begin
      WriteLine(AOut,
        'OK: Bootstrap compiler ' + RequiredVersion + ' found in resource repository');
      BootstrapPath := ResolveBootstrapCompilerPath(RequiredVersion, ACallbacks);

      if Assigned(ACallbacks.InstallBootstrapFromResourceRepository) and
         ACallbacks.InstallBootstrapFromResourceRepository(
           RequiredVersion,
           AState.Platform,
           ExtractFileDir(BootstrapPath)
         ) then
      begin
        WriteLine(AOut, 'OK: Bootstrap compiler downloaded and installed successfully');
        WriteLine(AOut, '  Location: ' + BootstrapPath);
        Exit(True);
      end;

        WriteLine(AErr,
          _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BOOTSTRAP_INSTALL_FAILED, ['from repository']));
    end
    else
    begin
      WriteLine(AOut,
        'Exact version ' + RequiredVersion + ' not available, searching for alternatives...');

      BestVersion := '';
      if Assigned(ACallbacks.FindBestResourceRepositoryBootstrapVersion) then
        BestVersion := ACallbacks.FindBestResourceRepositoryBootstrapVersion(
          AState.TargetVersion,
          AState.Platform
        );

      if BestVersion <> '' then
      begin
        WriteLine(AOut, 'OK: Found alternative bootstrap compiler: ' + BestVersion);
        BootstrapPath := ResolveBootstrapCompilerPath(BestVersion, ACallbacks);

        if Assigned(ACallbacks.InstallBootstrapFromResourceRepository) and
           ACallbacks.InstallBootstrapFromResourceRepository(
             BestVersion,
             AState.Platform,
             ExtractFileDir(BootstrapPath)
           ) then
        begin
          WriteLine(AOut, 'OK: Bootstrap compiler ' + BestVersion + ' installed successfully');
          WriteLine(AOut, '  Location: ' + BootstrapPath);
          Exit(True);
        end;

        WriteLine(AErr,
          _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BOOTSTRAP_INSTALL_FAILED, [BestVersion]));
      end
      else
        WriteLine(AErr, 'No bootstrap compiler available for platform ' + AState.Platform);
    end;
  end
  else
    WriteLine(AErr, _(MSG_ERROR) + ': ' + _(CMD_FPC_REPO_INIT_FAILED));

  WriteLine(AErr);
  WriteLine(AErr, 'Unable to automatically download bootstrap compiler.');
  WriteLine(AErr,
    'To build FPC ' + AState.TargetVersion + ' from source, you need FPC ' + RequiredVersion);
  WriteLine(AErr);
  WriteLine(AErr, 'Options:');
  WriteLine(AErr, '  1. Install FPC ' + RequiredVersion + ' system-wide');
  WriteLine(AErr, '  2. Contact maintainer to add bootstrap compiler to resource repository');
  WriteLine(AErr, '  3. Use binary installation instead of source build');
  WriteLine(AErr);
end;

function ExecuteFPCBuilderBuildFromSourceCore(
  const AState: TFPCBuilderBuildState;
  const AOut, AErr: IOutput;
  const ACallbacks: TFPCBuilderBuildCallbacks
): Boolean;
var
  BuildPlan: TFPCBuilderBuildPlan;
  BuildResult: TProcessResult;
  BootstrapFPC: string;
  CurrentFPC: string;
  InstalledBootstrapVersion: string;
  RequiredBootstrapVersion: string;
  ParamIndex: Integer;
begin
  Result := False;

  if (not Assigned(ACallbacks.SourceDirectoryExists)) or
     (not ACallbacks.SourceDirectoryExists(AState.SourceDir)) then
  begin
    WriteLine(AErr, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [AState.SourceDir]));
    Exit(False);
  end;

  WriteLine(AOut, 'Building FPC from source...');
  WriteLine(AOut, 'Source directory: ' + AState.SourceDir);
  WriteLine(AOut, 'Install directory: ' + AState.InstallDir);

  if Assigned(ACallbacks.PrepareSourceTree) then
    ACallbacks.PrepareSourceTree(AState.SourceDir);

  if Assigned(ACallbacks.EnsureInstallDirectory) then
    ACallbacks.EnsureInstallDirectory(AState.InstallDir);

  RequiredBootstrapVersion := '';
  if Assigned(ACallbacks.GetRequiredBootstrapVersion) then
    RequiredBootstrapVersion := ACallbacks.GetRequiredBootstrapVersion(AState.TargetVersion);

  BootstrapFPC := '';
  InstalledBootstrapVersion := '';
  if Assigned(ACallbacks.TryResolveInstalledBootstrapCompiler) and
     ACallbacks.TryResolveInstalledBootstrapCompiler(
       AState.TargetVersion,
       RequiredBootstrapVersion,
       InstalledBootstrapVersion,
       BootstrapFPC
     ) then
  begin
    WriteLine(AOut,
      'Using installed FPC ' + InstalledBootstrapVersion + ' as bootstrap compiler');
    WriteLine(AOut, 'Bootstrap compiler: ' + BootstrapFPC);
  end
  else
  begin
    CurrentFPC := '';
    if Assigned(ACallbacks.GetCurrentCompilerVersion) then
      CurrentFPC := ACallbacks.GetCurrentCompilerVersion();

    if Assigned(ACallbacks.CanUseSystemCompiler) and
       ACallbacks.CanUseSystemCompiler(
         AState.TargetVersion,
         CurrentFPC,
         RequiredBootstrapVersion
       ) then
    begin
      WriteLine(AOut,
        'Using system FPC ' + CurrentFPC + ' as bootstrap compiler');
      BootstrapFPC := 'fpc';
    end
    else if CurrentFPC <> '' then
    begin
      WriteLine(AErr,
        'Warning: System FPC ' + CurrentFPC +
        ' is not bootstrap-compatible with target ' + AState.TargetVersion);
      WriteLine(AErr,
        'Build will likely fail without a compatible bootstrap compiler');
      BootstrapFPC := '';
    end
    else
    begin
      WriteLine(AErr, 'Warning: No FPC compiler found');
      WriteLine(AErr,
        'Build will likely fail without a bootstrap compiler');
      BootstrapFPC := '';
    end;
  end;

  if not Assigned(ACallbacks.ResolveBuildPlan) then
    Exit(False);

  BuildPlan := ACallbacks.ResolveBuildPlan(
    AState.InstallDir,
    BootstrapFPC,
    AState.ParallelJobs
  );

  WriteText(AOut, 'Executing: ' + BuildPlan.MakeCommand);
  for ParamIndex := 0 to High(BuildPlan.Params) do
    WriteText(AOut, ' ' + BuildPlan.Params[ParamIndex]);
  WriteLine(AOut);

  if not Assigned(ACallbacks.ExecuteBuildPlan) then
    Exit(False);

  BuildResult := ACallbacks.ExecuteBuildPlan(BuildPlan, AState.SourceDir);
  Result := BuildResult.Success;

  if not Result then
  begin
    WriteLine(AErr, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_BUILD_FAILED, [BuildResult.ExitCode]));
    WriteLine(AErr);
    WriteLine(AErr, 'Common causes:');
    WriteLine(AErr,
      '  1. Wrong bootstrap compiler version (FPC builds require specific FPC versions)');
    WriteLine(AErr,
      '  2. Missing build dependencies (make, binutils, etc.)');
    WriteLine(AErr);
    WriteLine(AErr, 'To diagnose the issue, try running manually:');
    WriteLine(AErr, '  cd ' + AState.SourceDir);
    WriteLine(AErr, '  make all');
    WriteLine(AErr);
    WriteLine(AErr,
      'Note: Building from source requires a compatible bootstrap FPC compiler.');
    WriteLine(AErr,
      '      Consider using binary installation if available.');
  end;
end;

end.
