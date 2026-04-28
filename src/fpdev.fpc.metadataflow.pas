unit fpdev.fpc.metadataflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.types,
  fpdev.fpc.types;

function ResolveFPCMetadataScopeCore(
  const AInstallPath, AExpectedInstallPath: string;
  const ADetectedScope: TInstallScope
): TInstallScope;

function InferFPCStatusScopeCore(
  const AVersion, AInstallPath, AProjectRoot, AInstallRoot: string
): TFPCStatusScope;

function BuildFPCInstallMetadataCore(
  const AVersion, AInstallPath, AChannel, ARepositoryURL: string;
  AFromSource: Boolean;
  AScope: TInstallScope;
  const AInstalledAt: TDateTime
): TFPDevMetadata;

function ApplyFPCVerificationMetadataCore(
  const AExistingMeta: TFPDevMetadata;
  AMetaLoaded: Boolean;
  const AVersion, AInstallPath, AChannel: string;
  AScope: TInstallScope;
  const AVerifResult: TVerificationResult;
  const AVerifyTimestamp: TDateTime
): TFPDevMetadata;

implementation

uses
  fpdev.constants,
  fpdev.paths;

function NormalizePath(const APath: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
end;

function ResolveFPCMetadataScopeCore(
  const AInstallPath, AExpectedInstallPath: string;
  const ADetectedScope: TInstallScope
): TInstallScope;
begin
  Result := isUser;

  if SameText(NormalizePath(AInstallPath), NormalizePath(AExpectedInstallPath)) then
    Result := ADetectedScope;
end;

function InferFPCStatusScopeCore(
  const AVersion, AInstallPath, AProjectRoot, AInstallRoot: string
): TFPCStatusScope;
var
  ProjectInstallPath: string;
  UserInstallPath: string;
  NormalizedInstallPath: string;
begin
  Result := fssNone;
  if AInstallPath = '' then
    Exit;

  NormalizedInstallPath := NormalizePath(AInstallPath);

  if AProjectRoot <> '' then
  begin
    ProjectInstallPath := NormalizePath(
      AProjectRoot + PathDelim + FPDEV_CONFIG_DIR + PathDelim +
      'toolchains' + PathDelim + 'fpc' + PathDelim + AVersion
    );
    if SameText(NormalizedInstallPath, ProjectInstallPath) then
      Exit(fssProject);
  end;

  UserInstallPath := NormalizePath(
    BuildFPCInstallDirFromInstallRoot(AInstallRoot, AVersion)
  );
  if SameText(NormalizedInstallPath, UserInstallPath) then
    Exit(fssUser);

  Result := fssUser;
end;

function BuildFPCInstallMetadataCore(
  const AVersion, AInstallPath, AChannel, ARepositoryURL: string;
  AFromSource: Boolean;
  AScope: TInstallScope;
  const AInstalledAt: TDateTime
): TFPDevMetadata;
begin
  Result := Default(TFPDevMetadata);
  Result.Version := AVersion;
  Result.Scope := AScope;
  if AFromSource then
    Result.SourceMode := smSource
  else
    Result.SourceMode := smBinary;
  Result.Channel := AChannel;
  Result.Prefix := ExpandFileName(AInstallPath);
  Result.Origin.BuiltFromSource := AFromSource;
  if AFromSource then
    Result.Origin.RepoURL := ARepositoryURL;
  Result.InstalledAt := AInstalledAt;
end;

function ApplyFPCVerificationMetadataCore(
  const AExistingMeta: TFPDevMetadata;
  AMetaLoaded: Boolean;
  const AVersion, AInstallPath, AChannel: string;
  AScope: TInstallScope;
  const AVerifResult: TVerificationResult;
  const AVerifyTimestamp: TDateTime
): TFPDevMetadata;
begin
  Result := AExistingMeta;

  if Result.Version = '' then
    Result.Version := AVersion;
  if not AMetaLoaded then
    Result.Scope := AScope;
  if Result.Channel = '' then
    Result.Channel := AChannel;
  if Result.Prefix = '' then
    Result.Prefix := ExpandFileName(AInstallPath);
  if Result.InstalledAt = 0 then
    Result.InstalledAt := AVerifyTimestamp;

  Result.Verify.Timestamp := AVerifyTimestamp;
  Result.Verify.OK := AVerifResult.Verified;
  Result.Verify.DetectedVersion := AVerifResult.DetectedVersion;
  Result.Verify.SmokeTestPassed := AVerifResult.SmokeTestPassed;
end;

end.
