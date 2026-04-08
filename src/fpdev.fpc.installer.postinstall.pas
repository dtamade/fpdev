unit fpdev.fpc.installer.postinstall;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf, fpdev.build.cache, fpdev.fpc.installer.config;

type
  TFPCSetupEnvironmentHandler = function(const AVersion,
    AInstallPath: string): Boolean of object;

  TFPCBinaryPostInstallActions = record
    ConfigGenerated: Boolean;
    EnvironmentConfigured: Boolean;
    CacheAttempted: Boolean;
    CacheSaved: Boolean;
  end;

function ExecuteFPCBinaryPostInstall(const AVersion, AInstallPath: string;
  const AOut, AErr: IOutput; AConfigGen: TFPCConfigGenerator;
  ASetupEnvironment: TFPCSetupEnvironmentHandler; ACache: TBuildCache;
  ANoCache: Boolean): TFPCBinaryPostInstallActions;

implementation

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ExecuteFPCBinaryPostInstall(const AVersion, AInstallPath: string;
  const AOut, AErr: IOutput; AConfigGen: TFPCConfigGenerator;
  ASetupEnvironment: TFPCSetupEnvironmentHandler; ACache: TBuildCache;
  ANoCache: Boolean): TFPCBinaryPostInstallActions;
begin
  Result := Default(TFPCBinaryPostInstallActions);
  if AConfigGen <> nil then;

  Result.ConfigGenerated := EnsureManagedFPCInstallLayout(AInstallPath, AVersion, AOut);
  if not Result.ConfigGenerated then
  begin
    WriteLine(AErr, '  Warning: Managed install layout incomplete');
    Exit;
  end;

  WriteLine(AOut, 'Setting up environment...');
  if Assigned(ASetupEnvironment) and ASetupEnvironment(AVersion, AInstallPath) then
  begin
    Result.EnvironmentConfigured := True;
    WriteLine(AOut, '  Environment configured');
  end
  else
    WriteLine(AErr, '  Warning: Environment setup incomplete');
  WriteLine(AOut);

  WriteLine(AOut, '===========================================');
  WriteLine(AOut, 'Installation completed!');
  WriteLine(AOut, 'FPC ' + AVersion + ' installed to: ' + AInstallPath);
  WriteLine(AOut);
  WriteLine(AOut, 'To activate this version, run:');
  WriteLine(AOut, '  fpdev fpc use ' + AVersion);
  WriteLine(AOut, '===========================================');

  if Assigned(ACache) and not ANoCache then
  begin
    Result.CacheAttempted := True;
    WriteLine(AOut);
    WriteLine(AOut, '[CACHE] Saving installation to cache...');
    Result.CacheSaved := ACache.SaveArtifacts(AVersion, AInstallPath);
    if Result.CacheSaved then
      WriteLine(AOut, '[CACHE] Installation cached successfully')
    else
      WriteLine(AOut, '[WARN] Failed to cache installation (non-fatal)');
  end;
end;

end.
