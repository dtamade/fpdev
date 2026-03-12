unit fpdev.package.publishflow;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.package.metadataio;

procedure BuildPublishArchivePathCore(const AInstallRoot, APackageName,
  AVersion: string; out AArchiveName, AArchivePath: string);
function HandlePublishMetadataFailureCore(
  AStatus: TPackageMetadataLoadStatus;
  const AError: string;
  Errp: IOutput
): Integer;
function CreatePublishArchiveCore(
  const APackageName, AVersion, AArchiveSourcePath, AInstallRoot: string;
  Outp, Errp: IOutput;
  out AArchivePath: string;
  out AExitCode: Integer
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.archiver,
  fpdev.utils.fs;

procedure BuildPublishArchivePathCore(const AInstallRoot, APackageName,
  AVersion: string; out AArchiveName, AArchivePath: string);
begin
  AArchiveName := APackageName + '-' + AVersion + '.tar.gz';
  AArchivePath := IncludeTrailingPathDelimiter(AInstallRoot) + 'publish' +
    PathDelim + AArchiveName;
end;

function HandlePublishMetadataFailureCore(
  AStatus: TPackageMetadataLoadStatus;
  const AError: string;
  Errp: IOutput
): Integer;
begin
  Result := EXIT_ERROR;

  case AStatus of
    pmlsMissing:
      begin
        Result := EXIT_NOT_FOUND;
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' +
            _Fmt(CMD_PKG_META_NOT_FOUND, [_(MSG_PKG_META_HINT)]));
      end;
    pmlsIOError:
      begin
        Result := EXIT_IO_ERROR;
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' +
            _Fmt(CMD_PKG_META_INVALID, [AError]));
      end;
    pmlsInvalidShape:
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_META_NOT_JSON));
      end;
    pmlsInvalidJSON:
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' +
            _Fmt(CMD_PKG_META_INVALID, [AError]));
      end;
    pmlsSourcePathMissing:
      begin
        Result := EXIT_NOT_FOUND;
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' +
            _Fmt(CMD_PKG_PUBLISH_SOURCE_PATH_NOT_FOUND, [AError]));
      end;
    pmlsOk:
      ;
  end;
end;

function CreatePublishArchiveCore(
  const APackageName, AVersion, AArchiveSourcePath, AInstallRoot: string;
  Outp, Errp: IOutput;
  out AArchivePath: string;
  out AExitCode: Integer
): Boolean;
var
  ArchiveName: string;
  Archiver: TPackageArchiver;
  ArchiverError: string;
begin
  Result := False;
  AExitCode := EXIT_ERROR;
  AArchivePath := '';

  BuildPublishArchivePathCore(
    AInstallRoot,
    APackageName,
    AVersion,
    ArchiveName,
    AArchivePath
  );

  if not DirectoryExists(ExtractFileDir(AArchivePath)) then
    EnsureDir(ExtractFileDir(AArchivePath));

  if Outp <> nil then
    Outp.WriteLn(_Fmt(MSG_PKG_CREATING_ARCHIVE, [ArchiveName]));

  Archiver := TPackageArchiver.Create(AArchiveSourcePath);
  try
    if not Archiver.CreateArchive(AArchivePath) then
    begin
      ArchiverError := Trim(Archiver.GetLastError);
      if Archiver.GetLastErrorCode = paecNoSourceFiles then
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' +
            _Fmt(CMD_PKG_PUBLISH_SOURCE_NO_FILES, [AArchiveSourcePath]));
        Exit(False);
      end;

      if Archiver.GetLastErrorCode in
        [paecTarCommandFailed, paecArchiveNotCreated, paecTarExecutionFailed] then
        AExitCode := EXIT_IO_ERROR;

      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' +
          _Fmt(CMD_PKG_ARCHIVE_FAILED, [ArchiverError]));
      Exit(False);
    end;

    if Outp <> nil then
    begin
      Outp.WriteLn(_Fmt(MSG_PKG_ARCHIVE_CREATED, [AArchivePath]));
      Outp.WriteLn(_Fmt(MSG_PKG_ARCHIVE_SHA256, [Archiver.GetChecksum]));
      Outp.WriteLn('');
      Outp.WriteLn(_Fmt(MSG_PKG_READY_PUBLISH, [APackageName, AVersion]));
      Outp.WriteLn('');
      Outp.WriteLn(_(MSG_PKG_TO_PUBLISH));
      Outp.WriteLn(_(MSG_PKG_PUBLISH_STEP1));
      Outp.WriteLn(_(MSG_PKG_PUBLISH_STEP2));
    end;

    AExitCode := EXIT_OK;
    Result := True;
  finally
    Archiver.Free;
  end;
end;

end.
