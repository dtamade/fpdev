unit fpdev.fpc.binaryflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.build.cache.types,
  fpdev.fpc.types,
  fpdev.manifest,
  fpdev.toolchain.fetcher;

type
  TBinaryFlowLogProc = procedure(const AText: string) of object;
  TBinaryFlowEnsureManifestProc = procedure of object;
  TBinaryFlowLoadManifestFunc = function(const AManifestURL: string): Boolean of object;
  TBinaryFlowGetManifestErrorFunc = function: string of object;
  TBinaryFlowResolveManifestTargetFunc = function(
    const AVersion, APlatform: string;
    out ATarget: TManifestTarget
  ): Boolean of object;
  TBinaryFlowResolveLegacyURLFunc = function(
    const AVersion, APlatform: string
  ): string of object;
  TBinaryFlowEnsureDownloadedFunc = function(
    const AURLs: TStringArray;
    const ADestFile: string;
    const AOptions: TFetchOptions;
    out AError: string
  ): Boolean of object;
  TBinaryFlowGetCacheKeyFunc = function(const AVersion: string): string of object;
  TBinaryFlowHasArtifactsFunc = function(const ACacheKey: string): Boolean of object;
  TBinaryFlowGetArtifactInfoFunc = function(
    const ACacheKey: string;
    out AInfo: TArtifactInfo
  ): Boolean of object;
  TBinaryFlowRestoreArtifactFunc = function(
    const ACacheKey, AInstallDir: string
  ): Boolean of object;
  TBinaryFlowDownloadFunc = function(
    const AVersion, ADestFile: string;
    out AError: string
  ): Boolean of object;
  TBinaryFlowExtractFunc = function(
    const AArchive, AInstallDir: string;
    out AError: string
  ): Boolean of object;
  TBinaryFlowSaveArtifactProc = procedure(
    const ACacheKey, AArchivePath: string
  ) of object;
  TBinaryFlowRunVerificationFunc = function(
    const AVersion, AInstallDir: string;
    out AVerifResult: TVerificationResult
  ): Boolean of object;
  TBinaryFlowWriteMetadataFunc = function(
    const AVersion, AInstallDir: string;
    const AVerifResult: TVerificationResult
  ): Boolean of object;

  TBinaryManifestCallbacks = record
    Log: TBinaryFlowLogProc;
    EnsureManifestParser: TBinaryFlowEnsureManifestProc;
    LoadFromURL: TBinaryFlowLoadManifestFunc;
    GetManifestError: TBinaryFlowGetManifestErrorFunc;
  end;

  TBinaryDownloadCallbacks = record
    Log: TBinaryFlowLogProc;
    EnsureManifestParser: TBinaryFlowEnsureManifestProc;
    ResolveManifestTarget: TBinaryFlowResolveManifestTargetFunc;
    ResolveLegacyURL: TBinaryFlowResolveLegacyURLFunc;
    EnsureDownloaded: TBinaryFlowEnsureDownloadedFunc;
  end;

  TBinaryInstallCallbacks = record
    Log: TBinaryFlowLogProc;
    GetCacheKey: TBinaryFlowGetCacheKeyFunc;
    HasArtifacts: TBinaryFlowHasArtifactsFunc;
    GetBinaryArtifactInfo: TBinaryFlowGetArtifactInfoFunc;
    RestoreBinaryArtifact: TBinaryFlowRestoreArtifactFunc;
    DownloadBinary: TBinaryFlowDownloadFunc;
    ExtractArchive: TBinaryFlowExtractFunc;
    SaveBinaryArtifact: TBinaryFlowSaveArtifactProc;
    RunVerification: TBinaryFlowRunVerificationFunc;
    WriteVerificationMetadata: TBinaryFlowWriteMetadataFunc;
  end;

function LoadBinaryManifestCore(
  const AManifestURL: string;
  AOfflineMode: Boolean;
  const ACallbacks: TBinaryManifestCallbacks
): Boolean;

function DownloadBinaryArchiveCore(
  const AVersion, ADestFile, APlatform: string;
  AUseManifest, AOfflineMode: Boolean;
  const ACallbacks: TBinaryDownloadCallbacks;
  out AError: string
): Boolean;

function ExecuteBinaryInstallCore(
  const AVersion, AInstallDir: string;
  AUseCache, AOfflineMode, AVerifyInstallation: Boolean;
  const ACallbacks: TBinaryInstallCallbacks;
  out AError: string
): Boolean;

implementation

procedure WriteLine(const ALog: TBinaryFlowLogProc; const AText: string);
begin
  if Assigned(ALog) then
    ALog(AText);
end;

function BuildOfflineDownloadError: string;
begin
  Result := 'Offline mode enabled, cannot download' + LineEnding +
            'Troubleshooting:' + LineEnding +
            '  1. Check if version is cached: fpdev fpc cache list' + LineEnding +
            '  2. Run without --offline flag to download' + LineEnding +
            '  3. Use --from=source if binary is unavailable';
end;

function BuildLegacyURLFailure(const AVersion: string): string;
begin
  Result := 'Failed to generate download URL for ' + AVersion + LineEnding +
            'Troubleshooting:' + LineEnding +
            '  1. Verify version exists: fpdev fpc list --all' + LineEnding +
            '  2. Check platform support for this version' + LineEnding +
            '  3. Try source installation: fpdev fpc install ' + AVersion + ' --from=source';
end;

function BuildOfflineCacheMissError: string;
begin
  Result := 'Binary not in cache and offline mode enabled' + LineEnding +
            'Troubleshooting:' + LineEnding +
            '  1. Run without --offline to download' + LineEnding +
            '  2. Check available cached versions: fpdev fpc cache list' + LineEnding +
            '  3. Install a different version that is cached';
end;

function BuildDownloadFailure(const AVersion, ADownloadError: string): string;
begin
  Result := 'Failed to download binary: ' + ADownloadError + LineEnding +
            'Troubleshooting:' + LineEnding +
            '  1. Check network connectivity' + LineEnding +
            '  2. Verify mirror availability' + LineEnding +
            '  3. Try source installation: fpdev fpc install ' + AVersion + ' --from=source' + LineEnding +
            '  4. Use --offline with cached version if available';
end;

function LoadBinaryManifestCore(
  const AManifestURL: string;
  AOfflineMode: Boolean;
  const ACallbacks: TBinaryManifestCallbacks
): Boolean;
var
  ManifestError: string;
begin
  Result := False;

  if AOfflineMode then
  begin
    WriteLine(ACallbacks.Log, 'Offline mode: skipping manifest download');
    Exit(False);
  end;

  if Assigned(ACallbacks.EnsureManifestParser) then
    ACallbacks.EnsureManifestParser;

  WriteLine(ACallbacks.Log, 'Loading manifest from: ' + AManifestURL);

  if Assigned(ACallbacks.LoadFromURL) and ACallbacks.LoadFromURL(AManifestURL) then
  begin
    WriteLine(ACallbacks.Log, 'Manifest loaded successfully');
    Exit(True);
  end;

  ManifestError := '';
  if Assigned(ACallbacks.GetManifestError) then
    ManifestError := ACallbacks.GetManifestError();
  WriteLine(ACallbacks.Log, 'Warning: Failed to load manifest: ' + ManifestError);
  WriteLine(ACallbacks.Log, 'Falling back to legacy download method');
end;

function DownloadBinaryArchiveCore(
  const AVersion, ADestFile, APlatform: string;
  AUseManifest, AOfflineMode: Boolean;
  const ACallbacks: TBinaryDownloadCallbacks;
  out AError: string
): Boolean;
var
  URL: string;
  Opt: TFetchOptions;
  URLs: TStringArray;
  ManifestTarget: TManifestTarget;
  Index: Integer;
  HashAlgo: string;
  HashDigest: string;
begin
  Result := False;
  AError := '';
  Opt := Default(TFetchOptions);

  if AOfflineMode then
  begin
    AError := BuildOfflineDownloadError;
    Exit(False);
  end;

  if AUseManifest and Assigned(ACallbacks.EnsureManifestParser) then
    ACallbacks.EnsureManifestParser;

  if AUseManifest and Assigned(ACallbacks.ResolveManifestTarget) and
     ACallbacks.ResolveManifestTarget(AVersion, APlatform, ManifestTarget) then
  begin
    WriteLine(ACallbacks.Log, 'Using manifest data for download');

    SetLength(URLs, Length(ManifestTarget.URLs));
    for Index := 0 to High(ManifestTarget.URLs) do
      URLs[Index] := ManifestTarget.URLs[Index];

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
      WriteLine(ACallbacks.Log, 'Hash verification enabled: ' + HashAlgo);
    end
    else
    begin
      Opt.Hash := '';
      Opt.HashAlgorithm := haUnknown;
      Opt.HashDigest := '';
      WriteLine(ACallbacks.Log,
        'Warning: Invalid hash format in manifest, skipping verification');
    end;

    Opt.ExpectedSize := ManifestTarget.Size;
    if Opt.ExpectedSize > 0 then
      WriteLine(ACallbacks.Log,
        'Expected size: ' + IntToStr(Opt.ExpectedSize) + ' bytes');
  end
  else
  begin
    WriteLine(ACallbacks.Log, 'Using legacy download method (no manifest)');
    URL := '';
    if Assigned(ACallbacks.ResolveLegacyURL) then
      URL := ACallbacks.ResolveLegacyURL(AVersion, APlatform);
    if URL = '' then
    begin
      AError := BuildLegacyURLFailure(AVersion);
      Exit(False);
    end;

    SetLength(URLs, 1);
    URLs[0] := URL;

    Opt.Hash := '';
    Opt.HashAlgorithm := haUnknown;
    Opt.HashDigest := '';
    Opt.ExpectedSize := 0;
    WriteLine(ACallbacks.Log, 'Warning: No hash verification (manifest not available)');
  end;

  Opt.DestDir := ExtractFileDir(ADestFile);
  Opt.TimeoutMS := DEFAULT_DOWNLOAD_TIMEOUT_MS;

  if Length(URLs) = 0 then
  begin
    AError := 'No download URLs resolved';
    Exit(False);
  end;

  WriteLine(ACallbacks.Log, 'Downloading from: ' + URLs[0]);
  if Length(URLs) > 1 then
    WriteLine(ACallbacks.Log,
      'Fallback mirrors available: ' + IntToStr(Length(URLs) - 1));

  if not Assigned(ACallbacks.EnsureDownloaded) then
  begin
    AError := 'Download callback not assigned';
    Exit(False);
  end;

  Result := ACallbacks.EnsureDownloaded(URLs, ADestFile, Opt, AError);
end;

function ExecuteBinaryInstallCore(
  const AVersion, AInstallDir: string;
  AUseCache, AOfflineMode, AVerifyInstallation: Boolean;
  const ACallbacks: TBinaryInstallCallbacks;
  out AError: string
): Boolean;
var
  CacheKey: string;
  TempArchive: string;
  CacheInfo: TArtifactInfo;
  DownloadError: string;
  ExtractError: string;
  VerifResult: TVerificationResult;
  RestoredFromCache: Boolean;
begin
  Result := False;
  AError := '';
  TempArchive := '';
  RestoredFromCache := False;
  CacheInfo := Default(TArtifactInfo);
  VerifResult := Default(TVerificationResult);

  if AUseCache and Assigned(ACallbacks.GetCacheKey) and
     Assigned(ACallbacks.HasArtifacts) then
  begin
    CacheKey := ACallbacks.GetCacheKey(AVersion);
    if ACallbacks.HasArtifacts(CacheKey) then
    begin
      WriteLine(ACallbacks.Log, 'Found in cache, restoring...');
      if Assigned(ACallbacks.GetBinaryArtifactInfo) and
         ACallbacks.GetBinaryArtifactInfo(CacheKey, CacheInfo) then
        WriteLine(ACallbacks.Log, 'Cache info: ' + CacheInfo.Version);
      if Assigned(ACallbacks.RestoreBinaryArtifact) and
         ACallbacks.RestoreBinaryArtifact(CacheKey, AInstallDir) then
      begin
        WriteLine(ACallbacks.Log, 'Successfully restored from cache');
        RestoredFromCache := True;
      end
      else
        WriteLine(ACallbacks.Log, 'Cache restore failed, falling back to download');
    end;
  end;

  if not RestoredFromCache then
  begin
    TempArchive := GetTempDir + 'fpc-' + AVersion + '.tar.gz';
    try
      if not Assigned(ACallbacks.DownloadBinary) then
      begin
        AError := 'Download callback not assigned';
        Exit(False);
      end;

      if not ACallbacks.DownloadBinary(AVersion, TempArchive, DownloadError) then
      begin
        if AOfflineMode then
          AError := BuildOfflineCacheMissError
        else
          AError := BuildDownloadFailure(AVersion, DownloadError);
        Exit(False);
      end;

      WriteLine(ACallbacks.Log, 'Extracting archive...');
      if not Assigned(ACallbacks.ExtractArchive) then
      begin
        AError := 'Archive extractor callback not assigned';
        Exit(False);
      end;

      if not ACallbacks.ExtractArchive(TempArchive, AInstallDir, ExtractError) then
      begin
        AError := 'Failed to extract archive: ' + ExtractError;
        Exit(False);
      end;

      if AUseCache and (not AOfflineMode) and
         Assigned(ACallbacks.GetCacheKey) and
         Assigned(ACallbacks.SaveBinaryArtifact) then
      begin
        WriteLine(ACallbacks.Log, 'Saving to cache...');
        CacheKey := ACallbacks.GetCacheKey(AVersion);
        ACallbacks.SaveBinaryArtifact(CacheKey, TempArchive);
      end;
    finally
      if (TempArchive <> '') and FileExists(TempArchive) then
        DeleteFile(TempArchive);
    end;
  end;

  if AVerifyInstallation then
  begin
    WriteLine(ACallbacks.Log, 'Verifying installation...');
    if not Assigned(ACallbacks.RunVerification) then
    begin
      AError := 'Verification callback not assigned';
      Exit(False);
    end;

    if not ACallbacks.RunVerification(AVersion, AInstallDir, VerifResult) then
    begin
      if not VerifResult.ExecutableExists then
        AError := VerifResult.ErrorMessage
      else if VerifResult.DetectedVersion = '' then
        AError := 'Version verification failed: ' + VerifResult.ErrorMessage
      else
        AError := 'Hello world compilation failed: ' + VerifResult.ErrorMessage;
      Exit(False);
    end;

    WriteLine(ACallbacks.Log, 'Version verified: ' + AVersion);
    WriteLine(ACallbacks.Log, 'Hello world test passed');

    if not Assigned(ACallbacks.WriteVerificationMetadata) or
       (not ACallbacks.WriteVerificationMetadata(AVersion, AInstallDir, VerifResult)) then
    begin
      AError := 'Metadata generation failed: failed to write verification metadata';
      Exit(False);
    end;

    WriteLine(ACallbacks.Log, 'Metadata generated');
  end;

  Result := True;
  WriteLine(ACallbacks.Log, 'Installation complete');
end;

end.
