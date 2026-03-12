unit fpdev.system.view;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function BuildSystemEnvOverviewLinesCore(
  const APlatformOS,
  AArchitecture,
  AMode,
  ADataRoot,
  AConfigPath,
  ACacheDir,
  AToolchainsDir,
  AFPCDir,
  ALazarusDir,
  AHome,
  AUserProfile,
  AAppData: string
): TStringArray;

function BuildSystemConfigShowLinesCore(
  const AMirror,
  ACustomRepoURL,
  AParallelJobs,
  AKeepSources,
  AAutoUpdate,
  AConfigFile,
  AInstallRoot,
  AToolchainsDir,
  AResourcesDir: string
): TStringArray;

function BuildSystemIndexStatusLinesCore(
  const APlatform,
  ACacheDir,
  AIndexFile: string;
  ACacheDirExists,
  AIndexFileExists: Boolean
): TStringArray;

function BuildSystemIndexShowLinesCore(
  const ABootstrapName,
  ABootstrapGitHub,
  ABootstrapGitee,
  AFPCName,
  AFPCGitHub,
  AFPCGitee,
  ALazarusName,
  ALazarusGitHub,
  ALazarusGitee,
  AStableBootstrap,
  AStableFPC,
  AStableLazarus,
  AEdgeBootstrap,
  AEdgeFPC,
  AEdgeLazarus: string;
  const ABootstrapVersions,
  AFPCVersions,
  ALazarusVersions: TStringArray
): TStringArray;

function BuildSystemIndexUpdateResultLinesCore(
  ASuccess: Boolean
): TStringArray;

function BuildSystemCacheStatusLinesCore(
  const APackagesDir,
  AIndexDir: string;
  ABuildEntries: Integer;
  const ABuildSize,
  APackageSize,
  AIndexSize,
  ATotalSize: string;
  ABuildsDirExists,
  APackagesDirExists,
  AIndexDirExists: Boolean
): TStringArray;

function BuildSystemCachePathLinesCore(
  const ADataRoot,
  ABuildsDir,
  AIndexDir,
  ADownloadsDir,
  APackagesDir,
  AConfigFile: string
): TStringArray;

function BuildSystemCacheStatsLinesCore(
  ABuildsDirExists: Boolean;
  ATotalEntries: Integer;
  const ATotalSize,
  AAverageSize,
  ATotalAccesses,
  AMostAccessed,
  ALeastAccessed: string
): TStringArray;

implementation

function AppendLine(const ALines: TStringArray; const ALine: string): TStringArray;
begin
  Result := Copy(ALines);
  SetLength(Result, Length(Result) + 1);
  Result[High(Result)] := ALine;
end;

function BuildSystemEnvOverviewLinesCore(
  const APlatformOS,
  AArchitecture,
  AMode,
  ADataRoot,
  AConfigPath,
  ACacheDir,
  AToolchainsDir,
  AFPCDir,
  ALazarusDir,
  AHome,
  AUserProfile,
  AAppData: string
): TStringArray;
begin
  Result := nil;
  Result := AppendLine(Result, 'Environment Overview');
  Result := AppendLine(Result, '====================');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Platform:');
  Result := AppendLine(Result, '  OS:           ' + APlatformOS);
  Result := AppendLine(Result, '  Architecture: ' + AArchitecture);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'FPDev Paths:');
  Result := AppendLine(Result, '  Mode:         ' + AMode);
  Result := AppendLine(Result, '  Data Root:    ' + ADataRoot);
  Result := AppendLine(Result, '  Config:       ' + AConfigPath);
  Result := AppendLine(Result, '  Cache:        ' + ACacheDir);
  Result := AppendLine(Result, '  Toolchains:   ' + AToolchainsDir);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Key Environment Variables:');
  Result := AppendLine(Result, '  FPCDIR:       ' + AFPCDir);
  Result := AppendLine(Result, '  LAZARUSDIR:   ' + ALazarusDir);
  Result := AppendLine(Result, '  HOME:         ' + AHome);
  if AUserProfile <> '' then
    Result := AppendLine(Result, '  USERPROFILE:  ' + AUserProfile);
  if AAppData <> '' then
    Result := AppendLine(Result, '  APPDATA:      ' + AAppData);
end;

function BuildSystemConfigShowLinesCore(
  const AMirror,
  ACustomRepoURL,
  AParallelJobs,
  AKeepSources,
  AAutoUpdate,
  AConfigFile,
  AInstallRoot,
  AToolchainsDir,
  AResourcesDir: string
): TStringArray;
begin
  Result := nil;
  Result := AppendLine(Result, 'FPDev Configuration');
  Result := AppendLine(Result, '===================');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Mirror Settings:');
  Result := AppendLine(Result, '  mirror:           ' + AMirror);
  Result := AppendLine(Result, '  custom_repo_url:  ' + ACustomRepoURL);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Build Settings:');
  Result := AppendLine(Result, '  parallel_jobs:    ' + AParallelJobs);
  Result := AppendLine(Result, '  keep_sources:     ' + AKeepSources);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Update Settings:');
  Result := AppendLine(Result, '  auto_update:      ' + AAutoUpdate);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Paths:');
  Result := AppendLine(Result, '  config_file:      ' + AConfigFile);
  Result := AppendLine(Result, '  install_root:     ' + AInstallRoot);
  Result := AppendLine(Result, '  toolchains_dir:   ' + AToolchainsDir);
  Result := AppendLine(Result, '  resources_dir:    ' + AResourcesDir);
end;

function BuildSystemIndexStatusLinesCore(
  const APlatform,
  ACacheDir,
  AIndexFile: string;
  ACacheDirExists,
  AIndexFileExists: Boolean
): TStringArray;
begin
  Result := nil;
  Result := AppendLine(Result, 'Index Status');
  Result := AppendLine(Result, '============');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Platform: ' + APlatform);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Cache Directory: ' + ACacheDir);
  if ACacheDirExists then
    Result := AppendLine(Result, '  Status: exists')
  else
    Result := AppendLine(Result, '  Status: not created yet');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Index File: ' + AIndexFile);
  if AIndexFileExists then
    Result := AppendLine(Result, '  Status: cached')
  else
    Result := AppendLine(Result, '  Status: not cached (will fetch on first use)');
end;

function BuildSystemCacheStatusLinesCore(
  const APackagesDir,
  AIndexDir: string;
  ABuildEntries: Integer;
  const ABuildSize,
  APackageSize,
  AIndexSize,
  ATotalSize: string;
  ABuildsDirExists,
  APackagesDirExists,
  AIndexDirExists: Boolean
): TStringArray;
begin
  Result := nil;
  Result := AppendLine(Result, 'Cache Status');
  Result := AppendLine(Result, '============');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'FPC Build Cache:');
  if ABuildsDirExists then
  begin
    Result := AppendLine(Result, '  Entries: ' + IntToStr(ABuildEntries));
    Result := AppendLine(Result, '  Size:    ' + ABuildSize);
  end
  else
    Result := AppendLine(Result, '  (not created)');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Package Registry:');
  if APackagesDirExists then
  begin
    Result := AppendLine(Result, '  Path: ' + APackagesDir);
    Result := AppendLine(Result, '  Size: ' + APackageSize);
  end
  else
    Result := AppendLine(Result, '  (not created)');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Index Cache:');
  if AIndexDirExists then
  begin
    Result := AppendLine(Result, '  Path: ' + AIndexDir);
    Result := AppendLine(Result, '  Size: ' + AIndexSize);
  end
  else
    Result := AppendLine(Result, '  (not created)');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Total Cache Size: ' + ATotalSize);
end;

function BuildSystemCachePathLinesCore(
  const ADataRoot,
  ABuildsDir,
  AIndexDir,
  ADownloadsDir,
  APackagesDir,
  AConfigFile: string
): TStringArray;
begin
  Result := nil;
  Result := AppendLine(Result, 'Cache Paths');
  Result := AppendLine(Result, '===========');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Data Root:');
  Result := AppendLine(Result, '  ' + ADataRoot);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Cache Directories:');
  Result := AppendLine(Result, '  Builds:    ' + ABuildsDir);
  Result := AppendLine(Result, '  Index:     ' + AIndexDir);
  Result := AppendLine(Result, '  Downloads: ' + ADownloadsDir);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Registry:');
  Result := AppendLine(Result, '  Packages:  ' + APackagesDir);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Config:');
  Result := AppendLine(Result, '  File:      ' + AConfigFile);
end;

function BuildSystemIndexShowLinesCore(
  const ABootstrapName,
  ABootstrapGitHub,
  ABootstrapGitee,
  AFPCName,
  AFPCGitHub,
  AFPCGitee,
  ALazarusName,
  ALazarusGitHub,
  ALazarusGitee,
  AStableBootstrap,
  AStableFPC,
  AStableLazarus,
  AEdgeBootstrap,
  AEdgeFPC,
  AEdgeLazarus: string;
  const ABootstrapVersions,
  AFPCVersions,
  ALazarusVersions: TStringArray
): TStringArray;
var
  VersionText: string;
begin
  Result := nil;
  Result := AppendLine(Result, 'Index Details');
  Result := AppendLine(Result, '=============');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Repositories:');
  Result := AppendLine(Result, '-------------');
  Result := AppendLine(Result, '  Bootstrap:');
  Result := AppendLine(Result, '    Name: ' + ABootstrapName);
  Result := AppendLine(Result, '    GitHub: ' + ABootstrapGitHub);
  Result := AppendLine(Result, '    Gitee: ' + ABootstrapGitee);
  Result := AppendLine(Result, '  FPC:');
  Result := AppendLine(Result, '    Name: ' + AFPCName);
  Result := AppendLine(Result, '    GitHub: ' + AFPCGitHub);
  Result := AppendLine(Result, '    Gitee: ' + AFPCGitee);
  Result := AppendLine(Result, '  Lazarus:');
  Result := AppendLine(Result, '    Name: ' + ALazarusName);
  Result := AppendLine(Result, '    GitHub: ' + ALazarusGitHub);
  Result := AppendLine(Result, '    Gitee: ' + ALazarusGitee);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Channels:');
  Result := AppendLine(Result, '---------');
  Result := AppendLine(Result, '  stable:');
  Result := AppendLine(Result, '    Bootstrap: ' + AStableBootstrap);
  Result := AppendLine(Result, '    FPC: ' + AStableFPC);
  Result := AppendLine(Result, '    Lazarus: ' + AStableLazarus);
  Result := AppendLine(Result, '  edge:');
  Result := AppendLine(Result, '    Bootstrap: ' + AEdgeBootstrap);
  Result := AppendLine(Result, '    FPC: ' + AEdgeFPC);
  Result := AppendLine(Result, '    Lazarus: ' + AEdgeLazarus);
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'Available Versions:');
  Result := AppendLine(Result, '-------------------');

  if Length(ABootstrapVersions) > 0 then
  begin
    Result := AppendLine(Result, '  Bootstrap:');
    for VersionText in ABootstrapVersions do
      Result := AppendLine(Result, '    - ' + VersionText);
  end;
  if Length(AFPCVersions) > 0 then
  begin
    Result := AppendLine(Result, '  FPC:');
    for VersionText in AFPCVersions do
      Result := AppendLine(Result, '    - ' + VersionText);
  end;
  if Length(ALazarusVersions) > 0 then
  begin
    Result := AppendLine(Result, '  Lazarus:');
    for VersionText in ALazarusVersions do
      Result := AppendLine(Result, '    - ' + VersionText);
  end;
end;

function BuildSystemIndexUpdateResultLinesCore(
  ASuccess: Boolean
): TStringArray;
begin
  Result := nil;
  Result := AppendLine(Result, 'Updating index...');
  Result := AppendLine(Result, '');
  if ASuccess then
  begin
    Result := AppendLine(Result, 'Index updated successfully.');
    Result := AppendLine(Result, '');
    Result := AppendLine(Result, 'Run "fpdev system index show" to see available versions.');
  end
  else
  begin
    Result := AppendLine(Result, 'Failed to update index.');
    Result := AppendLine(Result, 'Please check your network connection.');
  end;
end;

function BuildSystemCacheStatsLinesCore(
  ABuildsDirExists: Boolean;
  ATotalEntries: Integer;
  const ATotalSize,
  AAverageSize,
  ATotalAccesses,
  AMostAccessed,
  ALeastAccessed: string
): TStringArray;
begin
  Result := nil;
  Result := AppendLine(Result, 'Cache Statistics');
  Result := AppendLine(Result, '================');
  Result := AppendLine(Result, '');
  Result := AppendLine(Result, 'FPC Build Cache:');
  if ABuildsDirExists then
  begin
    Result := AppendLine(Result, '  Total Entries:    ' + IntToStr(ATotalEntries));
    Result := AppendLine(Result, '  Total Size:       ' + ATotalSize);
    Result := AppendLine(Result, '  Average Size:     ' + AAverageSize);
    Result := AppendLine(Result, '  Total Accesses:   ' + ATotalAccesses);
    if AMostAccessed <> '' then
    begin
      Result := AppendLine(Result, '');
      Result := AppendLine(Result, '  Most Accessed:    ' + AMostAccessed);
    end;
    if ALeastAccessed <> '' then
      Result := AppendLine(Result, '  Least Accessed:   ' + ALeastAccessed);
  end
  else
    Result := AppendLine(Result, '  (not created)');
end;

end.
