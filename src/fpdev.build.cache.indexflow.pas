unit fpdev.build.cache.indexflow;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  fpdev.build.cache.types;

type
  TBuildCacheIndexLookup = function(const AVersion: string; out AInfo: TArtifactInfo): Boolean of object;
  TBuildCacheIndexUpdate = procedure(const AInfo: TArtifactInfo) of object;
  TBuildCacheIndexInfoSave = procedure(const AInfo: TArtifactInfo) of object;
  TBuildCacheIndexSave = procedure of object;

function BuildCacheLookupIndexArtifactInfo(const AEntryJSON: string;
  out AInfo: TArtifactInfo): Boolean;
procedure BuildCacheUpsertIndexEntry(AEntries: TStringList;
  const AInfo: TArtifactInfo);
procedure BuildCacheRemoveIndexEntryVersion(AEntries: TStringList;
  const AVersion: string);
function BuildCacheRecordIndexAccessCore(const AVersion: string;
  AAccessedAt: TDateTime;
  ALookup: TBuildCacheIndexLookup;
  AUpdate: TBuildCacheIndexUpdate;
  ASaveMetadata: TBuildCacheIndexInfoSave;
  ASaveIndex: TBuildCacheIndexSave): Boolean;

implementation

uses
  SysUtils, fpjson,
  fpdev.build.cache.access,
  fpdev.build.cache.fileops,
  fpdev.build.cache.indexjson;

function BuildCacheLookupIndexArtifactInfo(const AEntryJSON: string;
  out AInfo: TArtifactInfo): Boolean;
var
  JSONObj: TJSONObject;
  CreatedAtStr: string;
  LastAccessedStr: string;
begin
  Result := False;
  Initialize(AInfo);

  try
    if not BuildCacheParseIndexEntryJSON(AEntryJSON, JSONObj) then
      Exit;

    try
      AInfo.Version := JSONObj.Get('version', '');
      AInfo.CPU := JSONObj.Get('cpu', '');
      AInfo.OS := JSONObj.Get('os', '');
      AInfo.ArchivePath := JSONObj.Get('archive_path', '');
      AInfo.ArchiveSize := JSONObj.Get('archive_size', Int64(0));
      AInfo.SourceType := JSONObj.Get('source_type', '');
      AInfo.SHA256 := JSONObj.Get('sha256', '');
      AInfo.DownloadURL := JSONObj.Get('download_url', '');
      AInfo.SourcePath := JSONObj.Get('source_path', '');
      AInfo.AccessCount := JSONObj.Get('access_count', 0);

      BuildCacheGetNormalizedIndexDates(JSONObj, CreatedAtStr, LastAccessedStr);
      if CreatedAtStr <> '' then
        AInfo.CreatedAt := BuildCacheParseDateTimeString(CreatedAtStr);
      if LastAccessedStr <> '' then
        AInfo.LastAccessed := BuildCacheParseDateTimeString(LastAccessedStr)
      else
        AInfo.LastAccessed := 0;

      Result := AInfo.Version <> '';
    finally
      JSONObj.Free;
    end;
  except
    Initialize(AInfo);
    Result := False;
  end;
end;

procedure BuildCacheUpsertIndexEntry(AEntries: TStringList;
  const AInfo: TArtifactInfo);
var
  EntryStr: string;
  Idx: Integer;
begin
  if not Assigned(AEntries) then
    Exit;

  EntryStr := BuildCacheBuildIndexEntryJSON(
    AInfo.Version,
    AInfo.CPU,
    AInfo.OS,
    AInfo.ArchivePath,
    AInfo.ArchiveSize,
    AInfo.SourceType,
    AInfo.SHA256,
    AInfo.DownloadURL,
    AInfo.SourcePath,
    AInfo.AccessCount,
    AInfo.CreatedAt,
    AInfo.LastAccessed
  );

  Idx := AEntries.IndexOfName(AInfo.Version);
  if Idx >= 0 then
    AEntries.Delete(Idx);
  AEntries.Add(EntryStr);
end;

procedure BuildCacheRemoveIndexEntryVersion(AEntries: TStringList;
  const AVersion: string);
var
  Idx: Integer;
begin
  if not Assigned(AEntries) then
    Exit;

  Idx := AEntries.IndexOfName(AVersion);
  if Idx >= 0 then
    AEntries.Delete(Idx);
end;

function BuildCacheRecordIndexAccessCore(const AVersion: string;
  AAccessedAt: TDateTime;
  ALookup: TBuildCacheIndexLookup;
  AUpdate: TBuildCacheIndexUpdate;
  ASaveMetadata: TBuildCacheIndexInfoSave;
  ASaveIndex: TBuildCacheIndexSave): Boolean;
var
  Info: TArtifactInfo;
begin
  Result := Assigned(ALookup) and ALookup(AVersion, Info);
  if not Result then
    Exit;

  Info := BuildCacheRecordAccessInfo(Info, AAccessedAt);

  if Assigned(AUpdate) then
    AUpdate(Info);
  if Assigned(ASaveMetadata) then
    ASaveMetadata(Info);
  if Assigned(ASaveIndex) then
    ASaveIndex;
end;

end.
