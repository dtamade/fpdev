unit fpdev.lazarus.commandflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.lazarus.config;

type
  TLazarusBuildArgs = array of string;
  TLazarusBuildEnvVars = array of string;

  TLazarusInstallPlan = record
    Version: string;
    InstallPath: string;
    SourceDir: string;
    FPCVersion: string;
    ConfigureAfterInstall: Boolean;
    NeedsSourceFallbackWarning: Boolean;
  end;

  TLazarusConfigurePlan = record
    Version: string;
    InstallPath: string;
    ConfigDir: string;
    FPCVersion: string;
    FPCPath: string;
    FPCSourcePath: string;
    MakePath: string;
    CompilerExists: Boolean;
    FPCSourceExists: Boolean;
  end;

  TLazarusSourcePlan = record
    Version: string;
    SourceDir: string;
  end;

  TLazarusBuildPlan = record
    SourceDir: string;
    InstallDir: string;
    FPCVersion: string;
    FPCBinDir: string;
    FPCExecutable: string;
    MakeCommand: string;
    Params: TLazarusBuildArgs;
    EnvVars: TLazarusBuildEnvVars;
  end;

  TLazarusLaunchPlan = record
    Version: string;
    ExecutablePath: string;
  end;

  TLazarusSourceDownloader = function(const AVersion, ATargetDir: string): Boolean of object;
  TLazarusSourceBuilder = function(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean of object;
  TLazarusEnvironmentSetup = function(const AVersion: string): Boolean of object;
  TLazarusIDEConfigurator = function(const Outp, Errp: IOutput; const AVersion: string): Boolean of object;
  TLazarusGitPathCheck = function(const APath: string): Boolean of object;
  TLazarusSourceCleaner = function(const ASourceDir: string): Integer of object;
  TLazarusVersionInstalledChecker = function(const AVersion: string): Boolean of object;
  TLazarusExecutableLauncher = function(const AExecutable: string): Boolean of object;

function CreateLazarusInstallPlanCore(
  const AInstallRoot, AVersion, ARequestedFPCVersion, ARecommendedFPCVersion: string;
  AFromSource, AConfigure: Boolean
): TLazarusInstallPlan;

function ExecuteLazarusInstallPlanCore(
  const APlan: TLazarusInstallPlan;
  const Outp, Errp: IOutput;
  ADownloadSource: TLazarusSourceDownloader;
  ABuildFromSource: TLazarusSourceBuilder;
  ASetupEnvironment: TLazarusEnvironmentSetup;
  AConfigureIDE: TLazarusIDEConfigurator
): Boolean;

function ResolveLazarusConfigDirCore(
  const AVersion, AConfigRoot, AHomeDir, AAppDataDir: string
): string;

function CreateLazarusConfigurePlanCore(
  const AVersion, AInstallPath, ASettingsInstallRoot, AFPCVersion, AConfigRoot,
  AHomeDir, AAppDataDir: string
): TLazarusConfigurePlan;

function ApplyLazarusConfigurePlanCore(
  const APlan: TLazarusConfigurePlan;
  const Outp, Errp: IOutput;
  AIDEConfig: TLazarusIDEConfig
): Boolean;

function CreateLazarusSourcePlanCore(
  const AInstallRoot, ARequestedVersion, ACurrentVersion: string
): TLazarusSourcePlan;

function CreateLazarusBuildPlanCore(
  const ASourceDir, AInstallDir, ASettingsInstallRoot, AFPCVersion: string;
  const AParallelJobs: Integer;
  const AMakeCommand, ACurrentPath: string;
  const AIsWindows: Boolean
): TLazarusBuildPlan;

function ExecuteLazarusUpdatePlanCore(
  const APlan: TLazarusSourcePlan;
  AGitBackendAvailable: Boolean;
  AIsRepository: TLazarusGitPathCheck;
  AHasRemote: TLazarusGitPathCheck;
  APull: TLazarusGitPathCheck
): Boolean;

function ExecuteLazarusCleanPlanCore(
  const APlan: TLazarusSourcePlan;
  const Outp: IOutput;
  ACleanSource: TLazarusSourceCleaner
): Boolean;

function CreateLazarusLaunchPlanCore(
  const AInstallRoot, ARequestedVersion, ACurrentVersion: string
): TLazarusLaunchPlan;

function ExecuteLazarusLaunchPlanCore(
  const APlan: TLazarusLaunchPlan;
  const Outp: IOutput;
  AIsInstalled: TLazarusVersionInstalledChecker;
  ALaunchExecutable: TLazarusExecutableLauncher
): Boolean;

implementation

uses
  fpdev.constants,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function JoinBaseAndName(const ABase, AName: string): string;
begin
  if ABase <> '' then
    Result := ExcludeTrailingPathDelimiter(ABase) + PathDelim + AName
  else
    Result := PathDelim + AName;
end;

function CreateLazarusInstallPlanCore(
  const AInstallRoot, AVersion, ARequestedFPCVersion, ARecommendedFPCVersion: string;
  AFromSource, AConfigure: Boolean
): TLazarusInstallPlan;
begin
  Result := Default(TLazarusInstallPlan);
  Result.Version := AVersion;
  Result.InstallPath := AInstallRoot + PathDelim + 'lazarus' + PathDelim + AVersion;
  Result.SourceDir := AInstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-' + AVersion;
  if ARequestedFPCVersion <> '' then
    Result.FPCVersion := ARequestedFPCVersion
  else
    Result.FPCVersion := ARecommendedFPCVersion;
  Result.ConfigureAfterInstall := AConfigure;
  Result.NeedsSourceFallbackWarning := not AFromSource;
end;

function ExecuteLazarusInstallPlanCore(
  const APlan: TLazarusInstallPlan;
  const Outp, Errp: IOutput;
  ADownloadSource: TLazarusSourceDownloader;
  ABuildFromSource: TLazarusSourceBuilder;
  ASetupEnvironment: TLazarusEnvironmentSetup;
  AConfigureIDE: TLazarusIDEConfigurator
): Boolean;
begin
  Result := False;

  if (not Assigned(ADownloadSource)) or (not Assigned(ABuildFromSource)) or
     (not Assigned(ASetupEnvironment)) then
    Exit;

  if APlan.NeedsSourceFallbackWarning then
    WriteLine(Outp, _(MSG_WARNING) + ': binary package path unavailable, fallback to source build');

  if not ADownloadSource(APlan.Version, APlan.SourceDir) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _(CMD_LAZARUS_SOURCE_DOWNLOAD_FAILED));
    Exit;
  end;

  if not ABuildFromSource(APlan.SourceDir, APlan.InstallPath, APlan.FPCVersion) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _(CMD_LAZARUS_SOURCE_BUILD_FAILED));
    Exit;
  end;

  Result := ASetupEnvironment(APlan.Version);
  if not Result then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _(CMD_LAZARUS_ENV_SETUP_FAILED));
    Exit;
  end;

  if Result and APlan.ConfigureAfterInstall and Assigned(AConfigureIDE) then
  begin
    WriteLine(Outp);
    if not AConfigureIDE(Outp, Errp, APlan.Version) then
      WriteLine(
        Errp,
        _(MSG_WARNING) + ': IDE configuration incomplete, run "fpdev lazarus configure ' +
        APlan.Version + '" manually'
      );
  end;
end;

function ResolveLazarusConfigDirCore(
  const AVersion, AConfigRoot, AHomeDir, AAppDataDir: string
): string;
var
  ConfigDirName: string;
begin
  {$IFDEF MSWINDOWS}
  ConfigDirName := 'lazarus-' + AVersion;
  if AConfigRoot <> '' then
    Result := JoinBaseAndName(AConfigRoot, ConfigDirName)
  else
    Result := JoinBaseAndName(AAppDataDir, ConfigDirName);
  {$ELSE}
  if AAppDataDir = '' then;
  ConfigDirName := '.lazarus-' + AVersion;
  if AConfigRoot <> '' then
    Result := JoinBaseAndName(AConfigRoot, ConfigDirName)
  else
    Result := JoinBaseAndName(AHomeDir, ConfigDirName);
  {$ENDIF}
end;

function CreateLazarusConfigurePlanCore(
  const AVersion, AInstallPath, ASettingsInstallRoot, AFPCVersion, AConfigRoot,
  AHomeDir, AAppDataDir: string
): TLazarusConfigurePlan;
begin
  Result := Default(TLazarusConfigurePlan);
  Result.Version := AVersion;
  Result.InstallPath := AInstallPath;
  Result.ConfigDir := ResolveLazarusConfigDirCore(AVersion, AConfigRoot, AHomeDir, AAppDataDir);
  Result.FPCVersion := AFPCVersion;
  Result.FPCPath := ASettingsInstallRoot + PathDelim + 'fpc' + PathDelim + AFPCVersion +
                    PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF MSWINDOWS}
  Result.FPCPath := Result.FPCPath + '.exe';
  Result.MakePath := 'make.exe';
  {$ELSE}
  Result.MakePath := UNIX_MAKE_PATH;
  {$ENDIF}
  Result.FPCSourcePath := ASettingsInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-' + AFPCVersion;
  Result.CompilerExists := FileExists(Result.FPCPath);
  Result.FPCSourceExists := DirectoryExists(Result.FPCSourcePath);
end;

function ApplyLazarusConfigurePlanCore(
  const APlan: TLazarusConfigurePlan;
  const Outp, Errp: IOutput;
  AIDEConfig: TLazarusIDEConfig
): Boolean;
var
  BackupPath: string;
begin
  Result := False;
  if AIDEConfig = nil then
    Exit;

  WriteLine(Outp, _Fmt(MSG_LAZARUS_CONFIGURING, [APlan.Version]));
  WriteLine(Outp, _Fmt(MSG_LAZARUS_INSTALL_PATH, [APlan.InstallPath]));
  WriteLine(Outp, _Fmt(MSG_LAZARUS_CONFIG_DIR, [APlan.ConfigDir]));

  BackupPath := AIDEConfig.BackupConfig;
  if BackupPath <> '' then
    WriteLine(Outp, 'Configuration backed up to: ' + BackupPath);

  if APlan.CompilerExists then
  begin
    if AIDEConfig.SetCompilerPath(APlan.FPCPath) then
      WriteLine(Outp, _Fmt(MSG_LAZARUS_COMPILER_SET, [APlan.FPCPath]))
    else
      WriteLine(Errp, _(MSG_LAZARUS_COMPILER_WARN));
  end
  else
    WriteLine(Errp, _Fmt(MSG_LAZARUS_FPC_NOT_FOUND, [APlan.FPCPath]));

  if AIDEConfig.SetLibraryPath(APlan.InstallPath) then
    WriteLine(Outp, _Fmt(MSG_LAZARUS_DIR_SET, [APlan.InstallPath]))
  else
    WriteLine(Errp, _(MSG_LAZARUS_DIR_WARN));

  if APlan.FPCSourceExists then
  begin
    if AIDEConfig.SetFPCSourcePath(APlan.FPCSourcePath) then
      WriteLine(Outp, _(MSG_LAZARUS_FPC_SRC_SET));
  end;

  if AIDEConfig.SetMakePath(APlan.MakePath) then
    WriteLine(Outp, _Fmt(MSG_LAZARUS_MAKE_SET, [APlan.MakePath]));

  if AIDEConfig.ValidateConfig then
  begin
    WriteLine(Outp);
    WriteLine(Outp, _(CMD_LAZARUS_CONFIG_DONE));
    WriteLine(Outp);
    WriteLine(Outp, _(MSG_LAZARUS_CONFIG_SUMMARY));
    WriteLine(Outp, AIDEConfig.GetConfigSummary);
    Result := True;
  end
  else
  begin
    WriteLine(Outp);
    WriteLine(Errp, _(MSG_WARNING) + ': ' + _(CMD_LAZARUS_CONFIG_INCOMPLETE));
    WriteLine(Errp, _(CMD_LAZARUS_CONFIG_VERIFY));
    Result := True;
  end;
end;

function CreateLazarusSourcePlanCore(
  const AInstallRoot, ARequestedVersion, ACurrentVersion: string
): TLazarusSourcePlan;
var
  UseVersion: string;
begin
  Result := Default(TLazarusSourcePlan);
  if ARequestedVersion <> '' then
    UseVersion := ARequestedVersion
  else
    UseVersion := ACurrentVersion;

  Result.Version := UseVersion;
  if UseVersion <> '' then
    Result.SourceDir := AInstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-' + UseVersion;
end;

function CreateLazarusBuildPlanCore(
  const ASourceDir, AInstallDir, ASettingsInstallRoot, AFPCVersion: string;
  const AParallelJobs: Integer;
  const AMakeCommand, ACurrentPath: string;
  const AIsWindows: Boolean
): TLazarusBuildPlan;
begin
  Result := Default(TLazarusBuildPlan);
  Result.SourceDir := ASourceDir;
  Result.InstallDir := AInstallDir;
  Result.FPCVersion := AFPCVersion;
  Result.FPCBinDir := ASettingsInstallRoot + PathDelim + 'fpc' + PathDelim + AFPCVersion + PathDelim + 'bin';
  Result.FPCExecutable := Result.FPCBinDir + PathDelim + 'fpc';
  if AIsWindows then
    Result.FPCExecutable := Result.FPCExecutable + '.exe';

  if Trim(AMakeCommand) <> '' then
    Result.MakeCommand := AMakeCommand
  else
    Result.MakeCommand := 'make';

  SetLength(Result.Params, 5);
  Result.Params[0] := 'all';
  Result.Params[1] := 'install';
  Result.Params[2] := 'INSTALL_PREFIX=' + AInstallDir;
  Result.Params[3] := 'FPC=' + Result.FPCExecutable;
  Result.Params[4] := '-j' + IntToStr(AParallelJobs);

  SetLength(Result.EnvVars, 1);
  Result.EnvVars[0] := 'PATH=' + Result.FPCBinDir + PathSeparator + ACurrentPath;
end;

function ExecuteLazarusUpdatePlanCore(
  const APlan: TLazarusSourcePlan;
  AGitBackendAvailable: Boolean;
  AIsRepository: TLazarusGitPathCheck;
  AHasRemote: TLazarusGitPathCheck;
  APull: TLazarusGitPathCheck
): Boolean;
begin
  Result := False;

  if (APlan.Version = '') or (APlan.SourceDir = '') then
    Exit;

  if not AGitBackendAvailable then
    Exit;

  if (not Assigned(AIsRepository)) or (not Assigned(AHasRemote)) or (not Assigned(APull)) then
    Exit;

  if not AIsRepository(APlan.SourceDir) then
    Exit;

  if not AHasRemote(APlan.SourceDir) then
    Exit(True);

  Result := APull(APlan.SourceDir);
  if not Result then
    Result := True;
end;

function ExecuteLazarusCleanPlanCore(
  const APlan: TLazarusSourcePlan;
  const Outp: IOutput;
  ACleanSource: TLazarusSourceCleaner
): Boolean;
begin
  Result := False;

  if (APlan.Version = '') or (APlan.SourceDir = '') or (not Assigned(ACleanSource)) then
    Exit;

  try
    ACleanSource(APlan.SourceDir);
    Result := True;
  except
    on E: Exception do
    begin
      WriteLine(Outp, 'CleanSources error: ' + E.Message);
      Result := False;
    end;
  end;
end;

function CreateLazarusLaunchPlanCore(
  const AInstallRoot, ARequestedVersion, ACurrentVersion: string
): TLazarusLaunchPlan;
var
  UseVersion: string;
begin
  Result := Default(TLazarusLaunchPlan);
  if ARequestedVersion <> '' then
    UseVersion := ARequestedVersion
  else
    UseVersion := ACurrentVersion;

  Result.Version := UseVersion;
  if UseVersion <> '' then
  begin
    {$IFDEF MSWINDOWS}
    Result.ExecutablePath := AInstallRoot + PathDelim + 'lazarus' + PathDelim + UseVersion + PathDelim + 'lazarus.exe';
    {$ELSE}
    Result.ExecutablePath := AInstallRoot + PathDelim + 'lazarus' + PathDelim + UseVersion + PathDelim + 'lazarus';
    {$ENDIF}
  end;
end;

function ExecuteLazarusLaunchPlanCore(
  const APlan: TLazarusLaunchPlan;
  const Outp: IOutput;
  AIsInstalled: TLazarusVersionInstalledChecker;
  ALaunchExecutable: TLazarusExecutableLauncher
): Boolean;
begin
  Result := False;

  if APlan.Version = '' then
  begin
    WriteLine(Outp, _(MSG_ERROR) + ': ' + _(CMD_LAZARUS_RUN_NO_VERSION));
    Exit;
  end;

  if (not Assigned(AIsInstalled)) or (not Assigned(ALaunchExecutable)) then
    Exit;

  if not AIsInstalled(APlan.Version) then
  begin
    WriteLine(Outp, _(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_RUN_NOT_INSTALLED, [APlan.Version]));
    Exit;
  end;

  WriteLine(Outp, _Fmt(CMD_LAZARUS_RUN_START, [APlan.Version]));
  if ALaunchExecutable(APlan.ExecutablePath) then
  begin
    WriteLine(Outp, _Fmt(CMD_LAZARUS_RUN_LAUNCHED, [APlan.Version]));
    Result := True;
  end
  else
    WriteLine(Outp, _(MSG_ERROR) + ': ' + _(CMD_LAZARUS_RUN_FAILED));
end;

end.
