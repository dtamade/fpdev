unit fpdev.fpc.binary;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpdev.platform, fpdev.fpc.mirrors,
  fpdev.http.download, fpdev.archive.extract, fpdev.build.cache;

type
  { TBinaryInstaller - Manages FPC binary installation }
  TBinaryInstaller = class
  private
    FMirrorManager: TMirrorManager;
    FDownloader: THTTPDownloader;
    FExtractor: TArchiveExtractor;
    FCacheManager: TBuildCache;
    FLastError: string;
    FUseCache: Boolean;
    FOfflineMode: Boolean;

    function GetCacheKey(const AVersion: string): string;
    function DownloadBinary(const AVersion, ADestFile: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { Install FPC binary for specified version }
    function Install(const AVersion, AInstallDir: string): Boolean;

    { Check if binary is available in cache }
    function IsCached(const AVersion: string): Boolean;

    { Configuration }
    property UseCache: Boolean read FUseCache write FUseCache;
    property OfflineMode: Boolean read FOfflineMode write FOfflineMode;

    { Get last error message }
    function GetLastError: string;
  end;

implementation

{ TBinaryInstaller }

constructor TBinaryInstaller.Create;
begin
  inherited Create;
  FMirrorManager := TMirrorManager.Create;
  FDownloader := THTTPDownloader.Create;
  FExtractor := TArchiveExtractor.Create;
  FCacheManager := TBuildCache.Create(GetUserDir + '.fpdev' + PathDelim + 'cache');
  FLastError := '';
  FUseCache := True;
  FOfflineMode := False;
end;

destructor TBinaryInstaller.Destroy;
begin
  FCacheManager.Free;
  FExtractor.Free;
  FDownloader.Free;
  FMirrorManager.Free;
  inherited Destroy;
end;

function TBinaryInstaller.GetCacheKey(const AVersion: string): string;
var
  Platform: TPlatformInfo;
begin
  Platform := DetectPlatform;
  Result := 'fpc-' + AVersion + '-' + Platform.ToString;
end;

function TBinaryInstaller.DownloadBinary(const AVersion, ADestFile: string): Boolean;
var
  Platform: TPlatformInfo;
  URL: string;
begin
  Result := False;

  if FOfflineMode then
  begin
    FLastError := 'Offline mode enabled, cannot download';
    Exit;
  end;

  Platform := DetectPlatform;
  URL := FMirrorManager.GetDownloadURL(AVersion, Platform.ToString);

  if URL = '' then
  begin
    FLastError := 'Failed to generate download URL';
    Exit;
  end;

  WriteLn('Downloading from: ', URL);
  Result := FDownloader.Download(URL, ADestFile);

  if not Result then
    FLastError := FDownloader.GetLastError;
end;

function TBinaryInstaller.Install(const AVersion, AInstallDir: string): Boolean;
var
  CacheKey: string;
  TempArchive: string;
  CacheInfo: TArtifactInfo;
begin
  Result := False;
  FLastError := '';

  // Check cache first if enabled
  if FUseCache then
  begin
    CacheKey := GetCacheKey(AVersion);
    if FCacheManager.HasArtifacts(CacheKey) then
    begin
      WriteLn('Found in cache, restoring...');
      if FCacheManager.GetBinaryArtifactInfo(CacheKey, CacheInfo) then
        WriteLn('Cache info: ', CacheInfo.Version);
      if FCacheManager.RestoreBinaryArtifact(CacheKey, AInstallDir) then
      begin
        WriteLn('Successfully restored from cache');
        Result := True;
        Exit;
      end
      else
        WriteLn('Cache restore failed, falling back to download');
    end;
  end;

  // Download binary
  TempArchive := GetTempDir + 'fpc-' + AVersion + '.tar.gz';
  try
    if not DownloadBinary(AVersion, TempArchive) then
    begin
      if FOfflineMode then
        FLastError := 'Binary not in cache and offline mode enabled'
      else
        FLastError := 'Failed to download binary: ' + FLastError;
      Exit;
    end;

    // Extract archive
    WriteLn('Extracting archive...');
    if not FExtractor.Extract(TempArchive, AInstallDir) then
    begin
      FLastError := 'Failed to extract archive: ' + FExtractor.GetLastError;
      Exit;
    end;

    // Save to cache if enabled
    if FUseCache and not FOfflineMode then
    begin
      WriteLn('Saving to cache...');
      CacheKey := GetCacheKey(AVersion);
      FCacheManager.SaveBinaryArtifact(CacheKey, TempArchive);
    end;

    Result := True;
    WriteLn('Installation complete');

  finally
    // Clean up temporary file
    if FileExists(TempArchive) then
      DeleteFile(TempArchive);
  end;
end;

function TBinaryInstaller.IsCached(const AVersion: string): Boolean;
var
  CacheKey: string;
begin
  CacheKey := GetCacheKey(AVersion);
  Result := FCacheManager.HasArtifacts(CacheKey);
end;

function TBinaryInstaller.GetLastError: string;
begin
  Result := FLastError;
end;

end.
