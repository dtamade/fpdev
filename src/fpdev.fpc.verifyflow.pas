unit fpdev.fpc.verifyflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.fpc.types;

type
  TFPCManagedVerificationCallback = function(
    const AVersion: string;
    out AVerifResult: TVerificationResult
  ): Boolean of object;

  TFPCVerificationMetadataWriter = function(
    const AVersion, AInstallPath: string;
    const AVerifResult: TVerificationResult
  ): Boolean of object;

function VerifyInstalledExecutableVersionCore(
  const AFPCExe, AVersion: string;
  out AError: string
): Boolean;

function RunInstalledFPCVerificationCore(
  const AVersion, AInstallPath: string;
  out AVerifResult: TVerificationResult
): Boolean;

function PersistManagedFPCVerificationResultCore(
  const APreferredInstallPath, AVersion: string;
  const AVerifResult: TVerificationResult;
  AWriteVerificationMetadata: TFPCVerificationMetadataWriter
): Boolean;

function ExecuteManagedFPCVerificationSurfaceCore(
  const AVersion, APreferredInstallPath: string;
  AVerifyInstallation: TFPCManagedVerificationCallback;
  AWriteVerificationMetadata: TFPCVerificationMetadataWriter;
  out AVerifResult: TVerificationResult
): Boolean;

function WriteBinaryInstallVerificationMetadataCore(
  const AVersion, AInstallPath: string;
  const AVerifResult: TVerificationResult
): Boolean;

function RefreshInstalledFPCVerificationCore(
  const AVersion, AInstallPath: string;
  const AErr: IOutput;
  AWriteVerificationMetadata: TFPCVerificationMetadataWriter
): Boolean;

implementation

uses
  SysUtils,
  fpdev.types,
  fpdev.fpc.installversionflow,
  fpdev.fpc.metadata,
  fpdev.fpc.metadataflow,
  fpdev.fpc.verify,
  fpdev.version.registry;

procedure WriteLine(const AOut: IOutput; const AText: string);
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

procedure InitializeVerificationResultCore(
  out AVerifResult: TVerificationResult
);
begin
  Initialize(AVerifResult);
  AVerifResult.Verified := False;
  AVerifResult.ExecutableExists := False;
  AVerifResult.DetectedVersion := '';
  AVerifResult.SmokeTestPassed := False;
  AVerifResult.ErrorMessage := '';
end;

function VerifyInstalledExecutableVersionCore(
  const AFPCExe, AVersion: string;
  out AError: string
): Boolean;
var
  Verifier: TFPCVerifier;
begin
  AError := '';
  Verifier := TFPCVerifier.Create;
  try
    Result := Verifier.VerifyVersion(AFPCExe, AVersion);
    if not Result then
      AError := Verifier.GetLastError;
  finally
    Verifier.Free;
  end;
end;

function RunInstalledFPCVerificationCore(
  const AVersion, AInstallPath: string;
  out AVerifResult: TVerificationResult
): Boolean;
var
  Verifier: TFPCVerifier;
  FPCExe: string;
begin
  Result := False;
  InitializeVerificationResultCore(AVerifResult);

  if AInstallPath = '' then
    Exit(False);

  FPCExe := BuildFPCInstalledExecutablePathCore(AInstallPath);
  AVerifResult.ExecutableExists := FileExists(FPCExe);
  if not AVerifResult.ExecutableExists then
  begin
    AVerifResult.ErrorMessage := 'FPC executable not found: ' + FPCExe;
    Exit(False);
  end;

  Verifier := TFPCVerifier.Create;
  try
    if not Verifier.VerifyVersion(FPCExe, AVersion) then
    begin
      AVerifResult.ErrorMessage := Verifier.GetLastError;
      Exit(False);
    end;

    AVerifResult.DetectedVersion := AVersion;
    if not Verifier.CompileHelloWorld(FPCExe) then
    begin
      AVerifResult.ErrorMessage := Verifier.GetLastError;
      Exit(False);
    end;

    AVerifResult.SmokeTestPassed := True;
    AVerifResult.Verified := True;
    Result := True;
  finally
    Verifier.Free;
  end;
end;

function PersistManagedFPCVerificationResultCore(
  const APreferredInstallPath, AVersion: string;
  const AVerifResult: TVerificationResult;
  AWriteVerificationMetadata: TFPCVerificationMetadataWriter
): Boolean;
var
  InstallPath: string;
begin
  Result := False;
  if not Assigned(AWriteVerificationMetadata) then
    Exit(False);

  InstallPath := ResolveInstalledFPCInstallPathCore(
    APreferredInstallPath,
    AVersion
  );
  if not DirectoryExists(InstallPath) then
    Exit(False);

  Result := AWriteVerificationMetadata(AVersion, InstallPath, AVerifResult);
end;

function ExecuteManagedFPCVerificationSurfaceCore(
  const AVersion, APreferredInstallPath: string;
  AVerifyInstallation: TFPCManagedVerificationCallback;
  AWriteVerificationMetadata: TFPCVerificationMetadataWriter;
  out AVerifResult: TVerificationResult
): Boolean;
begin
  if Assigned(AVerifyInstallation) then
    Result := AVerifyInstallation(AVersion, AVerifResult)
  else
  begin
    InitializeVerificationResultCore(AVerifResult);
    AVerifResult.ErrorMessage := 'Verify callback not assigned';
    Exit(False);
  end;

  PersistManagedFPCVerificationResultCore(
    APreferredInstallPath,
    AVersion,
    AVerifResult,
    AWriteVerificationMetadata
  );
end;

function ResolveBinaryMetadataScope(
  const AMeta: TFPDevMetadata;
  AMetaLoaded: Boolean
): TInstallScope;
begin
  if AMetaLoaded then
    Result := AMeta.Scope
  else
    Result := isUser;
end;

function WriteBinaryInstallVerificationMetadataCore(
  const AVersion, AInstallPath: string;
  const AVerifResult: TVerificationResult
): Boolean;
var
  Meta: TFPDevMetadata;
  MetaLoaded: Boolean;
  ReleaseInfo: TFPCReleaseInfo;
  Scope: TInstallScope;
begin
  Result := False;
  if not DirectoryExists(AInstallPath) then
    Exit(False);

  try
    MetaLoaded := ReadFPCMetadata(AInstallPath, Meta);
    if not MetaLoaded then
      Meta := Default(TFPDevMetadata);

    ReleaseInfo := TVersionRegistry.Instance.GetFPCRelease(AVersion);
    Scope := ResolveBinaryMetadataScope(Meta, MetaLoaded);

    if not MetaLoaded then
      Meta := BuildFPCInstallMetadataCore(
        AVersion,
        AInstallPath,
        ReleaseInfo.Channel,
        TVersionRegistry.Instance.GetFPCRepository,
        False,
        Scope,
        Now
      );

    Meta := ApplyFPCVerificationMetadataCore(
      Meta,
      MetaLoaded,
      AVersion,
      AInstallPath,
      ReleaseInfo.Channel,
      Scope,
      AVerifResult,
      Now
    );

    Result := WriteFPCMetadata(AInstallPath, Meta);
  except
    Result := False;
  end;
end;

function RefreshInstalledFPCVerificationCore(
  const AVersion, AInstallPath: string;
  const AErr: IOutput;
  AWriteVerificationMetadata: TFPCVerificationMetadataWriter
): Boolean;
var
  VerifResult: TVerificationResult;
begin
  Result := RunInstalledFPCVerificationCore(
    AVersion,
    AInstallPath,
    VerifResult
  );

  if not VerifResult.ExecutableExists then
    WriteLine(
      AErr,
      'Warning: Post-install verification skipped - ' + VerifResult.ErrorMessage
    )
  else if not Result then
  begin
    if VerifResult.DetectedVersion = '' then
      WriteLine(
        AErr,
        'Warning: Post-install version verification failed - ' +
          VerifResult.ErrorMessage
      )
    else
      WriteLine(
        AErr,
        'Warning: Post-install smoke test failed - ' +
          VerifResult.ErrorMessage
      );
  end;

  if Assigned(AWriteVerificationMetadata) then
    AWriteVerificationMetadata(AVersion, AInstallPath, VerifResult);
end;

end.
