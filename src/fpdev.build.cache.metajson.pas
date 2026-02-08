unit fpdev.build.cache.metajson;

{$mode objfpc}{$H+}

{
  B070: Metadata JSON helpers for TBuildCache

  Extracts JSON-based metadata read/write logic from build.cache.
  Pure functions that work with file paths and records.
}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, DateUtils;

type
  { Artifact information record - used for JSON serialization }
  TMetaJSONArtifactInfo = record
    Version: string;
    CPU: string;
    OS: string;
    ArchivePath: string;
    ArchiveSize: Int64;
    CreatedAt: TDateTime;
    SourceType: string;
    SHA256: string;
    DownloadURL: string;
    SourcePath: string;
    AccessCount: Integer;
    LastAccessed: TDateTime;
  end;

{ Check if JSON metadata file exists }
function BuildCacheHasMetadataJSON(const AMetaPath: string): Boolean;

{ Save artifact info to JSON file }
procedure BuildCacheSaveMetadataJSON(const AMetaPath: string;
  const AVersion, ACPU, AOS, AArchivePath: string;
  AArchiveSize: Int64; ACreatedAt: TDateTime;
  const ASourceType, ASHA256, ADownloadURL, ASourcePath: string;
  AAccessCount: Integer; ALastAccessed: TDateTime);

{ Load artifact info from JSON file }
function BuildCacheLoadMetadataJSON(const AMetaPath: string;
  out AInfo: TMetaJSONArtifactInfo): Boolean;

{ Parse ISO 8601 datetime string (yyyy-mm-ddThh:nn:ss or yyyy-mm-dd hh:nn:ss) }
function MetaJSONParseDateTime(const ADateStr: string): TDateTime;

{ Format datetime to ISO 8601 string }
function MetaJSONFormatDateTime(const ADateTime: TDateTime): string;

implementation

function BuildCacheHasMetadataJSON(const AMetaPath: string): Boolean;
begin
  Result := FileExists(AMetaPath);
end;

function MetaJSONFormatDateTime(const ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', ADateTime);
end;

function MetaJSONParseDateTime(const ADateStr: string): TDateTime;
var
  NormalizedStr: string;
  Year, Month, Day, Hour, Min, Sec: Word;
begin
  Result := 0;
  if ADateStr = '' then
    Exit;

  // Replace 'T' with space for easier parsing
  NormalizedStr := StringReplace(ADateStr, 'T', ' ', []);

  // Parse format: yyyy-mm-dd hh:nn:ss
  if Length(NormalizedStr) >= 19 then
  begin
    try
      Year := StrToInt(Copy(NormalizedStr, 1, 4));
      Month := StrToInt(Copy(NormalizedStr, 6, 2));
      Day := StrToInt(Copy(NormalizedStr, 9, 2));
      Hour := StrToInt(Copy(NormalizedStr, 12, 2));
      Min := StrToInt(Copy(NormalizedStr, 15, 2));
      Sec := StrToInt(Copy(NormalizedStr, 18, 2));
      Result := EncodeDateTime(Year, Month, Day, Hour, Min, Sec, 0);
    except
      Result := 0;
    end;
  end;
end;

procedure BuildCacheSaveMetadataJSON(const AMetaPath: string;
  const AVersion, ACPU, AOS, AArchivePath: string;
  AArchiveSize: Int64; ACreatedAt: TDateTime;
  const ASourceType, ASHA256, ADownloadURL, ASourcePath: string;
  AAccessCount: Integer; ALastAccessed: TDateTime);
var
  JSONObj: TJSONObject;
  JSONStr: TStringList;
  MetaDir: string;
begin
  // Ensure directory exists
  MetaDir := ExtractFileDir(AMetaPath);
  if MetaDir <> '' then
    ForceDirectories(MetaDir);

  JSONObj := TJSONObject.Create;
  try
    JSONObj.Add('version', AVersion);
    JSONObj.Add('cpu', ACPU);
    JSONObj.Add('os', AOS);
    JSONObj.Add('archive_path', AArchivePath);
    JSONObj.Add('archive_size', AArchiveSize);
    JSONObj.Add('created_at', MetaJSONFormatDateTime(ACreatedAt));
    JSONObj.Add('source_type', ASourceType);
    JSONObj.Add('sha256', ASHA256);
    JSONObj.Add('download_url', ADownloadURL);
    JSONObj.Add('source_path', ASourcePath);
    JSONObj.Add('access_count', AAccessCount);
    if ALastAccessed > 0 then
      JSONObj.Add('last_accessed', MetaJSONFormatDateTime(ALastAccessed))
    else
      JSONObj.Add('last_accessed', '');

    JSONStr := TStringList.Create;
    try
      JSONStr.Text := JSONObj.FormatJSON;
      JSONStr.SaveToFile(AMetaPath);
    finally
      JSONStr.Free;
    end;
  finally
    JSONObj.Free;
  end;
end;

function BuildCacheLoadMetadataJSON(const AMetaPath: string;
  out AInfo: TMetaJSONArtifactInfo): Boolean;
var
  JSONStr: TStringList;
  JSONData: TJSONData;
  JSONObj: TJSONObject;
begin
  Result := False;
  Initialize(AInfo);

  if not FileExists(AMetaPath) then
    Exit;

  JSONStr := TStringList.Create;
  try
    JSONStr.LoadFromFile(AMetaPath);

    try
      JSONData := GetJSON(JSONStr.Text);
      if not (JSONData is TJSONObject) then
      begin
        JSONData.Free;
        Exit;
      end;

      JSONObj := TJSONObject(JSONData);
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

        // Parse dates
        AInfo.CreatedAt := MetaJSONParseDateTime(JSONObj.Get('created_at', ''));
        AInfo.LastAccessed := MetaJSONParseDateTime(JSONObj.Get('last_accessed', ''));

        Result := AInfo.Version <> '';
      finally
        JSONObj.Free;
      end;
    except
      on E: Exception do
      begin
        // Silent failure - JSON parsing error
        Result := False;
      end;
    end;
  finally
    JSONStr.Free;
  end;
end;

end.
