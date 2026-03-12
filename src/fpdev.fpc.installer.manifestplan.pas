unit fpdev.fpc.installer.manifestplan;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.config.interfaces, fpdev.manifest, fpdev.manifest.cache;

type
  TFPCManifestInstallPlan = record
    ManifestCacheDir: string;
    Platform: string;
    Target: TManifestTarget;
    DownloadDir: string;
    DownloadFile: string;
    ExtractDir: string;
  end;

function PrepareFPCManifestInstallPlan(const AConfigManager: IConfigManager;
  const AVersion: string; out APlan: TFPCManifestInstallPlan;
  out AError: string): Boolean;

implementation

uses
  fpdev.resource.repo, fpdev.utils.fs;

function ResolveManifestCacheDirForConfig(const AConfigManager: IConfigManager): string;
var
  InstallRoot: string;
begin
  InstallRoot := '';
  if AConfigManager <> nil then
    InstallRoot := AConfigManager.GetSettingsManager.GetSettings.InstallRoot;
  Result := BuildManifestCacheDirFromInstallRoot(InstallRoot);
end;

function ResolveTargetFileExt(const ATarget: TManifestTarget): string;
begin
  Result := '';
  if Length(ATarget.URLs) > 0 then
    Result := ExtractFileExt(ATarget.URLs[0]);
  if Result = '' then
    Result := '.tar.gz';
end;

function BuildDownloadDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'fpdev_downloads';
end;

function BuildExtractDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False))
    + 'fpdev_extract_' + IntToStr(GetTickCount64);
end;

function PrepareFPCManifestInstallPlan(const AConfigManager: IConfigManager;
  const AVersion: string; out APlan: TFPCManifestInstallPlan;
  out AError: string): Boolean;
var
  Cache: TManifestCache;
  ManifestParser: TManifestParser;
  FileExt: string;
begin
  Result := False;
  APlan := Default(TFPCManifestInstallPlan);
  AError := '';

  APlan.ManifestCacheDir := ResolveManifestCacheDirForConfig(AConfigManager);
  APlan.Platform := GetCurrentPlatform;

  Cache := TManifestCache.Create(APlan.ManifestCacheDir);
  try
    if not Cache.LoadCachedManifest('fpc', ManifestParser, False) then
    begin
      AError := 'Failed to load manifest';
      Exit;
    end;

    try
      if not ManifestParser.GetTarget('fpc', AVersion, APlan.Platform, APlan.Target) then
      begin
        AError := 'No binary available for FPC ' + AVersion + ' on ' + APlan.Platform;
        if ManifestParser.LastError <> '' then
          AError := AError + ': ' + ManifestParser.LastError;
        Exit;
      end;
    finally
      ManifestParser.Free;
    end;
  finally
    Cache.Free;
  end;

  APlan.DownloadDir := BuildDownloadDir;
  if not DirectoryExists(APlan.DownloadDir) then
    EnsureDir(APlan.DownloadDir);

  FileExt := ResolveTargetFileExt(APlan.Target);
  APlan.DownloadFile := IncludeTrailingPathDelimiter(APlan.DownloadDir)
    + 'fpc-' + AVersion + '-' + IntToStr(GetTickCount64) + FileExt;
  APlan.ExtractDir := BuildExtractDir;
  Result := True;
end;

end.
