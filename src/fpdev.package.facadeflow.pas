unit fpdev.package.facadeflow;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.package.metadataio;

type
  TPackagePathExistsFunc = function(const APath: string): Boolean of object;
  TPackageNameResolver = function(const AMetaPath, ADefaultName: string): string of object;
  TPackageSourceInstallFunc = function(const APackageName, ASourcePath: string): Boolean of object;
  TPackageNameValidatorFunc = function(const APackageName: string): Boolean of object;
  TPackageEnsureMetadataFunc = function(const APackageName, ASourceDir, AMetaPath: string;
    out ACreated: Boolean; out AError: string): Boolean of object;
  TPackageInstalledCheckerFunc = function(const APackageName: string): Boolean of object;
  TPackageInstallPathResolverFunc = function(const APackageName: string): string of object;
  TPackagePublishMetadataResolverFunc = function(const AInstallPath, ADefaultVersion: string;
    out AVersion, AArchiveSourcePath, ASourcePathFromMeta: string;
    out AStatus: TPackageMetadataLoadStatus; out AError: string): Boolean of object;
  TPackagePublishMetadataFailureHandlerFunc = function(AStatus: TPackageMetadataLoadStatus;
    const AError: string; Errp: IOutput): Integer of object;
  TPackageArchiveCreatorFunc = function(const APackageName, AVersion, AArchiveSourcePath,
    AInstallRoot: string; Outp, Errp: IOutput; out AArchivePath: string;
    out AExitCode: Integer): Boolean of object;

function ExecutePackageInstallFromLocalCore(
  const APackagePath: string;
  const Outp, Errp: IOutput;
  ADirectoryExists: TPackagePathExistsFunc;
  AResolvePackageName: TPackageNameResolver;
  AInstallFromSource: TPackageSourceInstallFunc
): Boolean;

function ExecutePackageCreateCore(
  const APackageName, APath, ACurrentDir: string;
  const Outp, Errp: IOutput;
  AValidatePackage: TPackageNameValidatorFunc;
  ADirectoryExists: TPackagePathExistsFunc;
  AEnsureMetadataFile: TPackageEnsureMetadataFunc
): Boolean;

function ExecutePackagePublishCore(
  const APackageName, ADefaultVersion, AInstallRoot: string;
  const Outp, Errp: IOutput;
  AIsInstalled: TPackageInstalledCheckerFunc;
  AGetInstallPath: TPackageInstallPathResolverFunc;
  AResolvePublishMetadata: TPackagePublishMetadataResolverFunc;
  AHandleMetadataFailure: TPackagePublishMetadataFailureHandlerFunc;
  ACreateArchive: TPackageArchiveCreatorFunc;
  out AExitCode: Integer
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes;

function ExecutePackageInstallFromLocalCore(
  const APackagePath: string;
  const Outp, Errp: IOutput;
  ADirectoryExists: TPackagePathExistsFunc;
  AResolvePackageName: TPackageNameResolver;
  AInstallFromSource: TPackageSourceInstallFunc
): Boolean;
var
  PackageName: string;
begin
  Result := False;

  if (not Assigned(ADirectoryExists)) or (not Assigned(AResolvePackageName)) or
     (not Assigned(AInstallFromSource)) then
    Exit;

  if not ADirectoryExists(APackagePath) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_PATH_NOT_FOUND, [APackagePath]));
    Exit;
  end;

  try
    PackageName := ExtractFileName(APackagePath);
    if PackageName = '' then
      PackageName := 'local_package';

    PackageName := AResolvePackageName(
      IncludeTrailingPathDelimiter(APackagePath) + 'package.json',
      PackageName
    );

    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_PKG_INSTALL_LOCAL, [APackagePath]));

    Result := AInstallFromSource(PackageName, APackagePath);
    if Result and (Outp <> nil) then
      Outp.WriteLn(_Fmt(MSG_PKG_INSTALL_COMPLETE, [PackageName]));
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' +
          _Fmt(CMD_PKG_EXCEPTION, ['install-local', E.Message]));
      Result := False;
    end;
  end;
end;

function ExecutePackageCreateCore(
  const APackageName, APath, ACurrentDir: string;
  const Outp, Errp: IOutput;
  AValidatePackage: TPackageNameValidatorFunc;
  ADirectoryExists: TPackagePathExistsFunc;
  AEnsureMetadataFile: TPackageEnsureMetadataFunc
): Boolean;
var
  SourceDir: string;
  MetaPath: string;
  CreatedMeta: Boolean;
  CreateError: string;
begin
  Result := False;

  if (not Assigned(AValidatePackage)) or (not Assigned(ADirectoryExists)) or
     (not Assigned(AEnsureMetadataFile)) then
    Exit;

  if not AValidatePackage(APackageName) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_INVALID_NAME, [APackageName]));
    Exit;
  end;

  if APath = '' then
    SourceDir := ACurrentDir
  else
    SourceDir := ExpandFileName(APath);

  if not ADirectoryExists(SourceDir) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_SOURCE_NOT_FOUND, [SourceDir]));
    Exit;
  end;

  MetaPath := IncludeTrailingPathDelimiter(SourceDir) + 'package.json';
  if not AEnsureMetadataFile(APackageName, SourceDir, MetaPath, CreatedMeta, CreateError) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + CreateError);
    Exit;
  end;

  if Outp <> nil then
  begin
    if CreatedMeta then
      Outp.WriteLn(_Fmt(MSG_PKG_CREATED_JSON, [MetaPath]))
    else
      Outp.WriteLn(_Fmt(MSG_PKG_JSON_EXISTS, [MetaPath]));

    Outp.WriteLn(_Fmt(MSG_PKG_CREATE_SUCCESS, [APackageName]));
    Outp.WriteLn('');
    Outp.WriteLn(_(MSG_PKG_NEXT_STEPS));
    Outp.WriteLn(_(MSG_PKG_STEP_EDIT));
    Outp.WriteLn(_(MSG_PKG_STEP_ADD_SOURCE));
    Outp.WriteLn(_Fmt(MSG_PKG_STEP_PUBLISH, [APackageName]));
  end;

  Result := True;
end;

function ExecutePackagePublishCore(
  const APackageName, ADefaultVersion, AInstallRoot: string;
  const Outp, Errp: IOutput;
  AIsInstalled: TPackageInstalledCheckerFunc;
  AGetInstallPath: TPackageInstallPathResolverFunc;
  AResolvePublishMetadata: TPackagePublishMetadataResolverFunc;
  AHandleMetadataFailure: TPackagePublishMetadataFailureHandlerFunc;
  ACreateArchive: TPackageArchiveCreatorFunc;
  out AExitCode: Integer
): Boolean;
var
  InstallPath: string;
  ArchivePath: string;
  ArchiveSourcePath: string;
  SourcePathFromMeta: string;
  Version: string;
  MetaStatus: TPackageMetadataLoadStatus;
  MetaError: string;
begin
  Result := False;
  AExitCode := EXIT_ERROR;
  ArchivePath := '';

  if (not Assigned(AIsInstalled)) or (not Assigned(AGetInstallPath)) or
     (not Assigned(AResolvePublishMetadata)) or
     (not Assigned(AHandleMetadataFailure)) or (not Assigned(ACreateArchive)) then
    Exit;

  if not AIsInstalled(APackageName) then
  begin
    AExitCode := EXIT_NOT_FOUND;
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_FOUND, [APackageName]));
    Exit;
  end;

  InstallPath := AGetInstallPath(APackageName);
  if not AResolvePublishMetadata(
    InstallPath,
    ADefaultVersion,
    Version,
    ArchiveSourcePath,
    SourcePathFromMeta,
    MetaStatus,
    MetaError
  ) then
  begin
    AExitCode := AHandleMetadataFailure(MetaStatus, MetaError, Errp);
    Exit;
  end;

  Result := ACreateArchive(
    APackageName,
    Version,
    ArchiveSourcePath,
    AInstallRoot,
    Outp,
    Errp,
    ArchivePath,
    AExitCode
  );
  if SourcePathFromMeta = '' then;
end;

end.
