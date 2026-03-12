unit fpdev.package.verification;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, fpdev.hash, fpdev.output.intf;

type
  TPackageVerifyStatus = (pvsValid, pvsInvalid, pvsMissingFiles, pvsMetadataError);

  TPackageVerifyResult = record
    Status: TPackageVerifyStatus;
    PackageName: string;
    Version: string;
    MissingFiles: TStringArray;
  end;

  TPackageVerifyMetadataLoadStatus = (
    pvmlsOk,
    pvmlsMissing,
    pvmlsIOError,
    pvmlsInvalidJSON,
    pvmlsInvalidShape,
    pvmlsMissingName
  );

  TPackageVerifyMetadata = record
    Name: string;
    Version: string;
    ExpectedSha256: string;
    SourcePath: string;
  end;

  TPackageVerifyChecksumStatus = (pvcsSkipped, pvcsOk, pvcsMismatch);
  TPackageVerifyInstalledChecker = function(const APackageName: string): Boolean of object;
  TPackageVerifyInstallPathProvider = function(const APackageName: string): string of object;

function VerifyInstalledPackageCore(const TestDir: string): TPackageVerifyResult;
function VerifyPackageChecksumCore(const FilePath, Hash: string): Boolean;
function TryLoadPackageVerifyMetadataCore(const AMetaPath: string;
  out AMetadata: TPackageVerifyMetadata;
  out AStatus: TPackageVerifyMetadataLoadStatus;
  out AError: string): Boolean;
function VerifyPackageMetadataChecksumCore(const AMetadata: TPackageVerifyMetadata;
  out AActualHash: string): TPackageVerifyChecksumStatus;
function ExecutePackageVerifyCore(
  const APackageName: string;
  AIsPackageInstalled: TPackageVerifyInstalledChecker;
  AGetPackageInstallPath: TPackageVerifyInstallPathProvider;
  Outp, Errp: IOutput
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.package.metadataio;

function MapPackageVerifyMetadataStatusCore(
  const AStatus: TPackageMetadataLoadStatus): TPackageVerifyMetadataLoadStatus;
begin
  case AStatus of
    pmlsOk:
      Result := pvmlsOk;
    pmlsMissing:
      Result := pvmlsMissing;
    pmlsIOError:
      Result := pvmlsIOError;
    pmlsInvalidJSON:
      Result := pvmlsInvalidJSON;
    pmlsInvalidShape,
    pmlsSourcePathMissing:
      Result := pvmlsInvalidShape;
  end;
end;

procedure InitializePackageVerifyMetadataCore(out AMetadata: TPackageVerifyMetadata);
begin
  AMetadata.Name := '';
  AMetadata.Version := '';
  AMetadata.ExpectedSha256 := '';
  AMetadata.SourcePath := '';
end;

function VerifyInstalledPackageCore(const TestDir: string): TPackageVerifyResult;
var
  MetaPath: string;
  SL: TStringList;
  J: TJSONData;
  O: TJSONObject;
  FilesArray: TJSONArray;
  i: Integer;
  FilePath: string;
begin
  Result.Status := pvsInvalid;
  Result.PackageName := '';
  Result.Version := '';
  SetLength(Result.MissingFiles, 0);

  MetaPath := IncludeTrailingPathDelimiter(TestDir) + 'package.json';
  if not FileExists(MetaPath) then
  begin
    Result.Status := pvsMetadataError;
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(MetaPath);
    try
      J := GetJSON(SL.Text);
      if J.JSONType = jtObject then
      begin
        O := TJSONObject(J);
        Result.PackageName := O.Get('name', '');
        Result.Version := O.Get('version', '');

        if O.Find('files') <> nil then
        begin
          FilesArray := O.Arrays['files'];
          for i := 0 to FilesArray.Count - 1 do
          begin
            FilePath := IncludeTrailingPathDelimiter(TestDir) + FilesArray.Strings[i];
            if not FileExists(FilePath) then
            begin
              SetLength(Result.MissingFiles, Length(Result.MissingFiles) + 1);
              Result.MissingFiles[High(Result.MissingFiles)] := FilesArray.Strings[i];
            end;
          end;
        end;

        if (Result.PackageName = '') or (Result.Version = '') then
          Result.Status := pvsMetadataError
        else if Length(Result.MissingFiles) > 0 then
          Result.Status := pvsMissingFiles
        else
          Result.Status := pvsValid;
      end
      else
        Result.Status := pvsMetadataError;
      J.Free;
    except
      Result.Status := pvsMetadataError;
    end;
  finally
    SL.Free;
  end;
end;

function VerifyPackageChecksumCore(const FilePath, Hash: string): Boolean;
var
  ActualHash: string;
begin
  Result := False;
  if not FileExists(FilePath) then
    Exit;

  ActualHash := SHA256FileHex(FilePath);
  Result := SameText(ActualHash, Hash);
end;

function TryLoadPackageVerifyMetadataCore(const AMetaPath: string;
  out AMetadata: TPackageVerifyMetadata;
  out AStatus: TPackageVerifyMetadataLoadStatus;
  out AError: string): Boolean;
var
  Metadata: TJSONObject;
  BaseStatus: TPackageMetadataLoadStatus;
begin
  Result := False;
  InitializePackageVerifyMetadataCore(AMetadata);
  AError := '';
  AStatus := pvmlsMissing;

  if not TryLoadPackageMetadataCore(AMetaPath, Metadata, BaseStatus, AError) then
  begin
    AStatus := MapPackageVerifyMetadataStatusCore(BaseStatus);
    Exit;
  end;

  try
    AMetadata.Name := Trim(Metadata.Get('name', ''));
    if AMetadata.Name = '' then
    begin
      AStatus := pvmlsMissingName;
      Exit;
    end;

    AMetadata.Version := Trim(Metadata.Get('version', ''));
    AMetadata.ExpectedSha256 := Trim(Metadata.Get('sha256', ''));
    AMetadata.SourcePath := Trim(Metadata.Get('source_path', ''));

    AStatus := pvmlsOk;
    Result := True;
  finally
    Metadata.Free;
  end;
end;

function VerifyPackageMetadataChecksumCore(const AMetadata: TPackageVerifyMetadata;
  out AActualHash: string): TPackageVerifyChecksumStatus;
var
  FilePath: string;
begin
  AActualHash := '';
  Result := pvcsSkipped;

  FilePath := Trim(AMetadata.SourcePath);
  if (Trim(AMetadata.ExpectedSha256) = '') or (FilePath = '') or
     (not FileExists(FilePath)) then
    Exit;

  AActualHash := SHA256FileHex(FilePath);
  if SameText(AMetadata.ExpectedSha256, AActualHash) then
    Result := pvcsOk
  else
    Result := pvcsMismatch;
end;

function ExecutePackageVerifyCore(
  const APackageName: string;
  AIsPackageInstalled: TPackageVerifyInstalledChecker;
  AGetPackageInstallPath: TPackageVerifyInstallPathProvider;
  Outp, Errp: IOutput
): Boolean;
var
  InstallPath, MetaPath: string;
  Metadata: TPackageVerifyMetadata;
  MetadataStatus: TPackageVerifyMetadataLoadStatus;
  ChecksumStatus: TPackageVerifyChecksumStatus;
  ActualSha256: string;
  ErrorText: string;
begin
  Result := False;

  if (not Assigned(AIsPackageInstalled)) or (not Assigned(AGetPackageInstallPath)) then
    Exit;

  if not AIsPackageInstalled(APackageName) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_INSTALLED, [APackageName]));
    Exit;
  end;

  InstallPath := AGetPackageInstallPath(APackageName);
  MetaPath := IncludeTrailingPathDelimiter(InstallPath) + 'package.json';

  if not TryLoadPackageVerifyMetadataCore(
    MetaPath,
    Metadata,
    MetadataStatus,
    ErrorText
  ) then
  begin
    if Errp <> nil then
    begin
      case MetadataStatus of
        pvmlsMissing:
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_NOT_FOUND, [MetaPath]));
        pvmlsIOError,
        pvmlsInvalidJSON:
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_META_INVALID, [ErrorText]));
        pvmlsInvalidShape:
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_META_NOT_JSON));
        pvmlsMissingName:
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_NAME_MISSING));
        pvmlsOk:
          ;
      end;
    end;
    Exit;
  end;

  if (Metadata.Version = '') and (Outp <> nil) then
    Outp.WriteLn(_(MSG_PKG_VERSION_MISSING));

  ChecksumStatus := VerifyPackageMetadataChecksumCore(Metadata, ActualSha256);
  case ChecksumStatus of
    pvcsMismatch:
      begin
        if Errp <> nil then
        begin
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_CHECKSUM_MISMATCH));
          Errp.WriteLn(_Fmt(MSG_PKG_CHECKSUM_EXPECTED, [Metadata.ExpectedSha256]));
          Errp.WriteLn(_Fmt(MSG_PKG_CHECKSUM_ACTUAL, [ActualSha256]));
        end;
        Exit;
      end;
    pvcsOk:
      if Outp <> nil then
        Outp.WriteLn(_(MSG_PKG_CHECKSUM_OK));
    pvcsSkipped:
      ;
  end;

  if Outp <> nil then
    Outp.WriteLn(_Fmt(MSG_PKG_VERIFY_SUCCESS, [APackageName]));
  Result := True;
end;

end.
