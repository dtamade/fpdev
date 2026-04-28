program test_fpc_binaryflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.cache.types,
  fpdev.fpc.binaryflow,
  fpdev.fpc.types,
  fpdev.manifest,
  fpdev.toolchain.fetcher;

type
  TBinaryFlowProbe = class
  private
    FLogs: TStringList;
    FEvents: TStringList;
    function GetEventText: string;
  public
    ManifestLoadResult: Boolean;
    ManifestErrorText: string;
    ManifestTargetResult: Boolean;
    ManifestTarget: TManifestTarget;
    LegacyURL: string;
    EnsureDownloadedResult: Boolean;
    EnsureDownloadedErrorText: string;
    HasArtifactsResult: Boolean;
    GetArtifactInfoResult: Boolean;
    RestoreArtifactResult: Boolean;
    DownloadBinaryResult: Boolean;
    DownloadBinaryErrorText: string;
    ExtractResult: Boolean;
    ExtractErrorText: string;
    VerificationResult: TVerificationResult;
    RunVerificationResult: Boolean;
    WriteMetadataResult: Boolean;
    EnsureManifestCalls: Integer;
    LoadManifestCalls: Integer;
    ResolveManifestTargetCalls: Integer;
    ResolveLegacyURLCalls: Integer;
    EnsureDownloadedCalls: Integer;
    GetCacheKeyCalls: Integer;
    HasArtifactsCalls: Integer;
    GetArtifactInfoCalls: Integer;
    RestoreArtifactCalls: Integer;
    DownloadBinaryCalls: Integer;
    ExtractCalls: Integer;
    SaveArtifactCalls: Integer;
    RunVerificationCalls: Integer;
    WriteMetadataCalls: Integer;
    LastManifestURL: string;
    LastVersion: string;
    LastPlatform: string;
    LastLegacyVersion: string;
    LastLegacyPlatform: string;
    LastInstallDir: string;
    LastArchivePath: string;
    LastDownloadDestFile: string;
    LastCacheKey: string;
    LastSavedArchivePath: string;
    LastDownloadURLs: TStringArray;
    LastFetchOptions: TFetchOptions;
    constructor Create;
    destructor Destroy; override;
    procedure Log(const AText: string);
    procedure EnsureManifestParser;
    function LoadManifest(const AManifestURL: string): Boolean;
    function GetManifestError: string;
    function ResolveManifestTarget(
      const AVersion, APlatform: string;
      out ATarget: TManifestTarget
    ): Boolean;
    function ResolveLegacyURL(
      const AVersion, APlatform: string
    ): string;
    function EnsureDownloaded(
      const AURLs: TStringArray;
      const ADestFile: string;
      const AOptions: TFetchOptions;
      out AError: string
    ): Boolean;
    function GetCacheKey(const AVersion: string): string;
    function HasArtifacts(const ACacheKey: string): Boolean;
    function GetBinaryArtifactInfo(
      const ACacheKey: string;
      out AInfo: TArtifactInfo
    ): Boolean;
    function RestoreBinaryArtifact(
      const ACacheKey, AInstallDir: string
    ): Boolean;
    function DownloadBinary(
      const AVersion, ADestFile: string;
      out AError: string
    ): Boolean;
    function ExtractArchive(
      const AArchive, AInstallDir: string;
      out AError: string
    ): Boolean;
    procedure SaveBinaryArtifact(
      const ACacheKey, AArchivePath: string
    );
    function RunVerification(
      const AVersion, AInstallDir: string;
      out AVerifResult: TVerificationResult
    ): Boolean;
    function WriteVerificationMetadata(
      const AVersion, AInstallDir: string;
      const AVerifResult: TVerificationResult
    ): Boolean;
    function LogContains(const AText: string): Boolean;
    property EventText: string read GetEventText;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

constructor TBinaryFlowProbe.Create;
begin
  inherited Create;
  FLogs := TStringList.Create;
  FEvents := TStringList.Create;
  ManifestLoadResult := False;
  ManifestErrorText := '';
  ManifestTargetResult := False;
  LegacyURL := '';
  EnsureDownloadedResult := False;
  EnsureDownloadedErrorText := '';
  HasArtifactsResult := False;
  GetArtifactInfoResult := False;
  RestoreArtifactResult := False;
  DownloadBinaryResult := False;
  DownloadBinaryErrorText := '';
  ExtractResult := False;
  ExtractErrorText := '';
  VerificationResult := Default(TVerificationResult);
  RunVerificationResult := False;
  WriteMetadataResult := False;
end;

destructor TBinaryFlowProbe.Destroy;
begin
  FEvents.Free;
  FLogs.Free;
  inherited Destroy;
end;

function TBinaryFlowProbe.GetEventText: string;
var
  Index: Integer;
begin
  Result := '';
  for Index := 0 to FEvents.Count - 1 do
  begin
    if Result <> '' then
      Result := Result + '>';
    Result := Result + FEvents[Index];
  end;
end;

procedure TBinaryFlowProbe.Log(const AText: string);
begin
  FLogs.Add(AText);
end;

procedure TBinaryFlowProbe.EnsureManifestParser;
begin
  Inc(EnsureManifestCalls);
  FEvents.Add('manifest.ensure');
end;

function TBinaryFlowProbe.LoadManifest(const AManifestURL: string): Boolean;
begin
  Inc(LoadManifestCalls);
  LastManifestURL := AManifestURL;
  FEvents.Add('manifest.load');
  Result := ManifestLoadResult;
end;

function TBinaryFlowProbe.GetManifestError: string;
begin
  Result := ManifestErrorText;
end;

function TBinaryFlowProbe.ResolveManifestTarget(
  const AVersion, APlatform: string;
  out ATarget: TManifestTarget
): Boolean;
begin
  Inc(ResolveManifestTargetCalls);
  LastVersion := AVersion;
  LastPlatform := APlatform;
  FEvents.Add('download.manifest');
  ATarget := ManifestTarget;
  Result := ManifestTargetResult;
end;

function TBinaryFlowProbe.ResolveLegacyURL(
  const AVersion, APlatform: string
): string;
begin
  Inc(ResolveLegacyURLCalls);
  LastLegacyVersion := AVersion;
  LastLegacyPlatform := APlatform;
  FEvents.Add('download.legacy');
  Result := LegacyURL;
end;

function TBinaryFlowProbe.EnsureDownloaded(
  const AURLs: TStringArray;
  const ADestFile: string;
  const AOptions: TFetchOptions;
  out AError: string
): Boolean;
var
  Index: Integer;
begin
  Inc(EnsureDownloadedCalls);
  SetLength(LastDownloadURLs, Length(AURLs));
  for Index := 0 to High(AURLs) do
    LastDownloadURLs[Index] := AURLs[Index];
  LastDownloadDestFile := ADestFile;
  LastFetchOptions := AOptions;
  FEvents.Add('download.fetch');
  AError := EnsureDownloadedErrorText;
  Result := EnsureDownloadedResult;
end;

function TBinaryFlowProbe.GetCacheKey(const AVersion: string): string;
begin
  Inc(GetCacheKeyCalls);
  LastVersion := AVersion;
  FEvents.Add('install.cachekey');
  Result := 'cache-' + AVersion;
end;

function TBinaryFlowProbe.HasArtifacts(const ACacheKey: string): Boolean;
begin
  Inc(HasArtifactsCalls);
  LastCacheKey := ACacheKey;
  FEvents.Add('install.has');
  Result := HasArtifactsResult;
end;

function TBinaryFlowProbe.GetBinaryArtifactInfo(
  const ACacheKey: string;
  out AInfo: TArtifactInfo
): Boolean;
begin
  Inc(GetArtifactInfoCalls);
  LastCacheKey := ACacheKey;
  FEvents.Add('install.info');
  AInfo := Default(TArtifactInfo);
  AInfo.Version := 'cache-version';
  Result := GetArtifactInfoResult;
end;

function TBinaryFlowProbe.RestoreBinaryArtifact(
  const ACacheKey, AInstallDir: string
): Boolean;
begin
  Inc(RestoreArtifactCalls);
  LastCacheKey := ACacheKey;
  LastInstallDir := AInstallDir;
  FEvents.Add('install.restore');
  Result := RestoreArtifactResult;
end;

function TBinaryFlowProbe.DownloadBinary(
  const AVersion, ADestFile: string;
  out AError: string
): Boolean;
var
  Archive: TStringList;
begin
  Inc(DownloadBinaryCalls);
  LastVersion := AVersion;
  LastDownloadDestFile := ADestFile;
  FEvents.Add('install.download');
  if DownloadBinaryResult then
  begin
    ForceDirectories(ExtractFileDir(ADestFile));
    Archive := TStringList.Create;
    try
      Archive.Add('archive');
      Archive.SaveToFile(ADestFile);
    finally
      Archive.Free;
    end;
  end;
  AError := DownloadBinaryErrorText;
  Result := DownloadBinaryResult;
end;

function TBinaryFlowProbe.ExtractArchive(
  const AArchive, AInstallDir: string;
  out AError: string
): Boolean;
begin
  Inc(ExtractCalls);
  LastArchivePath := AArchive;
  LastInstallDir := AInstallDir;
  FEvents.Add('install.extract');
  AError := ExtractErrorText;
  Result := ExtractResult;
end;

procedure TBinaryFlowProbe.SaveBinaryArtifact(
  const ACacheKey, AArchivePath: string
);
begin
  Inc(SaveArtifactCalls);
  LastCacheKey := ACacheKey;
  LastSavedArchivePath := AArchivePath;
  FEvents.Add('install.save');
end;

function TBinaryFlowProbe.RunVerification(
  const AVersion, AInstallDir: string;
  out AVerifResult: TVerificationResult
): Boolean;
begin
  Inc(RunVerificationCalls);
  LastVersion := AVersion;
  LastInstallDir := AInstallDir;
  FEvents.Add('install.verify');
  AVerifResult := VerificationResult;
  Result := RunVerificationResult;
end;

function TBinaryFlowProbe.WriteVerificationMetadata(
  const AVersion, AInstallDir: string;
  const AVerifResult: TVerificationResult
): Boolean;
begin
  Inc(WriteMetadataCalls);
  LastVersion := AVersion;
  LastInstallDir := AInstallDir;
  FEvents.Add('install.metadata');
  if AVerifResult.Verified then;
  Result := WriteMetadataResult;
end;

function TBinaryFlowProbe.LogContains(const AText: string): Boolean;
begin
  Result := Pos(AText, FLogs.Text) > 0;
end;

procedure TestLoadManifestOfflineShortCircuits;
var
  Probe: TBinaryFlowProbe;
  Callbacks: TBinaryManifestCallbacks;
  OK: Boolean;
begin
  Probe := TBinaryFlowProbe.Create;
  try
    Callbacks.Log := @Probe.Log;
    Callbacks.EnsureManifestParser := @Probe.EnsureManifestParser;
    Callbacks.LoadFromURL := @Probe.LoadManifest;
    Callbacks.GetManifestError := @Probe.GetManifestError;

    OK := LoadBinaryManifestCore(
      'https://example.invalid/manifest.json',
      True,
      Callbacks
    );

    Check('binaryflow offline manifest returns false', not OK, 'expected false');
    Check('binaryflow offline manifest skips parser init',
      Probe.EnsureManifestCalls = 0, IntToStr(Probe.EnsureManifestCalls));
    Check('binaryflow offline manifest skips load',
      Probe.LoadManifestCalls = 0, IntToStr(Probe.LoadManifestCalls));
    Check('binaryflow offline manifest logs skip message',
      Probe.LogContains('Offline mode: skipping manifest download'),
      Probe.EventText);
  finally
    Probe.Free;
  end;
end;

procedure TestDownloadUsesManifestTarget;
var
  Probe: TBinaryFlowProbe;
  Callbacks: TBinaryDownloadCallbacks;
  OK: Boolean;
  ErrText: string;
begin
  Probe := TBinaryFlowProbe.Create;
  try
    SetLength(Probe.ManifestTarget.URLs, 2);
    Probe.ManifestTarget.URLs[0] := 'https://mirror-1.example/fpc.tar.gz';
    Probe.ManifestTarget.URLs[1] := 'https://mirror-2.example/fpc.tar.gz';
    Probe.ManifestTarget.Hash := 'sha512:abcd';
    Probe.ManifestTarget.Size := 123;
    Probe.ManifestTargetResult := True;
    Probe.EnsureDownloadedResult := True;

    Callbacks.Log := @Probe.Log;
    Callbacks.EnsureManifestParser := @Probe.EnsureManifestParser;
    Callbacks.ResolveManifestTarget := @Probe.ResolveManifestTarget;
    Callbacks.ResolveLegacyURL := @Probe.ResolveLegacyURL;
    Callbacks.EnsureDownloaded := @Probe.EnsureDownloaded;

    OK := DownloadBinaryArchiveCore(
      '3.2.2',
      '/tmp/fpc-binaryflow.tar.gz',
      'linux-x86_64',
      True,
      False,
      Callbacks,
      ErrText
    );

    Check('binaryflow manifest download succeeds', OK, ErrText);
    Check('binaryflow manifest init runs once',
      Probe.EnsureManifestCalls = 1, IntToStr(Probe.EnsureManifestCalls));
    Check('binaryflow manifest target lookup runs once',
      Probe.ResolveManifestTargetCalls = 1, IntToStr(Probe.ResolveManifestTargetCalls));
    Check('binaryflow manifest path skips legacy lookup',
      Probe.ResolveLegacyURLCalls = 0, IntToStr(Probe.ResolveLegacyURLCalls));
    Check('binaryflow manifest forwards both mirrors',
      Length(Probe.LastDownloadURLs) = 2, IntToStr(Length(Probe.LastDownloadURLs)));
    Check('binaryflow manifest forwards first mirror',
      Probe.LastDownloadURLs[0] = 'https://mirror-1.example/fpc.tar.gz',
      Probe.LastDownloadURLs[0]);
    Check('binaryflow manifest enables sha512',
      Probe.LastFetchOptions.HashAlgorithm = haSHA512,
      IntToStr(Ord(Probe.LastFetchOptions.HashAlgorithm)));
    Check('binaryflow manifest forwards hash digest',
      Probe.LastFetchOptions.HashDigest = 'abcd',
      Probe.LastFetchOptions.HashDigest);
    Check('binaryflow manifest forwards expected size',
      Probe.LastFetchOptions.ExpectedSize = 123,
      IntToStr(Probe.LastFetchOptions.ExpectedSize));
    Check('binaryflow manifest logs manifest mode',
      Probe.LogContains('Using manifest data for download'),
      Probe.EventText);
  finally
    Probe.Free;
  end;
end;

procedure TestInstallUsesCacheRestoreThenVerification;
var
  Probe: TBinaryFlowProbe;
  Callbacks: TBinaryInstallCallbacks;
  OK: Boolean;
  ErrText: string;
begin
  Probe := TBinaryFlowProbe.Create;
  try
    Probe.HasArtifactsResult := True;
    Probe.GetArtifactInfoResult := True;
    Probe.RestoreArtifactResult := True;
    Probe.VerificationResult := Default(TVerificationResult);
    Probe.VerificationResult.Verified := True;
    Probe.VerificationResult.ExecutableExists := True;
    Probe.VerificationResult.DetectedVersion := '3.2.2';
    Probe.VerificationResult.SmokeTestPassed := True;
    Probe.RunVerificationResult := True;
    Probe.WriteMetadataResult := True;

    Callbacks.Log := @Probe.Log;
    Callbacks.GetCacheKey := @Probe.GetCacheKey;
    Callbacks.HasArtifacts := @Probe.HasArtifacts;
    Callbacks.GetBinaryArtifactInfo := @Probe.GetBinaryArtifactInfo;
    Callbacks.RestoreBinaryArtifact := @Probe.RestoreBinaryArtifact;
    Callbacks.DownloadBinary := @Probe.DownloadBinary;
    Callbacks.ExtractArchive := @Probe.ExtractArchive;
    Callbacks.SaveBinaryArtifact := @Probe.SaveBinaryArtifact;
    Callbacks.RunVerification := @Probe.RunVerification;
    Callbacks.WriteVerificationMetadata := @Probe.WriteVerificationMetadata;

    OK := ExecuteBinaryInstallCore(
      '3.2.2',
      '/tmp/fpc-binaryflow-install',
      True,
      True,
      True,
      Callbacks,
      ErrText
    );

    Check('binaryflow cache restore install succeeds', OK, ErrText);
    Check('binaryflow cache restore skips download',
      Probe.DownloadBinaryCalls = 0, IntToStr(Probe.DownloadBinaryCalls));
    Check('binaryflow cache restore skips extract',
      Probe.ExtractCalls = 0, IntToStr(Probe.ExtractCalls));
    Check('binaryflow cache restore runs verification',
      Probe.RunVerificationCalls = 1, IntToStr(Probe.RunVerificationCalls));
    Check('binaryflow cache restore writes metadata',
      Probe.WriteMetadataCalls = 1, IntToStr(Probe.WriteMetadataCalls));
    Check('binaryflow cache restore preserves event order',
      Probe.EventText = 'install.cachekey>install.has>install.info>install.restore>install.verify>install.metadata',
      Probe.EventText);
  finally
    Probe.Free;
  end;
end;

procedure TestInstallDownloadPathSavesCacheAndCleansTempArchive;
var
  Probe: TBinaryFlowProbe;
  Callbacks: TBinaryInstallCallbacks;
  OK: Boolean;
  ErrText: string;
begin
  Probe := TBinaryFlowProbe.Create;
  try
    Probe.HasArtifactsResult := False;
    Probe.DownloadBinaryResult := True;
    Probe.ExtractResult := True;

    Callbacks.Log := @Probe.Log;
    Callbacks.GetCacheKey := @Probe.GetCacheKey;
    Callbacks.HasArtifacts := @Probe.HasArtifacts;
    Callbacks.GetBinaryArtifactInfo := @Probe.GetBinaryArtifactInfo;
    Callbacks.RestoreBinaryArtifact := @Probe.RestoreBinaryArtifact;
    Callbacks.DownloadBinary := @Probe.DownloadBinary;
    Callbacks.ExtractArchive := @Probe.ExtractArchive;
    Callbacks.SaveBinaryArtifact := @Probe.SaveBinaryArtifact;
    Callbacks.RunVerification := @Probe.RunVerification;
    Callbacks.WriteVerificationMetadata := @Probe.WriteVerificationMetadata;

    OK := ExecuteBinaryInstallCore(
      '9.9.9-flowcleanup',
      '/tmp/fpc-binaryflow-download',
      True,
      False,
      False,
      Callbacks,
      ErrText
    );

    Check('binaryflow download install succeeds', OK, ErrText);
    Check('binaryflow download path downloads once',
      Probe.DownloadBinaryCalls = 1, IntToStr(Probe.DownloadBinaryCalls));
    Check('binaryflow download path extracts once',
      Probe.ExtractCalls = 1, IntToStr(Probe.ExtractCalls));
    Check('binaryflow download path saves cache once',
      Probe.SaveArtifactCalls = 1, IntToStr(Probe.SaveArtifactCalls));
    Check('binaryflow download path cleans temp archive',
      (Probe.LastDownloadDestFile <> '') and (not FileExists(Probe.LastDownloadDestFile)),
      Probe.LastDownloadDestFile);
    Check('binaryflow download path preserves event order',
      Probe.EventText = 'install.cachekey>install.has>install.download>install.extract>install.cachekey>install.save',
      Probe.EventText);
  finally
    if (Probe.LastDownloadDestFile <> '') and FileExists(Probe.LastDownloadDestFile) then
      DeleteFile(Probe.LastDownloadDestFile);
    Probe.Free;
  end;
end;

begin
  TestLoadManifestOfflineShortCircuits;
  TestDownloadUsesManifestTarget;
  TestInstallUsesCacheRestoreThenVerification;
  TestInstallDownloadPathSavesCacheAndCleansTempArchive;

  if FailCount > 0 then
    Halt(1);
end.
