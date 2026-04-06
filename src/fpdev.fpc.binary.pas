unit fpdev.fpc.binary;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file

interface

uses
  Classes, SysUtils, fpdev.platform, fpdev.fpc.mirrors,
  fpdev.archive.extract, fpdev.build.cache,
  fpdev.build.cache.types, fpdev.fpc.verify, fpdev.toolchain.fetcher,
  fpdev.manifest, fpdev.paths;

type
  { TBinaryInstaller - Manages FPC binary installation }
  TBinaryInstaller = class
  private
    FMirrorManager: TMirrorManager;
    FExtractor: TArchiveExtractor;
    FCacheManager: TBuildCache;
    FVerifier: TFPCVerifier;
    FManifestParser: TManifestParser;
    FLastError: string;
    FUseCache: Boolean;
    FOfflineMode: Boolean;
    FVerifyInstallation: Boolean;
    FUseManifest: Boolean;

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
  FVerifier := TFPCVerifier.Create;
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
  FVerifier.Free;
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

function TBinaryInstaller.LoadManifest(const AManifestURL: string): Boolean;
begin
  Result := False;

  if FOfflineMode then
  begin
    WriteLn('Offline mode: skipping manifest download');
    Exit;
  end;

  // Create manifest parser lazily when needed
  if not Assigned(FManifestParser) then
    FManifestParser := TManifestParser.Create;

  WriteLn('Loading manifest from: ', AManifestURL);

  if not FManifestParser.LoadFromURL(AManifestURL) then
  begin
    WriteLn('Warning: Failed to load manifest: ', FManifestParser.LastError);
    WriteLn('Falling back to legacy download method');
    Exit;
  end;

  Result := True;
  WriteLn('Manifest loaded successfully');
end;

function TBinaryInstaller.DownloadBinary(const AVersion, ADestFile: string): Boolean;
var
  Platform: TPlatformInfo;
  URL: string;
  Err: string;
  Opt: TFetchOptions;
  URLs: array of string;
  ManifestTarget: TManifestTarget;
  I: Integer;
  HashAlgo, HashDigest: string;
begin
  Result := False;

  if FOfflineMode then
  begin
    FLastError := 'Offline mode enabled, cannot download' + LineEnding +
                  'Troubleshooting:' + LineEnding +
                  '  1. Check if version is cached: fpdev fpc cache list' + LineEnding +
                  '  2. Run without --offline flag to download' + LineEnding +
                  '  3. Use --from=source if binary is unavailable';
    Exit;
  end;

  Platform := DetectPlatform;

  // Try to use manifest for enhanced security and multiple mirrors
  if FUseManifest then
  begin
    // Create manifest parser lazily when needed
    if not Assigned(FManifestParser) then
      FManifestParser := TManifestParser.Create;
  end;

  if FUseManifest and FManifestParser.GetTarget('fpc', AVersion, Platform.ToString, ManifestTarget) then
  begin
    WriteLn('Using manifest data for download');

    // Use multiple mirrors from manifest
    SetLength(URLs, Length(ManifestTarget.URLs));
    for I := 0 to High(ManifestTarget.URLs) do
      URLs[I] := ManifestTarget.URLs[I];

    // Parse hash from manifest
    if ParseHashAlgorithm(ManifestTarget.Hash, HashAlgo, HashDigest) then
    begin
      Opt.Hash := ManifestTarget.Hash;
      if HashAlgo = 'sha256' then
        Opt.HashAlgorithm := haSHA256
      else if HashAlgo = 'sha512' then
        Opt.HashAlgorithm := haSHA512
      else
        Opt.HashAlgorithm := haUnknown;
      Opt.HashDigest := HashDigest;
      WriteLn('Hash verification enabled: ', HashAlgo);
    end
    else
    begin
      Opt.Hash := '';
      Opt.HashAlgorithm := haUnknown;
      Opt.HashDigest := '';
      WriteLn('Warning: Invalid hash format in manifest, skipping verification');
    end;

    Opt.ExpectedSize := ManifestTarget.Size;
    if Opt.ExpectedSize > 0 then
      WriteLn('Expected size: ', Opt.ExpectedSize, ' bytes');
  end
  else
  begin
    // Fallback to legacy mirror manager
    WriteLn('Using legacy download method (no manifest)');
    URL := FMirrorManager.GetDownloadURL(AVersion, Platform.ToString);

    if URL = '' then
    begin
      FLastError := 'Failed to generate download URL for ' + AVersion + LineEnding +
                    'Troubleshooting:' + LineEnding +
                    '  1. Verify version exists: fpdev fpc list --all' + LineEnding +
                    '  2. Check platform support for this version' + LineEnding +
                    '  3. Try source installation: fpdev fpc install ' + AVersion + ' --from=source';
      Exit;
    end;

    SetLength(URLs, 1);
    URLs[0] := URL;

    Opt.Hash := '';
    Opt.HashAlgorithm := haUnknown;
    Opt.HashDigest := '';
    Opt.ExpectedSize := 0;
    WriteLn('Warning: No hash verification (manifest not available)');
  end;

  Opt.DestDir := ExtractFileDir(ADestFile);
  Opt.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;

  WriteLn('Downloading from: ', URLs[0]);
  if Length(URLs) > 1 then
    WriteLn('Fallback mirrors available: ', Length(URLs) - 1);

  Result := EnsureDownloadedCached(URLs, ADestFile, Opt, Err);

  if not Result then
    FLastError := Err;
end;

function TBinaryInstaller.Install(const AVersion, AInstallDir: string): Boolean;
var
  CacheKey: string;
  TempArchive: string;
  CacheInfo: TArtifactInfo;
  FPCPath: string;
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
        FLastError := 'Binary not in cache and offline mode enabled' + LineEnding +
                      'Troubleshooting:' + LineEnding +
                      '  1. Run without --offline to download' + LineEnding +
                      '  2. Check available cached versions: fpdev fpc cache list' + LineEnding +
                      '  3. Install a different version that is cached'
      else
        FLastError := 'Failed to download binary: ' + FLastError + LineEnding +
                      'Troubleshooting:' + LineEnding +
                      '  1. Check network connectivity' + LineEnding +
                      '  2. Verify mirror availability' + LineEnding +
                      '  3. Try source installation: fpdev fpc install ' + AVersion + ' --from=source' + LineEnding +
                      '  4. Use --offline with cached version if available';
      Exit;
    end;

    // Extract archive
    WriteLn('Extracting archive...');
    if not FExtractor.Extract(TempArchive, AInstallDir) then
    begin
      FLastError := 'Failed to extract archive: ' + FExtractor.GetLastError;
      Exit;
    end;

    // Verify installation if enabled
    if FVerifyInstallation then
    begin
      WriteLn('Verifying installation...');

      // Find FPC executable (assume standard location)
      FPCPath := AInstallDir + PathDelim + 'bin' + PathDelim + 'fpc';
      {$IFDEF WINDOWS}
      FPCPath := FPCPath + '.exe';
      {$ENDIF}

      if not FileExists(FPCPath) then
      begin
        FLastError := 'FPC executable not found at: ' + FPCPath;
        Exit;
      end;

      // Verify version
      if not FVerifier.VerifyVersion(FPCPath, AVersion) then
      begin
        FLastError := 'Version verification failed: ' + FVerifier.GetLastError;
        Exit;
      end;

      WriteLn('Version verified: ', AVersion);

      // Compile hello world test
      if not FVerifier.CompileHelloWorld(FPCPath) then
      begin
        FLastError := 'Hello world compilation failed: ' + FVerifier.GetLastError;
        Exit;
      end;

      WriteLn('Hello world test passed');

      // Generate metadata
      if not FVerifier.GenerateMetadata(AInstallDir, AVersion) then
      begin
        FLastError := 'Metadata generation failed: ' + FVerifier.GetLastError;
        Exit;
      end;

      WriteLn('Metadata generated');
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
