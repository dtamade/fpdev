program test_fpc_installer_manifest_plan;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.config.managers,
  fpdev.manifest.cache, fpdev.manifest,
  fpdev.resource.repo,
  fpdev.fpc.installer.manifestplan,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  TestRoot: string;
  ConfigManager: IConfigManager;

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

procedure Check(const AName: string; ACondition: Boolean; const AReason: string);
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function BuildManifestJSON(const AVersion, APlatform, AURL: string): string;
const
  HASH_VALUE = 'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
begin
  Result := '{' + LineEnding +
    '  "manifest-version": "1",' + LineEnding +
    '  "date": "2026-03-09",' + LineEnding +
    '  "channel": "stable",' + LineEnding +
    '  "pkg": {' + LineEnding +
    '    "fpc": {' + LineEnding +
    '      "version": "' + AVersion + '",' + LineEnding +
    '      "targets": {' + LineEnding +
    '        "' + APlatform + '": {' + LineEnding +
    '          "url": "' + AURL + '",' + LineEnding +
    '          "hash": "' + HASH_VALUE + '",' + LineEnding +
    '          "size": 123456' + LineEnding +
    '        }' + LineEnding +
    '      }' + LineEnding +
    '    }' + LineEnding +
    '  }' + LineEnding +
    '}';
end;

procedure WriteTextFile(const AFileName, AContent: string);
var
  Stream: TStringStream;
begin
  Stream := TStringStream.Create(AContent);
  try
    Stream.SaveToFile(AFileName);
  finally
    Stream.Free;
  end;
end;

procedure SetupConfig;
var
  Settings: TFPDevSettings;
begin
  TestRoot := CreateUniqueTempDir('test_fpc_manifest_plan');
  ConfigManager := TConfigManager.Create(TestRoot + PathDelim + 'config.json');
  ConfigManager.CreateDefaultConfig;
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRoot;
  ConfigManager.GetSettingsManager.SetSettings(Settings);
end;

procedure CleanupConfig;
begin
  ConfigManager := nil;
  if TestRoot <> '' then
    CleanupTempDir(TestRoot);
end;

procedure TestPreparePlanUsesScopedCacheAndBuildsTempPaths;
var
  Plan: TFPCManifestInstallPlan;
  CacheDir: string;
  Err: string;
  CacheFile: string;
  Platform: string;
  DownloadDir: string;
begin
  Platform := GetCurrentPlatform;
  CacheDir := BuildManifestCacheDirFromInstallRoot(TestRoot);
  CacheFile := CacheDir + PathDelim + 'fpc.json';
  ForceDirectories(CacheDir);
  WriteTextFile(CacheFile,
    BuildManifestJSON('3.2.2', Platform, 'https://example.com/fpc-3.2.2.tar.gz'));

  if not PrepareFPCManifestInstallPlan(ConfigManager, '3.2.2', Plan, Err) then
  begin
    Fail('prepare plan succeeds', Err);
    Exit;
  end;

  DownloadDir := ExtractFileDir(Plan.DownloadFile);
  Check('plan uses scoped cache dir', Plan.ManifestCacheDir = CacheDir,
    'expected ' + CacheDir + ', got ' + Plan.ManifestCacheDir);
  Check('plan keeps current platform', Plan.Platform = Platform,
    'expected ' + Platform + ', got ' + Plan.Platform);
  Check('plan exposes target url', (Length(Plan.Target.URLs) = 1) and
    (Plan.Target.URLs[0] = 'https://example.com/fpc-3.2.2.tar.gz'),
    'target urls mismatch');
  Check('download file uses system temp root', PathUsesSystemTempRoot(Plan.DownloadFile),
    'download file should live under system temp root');
  Check('extract dir uses system temp root', PathUsesSystemTempRoot(Plan.ExtractDir),
    'extract dir should live under system temp root');
  Check('download file keeps extension', ExtractFileExt(Plan.DownloadFile) = '.gz',
    'expected .gz extension, got ' + ExtractFileExt(Plan.DownloadFile));
  Check('download dir is fpdev_downloads', Pos('fpdev_downloads', DownloadDir) > 0,
    'expected fpdev_downloads in ' + DownloadDir);
  Check('extract dir is prefixed', Pos('fpdev_extract_', ExtractFileName(Plan.ExtractDir)) = 1,
    'expected fpdev_extract_ prefix');
end;

procedure TestPreparePlanFallsBackToTarGzExtension;
var
  Plan: TFPCManifestInstallPlan;
  CacheDir: string;
  Err: string;
  Platform: string;
begin
  Platform := GetCurrentPlatform;
  CacheDir := BuildManifestCacheDirFromInstallRoot(TestRoot);
  ForceDirectories(CacheDir);
  WriteTextFile(CacheDir + PathDelim + 'fpc.json',
    BuildManifestJSON('3.2.3', Platform, 'https://example.com/download'));

  if not PrepareFPCManifestInstallPlan(ConfigManager, '3.2.3', Plan, Err) then
  begin
    Fail('prepare plan fallback extension succeeds', Err);
    Exit;
  end;

  Check('fallback extension is tar.gz', Pos('.tar.gz', Plan.DownloadFile) > 0,
    'expected .tar.gz fallback, got ' + Plan.DownloadFile);
end;

procedure TestPreparePlanFailsForMissingTarget;
var
  Plan: TFPCManifestInstallPlan;
  CacheDir: string;
  Err: string;
begin
  CacheDir := BuildManifestCacheDirFromInstallRoot(TestRoot);
  ForceDirectories(CacheDir);
  WriteTextFile(CacheDir + PathDelim + 'fpc.json',
    BuildManifestJSON('3.2.2', 'windows-x86_64', 'https://example.com/fpc-3.2.2.zip'));

  if PrepareFPCManifestInstallPlan(ConfigManager, '3.2.2', Plan, Err) then
  begin
    Fail('prepare plan missing target should fail', 'unexpected success');
    Exit;
  end;

  Check('missing target sets error', Pos('No binary available', Err) > 0,
    'expected target error, got ' + Err);
end;

begin
  WriteLn('=== FPC Installer Manifest Plan Tests ===');
  SetupConfig;
  try
    TestPreparePlanUsesScopedCacheAndBuildsTempPaths;
    TestPreparePlanFallsBackToTarGzExtension;
    TestPreparePlanFailsForMissingTarget;
  finally
    CleanupConfig;
  end;

  WriteLn;
  WriteLn('Total: ', PassCount + FailCount);
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
