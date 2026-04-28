unit fpdev.fpc.residualflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.types,
  fpdev.fpc.types,
  fpdev.fpc.installer.environmentflow,
  fpdev.fpc.verifyflow;

type
  TFPCResidualInstallPathGetter = function(
    const AVersion: string
  ): string of object;

  TFPCResidualMetadataScopeResolver = function(
    const AVersion, AInstallPath: string
  ): TInstallScope of object;

function ExecuteManagedFPCSetupEnvironmentCore(
  const AVersion, APreferredInstallPath: string;
  const AOut, AErr: IOutput;
  AGetInstallPath: TFPCResidualInstallPathGetter;
  AAddToolchain: TFPCAddToolchainHandler
): Boolean;

function ExecuteManagedFPCWriteInstallMetadataCore(
  const AVersion, AInstallPath: string;
  AFromSource: Boolean;
  const AErr: IOutput;
  AResolveScope: TFPCResidualMetadataScopeResolver
): Boolean;

function ExecuteManagedFPCUpdateVerificationMetadataCore(
  const AVersion, AInstallPath: string;
  const AVerifResult: TVerificationResult;
  const AErr: IOutput;
  AResolveScope: TFPCResidualMetadataScopeResolver
): Boolean;

function ExecuteManagedFPCRefreshVerificationMetadataCore(
  const AVersion, AInstallPath: string;
  const AErr: IOutput;
  AWriteVerificationMetadata: TFPCVerificationMetadataWriter
): Boolean;

implementation

uses
  SysUtils,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.fpc.installer.config,
  fpdev.fpc.metadata,
  fpdev.fpc.metadataflow,
  fpdev.version.registry;

procedure WriteLine(const AOut: IOutput; const AText: string);
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ResolveManagedFPCResidualInstallPath(
  const AVersion, APreferredInstallPath: string;
  AGetInstallPath: TFPCResidualInstallPathGetter
): string;
begin
  Result := APreferredInstallPath;
  if (Result = '') and Assigned(AGetInstallPath) then
    Result := AGetInstallPath(AVersion);
end;

function ResolveManagedFPCResidualScope(
  const AVersion, AInstallPath: string;
  AResolveScope: TFPCResidualMetadataScopeResolver
): TInstallScope;
begin
  if Assigned(AResolveScope) then
    Result := AResolveScope(AVersion, AInstallPath)
  else
    Result := isUser;
end;

function ExecuteManagedFPCSetupEnvironmentCore(
  const AVersion, APreferredInstallPath: string;
  const AOut, AErr: IOutput;
  AGetInstallPath: TFPCResidualInstallPathGetter;
  AAddToolchain: TFPCAddToolchainHandler
): Boolean;
var
  InstallPath: string;
begin
  Result := False;
  InstallPath := ResolveManagedFPCResidualInstallPath(
    AVersion,
    APreferredInstallPath,
    AGetInstallPath
  );

  try
    if not EnsureManagedFPCInstallLayout(InstallPath, AVersion, AOut) then
      Exit(False);
    Result := ExecuteFPCEnvironmentRegistrationFlow(
      AVersion,
      InstallPath,
      AErr,
      AAddToolchain
    );
  except
    on E: Exception do
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': SetupEnvironment failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function ExecuteManagedFPCWriteInstallMetadataCore(
  const AVersion, AInstallPath: string;
  AFromSource: Boolean;
  const AErr: IOutput;
  AResolveScope: TFPCResidualMetadataScopeResolver
): Boolean;
var
  Meta: TFPDevMetadata;
  ReleaseInfo: TFPCReleaseInfo;
begin
  Result := False;

  try
    ReleaseInfo := TVersionRegistry.Instance.GetFPCRelease(AVersion);
    Meta := BuildFPCInstallMetadataCore(
      AVersion,
      AInstallPath,
      ReleaseInfo.Channel,
      TVersionRegistry.Instance.GetFPCRepository,
      AFromSource,
      ResolveManagedFPCResidualScope(AVersion, AInstallPath, AResolveScope),
      Now
    );

    Result := WriteFPCMetadata(AInstallPath, Meta);
    if not Result then
      WriteLine(AErr, 'Warning: Failed to write installation metadata');
  except
    on E: Exception do
    begin
      WriteLine(AErr, 'Warning: Failed to write installation metadata - ' + E.Message);
      Result := False;
    end;
  end;
end;

function ExecuteManagedFPCUpdateVerificationMetadataCore(
  const AVersion, AInstallPath: string;
  const AVerifResult: TVerificationResult;
  const AErr: IOutput;
  AResolveScope: TFPCResidualMetadataScopeResolver
): Boolean;
var
  Meta: TFPDevMetadata;
  ReleaseInfo: TFPCReleaseInfo;
  MetaLoaded: Boolean;
begin
  Result := False;

  if not DirectoryExists(AInstallPath) then
    Exit(False);

  try
    MetaLoaded := ReadFPCMetadata(AInstallPath, Meta);
    if not MetaLoaded then
      Meta := Default(TFPDevMetadata);

    ReleaseInfo := TVersionRegistry.Instance.GetFPCRelease(AVersion);
    Meta := ApplyFPCVerificationMetadataCore(
      Meta,
      MetaLoaded,
      AVersion,
      AInstallPath,
      ReleaseInfo.Channel,
      ResolveManagedFPCResidualScope(AVersion, AInstallPath, AResolveScope),
      AVerifResult,
      Now
    );

    Result := WriteFPCMetadata(AInstallPath, Meta);
    if not Result then
      WriteLine(AErr, 'Warning: Failed to update verification metadata');
  except
    on E: Exception do
    begin
      WriteLine(AErr, 'Warning: Failed to update verification metadata - ' + E.Message);
      Result := False;
    end;
  end;
end;

function ExecuteManagedFPCRefreshVerificationMetadataCore(
  const AVersion, AInstallPath: string;
  const AErr: IOutput;
  AWriteVerificationMetadata: TFPCVerificationMetadataWriter
): Boolean;
begin
  Result := RefreshInstalledFPCVerificationCore(
    AVersion,
    AInstallPath,
    AErr,
    AWriteVerificationMetadata
  );
end;

end.
