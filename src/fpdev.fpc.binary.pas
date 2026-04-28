unit fpdev.fpc.binary;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file

interface

uses
  Classes, SysUtils, fpdev.platform, fpdev.fpc.mirrors,
  fpdev.archive.extract, fpdev.build.cache,
  fpdev.build.cache.types, fpdev.fpc.binaryflow,
  fpdev.fpc.types, fpdev.fpc.verifyflow,
  fpdev.toolchain.fetcher, fpdev.manifest, fpdev.paths;

type
  { TBinaryInstaller - Manages FPC binary installation }
  TBinaryInstaller = class
  private
    FMirrorManager: TMirrorManager;
    FExtractor: TArchiveExtractor;
    FCacheManager: TBuildCache;
    FManifestParser: TManifestParser;
    FLastError: string;
    FUseCache: Boolean;
    FOfflineMode: Boolean;
    FVerifyInstallation: Boolean;
    FUseManifest: Boolean;

    procedure WriteStatusLine(const AText: string);
    procedure EnsureManifestParserCreated;
    procedure ConfigureBinaryManifestCallbacks(
      out ACallbacks: TBinaryManifestCallbacks
    );
    procedure ConfigureBinaryDownloadCallbacks(
      out ACallbacks: TBinaryDownloadCallbacks
    );
    procedure ConfigureBinaryInstallCallbacks(
      out ACallbacks: TBinaryInstallCallbacks
    );
    function LoadManifestFromURL(const AManifestURL: string): Boolean;
    function GetManifestParserError: string;
    function ResolveManifestTarget(
      const AVersion, APlatform: string;
      out ATarget: TManifestTarget
    ): Boolean;
    function ResolveLegacyDownloadURL(
      const AVersion, APlatform: string
    ): string;
    function EnsureBinaryDownloaded(
      const AURLs: TStringArray;
      const ADestFile: string;
      const AOptions: TFetchOptions;
      out AError: string
    ): Boolean;
    function DownloadBinaryWithError(
      const AVersion, ADestFile: string;
      out AError: string
    ): Boolean;
    function ExtractBinaryArchive(
      const AArchive, AInstallDir: string;
      out AError: string
    ): Boolean;
    procedure SaveBinaryArtifactToCache(
      const ACacheKey, AArchivePath: string
    );
    function RunInstalledVerification(
      const AVersion, AInstallDir: string;
      out AVerifResult: TVerificationResult
    ): Boolean;
    function WriteVerificationMetadata(
      const AVersion, AInstallDir: string;
      const AVerifResult: TVerificationResult
    ): Boolean;
    function GetCacheKey(const AVersion: string): string;
    function DownloadBinary(const AVersion, ADestFile: string): Boolean;
    function LoadManifest(const AManifestURL: string): Boolean;
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
    property VerifyInstallation: Boolean read FVerifyInstallation write FVerifyInstallation;
    property UseManifest: Boolean read FUseManifest write FUseManifest;

    { Get last error message }
    function GetLastError: string;
  end;

implementation

{ TBinaryInstaller }

constructor TBinaryInstaller.Create;
begin
  inherited Create;
  FMirrorManager := TMirrorManager.Create;
  FExtractor := TArchiveExtractor.Create;
  FCacheManager := TBuildCache.Create(IncludeTrailingPathDelimiter(GetDataRoot) + 'cache');
  FManifestParser := nil;  // Create lazily when needed
  FLastError := '';
  FUseCache := True;
  FOfflineMode := False;
  FVerifyInstallation := True;
  FUseManifest := False;  // Disable manifest-based downloads by default (needs more testing)
end;

destructor TBinaryInstaller.Destroy;
begin
  if Assigned(FManifestParser) then
    FManifestParser.Free;
  FCacheManager.Free;
  FExtractor.Free;
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

procedure TBinaryInstaller.WriteStatusLine(const AText: string);
begin
  WriteLn(AText);
end;

procedure TBinaryInstaller.EnsureManifestParserCreated;
begin
  if not Assigned(FManifestParser) then
    FManifestParser := TManifestParser.Create;
end;

procedure TBinaryInstaller.ConfigureBinaryManifestCallbacks(
  out ACallbacks: TBinaryManifestCallbacks
);
begin
  ACallbacks := Default(TBinaryManifestCallbacks);
  ACallbacks.Log := @Self.WriteStatusLine;
  ACallbacks.EnsureManifestParser := @Self.EnsureManifestParserCreated;
  ACallbacks.LoadFromURL := @Self.LoadManifestFromURL;
  ACallbacks.GetManifestError := @Self.GetManifestParserError;
end;

procedure TBinaryInstaller.ConfigureBinaryDownloadCallbacks(
  out ACallbacks: TBinaryDownloadCallbacks
);
begin
  ACallbacks := Default(TBinaryDownloadCallbacks);
  ACallbacks.Log := @Self.WriteStatusLine;
  ACallbacks.EnsureManifestParser := @Self.EnsureManifestParserCreated;
  ACallbacks.ResolveManifestTarget := @Self.ResolveManifestTarget;
  ACallbacks.ResolveLegacyURL := @Self.ResolveLegacyDownloadURL;
  ACallbacks.EnsureDownloaded := @Self.EnsureBinaryDownloaded;
end;

procedure TBinaryInstaller.ConfigureBinaryInstallCallbacks(
  out ACallbacks: TBinaryInstallCallbacks
);
begin
  ACallbacks := Default(TBinaryInstallCallbacks);
  ACallbacks.Log := @Self.WriteStatusLine;
  ACallbacks.GetCacheKey := @Self.GetCacheKey;
  ACallbacks.HasArtifacts := @FCacheManager.HasArtifacts;
  ACallbacks.GetBinaryArtifactInfo := @FCacheManager.GetBinaryArtifactInfo;
  ACallbacks.RestoreBinaryArtifact := @FCacheManager.RestoreBinaryArtifact;
  ACallbacks.DownloadBinary := @Self.DownloadBinaryWithError;
  ACallbacks.ExtractArchive := @Self.ExtractBinaryArchive;
  ACallbacks.SaveBinaryArtifact := @Self.SaveBinaryArtifactToCache;
  ACallbacks.RunVerification := @Self.RunInstalledVerification;
  ACallbacks.WriteVerificationMetadata := @Self.WriteVerificationMetadata;
end;

function TBinaryInstaller.LoadManifestFromURL(const AManifestURL: string): Boolean;
begin
  EnsureManifestParserCreated;
  Result := FManifestParser.LoadFromURL(AManifestURL);
end;

function TBinaryInstaller.GetManifestParserError: string;
begin
  if Assigned(FManifestParser) then
    Result := FManifestParser.LastError
  else
    Result := '';
end;

function TBinaryInstaller.ResolveManifestTarget(
  const AVersion, APlatform: string;
  out ATarget: TManifestTarget
): Boolean;
begin
  EnsureManifestParserCreated;
  Result := FManifestParser.GetTarget('fpc', AVersion, APlatform, ATarget);
end;

function TBinaryInstaller.ResolveLegacyDownloadURL(
  const AVersion, APlatform: string
): string;
begin
  Result := FMirrorManager.GetDownloadURL(AVersion, APlatform);
end;

function TBinaryInstaller.EnsureBinaryDownloaded(
  const AURLs: TStringArray;
  const ADestFile: string;
  const AOptions: TFetchOptions;
  out AError: string
): Boolean;
begin
  Result := EnsureDownloadedCached(AURLs, ADestFile, AOptions, AError);
end;

function TBinaryInstaller.DownloadBinaryWithError(
  const AVersion, ADestFile: string;
  out AError: string
): Boolean;
var
  Platform: TPlatformInfo;
  Callbacks: TBinaryDownloadCallbacks;
begin
  Platform := DetectPlatform;
  ConfigureBinaryDownloadCallbacks(Callbacks);
  Result := DownloadBinaryArchiveCore(
    AVersion,
    ADestFile,
    Platform.ToString,
    FUseManifest,
    FOfflineMode,
    Callbacks,
    AError
  );
end;

function TBinaryInstaller.ExtractBinaryArchive(
  const AArchive, AInstallDir: string;
  out AError: string
): Boolean;
begin
  Result := FExtractor.Extract(AArchive, AInstallDir);
  if Result then
    AError := ''
  else
    AError := FExtractor.GetLastError;
end;

procedure TBinaryInstaller.SaveBinaryArtifactToCache(
  const ACacheKey, AArchivePath: string
);
begin
  FCacheManager.SaveBinaryArtifact(ACacheKey, AArchivePath);
end;

function TBinaryInstaller.RunInstalledVerification(
  const AVersion, AInstallDir: string;
  out AVerifResult: TVerificationResult
): Boolean;
begin
  Result := RunInstalledFPCVerificationCore(
    AVersion,
    AInstallDir,
    AVerifResult
  );
end;

function TBinaryInstaller.WriteVerificationMetadata(
  const AVersion, AInstallDir: string;
  const AVerifResult: TVerificationResult
): Boolean;
begin
  Result := WriteBinaryInstallVerificationMetadataCore(
    AVersion,
    AInstallDir,
    AVerifResult
  );
end;

function TBinaryInstaller.LoadManifest(const AManifestURL: string): Boolean;
var
  Callbacks: TBinaryManifestCallbacks;
begin
  ConfigureBinaryManifestCallbacks(Callbacks);
  Result := LoadBinaryManifestCore(AManifestURL, FOfflineMode, Callbacks);
end;

function TBinaryInstaller.DownloadBinary(const AVersion, ADestFile: string): Boolean;
var
  Platform: TPlatformInfo;
  Callbacks: TBinaryDownloadCallbacks;
begin
  FLastError := '';
  Platform := DetectPlatform;
  ConfigureBinaryDownloadCallbacks(Callbacks);
  Result := DownloadBinaryArchiveCore(
    AVersion,
    ADestFile,
    Platform.ToString,
    FUseManifest,
    FOfflineMode,
    Callbacks,
    FLastError
  );
end;

function TBinaryInstaller.Install(const AVersion, AInstallDir: string): Boolean;
var
  Callbacks: TBinaryInstallCallbacks;
begin
  FLastError := '';
  ConfigureBinaryInstallCallbacks(Callbacks);
  Result := ExecuteBinaryInstallCore(
    AVersion,
    AInstallDir,
    FUseCache,
    FOfflineMode,
    FVerifyInstallation,
    Callbacks,
    FLastError
  );
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
