program test_lazarus_installcallbacks;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.constants,
  fpdev.config.interfaces,
  fpdev.git.types,
  fpdev.lazarus.config,
  fpdev.lazarus.installcallbacks,
  fpdev.utils,
  fpdev.version.registry,
  test_config_isolation,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  TestRootDir: string = '';
  ConfigManager: IConfigManager;

type
  TProbeInstallGitClient = class(TInterfacedObject, ILazarusInstallGitClient)
  public
    BackendValue: TGitBackend;
    CloneResult: Boolean;
    CloneCalls: Integer;
    LastCloneURL: string;
    LastClonePath: string;
    LastCloneBranch: string;
    function GetBackend: TGitBackend;
    function BackendAvailable: Boolean;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function GetLastError: string;
  end;

  TInstallCallbackHarness = class
  public
    LastCliOnly: Boolean;
    Client: ILazarusInstallGitClient;
    InstalledValue: Boolean;
    ResolvedInstallPathValue: string;
    CompatibleFPCVersionValue: string;
    function CreateGitClient(const ACliOnly: Boolean): ILazarusInstallGitClient;
    function IsVersionInstalled(const AVersion: string): Boolean;
    function ResolveInstallPath(const AVersion: string): string;
    function ResolveCompatibleFPCVersion(const AVersion: string): string;
  end;

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

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

function TProbeInstallGitClient.GetBackend: TGitBackend;
begin
  Result := BackendValue;
end;

function TProbeInstallGitClient.BackendAvailable: Boolean;
begin
  Result := BackendValue <> gbNone;
end;

function TProbeInstallGitClient.Clone(const AURL, ALocalPath: string;
  const ABranch: string): Boolean;
begin
  Inc(CloneCalls);
  LastCloneURL := AURL;
  LastClonePath := ALocalPath;
  LastCloneBranch := ABranch;
  Result := CloneResult;
end;

function TProbeInstallGitClient.Fetch(const ARepoPath: string;
  const ARemote: string): Boolean;
begin
  if ARepoPath <> '' then;
  if ARemote <> '' then;
  Result := True;
end;

function TProbeInstallGitClient.Checkout(const ARepoPath, AName: string;
  const Force: Boolean): Boolean;
begin
  if ARepoPath <> '' then;
  if AName <> '' then;
  if Force then;
  Result := True;
end;

function TProbeInstallGitClient.IsRepository(const APath: string): Boolean;
begin
  if APath <> '' then;
  Result := True;
end;

function TProbeInstallGitClient.HasRemote(const APath: string): Boolean;
begin
  if APath <> '' then;
  Result := True;
end;

function TProbeInstallGitClient.Pull(const APath: string): Boolean;
begin
  if APath <> '' then;
  Result := True;
end;

function TProbeInstallGitClient.GetLastError: string;
begin
  Result := '';
end;

function TInstallCallbackHarness.CreateGitClient(
  const ACliOnly: Boolean): ILazarusInstallGitClient;
begin
  LastCliOnly := ACliOnly;
  Result := Client;
end;

function TInstallCallbackHarness.IsVersionInstalled(const AVersion: string): Boolean;
begin
  if AVersion <> '' then;
  Result := InstalledValue;
end;

function TInstallCallbackHarness.ResolveInstallPath(const AVersion: string): string;
begin
  if AVersion <> '' then;
  Result := ResolvedInstallPathValue;
end;

function TInstallCallbackHarness.ResolveCompatibleFPCVersion(
  const AVersion: string): string;
begin
  if AVersion <> '' then;
  Result := CompatibleFPCVersionValue;
end;

procedure MakeExecutable(const APath: string);
begin
  {$IFDEF UNIX}
  if fpchmod(APath, &755) <> 0 then
    raise Exception.Create('Failed to mark executable: ' + APath);
  {$ENDIF}
end;

procedure WriteMockBuildMakefile(const ASourceDir, ACapturePath: string);
begin
  ForceDirectories(ASourceDir);
  with TStringList.Create do
  try
    Add('all:');
    Add(#9 + 'printf ''%s\n'' "$$PATH" > "' + ACapturePath + '"');
    Add('install:');
    {$IFDEF MSWINDOWS}
    Add(#9 + 'if not exist "$(INSTALL_PREFIX)\\bin" mkdir "$(INSTALL_PREFIX)\\bin"');
    Add(#9 + 'echo @echo off> "$(INSTALL_PREFIX)\\bin\\lazarus.exe"');
    {$ELSE}
    Add(#9 + 'mkdir -p "$(INSTALL_PREFIX)/bin"');
    Add(#9 + 'echo ''#!/bin/sh'' > "$(INSTALL_PREFIX)/bin/lazarus-ide"');
    Add(#9 + 'echo ''exit 0'' >> "$(INSTALL_PREFIX)/bin/lazarus-ide"');
    Add(#9 + 'chmod +x "$(INSTALL_PREFIX)/bin/lazarus-ide"');
    {$ENDIF}
    SaveToFile(ASourceDir + PathDelim + 'Makefile');
  finally
    Free;
  end;
end;

procedure WriteCustomLazarusRegistry(
  const APath, ARepoURL, AGitTag: string
);
begin
  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.6",');
    Add('    "repository": "' + ARepoURL + '",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.6",');
    Add('        "release_date": "2024-10-14",');
    Add('        "git_tag": "' + AGitTag + '",');
    Add('        "branch": "' + AGitTag + '",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(APath);
  finally
    Free;
  end;
end;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  TestRootDir := CreateUniqueTempDir('test_lazarus_installcallbacks');
  ConfigManager := CreateIsolatedConfigManager;
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);
end;

procedure CleanupTestEnvironment;
begin
  ConfigManager := nil;
  CleanupTempDir(TestRootDir);
end;

procedure TestDownloadLazarusSourceCoreUsesOfficialRepository;
var
  Harness: TInstallCallbackHarness;
  Client: TProbeInstallGitClient;
  SourceDir: string;
begin
  Harness := TInstallCallbackHarness.Create;
  try
    Client := TProbeInstallGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Harness.Client := Client;
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-3.6-core';

    Check(
      'download helper uses official repository',
      DownloadLazarusSourceCore('3.6', SourceDir, @Harness.CreateGitClient),
      'expected download helper to succeed'
    );
    Check(
      'download helper does not force cli-only backend',
      not Harness.LastCliOnly,
      'expected helper to request default backend selection'
    );
    Check(
      'download helper clones from official repository',
      Client.LastCloneURL = LAZARUS_OFFICIAL_REPO,
      'url=' + Client.LastCloneURL
    );
    Check(
      'download helper clones using release tag',
      Client.LastCloneBranch = 'lazarus_3_6',
      'branch=' + Client.LastCloneBranch
    );
  finally
    Harness.Free;
  end;
end;

procedure TestBuildLazarusFromSourceCoreUsesSameProcessPath;
var
  SourceDir: string;
  InstallDir: string;
  CapturePath: string;
  SavedPath: string;
  ProbePath: string;
  CapturedPath: string;
  CaptureLines: TStringList;
begin
  SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-3.7';
  InstallDir := TestRootDir + PathDelim + 'lazarus' + PathDelim + '3.7';
  CapturePath := TestRootDir + PathDelim + 'build-path-capture.txt';
  ProbePath := TestRootDir + PathDelim + 'path-probe';

  ForceDirectories(ProbePath);
  WriteMockBuildMakefile(SourceDir, CapturePath);

  SavedPath := GetEnvironmentVariable('PATH');
  if not set_env('PATH', ProbePath + PathSeparator + SavedPath) then
    raise Exception.Create('Failed to set PATH for build helper test');
  try
    Check(
      'build helper succeeds for mock source tree',
      BuildLazarusFromSourceCore(ConfigManager, SourceDir, InstallDir, '3.2.2'),
      'expected build helper to succeed for mock Makefile'
    );
    Check(
      'build helper captures same-process PATH',
      FileExists(CapturePath),
      'missing path capture file'
    );
    if FileExists(CapturePath) then
    begin
      CaptureLines := TStringList.Create;
      try
        CaptureLines.LoadFromFile(CapturePath);
        CapturedPath := Trim(CaptureLines.Text);
      finally
        CaptureLines.Free;
      end;
      Check(
        'build helper propagates same-process PATH entry',
        Pos(ProbePath, CapturedPath) > 0,
        'captured path=' + CapturedPath
      );
    end;
  finally
    RestoreEnv('PATH', SavedPath);
  end;
end;

procedure TestSetupLazarusEnvironmentCorePersistsRegistryRepositoryURL;
var
  Harness: TInstallCallbackHarness;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomRepoURL: string;
  LazarusInfo: TLazarusInfo;
begin
  Harness := TInstallCallbackHarness.Create;
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-installcallbacks.json';
  CustomRepoURL := 'https://mirror.example.invalid/lazarus-core.git';
  try
    WriteCustomLazarusRegistry(VersionsJSONPath, CustomRepoURL, 'core_lazarus_3_6');
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    if not TVersionRegistry.Instance.Reload then
      raise Exception.Create('Failed to reload custom Lazarus registry');

    Harness.InstalledValue := True;
    Harness.ResolvedInstallPathValue := TestRootDir + PathDelim + 'custom-lazarus-3.6';
    Harness.CompatibleFPCVersionValue := '3.2.2';

    Check(
      'setup environment helper succeeds',
      SetupLazarusEnvironmentCore(
        ConfigManager,
        '3.6',
        @Harness.IsVersionInstalled,
        @Harness.ResolveInstallPath,
        @Harness.ResolveCompatibleFPCVersion
      ),
      'expected setup helper to write Lazarus config entry'
    );
    Check(
      'setup environment helper writes config entry',
      ConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-3.6', LazarusInfo),
      'missing lazarus-3.6 entry'
    );
    Check(
      'setup environment helper persists resolved install path',
      LazarusInfo.InstallPath = Harness.ResolvedInstallPathValue,
      'install path=' + LazarusInfo.InstallPath
    );
    Check(
      'setup environment helper persists compatible fpc version',
      LazarusInfo.FPCVersion = 'fpc-3.2.2',
      'fpc=' + LazarusInfo.FPCVersion
    );
    Check(
      'setup environment helper persists registry repository URL',
      LazarusInfo.SourceURL = CustomRepoURL,
      'source url=' + LazarusInfo.SourceURL
    );
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Harness.Free;
  end;
end;

begin
  WriteLn('=== Lazarus Install Callbacks Tests ===');

  InitTestEnvironment;
  try
    TestDownloadLazarusSourceCoreUsesOfficialRepository;
    TestBuildLazarusFromSourceCoreUsesSameProcessPath;
    TestSetupLazarusEnvironmentCorePersistsRegistryRepositoryURL;
  finally
    CleanupTestEnvironment;
  end;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
