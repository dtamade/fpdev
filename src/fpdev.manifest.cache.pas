unit fpdev.manifest.cache;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils,
  fpdev.manifest, fpdev.utils.fs, fpdev.paths;

const
  MANIFEST_CACHE_TTL_HOURS = 24;  // Cache TTL: 24 hours

type
  { TManifestCache - Manages local caching of manifest files }
  TManifestCache = class
  private
    FCacheDir: string;

    function GetCachePath(const APackage: string): string;
    function GetCacheAge(const APackage: string): Integer;  // Returns age in hours

  public
    constructor Create(const ACacheDir: string);

    { Download manifest from remote repository }
    function DownloadManifest(const APackage: string; out AError: string): Boolean;

    { Load manifest from cache }
    function LoadCachedManifest(const APackage: string; out AManifest: TManifestParser; AForceRefresh: Boolean = False): Boolean;

    { Check if cached manifest exists and is valid }
    function HasValidCache(const APackage: string): Boolean;

    { Get cache directory path }
    property CacheDir: string read FCacheDir;
  end;

implementation

uses
  fphttpclient, openssl;

{ TManifestCache }

constructor TManifestCache.Create(const ACacheDir: string);
begin
  inherited Create;

  if ACacheDir = '' then
    FCacheDir := GetCacheDir + PathDelim + 'manifests'
  else
    FCacheDir := ACacheDir;

  EnsureDir(FCacheDir);
end;

function TManifestCache.GetCachePath(const APackage: string): string;
begin
  Result := FCacheDir + PathDelim + APackage + '.json';
end;

function TManifestCache.GetCacheAge(const APackage: string): Integer;
var
  CachePath: string;
  FileTime: TDateTime;
  FileAgeValue: LongInt;
begin
  Result := -1;

  CachePath := GetCachePath(APackage);
  if not FileExists(CachePath) then
    Exit;

  FileAgeValue := FileAge(CachePath);
  if FileAgeValue = -1 then
    Exit;

  FileTime := FileDateToDateTime(FileAgeValue);
  Result := HoursBetween(Now, FileTime);
end;

function TManifestCache.DownloadManifest(const APackage: string; out AError: string): Boolean;
var
  URL: string;
  CachePath: string;
  HTTP: TFPHTTPClient;
  Stream: TFileStream;
begin
  Result := False;
  AError := '';

  // Construct GitHub raw URL
  URL := Format('https://raw.githubusercontent.com/dtamade/fpdev-%s/main/manifest.json', [APackage]);

  CachePath := GetCachePath(APackage);

  try
    // Initialize OpenSSL for HTTPS
    InitSSLInterface;

    HTTP := TFPHTTPClient.Create(nil);
    try
      Stream := TFileStream.Create(CachePath, fmCreate);
      try
        HTTP.Get(URL, Stream);
        Result := True;
      finally
        Stream.Free;
      end;
    finally
      HTTP.Free;
    end;
  except
    on E: Exception do
    begin
      AError := 'Failed to download manifest: ' + E.Message;

      // Clean up partial download
      if FileExists(CachePath) then
        DeleteFile(CachePath);
    end;
  end;
end;

function TManifestCache.LoadCachedManifest(const APackage: string; out AManifest: TManifestParser; AForceRefresh: Boolean): Boolean;
var
  CachePath: string;
  Age: Integer;
  Err: string;
begin
  Result := False;
  AManifest := nil;

  CachePath := GetCachePath(APackage);

  // Check if cache exists
  if not FileExists(CachePath) then
  begin
    // No cache, download
    if not DownloadManifest(APackage, Err) then
      Exit;
  end
  else
  begin
    // Check cache age
    Age := GetCacheAge(APackage);

    if AForceRefresh or (Age > MANIFEST_CACHE_TTL_HOURS) then
    begin
      // Cache expired or force refresh, try to update
      if not DownloadManifest(APackage, Err) then
      begin
        // Download failed, use expired cache if available
        if Age > 0 then
        begin
          // Use expired cache
        end
        else
          Exit;  // No cache available
      end;
    end;
  end;

  // Load manifest from cache
  AManifest := TManifestParser.Create;
  Result := AManifest.LoadFromFile(CachePath);

  if not Result then
  begin
    AManifest.Free;
    AManifest := nil;
  end;
end;

function TManifestCache.HasValidCache(const APackage: string): Boolean;
var
  Age: Integer;
begin
  Age := GetCacheAge(APackage);
  Result := (Age >= 0) and (Age <= MANIFEST_CACHE_TTL_HOURS);
end;

end.
