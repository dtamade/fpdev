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

  ILazarusGitRuntime = interface
    ['{EFB7811D-165D-48E3-BCA4-79842AAB3FA7}']
    function BackendAvailable: Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function GetLastError: string;
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
  const Outp, Errp: IOutput;
  const AGit: ILazarusGitRuntime
): Boolean;

function ExecuteLazarusCleanPlanCore(
  const APlan: TLazarusSourcePlan;
  const Outp: IOutput;
  ACleanSource: TLazarusSourceCleaner
): Boolean;

function CreateLazarusLaunchPlanCore(
  const AInstallRoot, ARequestedVersion, ACurrentVersion: string
): TLazarusLaunchPlan;
function BuildLazarusInstalledExecutablePathCore(
  const AInstallRoot, AVersion: string;
  const AIsWindows: Boolean
): string;

function ExecuteLazarusLaunchPlanCore(
  const APlan: TLazarusLaunchPlan;
  const Outp: IOutput;
  AIsInstalled: TLazarusVersionInstalledChecker;
  ALaunchExecutable: TLazarusExecutableLauncher
): Boolean;

implementation

uses
  fpdev.paths,
  fpdev.constants,
  fpdev.fpc.installversionflow,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.utils.git;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function NormalizeGitPullErrorDetail(const AError: string): string;
var
  LError: string;
begin
  LError := Trim(AError);
  case ClassifyGitPullFailure(LError) of
    gpfkDirtyWorktree:
      Exit(_(MSG_GIT_UPDATE_DIRTY_WORKTREE));
    gpfkDetachedHead:
      Exit(_(MSG_GIT_UPDATE_DETACHED_HEAD));
    gpfkDivergedHistory:
      Exit(_(MSG_GIT_UPDATE_DIVERGED_HISTORY));
    gpfkUnknown:
      ;
  end;

  if LError = '' then
    Result := _(MSG_FAILED)
  else
    Result := LError;
end;

function PathContainsEntry(const APathList, AEntry: string): Boolean;
var
  Remaining: string;
  NextPos: SizeInt;
  Item: string;
begin
  Result := False;
  if (APathList = '') or (AEntry = '') then
    Exit;

  Remaining := APathList;
  while Remaining <> '' do
  begin
    NextPos := Pos(PathSeparator, Remaining);
    if NextPos > 0 then
    begin
      Item := Copy(Remaining, 1, NextPos - 1);
      Delete(Remaining, 1, NextPos);
    end
    else
    begin
      Item := Remaining;
      Remaining := '';
    end;

    if Item = AEntry then
      Exit(True);
  end;
end;

function BuildUnixLazarusToolPath(const AFPCBinDir, ACurrentPath: string): string;
const
  LAZARUS_UNIX_FALLBACK_BIN_DIRS: array[0..1] of string = (
    '/usr/bin',
    '/bin'
  );
var
  Remaining: string;
  NextPos: SizeInt;
  Item: string;
  FallbackDir: string;

  procedure AppendUniquePathEntry(const AEntry: string);
  begin
    if Trim(AEntry) = '' then
      Exit;
    if PathContainsEntry(Result, AEntry) then
      Exit;
    if Result = '' then
      Result := AEntry
    else
      Result := Result + PathSeparator + AEntry;
  end;
begin
  Result := '';
  AppendUniquePathEntry(AFPCBinDir);
  for FallbackDir in LAZARUS_UNIX_FALLBACK_BIN_DIRS do
    AppendUniquePathEntry(FallbackDir);

  Remaining := ACurrentPath;
  while Remaining <> '' do
  begin
    NextPos := Pos(PathSeparator, Remaining);
    if NextPos > 0 then
    begin
      Item := Copy(Remaining, 1, NextPos - 1);
      Delete(Remaining, 1, NextPos);
    end
    else
    begin
      Item := Remaining;
      Remaining := '';
    end;
    AppendUniquePathEntry(Item);
  end;
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
  Result.FPCPath := BuildFPCInstalledExecutablePathCore(
    BuildFPCInstallDirFromInstallRoot(ASettingsInstallRoot, AFPCVersion)
  );
  {$IFDEF MSWINDOWS}
  Result.MakePath := 'make.exe';
  {$ELSE}
  Result.MakePath := UNIX_MAKE_PATH;
  {$ENDIF}
  Result.FPCSourcePath := BuildFPCSourceInstallPathCore(ASettingsInstallRoot, AFPCVersion);
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
var
  EffectiveJobs: Integer;
begin
  Result := Default(TLazarusBuildPlan);
  Result.SourceDir := ASourceDir;
  Result.InstallDir := AInstallDir;
  Result.FPCVersion := AFPCVersion;
  Result.FPCBinDir := BuildFPCInstallDirFromInstallRoot(ASettingsInstallRoot, AFPCVersion) +
    PathDelim + 'bin';
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
  if AParallelJobs > 0 then
    EffectiveJobs := AParallelJobs
  else
    EffectiveJobs := 1;

  if not AIsWindows then
    EffectiveJobs := 1;

  Result.Params[4] := '-j' + IntToStr(EffectiveJobs);

  if AIsWindows then
  begin
    SetLength(Result.EnvVars, 1);
    Result.EnvVars[0] := 'PATH=' + Result.FPCBinDir + PathSeparator + ACurrentPath;
  end
  else
  begin
    SetLength(Result.EnvVars, 2);
    Result.EnvVars[0] := 'PATH=' + BuildUnixLazarusToolPath(Result.FPCBinDir, ACurrentPath);
    Result.EnvVars[1] := 'INSTALL=/usr/bin/install';
  end;
end;

function BuildLazarusInstalledExecutablePathCore(
  const AInstallRoot, AVersion: string;
  const AIsWindows: Boolean
): string;
begin
  if AIsWindows then
    Result := AInstallRoot + PathDelim + 'lazarus' + PathDelim + AVersion +
      PathDelim + 'lazarus.exe'
  else
    Result := AInstallRoot + PathDelim + 'lazarus' + PathDelim + AVersion +
      PathDelim + 'bin' + PathDelim + 'lazarus-ide';
end;

function ExecuteLazarusUpdatePlanCore(
  const APlan: TLazarusSourcePlan;
  const Outp, Errp: IOutput;
  const AGit: ILazarusGitRuntime
): Boolean;
var
  LError: string;
begin
  Result := False;

  if (APlan.Version = '') or (APlan.SourceDir = '') then
    Exit;

  if AGit = nil then
    Exit;

  if not AGit.BackendAvailable then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _(CMD_LAZARUS_NO_GIT_BACKEND));
    Exit;
  end;

  if not AGit.IsRepository(APlan.SourceDir) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_NOT_GIT_REPO, [APlan.SourceDir]));
    Exit;
  end;

  if not AGit.HasRemote(APlan.SourceDir) then
  begin
    WriteLine(Outp, _(MSG_LAZARUS_SOURCE_LOCAL_ONLY) + ' ' + APlan.SourceDir);
    Exit(True);
  end;

  if AGit.Pull(APlan.SourceDir) then
  begin
    WriteLine(Outp, _(CMD_LAZARUS_UPDATE_DONE) + ': ' + APlan.SourceDir);
    Exit(True);
  end;

  LError := NormalizeGitPullErrorDetail(AGit.GetLastError);
  WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_GIT_PULL_FAILED, [LError]));
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
    Result.ExecutablePath := BuildLazarusInstalledExecutablePathCore(
      AInstallRoot,
      UseVersion,
      {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
    );
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
