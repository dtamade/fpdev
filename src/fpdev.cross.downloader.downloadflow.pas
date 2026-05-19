unit fpdev.cross.downloader.downloadflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.cross.manifest, fpdev.cross.cache,
  fpdev.toolchain.fetcher, fpdev.toolchain.extract;

const
  DEFAULT_MANIFEST_URL = 'https://raw.githubusercontent.com/dtamade/fpdev-repo/main/cross-toolchain-manifest.json';
  DEFAULT_TIMEOUT_MS = 30000;
  MAX_RETRY_COUNT = 3;
  RETRY_DELAYS: array[0..2] of Integer = (1000, 2000, 4000);
  MANIFEST_UPDATE_DAYS = 7;
  HOST_PLATFORM_SEPARATOR = '/';

type
  { TCacheMode - Cache operation mode }
  TCacheMode = (
    cmUse,
    cmRefresh,
    cmOnly
  );

  { TDownloadOptions - Options for download operations }
  TDownloadOptions = record
    CacheMode: TCacheMode;
    OfflineMode: Boolean;
    DownloadOnly: Boolean;
    LocalArchive: string;
    TimeoutMS: Integer;
  end;

  { TDownloadProgress - Progress information during download }
  TDownloadProgress = record
    TotalBytes: Int64;
    DownloadedBytes: Int64;
    SpeedBytesPerSec: Int64;
    CurrentMirror: string;
    RetryCount: Integer;
    CurrentFile: string;
  end;

  { TProgressCallback - Callback for progress updates }
  TProgressCallback = procedure(const Progress: TDownloadProgress) of object;

  { TStringDynArray - Dynamic array of strings }
  TStringDynArray = array of string;

  { TCrossVerificationResult - Result of cross-toolchain verification }
  TCrossVerificationResult = record
    Success: Boolean;
    MissingBinaries: TStringList;
    VersionInfo: string;
    ErrorMessage: string;
  end;

  { TDownloadFlowCallbacks - Callbacks for download operations }
  TLoadManifestCb = function: Boolean of object;
  TDetectHostCb = function: THostPlatform of object;
  TFindEntryCb = function(const ATarget, AComponent: string;
    const AHost: THostPlatform): TCrossToolchainEntry of object;
  TGetCacheDirCb = function: string of object;
  TGetInstallDirCb = function(const ATarget: string): string of object;
  TReportProgressCb = procedure(const AProgress: TDownloadProgress) of object;
  TSleepCb = function(AMilliseconds: Integer): Boolean of object;

  { TDownloadFlow - Download orchestration with retry, cache, and extraction }
  TDownloadFlow = class
  private
    FOptions: TDownloadOptions;
    FOnError: string;
    FOnLoadManifest: TLoadManifestCb;
    FOnDetectHost: TDetectHostCb;
    FOnFindEntry: TFindEntryCb;
    FOnGetCacheDir: TGetCacheDirCb;
    FOnGetInstallDir: TGetInstallDirCb;
    FOnReportProgress: TReportProgressCb;
    FOnSleep: TSleepCb;

    function DoDownloadWithRetry(const AURLs: TStringDynArray;
      const ADestFile, ASHA256: string): Boolean;
    function DoSleep(AMilliseconds: Integer): Boolean;
  public
    constructor Create(
      const AOptions: TDownloadOptions;
      const AOnLoadManifest: TLoadManifestCb;
      const AOnDetectHost: TDetectHostCb;
      const AOnFindEntry: TFindEntryCb;
      const AOnGetCacheDir: TGetCacheDirCb;
      const AOnGetInstallDir: TGetInstallDirCb;
      const AOnReportProgress: TReportProgressCb;
      const AOnSleep: TSleepCb
    );

    function DownloadBinutils(const ATarget: string;
      const ACache: TCrossToolchainCache): Boolean;
    function DownloadLibraries(const ATarget: string;
      const ACache: TCrossToolchainCache): Boolean;
    function InstallToolchain(const ATarget: string;
      const ACache: TCrossToolchainCache): Boolean;

    property LastError: string read FOnError;
    property Options: TDownloadOptions read FOptions write FOptions;
  end;

function DefaultDownloadOptions: TDownloadOptions;

implementation

function DefaultDownloadOptions: TDownloadOptions;
begin
  Result.CacheMode := cmUse;
  Result.OfflineMode := False;
  Result.DownloadOnly := False;
  Result.LocalArchive := '';
  Result.TimeoutMS := DEFAULT_TIMEOUT_MS;
end;

{ TDownloadFlow }

constructor TDownloadFlow.Create(
  const AOptions: TDownloadOptions;
  const AOnLoadManifest: TLoadManifestCb;
  const AOnDetectHost: TDetectHostCb;
  const AOnFindEntry: TFindEntryCb;
  const AOnGetCacheDir: TGetCacheDirCb;
  const AOnGetInstallDir: TGetInstallDirCb;
  const AOnReportProgress: TReportProgressCb;
  const AOnSleep: TSleepCb
);
begin
  inherited Create;
  FOptions := AOptions;
  FOnLoadManifest := AOnLoadManifest;
  FOnDetectHost := AOnDetectHost;
  FOnFindEntry := AOnFindEntry;
  FOnGetCacheDir := AOnGetCacheDir;
  FOnGetInstallDir := AOnGetInstallDir;
  FOnReportProgress := AOnReportProgress;
  FOnSleep := AOnSleep;
  FOnError := '';
end;

function TDownloadFlow.DoSleep(AMilliseconds: Integer): Boolean;
begin
  if Assigned(FOnSleep) then
    Result := FOnSleep(AMilliseconds)
  else
  begin
    Sleep(AMilliseconds);
    Result := True;
  end;
end;

function TDownloadFlow.DoDownloadWithRetry(const AURLs: TStringDynArray;
  const ADestFile, ASHA256: string): Boolean;
var
  Retry, MirrorIdx: Integer;
  Progress: TDownloadProgress;
  Opt: TFetchOptions;
  ErrMsg: string;
  SingleURL: array[0..0] of string;
begin
  Result := False;
  FOnError := '';

  Opt.DestDir := ExtractFileDir(ADestFile);
  Opt.Hash := 'sha256:' + ASHA256;
  Opt.HashAlgorithm := haSHA256;
  Opt.HashDigest := ASHA256;
  Opt.TimeoutMS := FOptions.TimeoutMS;
  Opt.ExpectedSize := 0;

  for MirrorIdx := 0 to High(AURLs) do
  begin
    for Retry := 0 to MAX_RETRY_COUNT - 1 do
    begin
      Progress.TotalBytes := 0;
      Progress.DownloadedBytes := 0;
      Progress.SpeedBytesPerSec := 0;
      Progress.CurrentMirror := AURLs[MirrorIdx];
      Progress.RetryCount := Retry;
      Progress.CurrentFile := ExtractFileName(ADestFile);
      if Assigned(FOnReportProgress) then
        FOnReportProgress(Progress);

      SingleURL[0] := AURLs[MirrorIdx];

      if FetchWithMirrors(SingleURL, ADestFile, Opt, ErrMsg) then
      begin
        Progress.DownloadedBytes := Progress.TotalBytes;
        if Assigned(FOnReportProgress) then
          FOnReportProgress(Progress);
        Result := True;
        Exit;
      end;

      FOnError := ErrMsg;

      if Retry < MAX_RETRY_COUNT - 1 then
        DoSleep(RETRY_DELAYS[Retry]);
    end;
  end;
end;

function TDownloadFlow.DownloadBinutils(const ATarget: string;
  const ACache: TCrossToolchainCache): Boolean;
var
  Host: THostPlatform;
  Entry: TCrossToolchainEntry;
  CachePath, InstallDir, ErrMsg: string;
begin
  Result := False;
  FOnError := '';

  if not FOnLoadManifest() then
    Exit;

  Host := FOnDetectHost();
  Entry := FOnFindEntry(ATarget, 'binutils', Host);

  if Entry.Target = '' then
  begin
    FOnError := 'No binutils available for target ' + ATarget + ' on ' +
      Host.OS + HOST_PLATFORM_SEPARATOR + Host.Arch;
    Exit;
  end;

  if (FOptions.CacheMode <> cmRefresh) and
     ACache.HasValidCache(ATarget, 'binutils', Entry.SHA256) then
    CachePath := ACache.GetCachedArchive(ATarget, 'binutils')
  else
  begin
    if FOptions.OfflineMode or (FOptions.CacheMode = cmOnly) then
    begin
      FOnError := 'Binutils not in cache and offline mode is enabled';
      Exit;
    end;

    CachePath := FOnGetCacheDir() + LowerCase(ATarget) + '-binutils.' + Entry.ArchiveFormat;
    ForceDirectories(ExtractFileDir(CachePath));

    if not DoDownloadWithRetry(Entry.URLs, CachePath, Entry.SHA256) then
      Exit;

    ACache.StoreArchive(CachePath, ATarget, 'binutils');
  end;

  if FOptions.DownloadOnly then
  begin
    Result := True;
    Exit;
  end;

  InstallDir := FOnGetInstallDir(ATarget);
  ForceDirectories(InstallDir);

  if not ZipExtract(CachePath, InstallDir, ErrMsg) then
  begin
    FOnError := 'Failed to extract binutils: ' + ErrMsg;
    Exit;
  end;

  Result := True;
end;

function TDownloadFlow.DownloadLibraries(const ATarget: string;
  const ACache: TCrossToolchainCache): Boolean;
var
  Host: THostPlatform;
  Entry: TCrossToolchainEntry;
  CachePath, InstallDir, ErrMsg: string;
begin
  Result := False;
  FOnError := '';

  if not FOnLoadManifest() then
    Exit;

  Host := FOnDetectHost();
  Entry := FOnFindEntry(ATarget, 'libraries', Host);

  if Entry.Target = '' then
  begin
    FOnError := 'No libraries available for target ' + ATarget + ' on ' +
      Host.OS + HOST_PLATFORM_SEPARATOR + Host.Arch;
    Exit;
  end;

  if (FOptions.CacheMode <> cmRefresh) and
     ACache.HasValidCache(ATarget, 'libraries', Entry.SHA256) then
    CachePath := ACache.GetCachedArchive(ATarget, 'libraries')
  else
  begin
    if FOptions.OfflineMode or (FOptions.CacheMode = cmOnly) then
    begin
      FOnError := 'Libraries not in cache and offline mode is enabled';
      Exit;
    end;

    CachePath := FOnGetCacheDir() + LowerCase(ATarget) + '-libraries.' + Entry.ArchiveFormat;
    ForceDirectories(ExtractFileDir(CachePath));

    if not DoDownloadWithRetry(Entry.URLs, CachePath, Entry.SHA256) then
      Exit;

    ACache.StoreArchive(CachePath, ATarget, 'libraries');
  end;

  if FOptions.DownloadOnly then
  begin
    Result := True;
    Exit;
  end;

  InstallDir := FOnGetInstallDir(ATarget);
  ForceDirectories(InstallDir);

  if not ZipExtract(CachePath, InstallDir, ErrMsg) then
  begin
    FOnError := 'Failed to extract libraries: ' + ErrMsg;
    Exit;
  end;

  Result := True;
end;

function TDownloadFlow.InstallToolchain(const ATarget: string;
  const ACache: TCrossToolchainCache): Boolean;
begin
  Result := False;
  FOnError := '';

  if not DownloadBinutils(ATarget, ACache) then
    Exit;

  if not DownloadLibraries(ATarget, ACache) then
    Exit;

  Result := True;
end;

end.
