unit fpdev.index.serviceflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson;

type
  TIndexServiceFetchJSONFunc = function(const AURL: string): TJSONObject of object;
  TIndexServiceLogProc = procedure(const AMsg: string) of object;

function BuildIndexCachePathCore(const ACacheDir: string): string;
function BuildManifestCachePathCore(const ACacheDir, AName: string): string;

function LoadRemoteJSONWithCacheCore(
  const ADisplayName, APrimaryURL, AFallbackURL, ACachePath: string;
  AFetchJSON: TIndexServiceFetchJSONFunc;
  ALogLine: TIndexServiceLogProc;
  out AUsedCache: Boolean;
  out ARemoteSucceeded: Boolean
): TJSONObject;

function BuildManifestVersionsCore(AManifestData: TJSONObject): TStringArray;

function ResolveManifestDownloadCore(
  AManifestData: TJSONObject;
  const AVersion, APlatform: string;
  out AURL: string;
  out AMirrors: TStringArray;
  out AFormat, ASHA256, AExecutable: string;
  out ASize: Int64
): Boolean;

implementation

uses
  Classes, jsonparser,
  fpdev.utils,
  fpdev.utils.fs;

procedure LogLineCore(
  ALogLine: TIndexServiceLogProc;
  const AMsg: string
);
begin
  if Assigned(ALogLine) then
    ALogLine(AMsg);
end;

function NormalizeBaseDir(const APath: string): string;
begin
  Result := Trim(APath);
  if Result = '' then
    Exit('');
  Result := IncludeTrailingPathDelimiter(ExcludeTrailingPathDelimiter(Result));
end;

function BuildIndexCachePathCore(const ACacheDir: string): string;
var
  BaseDir: string;
begin
  BaseDir := NormalizeBaseDir(ACacheDir);
  if BaseDir = '' then
    Exit('index.json');
  Result := BaseDir + 'index.json';
end;

function BuildManifestCachePathCore(const ACacheDir, AName: string): string;
var
  BaseDir: string;
begin
  BaseDir := NormalizeBaseDir(ACacheDir);
  if BaseDir = '' then
    Exit('manifests' + PathDelim + AName + '.json');
  Result := BaseDir + 'manifests' + PathDelim + AName + '.json';
end;

function LoadCachedJSONCore(
  const ACachePath, ADisplayName: string;
  ALogLine: TIndexServiceLogProc
): TJSONObject;
var
  JsonText: string;
  Parser: TJSONParser;
begin
  Result := nil;
  JsonText := ReadAllTextIfExists(ACachePath);
  if Trim(JsonText) = '' then
    Exit(nil);

  Parser := TJSONParser.Create(JsonText, []);
  try
    Result := Parser.Parse as TJSONObject;
  except
    on E: Exception do
    begin
      LogLineCore(
        ALogLine,
        Format('Warning: Failed to load cached %s: %s', [ADisplayName, E.Message])
      );
      Result := nil;
    end;
  end;
  Parser.Free;
end;

procedure SaveCachedJSONCore(
  const ACachePath, ADisplayName: string;
  AData: TJSONObject;
  ALogLine: TIndexServiceLogProc
);
var
  CacheDir: string;
begin
  if (Trim(ACachePath) = '') or (AData = nil) then
    Exit;

  CacheDir := ExtractFileDir(ACachePath);
  try
    if (CacheDir <> '') and (not EnsureDir(CacheDir)) then
      raise Exception.Create('failed to create cache directory: ' + CacheDir);
    SafeWriteAllText(ACachePath, AData.FormatJSON);
  except
    on E: Exception do
      LogLineCore(
        ALogLine,
        Format('Warning: Failed to update cached %s: %s', [ADisplayName, E.Message])
      );
  end;
end;

function LoadRemoteJSONWithCacheCore(
  const ADisplayName, APrimaryURL, AFallbackURL, ACachePath: string;
  AFetchJSON: TIndexServiceFetchJSONFunc;
  ALogLine: TIndexServiceLogProc;
  out AUsedCache: Boolean;
  out ARemoteSucceeded: Boolean
): TJSONObject;
begin
  Result := nil;
  AUsedCache := False;
  ARemoteSucceeded := False;

  if Assigned(AFetchJSON) and (APrimaryURL <> '') then
  begin
    LogLineCore(ALogLine, Format('Fetching %s from: %s', [ADisplayName, APrimaryURL]));
    Result := AFetchJSON(APrimaryURL);
  end;

  if (Result = nil) and Assigned(AFetchJSON) and (AFallbackURL <> '') and
     (AFallbackURL <> APrimaryURL) then
  begin
    LogLineCore(ALogLine, Format('Primary failed, trying fallback: %s', [AFallbackURL]));
    Result := AFetchJSON(AFallbackURL);
  end;

  if Result <> nil then
  begin
    ARemoteSucceeded := True;
    SaveCachedJSONCore(ACachePath, ADisplayName, Result, ALogLine);
    Exit(Result);
  end;

  Result := LoadCachedJSONCore(ACachePath, ADisplayName, ALogLine);
  if Result <> nil then
  begin
    AUsedCache := True;
    LogLineCore(
      ALogLine,
      Format(
        'Warning: Failed to fetch %s from remote, using cached %s: %s',
        [ADisplayName, ADisplayName, ACachePath]
      )
    );
    Exit(Result);
  end;

  LogLineCore(
    ALogLine,
    Format(
      'Warning: Failed to fetch %s from remote and no cached %s is available',
      [ADisplayName, ADisplayName]
    )
  );
end;

function BuildManifestVersionsCore(AManifestData: TJSONObject): TStringArray;
var
  Releases: TJSONObject;
  I: Integer;
begin
  Result := nil;
  if AManifestData = nil then
    Exit;

  Releases := AManifestData.Objects['releases'];
  if Releases = nil then
    Exit;

  SetLength(Result, Releases.Count);
  for I := 0 to Releases.Count - 1 do
    Result[I] := Releases.Names[I];
end;

function ResolveManifestDownloadCore(
  AManifestData: TJSONObject;
  const AVersion, APlatform: string;
  out AURL: string;
  out AMirrors: TStringArray;
  out AFormat, ASHA256, AExecutable: string;
  out ASize: Int64
): Boolean;
var
  Releases: TJSONObject;
  VersionData: TJSONObject;
  Platforms: TJSONObject;
  PlatformData: TJSONObject;
  LayoutObj: TJSONObject;
  MirrorsArray: TJSONArray;
  I: Integer;
begin
  Result := False;
  AURL := '';
  AMirrors := nil;
  AFormat := '';
  ASHA256 := '';
  AExecutable := '';
  ASize := 0;

  if AManifestData = nil then
    Exit(False);

  Releases := AManifestData.Objects['releases'];
  if Releases = nil then
    Exit(False);

  VersionData := Releases.Objects[AVersion];
  if VersionData = nil then
    Exit(False);

  Platforms := VersionData.Objects['platforms'];
  if Platforms = nil then
    Exit(False);

  PlatformData := Platforms.Objects[APlatform];
  if PlatformData = nil then
    Exit(False);

  AURL := PlatformData.Get('url', '');
  AFormat := PlatformData.Get('format', 'tar.gz');
  ASHA256 := PlatformData.Get('sha256', '');
  ASize := PlatformData.Get('size', Int64(0));

  MirrorsArray := PlatformData.Arrays['mirrors'];
  if MirrorsArray <> nil then
  begin
    SetLength(AMirrors, MirrorsArray.Count);
    for I := 0 to MirrorsArray.Count - 1 do
      AMirrors[I] := MirrorsArray.Strings[I];
  end;

  LayoutObj := PlatformData.Objects['layout'];
  if LayoutObj <> nil then
    AExecutable := LayoutObj.Get('executable', '');

  Result := AURL <> '';
end;

end.
