unit fpdev.cross.downloader;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.cross.manifest, fpdev.cross.cache, fpdev.toolchain.fetcher,
  fpdev.toolchain.extract;

const
  DEFAULT_MANIFEST_URL = 'https://raw.githubusercontent.com/dtamade/fpdev-repo/main/cross-toolchain-manifest.json';
  DEFAULT_TIMEOUT_MS = 30000;
  MAX_RETRY_COUNT = 3;
  RETRY_DELAYS: array[0..2] of Integer = (1000, 2000, 4000); // Exponential backoff
  MANIFEST_UPDATE_DAYS = 7; // Manifest update check interval in days
  HOST_PLATFORM_SEPARATOR = '/';

type
  { TCacheMode - Cache operation mode }
  TCacheMode = (
    cmUse,      // Use cache if valid, download if not
    cmRefresh,  // Re-download even if cache exists
    cmOnly      // Only use cache, fail if not available (offline mode)
  );

  { TDownloadOptions - Options for download operations }
  TDownloadOptions = record
    CacheMode: TCacheMode;
    OfflineMode: Boolean;       // No network operations
    DownloadOnly: Boolean;      // Download without installing
    LocalArchive: string;       // Install from local file
    TimeoutMS: Integer;         // Download timeout
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

  { TCrossToolchainDownloader - Main downloader class }
  TCrossToolchainDownloader = class
  private
    FManifest: TCrossToolchainManifest;
    FCache: TCrossToolchainCache;
    FOptions: TDownloadOptions;
    FOnProgress: TProgressCallback;
    FManifestURL: string;
    FDataRoot: string;
    FLastError: string;
    FCurrentProgress: TDownloadProgress;  // Current progress state for callback
    
    function GetCacheDir: string;
    function GetInstallDir(const ATarget: string): string;
    procedure ReportProgress(const AProgress: TDownloadProgress);
    function DownloadWithRetry(const AURLs: TStringDynArray; const ADestFile, ASHA256: string): Boolean;
    function SleepMS(AMilliseconds: Integer): Boolean;

  public
    constructor Create(const ADataRoot: string; const AManifestURL: string = '');
    destructor Destroy; override;
    
    { Load or refresh manifest }
    function LoadManifest: Boolean; virtual;
    function RefreshManifest: Boolean; virtual;
    
    { Host platform detection }
    function DetectHostPlatform: THostPlatform;
    
    { Toolchain selection }
    function SelectToolchainVariant(const ATarget: string; const AHost: THostPlatform): TCrossToolchainEntry;
    function IsToolchainAvailable(const ATarget: string): Boolean;
    
    { Download operations }
    function DownloadBinutils(const ATarget: string): Boolean;
    function DownloadLibraries(const ATarget: string): Boolean;
    function InstallToolchain(const ATarget: string): Boolean;
    
    { Verification }
    function VerifyInstallation(const ATarget: string): TCrossVerificationResult;
    
    { Properties }
    property Options: TDownloadOptions read FOptions write FOptions;
    property OnProgress: TProgressCallback read FOnProgress write FOnProgress;
    property Manifest: TCrossToolchainManifest read FManifest;
    property Cache: TCrossToolchainCache read FCache;
    property LastError: string read FLastError;
    property ManifestURL: string read FManifestURL;
    property DataRoot: string read FDataRoot;
  end;

{ Helper function to create default options }
function DefaultDownloadOptions: TDownloadOptions;

implementation

uses
  fpdev.cross.verifyflow;

function DefaultDownloadOptions: TDownloadOptions;
begin
  Result.CacheMode := cmUse;
  Result.OfflineMode := False;
  Result.DownloadOnly := False;
  Result.LocalArchive := '';
  Result.TimeoutMS := DEFAULT_TIMEOUT_MS;
end;

{ TCrossToolchainDownloader }

constructor TCrossToolchainDownloader.Create(const ADataRoot: string; const AManifestURL: string);
begin
  inherited Create;
  FDataRoot := ADataRoot;
  if AManifestURL <> '' then
    FManifestURL := AManifestURL
  else
    FManifestURL := DEFAULT_MANIFEST_URL;
  
  FManifest := TCrossToolchainManifest.Create;
  FCache := TCrossToolchainCache.Create(GetCacheDir);
  FOptions := DefaultDownloadOptions;
  FOnProgress := nil;
  FLastError := '';
end;

destructor TCrossToolchainDownloader.Destroy;
begin
  FCache.Free;
  FManifest.Free;
  inherited Destroy;
end;

function TCrossToolchainDownloader.GetCacheDir: string;
begin
  Result := IncludeTrailingPathDelimiter(FDataRoot) + 'cache' + PathDelim + 'cross' + PathDelim;
end;

function TCrossToolchainDownloader.GetInstallDir(const ATarget: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDataRoot) + 'cross' + PathDelim + LowerCase(ATarget) + PathDelim;
end;

procedure TCrossToolchainDownloader.ReportProgress(const AProgress: TDownloadProgress);
begin
  if Assigned(FOnProgress) then
    FOnProgress(AProgress);
end;

function TCrossToolchainDownloader.SleepMS(AMilliseconds: Integer): Boolean;
begin
  Sleep(AMilliseconds);
  Result := True;
end;

function TCrossToolchainDownloader.LoadManifest: Boolean;
var
  ManifestPath: string;
begin
  Result := False;
  FLastError := '';
  
  ManifestPath := IncludeTrailingPathDelimiter(FDataRoot) + 'cross-manifest.json';
  
  // Try to load from local file first
  if FileExists(ManifestPath) then
  begin
    if FManifest.LoadFromFile(ManifestPath) then
    begin
      // Check if update needed (unless offline)
      if (not FOptions.OfflineMode) and FManifest.NeedsUpdate then
        RefreshManifest;
      Result := True;
      Exit;
    end;
  end;
  
  // If offline mode, fail if no local manifest
  if FOptions.OfflineMode then
  begin
    FLastError := 'No local manifest available in offline mode';
    Exit;
  end;
  
  // Download manifest
  Result := RefreshManifest;
end;

function TCrossToolchainDownloader.RefreshManifest: Boolean;
var
  ManifestPath, TempPath, ErrMsg: string;
  URLs: array[0..0] of string;
  Opt: TFetchOptions;
begin
  Result := False;
  FLastError := '';
  
  if FOptions.OfflineMode then
  begin
    FLastError := 'Cannot refresh manifest in offline mode';
    Exit;
  end;
  
  ManifestPath := IncludeTrailingPathDelimiter(FDataRoot) + 'cross-manifest.json';
  TempPath := ManifestPath + '.tmp';
  
  // Ensure directory exists
  ForceDirectories(ExtractFileDir(ManifestPath));
  
  URLs[0] := FManifestURL;
  Opt.DestDir := ExtractFileDir(ManifestPath);
  Opt.Hash := ''; // No checksum for manifest
  Opt.HashAlgorithm := haUnknown;
  Opt.HashDigest := '';
  Opt.TimeoutMS := FOptions.TimeoutMS;
  Opt.ExpectedSize := 0;
  
  if not FetchWithMirrors(URLs, TempPath, Opt, ErrMsg) then
  begin
    FLastError := 'Failed to download manifest: ' + ErrMsg;
    Exit;
  end;
  
  // Validate downloaded manifest
  if not FManifest.LoadFromFile(TempPath) then
  begin
    FLastError := 'Downloaded manifest is invalid: ' + FManifest.LastError.Message;
    DeleteFile(TempPath);
    Exit;
  end;
  
  // Replace old manifest
  if FileExists(ManifestPath) then
    DeleteFile(ManifestPath);
  if not RenameFile(TempPath, ManifestPath) then
  begin
    FLastError := 'Failed to save manifest';
    Exit;
  end;
  
  Result := True;
end;

function TCrossToolchainDownloader.DetectHostPlatform: THostPlatform;
begin
  // Detect OS
  {$IFDEF WINDOWS}
  Result.OS := 'windows';
  {$ENDIF}
  {$IFDEF LINUX}
  Result.OS := 'linux';
  {$ENDIF}
  {$IFDEF DARWIN}
  Result.OS := 'darwin';
  {$ENDIF}
  {$IFDEF FREEBSD}
  Result.OS := 'freebsd';
  {$ENDIF}
  
  // Detect architecture
  {$IFDEF CPUX86_64}
  Result.Arch := 'x86_64';
  {$ENDIF}
  {$IFDEF CPUAARCH64}
  Result.Arch := 'aarch64';
  {$ENDIF}
  {$IFDEF CPUI386}
  Result.Arch := 'i386';
  {$ENDIF}
  {$IFDEF CPUARM}
  Result.Arch := 'arm';
  {$ENDIF}
end;

function TCrossToolchainDownloader.SelectToolchainVariant(
  const ATarget: string;
  const AHost: THostPlatform
): TCrossToolchainEntry;
begin
  Result := FManifest.FindEntry(ATarget, 'binutils', AHost);
end;

function TCrossToolchainDownloader.IsToolchainAvailable(const ATarget: string): Boolean;
var
  Host: THostPlatform;
  Entry: TCrossToolchainEntry;
begin
  Host := DetectHostPlatform;
  Entry := FManifest.FindEntry(ATarget, 'binutils', Host);
  Result := Entry.Target <> '';
end;

function TCrossToolchainDownloader.DownloadWithRetry(
  const AURLs: TStringDynArray;
  const ADestFile, ASHA256: string
): Boolean;
var
  Retry, MirrorIdx: Integer;
  Progress: TDownloadProgress;
  Opt: TFetchOptions;
  ErrMsg: string;
  SingleURL: array[0..0] of string;
begin
  Result := False;
  FLastError := '';

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
      // Initialize progress
      Progress.TotalBytes := 0;
      Progress.DownloadedBytes := 0;
      Progress.SpeedBytesPerSec := 0;
      Progress.CurrentMirror := AURLs[MirrorIdx];
      Progress.RetryCount := Retry;
      Progress.CurrentFile := ExtractFileName(ADestFile);
      ReportProgress(Progress);
      
      SingleURL[0] := AURLs[MirrorIdx];

      // Store current state for progress callback
      FCurrentProgress := Progress;

      if FetchWithMirrors(SingleURL, ADestFile, Opt, ErrMsg) then
      begin
        // Report completion
        Progress.DownloadedBytes := Progress.TotalBytes;
        ReportProgress(Progress);
        Result := True;
        Exit;
      end;
      
      FLastError := ErrMsg;
      
      // Wait before retry (exponential backoff)
      if Retry < MAX_RETRY_COUNT - 1 then
        SleepMS(RETRY_DELAYS[Retry]);
    end;
  end;
end;

function TCrossToolchainDownloader.DownloadBinutils(const ATarget: string): Boolean;
var
  Host: THostPlatform;
  Entry: TCrossToolchainEntry;
  CachePath, InstallDir, ErrMsg: string;
begin
  Result := False;
  FLastError := '';
  
  // Load manifest if needed
  if Length(FManifest.Entries) = 0 then
  begin
    if not LoadManifest then
      Exit;
  end;
  
  Host := DetectHostPlatform;
  Entry := FManifest.FindEntry(ATarget, 'binutils', Host);
  
  if Entry.Target = '' then
  begin
    FLastError := 'No binutils available for target ' + ATarget + ' on ' +
      Host.OS + HOST_PLATFORM_SEPARATOR + Host.Arch;
    Exit;
  end;
  
  // Check cache first (unless refresh mode)
  if (FOptions.CacheMode <> cmRefresh) and
     FCache.HasValidCache(ATarget, 'binutils', Entry.SHA256) then
  begin
    CachePath := FCache.GetCachedArchive(ATarget, 'binutils');
  end
  else
  begin
    // Offline mode - fail if not in cache
    if FOptions.OfflineMode or (FOptions.CacheMode = cmOnly) then
    begin
      FLastError := 'Binutils not in cache and offline mode is enabled';
      Exit;
    end;
    
    // Download
    CachePath := GetCacheDir + LowerCase(ATarget) + '-binutils.' + Entry.ArchiveFormat;
    ForceDirectories(ExtractFileDir(CachePath));
    
    if not DownloadWithRetry(Entry.URLs, CachePath, Entry.SHA256) then
      Exit;
    
    // Store in cache
    FCache.StoreArchive(CachePath, ATarget, 'binutils');
  end;
  
  // Download only mode - don't extract
  if FOptions.DownloadOnly then
  begin
    Result := True;
    Exit;
  end;
  
  // Extract to install directory
  InstallDir := GetInstallDir(ATarget);
  ForceDirectories(InstallDir);

  if not ZipExtract(CachePath, InstallDir, ErrMsg) then
  begin
    FLastError := 'Failed to extract binutils: ' + ErrMsg;
    Exit;
  end;
  
  Result := True;
end;

function TCrossToolchainDownloader.DownloadLibraries(const ATarget: string): Boolean;
var
  Host: THostPlatform;
  Entry: TCrossToolchainEntry;
  CachePath, InstallDir, ErrMsg: string;
begin
  Result := False;
  FLastError := '';
  
  // Load manifest if needed
  if Length(FManifest.Entries) = 0 then
  begin
    if not LoadManifest then
      Exit;
  end;
  
  Host := DetectHostPlatform;
  Entry := FManifest.FindEntry(ATarget, 'libraries', Host);
  
  if Entry.Target = '' then
  begin
    FLastError := 'No libraries available for target ' + ATarget + ' on ' +
      Host.OS + HOST_PLATFORM_SEPARATOR + Host.Arch;
    Exit;
  end;
  
  // Check cache first (unless refresh mode)
  if (FOptions.CacheMode <> cmRefresh) and
     FCache.HasValidCache(ATarget, 'libraries', Entry.SHA256) then
  begin
    CachePath := FCache.GetCachedArchive(ATarget, 'libraries');
  end
  else
  begin
    // Offline mode - fail if not in cache
    if FOptions.OfflineMode or (FOptions.CacheMode = cmOnly) then
    begin
      FLastError := 'Libraries not in cache and offline mode is enabled';
      Exit;
    end;
    
    // Download
    CachePath := GetCacheDir + LowerCase(ATarget) + '-libraries.' + Entry.ArchiveFormat;
    ForceDirectories(ExtractFileDir(CachePath));
    
    if not DownloadWithRetry(Entry.URLs, CachePath, Entry.SHA256) then
      Exit;
    
    // Store in cache
    FCache.StoreArchive(CachePath, ATarget, 'libraries');
  end;
  
  // Download only mode - don't extract
  if FOptions.DownloadOnly then
  begin
    Result := True;
    Exit;
  end;
  
  // Extract to install directory
  InstallDir := GetInstallDir(ATarget);
  ForceDirectories(InstallDir);

  if not ZipExtract(CachePath, InstallDir, ErrMsg) then
  begin
    FLastError := 'Failed to extract libraries: ' + ErrMsg;
    Exit;
  end;
  
  Result := True;
end;

function TCrossToolchainDownloader.InstallToolchain(const ATarget: string): Boolean;
begin
  Result := False;
  FLastError := '';
  
  // Download and install binutils
  if not DownloadBinutils(ATarget) then
    Exit;
  
  // Download and install libraries
  if not DownloadLibraries(ATarget) then
    Exit;
  
  Result := True;
end;

function TCrossToolchainDownloader.VerifyInstallation(const ATarget: string): TCrossVerificationResult;
var
  Host: THostPlatform;
  Entry: TCrossToolchainEntry;
  InstallDir: string;
begin
  Result.Success := False;
  Result.MissingBinaries := TStringList.Create;
  Result.VersionInfo := '';
  Result.ErrorMessage := '';
  
  // Load manifest if needed
  if Length(FManifest.Entries) = 0 then
  begin
    if not LoadManifest then
    begin
      Result.ErrorMessage := FLastError;
      Exit;
    end;
  end;
  
  Host := DetectHostPlatform;
  Entry := FManifest.FindEntry(ATarget, 'binutils', Host);
  
  if Entry.Target = '' then
  begin
    Result.ErrorMessage := 'No binutils entry found for target ' + ATarget;
    Exit;
  end;

  InstallDir := GetInstallDir(ATarget);
  Result.MissingBinaries.Free;
  Result := VerifyCrossBinutilsInstallationCore(InstallDir, ATarget, Entry.Version, Entry.SHA256);
end;

end.
