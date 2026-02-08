unit fpdev.build.cache.oldmeta;

{$mode objfpc}{$H+}

{
  B074/B075: Old metadata format helpers for TBuildCache

  Extracts legacy .meta file read/write logic from build.cache.
  These handle the key=value format used before JSON migration.
  Supports both source artifact and binary artifact formats.
}

interface

uses
  SysUtils, Classes;

type
  { Old metadata format artifact info (source builds) }
  TOldMetaArtifactInfo = record
    Version: string;
    CPU: string;
    OS: string;
    SourcePath: string;
    ArchiveSize: Int64;
    CreatedAt: TDateTime;
  end;

  { Binary artifact metadata info }
  TBinaryMetaArtifactInfo = record
    Version: string;
    CPU: string;
    OS: string;
    SourceType: string;
    SHA256: string;
    FileExt: string;
    ArchiveSize: Int64;
    CreatedAt: TDateTime;
  end;

{ Load artifact info from old .meta format file
  @param AMetaPath - Path to .meta file
  @param AInfo - Output artifact info
  @return True if loaded successfully }
function BuildCacheLoadOldMeta(const AMetaPath: string;
  out AInfo: TOldMetaArtifactInfo): Boolean;

{ Save artifact info to old .meta format file
  @param AMetaPath - Path to .meta file
  @param AVersion - Version string
  @param ACPU - CPU architecture
  @param AOS - Operating system
  @param ASourcePath - Original source/install path
  @param AArchiveSize - Archive file size }
procedure BuildCacheSaveOldMeta(const AMetaPath: string;
  const AVersion, ACPU, AOS, ASourcePath: string; AArchiveSize: Int64);

{ Load binary artifact info from .meta format file
  @param AMetaPath - Path to .meta file
  @param AInfo - Output binary artifact info
  @return True if loaded successfully }
function BuildCacheLoadBinaryMeta(const AMetaPath: string;
  out AInfo: TBinaryMetaArtifactInfo): Boolean;

{ Save binary artifact info to .meta format file
  @param AMetaPath - Path to .meta file
  @param AVersion - Version string
  @param ACPU - CPU architecture
  @param AOS - Operating system
  @param ASHA256 - SHA256 hash
  @param AFileExt - File extension (.tar or .tar.gz)
  @param AArchiveSize - Archive file size }
procedure BuildCacheSaveBinaryMeta(const AMetaPath: string;
  const AVersion, ACPU, AOS, ASHA256, AFileExt: string; AArchiveSize: Int64);

{ Parse a single key=value line from meta file
  @param ALine - Line to parse
  @param AKey - Output key
  @param AValue - Output value
  @return True if line has valid key=value format }
function BuildCacheParseMetaLine(const ALine: string;
  out AKey, AValue: string): Boolean;

implementation

uses
  fpdev.build.cache.fileops;

function BuildCacheParseMetaLine(const ALine: string;
  out AKey, AValue: string): Boolean;
var
  EqPos: Integer;
begin
  Result := False;
  AKey := '';
  AValue := '';

  EqPos := Pos('=', ALine);
  if EqPos > 0 then
  begin
    AKey := Copy(ALine, 1, EqPos - 1);
    AValue := Copy(ALine, EqPos + 1, Length(ALine));
    Result := True;
  end;
end;

function BuildCacheLoadOldMeta(const AMetaPath: string;
  out AInfo: TOldMetaArtifactInfo): Boolean;
var
  MetaFile: TStringList;
  i: Integer;
  Key, Value: string;
begin
  Result := False;
  Initialize(AInfo);

  if not FileExists(AMetaPath) then
    Exit;

  MetaFile := TStringList.Create;
  try
    MetaFile.LoadFromFile(AMetaPath);

    for i := 0 to MetaFile.Count - 1 do
    begin
      if BuildCacheParseMetaLine(MetaFile[i], Key, Value) then
      begin
        if Key = 'version' then
          AInfo.Version := Value
        else if Key = 'cpu' then
          AInfo.CPU := Value
        else if Key = 'os' then
          AInfo.OS := Value
        else if Key = 'source_path' then
          AInfo.SourcePath := Value
        else if Key = 'archive_size' then
          AInfo.ArchiveSize := StrToInt64Def(Value, 0)
        else if Key = 'created_at' then
          AInfo.CreatedAt := BuildCacheParseDateTimeString(Value);
      end;
    end;

    Result := AInfo.Version <> '';
  finally
    MetaFile.Free;
  end;
end;

procedure BuildCacheSaveOldMeta(const AMetaPath: string;
  const AVersion, ACPU, AOS, ASourcePath: string; AArchiveSize: Int64);
var
  MetaFile: TStringList;
begin
  MetaFile := TStringList.Create;
  try
    MetaFile.Add('version=' + AVersion);
    MetaFile.Add('cpu=' + ACPU);
    MetaFile.Add('os=' + AOS);
    MetaFile.Add('source_path=' + ASourcePath);
    MetaFile.Add('created_at=' + BuildCacheFormatDateTimeString(Now));
    MetaFile.Add('archive_size=' + IntToStr(AArchiveSize));

    MetaFile.SaveToFile(AMetaPath);
  finally
    MetaFile.Free;
  end;
end;

function BuildCacheLoadBinaryMeta(const AMetaPath: string;
  out AInfo: TBinaryMetaArtifactInfo): Boolean;
var
  MetaFile: TStringList;
  i: Integer;
  Key, Value: string;
begin
  Result := False;
  Initialize(AInfo);

  if not FileExists(AMetaPath) then
    Exit;

  MetaFile := TStringList.Create;
  try
    MetaFile.LoadFromFile(AMetaPath);

    for i := 0 to MetaFile.Count - 1 do
    begin
      if BuildCacheParseMetaLine(MetaFile[i], Key, Value) then
      begin
        if Key = 'version' then
          AInfo.Version := Value
        else if Key = 'cpu' then
          AInfo.CPU := Value
        else if Key = 'os' then
          AInfo.OS := Value
        else if Key = 'source_type' then
          AInfo.SourceType := Value
        else if Key = 'sha256' then
          AInfo.SHA256 := Value
        else if Key = 'file_ext' then
          AInfo.FileExt := Value
        else if Key = 'archive_size' then
          AInfo.ArchiveSize := StrToInt64Def(Value, 0)
        else if Key = 'created_at' then
          AInfo.CreatedAt := BuildCacheParseDateTimeString(Value);
      end;
    end;

    Result := AInfo.Version <> '';
  finally
    MetaFile.Free;
  end;
end;

procedure BuildCacheSaveBinaryMeta(const AMetaPath: string;
  const AVersion, ACPU, AOS, ASHA256, AFileExt: string; AArchiveSize: Int64);
var
  MetaFile: TStringList;
begin
  MetaFile := TStringList.Create;
  try
    MetaFile.Add('version=' + AVersion);
    MetaFile.Add('cpu=' + ACPU);
    MetaFile.Add('os=' + AOS);
    MetaFile.Add('source_type=binary');
    MetaFile.Add('sha256=' + ASHA256);
    MetaFile.Add('created_at=' + BuildCacheFormatDateTimeString(Now));
    MetaFile.Add('file_ext=' + AFileExt);
    MetaFile.Add('archive_size=' + IntToStr(AArchiveSize));

    MetaFile.SaveToFile(AMetaPath);
  finally
    MetaFile.Free;
  end;
end;

end.
