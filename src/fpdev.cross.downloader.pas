unit fpdev.cross.downloader;

{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.cross.manifest, fpdev.cross.cache, fpdev.toolchain.fetcher,
  fpdev.toolchain.extract, fpdev.cross.downloader.downloadflow;

type
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
    FDownloadFlow: TDownloadFlow;

    function GetCacheDir: string;
    function GetInstallDir(const ATarget: string): string;
    procedure ReportProgress(const AProgress: TDownloadProgress);
    function SleepMS(AMilliseconds: Integer): Boolean;
    function FindBinutilsEntry(const ATarget, AComponent: string;
      const AHost: THostPlatform): TCrossToolchainEntry;

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

    procedure SetOptions(const AValue: TDownloadOptions);

    { Properties }
    property Options: TDownloadOptions read FOptions write SetOptions;
    property OnProgress: TProgressCallback read FOnProgress write FOnProgress;
    property Manifest: TCrossToolchainManifest read FManifest;
    property Cache: TCrossToolchainCache read FCache;
    property LastError: string read FLastError;
    property ManifestURL: string read FManifestURL;
    property DataRoot: string read FDataRoot;
  end;

implementation

uses
  fpdev.cross.verifyflow;

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
  FDownloadFlow := TDownloadFlow.Create(
    FOptions,
    @LoadManifest,
    @DetectHostPlatform,
    @FindBinutilsEntry,
    @GetCacheDir,
    @GetInstallDir,
    @ReportProgress,
    @SleepMS
  );
end;

destructor TCrossToolchainDownloader.Destroy;
begin
  FDownloadFlow.Free;
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

function TCrossToolchainDownloader.FindBinutilsEntry(const ATarget, AComponent: string;
  const AHost: THostPlatform): TCrossToolchainEntry;
begin
  Result := FManifest.FindEntry(ATarget, AComponent, AHost);
end;

function TCrossToolchainDownloader.LoadManifest: Boolean;
var
  ManifestPath: string;
begin
  Result := False;
  FLastError := '';

  ManifestPath := IncludeTrailingPathDelimiter(FDataRoot) + 'cross-manifest.json';

  if FileExists(ManifestPath) then
  begin
    if FManifest.LoadFromFile(ManifestPath) then
    begin
      if (not FOptions.OfflineMode) and FManifest.NeedsUpdate then
        RefreshManifest;
      Result := True;
      Exit;
    end;
  end;

  if FOptions.OfflineMode then
  begin
    FLastError := 'No local manifest available in offline mode';
    Exit;
  end;

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

  ForceDirectories(ExtractFileDir(ManifestPath));

  URLs[0] := FManifestURL;
  Opt.DestDir := ExtractFileDir(ManifestPath);
  Opt.Hash := '';
  Opt.HashAlgorithm := haUnknown;
  Opt.HashDigest := '';
  Opt.TimeoutMS := FOptions.TimeoutMS;
  Opt.ExpectedSize := 0;

  if not FetchWithMirrors(URLs, TempPath, Opt, ErrMsg) then
  begin
    FLastError := 'Failed to download manifest: ' + ErrMsg;
    Exit;
  end;

  if not FManifest.LoadFromFile(TempPath) then
  begin
    FLastError := 'Downloaded manifest is invalid: ' + FManifest.LastError.Message;
    DeleteFile(TempPath);
    Exit;
  end;

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

procedure TCrossToolchainDownloader.SetOptions(const AValue: TDownloadOptions);
begin
  FOptions := AValue;
  FDownloadFlow.Options := FOptions;
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

function TCrossToolchainDownloader.DownloadBinutils(const ATarget: string): Boolean;
begin
  Result := FDownloadFlow.DownloadBinutils(ATarget, FCache);
  if not Result then
    FLastError := FDownloadFlow.LastError;
end;

function TCrossToolchainDownloader.DownloadLibraries(const ATarget: string): Boolean;
begin
  Result := FDownloadFlow.DownloadLibraries(ATarget, FCache);
  if not Result then
    FLastError := FDownloadFlow.LastError;
end;

function TCrossToolchainDownloader.InstallToolchain(const ATarget: string): Boolean;
begin
  Result := FDownloadFlow.InstallToolchain(ATarget, FCache);
  if not Result then
    FLastError := FDownloadFlow.LastError;
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
