unit fpdev.fpc.statusflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.types,
  fpdev.config.interfaces,
  fpdev.fpc.types;

type
  TFPCStatusLookupToolchainInfoFunc = function(
    const AVersion: string;
    out AInfo: TToolchainInfo
  ): Boolean of object;

  TFPCStatusReadMetadataFunc = function(
    const AInstallPath: string;
    out AMeta: TFPDevMetadata
  ): Boolean of object;

  TFPCStatusInferScopeFunc = function(
    const AVersion, AInstallPath: string
  ): TFPCStatusScope of object;

procedure InitializeFPCStatusInfoCore(out AStatus: TFPCStatusInfo);

function ResolveManagedFPCStatusInstallPathCore(
  const AVersion, ADefaultInstallPath, AConfiguredInstallPath: string
): string;

function BuildManagedFPCStatusCore(
  const AVersion, ADefaultInstallPath: string;
  ALookupToolchainInfo: TFPCStatusLookupToolchainInfoFunc;
  AReadMetadata: TFPCStatusReadMetadataFunc;
  AInferStatusScope: TFPCStatusInferScopeFunc;
  out AStatus: TFPCStatusInfo;
  out AError: string
): Boolean;

implementation

uses
  SysUtils,
  fpdev.fpc.installversionflow;

function MapInstallScopeToStatusScope(
  AScope: fpdev.types.TInstallScope
): TFPCStatusScope;
begin
  Result := fssNone;
  case AScope of
    fpdev.types.isProject:
      Result := fssProject;
    fpdev.types.isUser:
      Result := fssUser;
    fpdev.types.isSystem:
      Result := fssSystem;
  end;
end;

procedure InitializeFPCStatusInfoCore(out AStatus: TFPCStatusInfo);
begin
  AStatus := Default(TFPCStatusInfo);
  AStatus.ActiveScope := fssNone;
  AStatus.VerifyStatus := fvsUnknown;
  AStatus.SourceMode := smAuto;
  AStatus.HasSourceMode := False;
  AStatus.ConfiguredDefaultInstalled := False;
end;

function ResolveManagedFPCStatusInstallPathCore(
  const AVersion, ADefaultInstallPath, AConfiguredInstallPath: string
): string;
var
  PreferredInstallPath: string;
begin
  PreferredInstallPath := Trim(AConfiguredInstallPath);
  if PreferredInstallPath = '' then
    PreferredInstallPath := ADefaultInstallPath;
  Result := ResolveInstalledFPCInstallPathCore(PreferredInstallPath, AVersion);
end;

procedure ApplyManagedFPCMetadataStatusCore(
  const AMeta: TFPDevMetadata;
  var AStatus: TFPCStatusInfo
);
begin
  AStatus.ActiveScope := MapInstallScopeToStatusScope(AMeta.Scope);
  AStatus.SourceMode := AMeta.SourceMode;
  AStatus.HasSourceMode := True;

  if AMeta.Verify.OK then
    AStatus.VerifyStatus := fvsOk
  else if AMeta.Verify.Timestamp > 0 then
    AStatus.VerifyStatus := fvsFail
  else
    AStatus.VerifyStatus := fvsUnknown;
end;

function BuildManagedFPCStatusCore(
  const AVersion, ADefaultInstallPath: string;
  ALookupToolchainInfo: TFPCStatusLookupToolchainInfoFunc;
  AReadMetadata: TFPCStatusReadMetadataFunc;
  AInferStatusScope: TFPCStatusInferScopeFunc;
  out AStatus: TFPCStatusInfo;
  out AError: string
): Boolean;
var
  ToolchainInfo: TToolchainInfo;
  ConfiguredInstallPath: string;
  InstallPath: string;
  Meta: TFPDevMetadata;
  MetaLoaded: Boolean;
  InferredScope: TFPCStatusScope;
begin
  InitializeFPCStatusInfoCore(AStatus);
  AError := '';

  AStatus.ConfiguredDefault := AVersion;
  if AVersion = '' then
    Exit(True);

  AStatus.EffectiveVersion := AVersion;
  ConfiguredInstallPath := '';
  if Assigned(ALookupToolchainInfo) and
     ALookupToolchainInfo(AVersion, ToolchainInfo) then
    ConfiguredInstallPath := Trim(ToolchainInfo.InstallPath);

  InstallPath := ResolveManagedFPCStatusInstallPathCore(
    AVersion,
    ADefaultInstallPath,
    ConfiguredInstallPath
  );
  AStatus.ManagedPrefix := InstallPath;
  AStatus.ConfiguredDefaultInstalled := FileExists(
    BuildFPCInstalledExecutablePathCore(InstallPath)
  );
  if not AStatus.ConfiguredDefaultInstalled then
  begin
    AError := 'Configured default FPC ' + AVersion + ' is missing: ' +
      InstallPath;
    Exit(False);
  end;

  MetaLoaded := Assigned(AReadMetadata) and AReadMetadata(InstallPath, Meta);
  if MetaLoaded then
    ApplyManagedFPCMetadataStatusCore(Meta, AStatus);

  InferredScope := fssNone;
  if Assigned(AInferStatusScope) then
    InferredScope := AInferStatusScope(AVersion, InstallPath);

  if (not MetaLoaded) or (AStatus.ActiveScope = fssNone) then
    AStatus.ActiveScope := InferredScope;

  Result := True;
end;

end.
