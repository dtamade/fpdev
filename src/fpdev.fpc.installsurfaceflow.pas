unit fpdev.fpc.installsurfaceflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.fpc.installversionflow;

type
  TFPCInstallValidateVersionFunc = function(const AVersion: string): Boolean of object;
  TFPCInstallIsVersionInstalledFunc = function(const AVersion: string): Boolean of object;
  TFPCInstallGetVersionInstallPathFunc = function(const AVersion: string): string of object;
  TFPCInstallRefreshMetadataFunc = function(const AVersion, AInstallPath: string): Boolean of object;
  TFPCInstallConfigureInstallerProc = procedure(ANoCache, AOfflineMode: Boolean) of object;

  TFPCInstallSurfaceState = record
    Version: string;
    InstallRoot: string;
    Prefix: string;
    FromSource: Boolean;
    Ensure: Boolean;
    NoCache: Boolean;
    OfflineMode: Boolean;
  end;

  TFPCInstallSurfaceCallbacks = record
    ValidateVersion: TFPCInstallValidateVersionFunc;
    GetVersionInstallPath: TFPCInstallGetVersionInstallPathFunc;
    IsVersionInstalled: TFPCInstallIsVersionInstalledFunc;
    ConfigureInstaller: TFPCInstallConfigureInstallerProc;
    RefreshInstallVerificationMetadata: TFPCInstallRefreshMetadataFunc;
    VerifyInstalledExecutable: TFPCInstallVerifyFunc;
    HasCachedArtifacts: TFPCInstallHasArtifactsFunc;
    RestoreCachedArtifacts: TFPCInstallRestoreArtifactsFunc;
    SaveBuildArtifacts: TFPCInstallSaveArtifactsFunc;
    DownloadSource: TFPCInstallDownloadSourceFunc;
    EnsureBootstrap: TFPCInstallEnsureBootstrapFunc;
    BuildFromSource: TFPCInstallBuildSourceFunc;
    WriteMetadata: TFPCInstallWriteMetadataFunc;
    SetupEnvironment: TFPCInstallSetupEnvironmentFunc;
    InstallBinary: TFPCInstallBinaryFunc;
  end;

function ExecuteManagedFPCInstallSurfaceCore(
  const AState: TFPCInstallSurfaceState;
  Outp, Errp: IOutput;
  const ACallbacks: TFPCInstallSurfaceCallbacks
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function ExecuteManagedFPCInstallSurfaceCore(
  const AState: TFPCInstallSurfaceState;
  Outp, Errp: IOutput;
  const ACallbacks: TFPCInstallSurfaceCallbacks
): Boolean;
var
  DefaultInstallPath: string;
  InstallPath: string;
  AlreadyInstalled: Boolean;
begin
  Result := False;

  if (not AState.OfflineMode) and Assigned(ACallbacks.ValidateVersion) and
     (not ACallbacks.ValidateVersion(AState.Version)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_Fmt(ERR_INVALID_VERSION, [AState.Version]));
    Exit;
  end;

  DefaultInstallPath := '';
  if Assigned(ACallbacks.GetVersionInstallPath) then
    DefaultInstallPath := ACallbacks.GetVersionInstallPath(AState.Version);
  InstallPath := ResolveFPCInstallPathCore(AState.Prefix, DefaultInstallPath);

  AlreadyInstalled := Assigned(ACallbacks.IsVersionInstalled) and
    ACallbacks.IsVersionInstalled(AState.Version);

  if Assigned(ACallbacks.ConfigureInstaller) then
    ACallbacks.ConfigureInstaller(AState.NoCache, AState.OfflineMode);

  Result := ExecuteFPCInstallVersionCore(
    AState.Version,
    AState.InstallRoot,
    DefaultInstallPath,
    AState.Prefix,
    AState.FromSource,
    AState.Ensure,
    AlreadyInstalled,
    not AState.NoCache,
    AState.OfflineMode,
    Outp,
    Errp,
    ACallbacks.VerifyInstalledExecutable,
    ACallbacks.HasCachedArtifacts,
    ACallbacks.RestoreCachedArtifacts,
    ACallbacks.SaveBuildArtifacts,
    ACallbacks.DownloadSource,
    ACallbacks.EnsureBootstrap,
    ACallbacks.BuildFromSource,
    ACallbacks.WriteMetadata,
    ACallbacks.SetupEnvironment,
    ACallbacks.InstallBinary
  );

  if Result and Assigned(ACallbacks.RefreshInstallVerificationMetadata) then
    ACallbacks.RefreshInstallVerificationMetadata(AState.Version, InstallPath);
end;

end.
