unit fpdev.build.cache.indexjson;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson;

function BuildCacheParseIndexEntryJSON(const AEntryJSON: string; out AJSONObj: TJSONObject): Boolean;
function BuildCacheBuildIndexEntryJSON(const AVersion, ACPU, AOS, AArchivePath: string;
  AArchiveSize: Int64; const ASourceType, ASHA256, ADownloadURL, ASourcePath: string;
  AAccessCount: Integer; ACreatedAt, ALastAccessed: TDateTime): string;
function BuildCacheNormalizeIndexDate(const ADateStr: string): string;
function BuildCacheGetIndexEntryJSON(const AIndexEntries: TStringList; const AVersion: string): string;
procedure BuildCacheGetNormalizedIndexDates(const AJSONObj: TJSONObject;
  out ACreatedAt, ALastAccessed: string);

implementation

uses
  jsonparser;

function BuildCacheParseIndexEntryJSON(const AEntryJSON: string; out AJSONObj: TJSONObject): Boolean;
var
  JSONData: TJSONData;
begin
  Result := False;
  AJSONObj := nil;

  JSONData := GetJSON(AEntryJSON);
  if not (JSONData is TJSONObject) then
  begin
    JSONData.Free;
    Exit;
  end;

  AJSONObj := TJSONObject(JSONData);
  Result := True;
end;

function BuildCacheBuildIndexEntryJSON(const AVersion, ACPU, AOS, AArchivePath: string;
  AArchiveSize: Int64; const ASourceType, ASHA256, ADownloadURL, ASourcePath: string;
  AAccessCount: Integer; ACreatedAt, ALastAccessed: TDateTime): string;
var
  JSONObj: TJSONObject;
begin
  JSONObj := TJSONObject.Create;
  try
    JSONObj.Add('version', AVersion);
    JSONObj.Add('cpu', ACPU);
    JSONObj.Add('os', AOS);
    JSONObj.Add('archive_path', AArchivePath);
    JSONObj.Add('archive_size', AArchiveSize);
    JSONObj.Add('created_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', ACreatedAt));
    JSONObj.Add('source_type', ASourceType);
    JSONObj.Add('sha256', ASHA256);
    JSONObj.Add('download_url', ADownloadURL);
    JSONObj.Add('source_path', ASourcePath);
    JSONObj.Add('access_count', AAccessCount);

    if ALastAccessed > 0 then
      JSONObj.Add('last_accessed', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', ALastAccessed))
    else
      JSONObj.Add('last_accessed', '');

    Result := AVersion + '=' + JSONObj.AsJSON;
  finally
    JSONObj.Free;
  end;
end;

function BuildCacheNormalizeIndexDate(const ADateStr: string): string;
begin
  Result := StringReplace(ADateStr, 'T', ' ', []);
end;

function BuildCacheGetIndexEntryJSON(const AIndexEntries: TStringList; const AVersion: string): string;
begin
  if Assigned(AIndexEntries) then
    Result := AIndexEntries.Values[AVersion]
  else
    Result := '';
end;

procedure BuildCacheGetNormalizedIndexDates(const AJSONObj: TJSONObject;
  out ACreatedAt, ALastAccessed: string);
var
  DateStr: string;
begin
  ACreatedAt := '';
  ALastAccessed := '';

  if not Assigned(AJSONObj) then
    Exit;

  DateStr := AJSONObj.Get('created_at', '');
  if DateStr <> '' then
    ACreatedAt := BuildCacheNormalizeIndexDate(DateStr);

  DateStr := AJSONObj.Get('last_accessed', '');
  if DateStr <> '' then
    ALastAccessed := BuildCacheNormalizeIndexDate(DateStr);
end;

end.
