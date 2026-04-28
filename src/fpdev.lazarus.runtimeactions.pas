unit fpdev.lazarus.runtimeactions;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.lazarus.commandflow,
  fpdev.lazarus.installcallbacks,
  fpdev.output.intf;

type
  TLazarusExecutablePathResolver = function(
    const AInstallPath: string
  ): string of object;

function TestLazarusInstallationCore(
  const Outp, Errp: IOutput;
  const AVersion: string;
  AIsVersionInstalled: TLazarusInstallStateChecker;
  AResolveInstallPath: TLazarusInstallPathResolver;
  AResolveExecutablePath: TLazarusExecutablePathResolver
): Boolean;

function LaunchLazarusIDECore(
  const AInstallRoot, ARequestedVersion, ACurrentVersion: string;
  const Outp: IOutput;
  AResolveInstallPath: TLazarusInstallPathResolver;
  AResolveExecutablePath: TLazarusExecutablePathResolver;
  AIsVersionInstalled: TLazarusVersionInstalledChecker;
  ALaunchExecutable: TLazarusExecutableLauncher
): Boolean;

function ConfigureLazarusIDECore(
  const AConfigManager: IConfigManager;
  const Outp, Errp: IOutput;
  const AVersion: string;
  AIsVersionInstalled: TLazarusInstallStateChecker;
  AResolveInstallPath: TLazarusInstallPathResolver;
  AResolveCompatibleFPCVersion: TLazarusCompatibleFPCVersionResolver
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.lazarus.config,
  fpdev.output.console,
  fpdev.utils,
  fpdev.utils.process;

function TestLazarusInstallationCore(
  const Outp, Errp: IOutput;
  const AVersion: string;
  AIsVersionInstalled: TLazarusInstallStateChecker;
  AResolveInstallPath: TLazarusInstallPathResolver;
  AResolveExecutablePath: TLazarusExecutablePathResolver
): Boolean;
var
  LResult: TProcessResult;
  LazarusExe: string;
begin
  Result := False;
  if (not Assigned(AIsVersionInstalled)) or
     (not Assigned(AResolveInstallPath)) or
     (not Assigned(AResolveExecutablePath)) then
    Exit;

  if not AIsVersionInstalled(AVersion) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_USE_NOT_INSTALLED, [AVersion]));
    Exit;
  end;

  try
    LazarusExe := AResolveExecutablePath(AResolveInstallPath(AVersion));

    if Outp <> nil then
      Outp.WriteLn(_Fmt(CMD_LAZARUS_TEST_START, [AVersion]));

    LResult := TProcessExecutor.Execute(LazarusExe, ['--version'], '');
    Result := LResult.Success;

    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_LAZARUS_TEST_PASSED, [AVersion]));
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_Fmt(CMD_LAZARUS_TEST_FAILED, [AVersion]))
      else if Outp <> nil then
        Outp.WriteLn(_Fmt(CMD_LAZARUS_TEST_FAILED, [AVersion]));
    end;
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['testing installation', E.Message]));
      Result := False;
    end;
  end;
end;

function LaunchLazarusIDECore(
  const AInstallRoot, ARequestedVersion, ACurrentVersion: string;
  const Outp: IOutput;
  AResolveInstallPath: TLazarusInstallPathResolver;
  AResolveExecutablePath: TLazarusExecutablePathResolver;
  AIsVersionInstalled: TLazarusVersionInstalledChecker;
  ALaunchExecutable: TLazarusExecutableLauncher
): Boolean;
var
  LaunchPlan: TLazarusLaunchPlan;
begin
  Result := False;
  if (not Assigned(AResolveInstallPath)) or
     (not Assigned(AResolveExecutablePath)) or
     (not Assigned(AIsVersionInstalled)) or
     (not Assigned(ALaunchExecutable)) then
    Exit;

  try
    LaunchPlan := CreateLazarusLaunchPlanCore(AInstallRoot, ARequestedVersion, ACurrentVersion);
    if LaunchPlan.Version <> '' then
      LaunchPlan.ExecutablePath := AResolveExecutablePath(
        AResolveInstallPath(LaunchPlan.Version)
      );
    Result := ExecuteLazarusLaunchPlanCore(
      LaunchPlan,
      Outp,
      AIsVersionInstalled,
      ALaunchExecutable
    );
  except
    on E: Exception do
    begin
      if Outp <> nil then
        Outp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['launching IDE', E.Message]));
      Result := False;
    end;
  end;
end;

function ConfigureLazarusIDECore(
  const AConfigManager: IConfigManager;
  const Outp, Errp: IOutput;
  const AVersion: string;
  AIsVersionInstalled: TLazarusInstallStateChecker;
  AResolveInstallPath: TLazarusInstallPathResolver;
  AResolveCompatibleFPCVersion: TLazarusCompatibleFPCVersionResolver
): Boolean;
var
  ConfigurePlan: TLazarusConfigurePlan;
  IDEConfig: TLazarusIDEConfig;
  Settings: TFPDevSettings;
  LO, LE: IOutput;
begin
  Result := False;
  if (AConfigManager = nil) or
     (not Assigned(AIsVersionInstalled)) or
     (not Assigned(AResolveInstallPath)) or
     (not Assigned(AResolveCompatibleFPCVersion)) then
    Exit;

  LO := Outp;
  if LO = nil then
    LO := TConsoleOutput.Create(False) as IOutput;
  LE := Errp;
  if LE = nil then
    LE := TConsoleOutput.Create(True) as IOutput;

  if not AIsVersionInstalled(AVersion) then
  begin
    LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_USE_NOT_INSTALLED, [AVersion]));
    Exit;
  end;

  try
    Settings := AConfigManager.GetSettingsManager.GetSettings;
    ConfigurePlan := CreateLazarusConfigurePlanCore(
      AVersion,
      AResolveInstallPath(AVersion),
      Settings.InstallRoot,
      AResolveCompatibleFPCVersion(AVersion),
      get_env('FPDEV_LAZARUS_CONFIG_ROOT'),
      get_env('HOME'),
      get_env('APPDATA')
    );

    IDEConfig := TLazarusIDEConfig.Create(ConfigurePlan.ConfigDir);
    try
      Result := ApplyLazarusConfigurePlanCore(ConfigurePlan, LO, LE, IDEConfig);
    finally
      IDEConfig.Free;
    end;
  except
    on E: Exception do
    begin
      LE.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_EXCEPTION, ['IDE configuration', E.Message]));
      Result := False;
    end;
  end;
end;

end.
