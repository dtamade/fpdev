program test_fpc_builder;

{$mode objfpc}{$H+}

{
  Unit tests for TFPCBuilder

  Tests:
  - DownloadSource: Downloads FPC source from Git repository
  - BuildFromSource: Builds FPC from source code
  - UpdateSources: Updates FPC source from remote repository
  - CleanSources: Cleans build artifacts from source directory

  Note: These tests use mock implementations for file system and process runner
  to avoid dependency on real Git and make commands.
}

uses
  SysUtils, Classes, git2.api, git2.types, test_temp_paths,
  fpdev.fpc.version, fpdev.fpc.builder, fpdev.fpc.builder.di,
  fpdev.fpc.installversionflow,
  fpdev.fpc.types, fpdev.fpc.interfaces, fpdev.fpc.mocks, fpdev.config,
  fpdev.version.registry, fpdev.constants, fpdev.utils, fpdev.paths;

var
  TestInstallRoot: string;
  ConfigManager: TFPDevConfigManager;
  VersionManager: TFPCVersionManager;
  MockFileSystem: TMockFileSystem;
  MockProcessRunner: TMockProcessRunner;
  MockGitManager: TMockGitManager;
  Builder: TFPCBuilder;
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

type
  TProbeBuilderGitManager = class(TInterfacedObject, IGitManager)
  public
    InitializeResult: Boolean;
    CloneResult: IGitRepository;
    LastCloneURL: string;
    LastClonePath: string;
    function Initialize: Boolean;
    procedure Finalize;
    function OpenRepository(const APath: string): IGitRepository;
    function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
    function InitRepository(const APath: string; ABare: Boolean = False): IGitRepository;
    function IsRepository(const APath: string): Boolean;
    function DiscoverRepository(const AStartPath: string): string;
    function GetGlobalConfig(const AKey: string): string;
    function SetGlobalConfig(const AKey, AValue: string): Boolean;
    function Version: string;
    procedure SetVerifySSL(AEnabled: Boolean);
    procedure SetCredentialAcquireHandler(AHandler: TCredentialAcquireEvent);
    procedure SetCertificateCheckHandler(AHandler: TCertificateCheckEvent);
    function Initialized: Boolean;
    function VerifySSL: Boolean;
  end;

function BuildTempRoot(const APrefix: string): string;
begin
  Result := CreateUniqueTempDir(APrefix);
end;

procedure SetupTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  // Create temporary install root directory
  if TestInstallRoot = '' then
    TestInstallRoot := BuildTempRoot('test_builder_root_');
  ForceDirectories(TestInstallRoot);

  // Setup config manager to use test directory
  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := TestInstallRoot;
  Settings.ParallelJobs := 4;
  ConfigManager.SetSettings(Settings);

  WriteLn('[Setup] Created test directory: ', TestInstallRoot);
end;

procedure TeardownTestEnvironment;
  procedure DeleteDirectory(const DirPath: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if not DirectoryExists(DirPath) then Exit;

    if FindFirst(DirPath + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          FilePath := DirPath + PathDelim + SR.Name;
          if (SR.Attr and faDirectory) <> 0 then
            DeleteDirectory(FilePath)
          else
            DeleteFile(FilePath);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    RemoveDir(DirPath);
  end;

begin
  if DirectoryExists(TestInstallRoot) then
  begin
    DeleteDirectory(TestInstallRoot);
    WriteLn('[Teardown] Deleted test directory: ', TestInstallRoot);
  end;
end;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('  FAILED: ', AMessage);
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    WriteLn('  FAILED: ', AMessage, ' (expected ', AExpected, ', got ', AActual, ')');
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure AssertEqualsStr(const AExpected, AActual, AMessage: string);
begin
  if AExpected <> AActual then
  begin
    WriteLn('  FAILED: ', AMessage, ' (expected "', AExpected, '", got "', AActual, '")');
    Inc(TestsFailed);
  end
  else
  begin
    WriteLn('  PASSED: ', AMessage);
    Inc(TestsPassed);
  end;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

function BuildExpectedBootstrapCompilerPath(const AVersion: string): string;
begin
  {$IFDEF MSWINDOWS}
  Result := IncludeTrailingPathDelimiter(GetDataRoot) + 'bootstrap' + PathDelim +
    'fpc-' + AVersion + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  Result := IncludeTrailingPathDelimiter(GetDataRoot) + 'bootstrap' + PathDelim +
    'fpc-' + AVersion + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
end;

procedure TestTempPathsUseSystemTempRoot;
var
  TempRoot: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: temp paths use system temp root');
  WriteLn('==================================================');

  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  AssertTrue(Pos(TempRoot, ExpandFileName(TestInstallRoot)) = 1,
    'Test install root should live under system temp');
  AssertTrue(Pos(TempRoot, ExpandFileName(ConfigManager.ConfigPath)) = 1,
    'Config path should live under system temp');
end;

procedure ResetMocks;
begin
  MockFileSystem.Clear;
  MockProcessRunner.Clear;
  MockProcessRunner.SetDefaultResult(0, '', '');
end;

procedure Test_GetBootstrapCompilerPath_UsesSameProcessUserHome;
var
  LocalSourceBuilder: TFPCSourceBuilder;
  ProbeHome: string;
  ExpectedPath: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
  {$IFDEF MSWINDOWS}
  SavedAppData: string;
  SavedUserProfile: string;
  {$ELSE}
  SavedHome: string;
  {$ENDIF}
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetBootstrapCompilerPath - Same-Process User Home');
  WriteLn('==================================================');

  ProbeHome := BuildTempRoot('test_builder_bootstrap_home_');
  ForceDirectories(ProbeHome);
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  {$IFDEF MSWINDOWS}
  SavedAppData := get_env('APPDATA');
  SavedUserProfile := get_env('USERPROFILE');
  {$ELSE}
  SavedHome := get_env('HOME');
  {$ENDIF}
  try
    SetPortableMode(False);
    unset_env('FPDEV_DATA_ROOT');
    unset_env('XDG_DATA_HOME');
    {$IFDEF MSWINDOWS}
    set_env('APPDATA', ProbeHome);
    set_env('USERPROFILE', ProbeHome);
    {$ELSE}
    set_env('HOME', ProbeHome);
    {$ENDIF}
    ExpectedPath := BuildExpectedBootstrapCompilerPath('3.2.2');

    LocalSourceBuilder := TFPCSourceBuilder.Create(ConfigManager.AsConfigManager);
    try
      AssertEqualsStr(ExpectedPath,
        LocalSourceBuilder.GetBootstrapCompilerPath('3.2.2'),
        'GetBootstrapCompilerPath should use same-process user home');
    finally
      LocalSourceBuilder.Free;
    end;
  finally
    {$IFDEF MSWINDOWS}
    RestoreEnv('USERPROFILE', SavedUserProfile);
    RestoreEnv('APPDATA', SavedAppData);
    {$ELSE}
    RestoreEnv('HOME', SavedHome);
    {$ENDIF}
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    CleanupTempDir(ProbeHome);
  end;
end;

procedure Test_GetBootstrapCompilerPath_UsesFPDEVDataRootOverride;
var
  LocalSourceBuilder: TFPCSourceBuilder;
  ProbeRoot: string;
  ExpectedPath: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetBootstrapCompilerPath - FPDEV_DATA_ROOT override');
  WriteLn('==================================================');

  ProbeRoot := BuildTempRoot('test_builder_bootstrap_data_root_');
  ForceDirectories(ProbeRoot);
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  try
    SetPortableMode(False);
    unset_env('XDG_DATA_HOME');
    set_env('FPDEV_DATA_ROOT', ProbeRoot);
    ExpectedPath := BuildExpectedBootstrapCompilerPath('3.2.2');

    LocalSourceBuilder := TFPCSourceBuilder.Create(ConfigManager.AsConfigManager);
    try
      AssertEqualsStr(ExpectedPath,
        LocalSourceBuilder.GetBootstrapCompilerPath('3.2.2'),
        'GetBootstrapCompilerPath should use FPDEV_DATA_ROOT override');
    finally
      LocalSourceBuilder.Free;
    end;
  finally
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    CleanupTempDir(ProbeRoot);
  end;
end;

procedure Test_GetRequiredBootstrapVersion_UsesFPDEVDataRootInstallRoot;
var
  LocalSourceBuilder: TFPCSourceBuilder;
  Settings: TFPDevSettings;
  SavedInstallRoot: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
  ProbeRoot: string;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: GetRequiredBootstrapVersion - FPDEV_DATA_ROOT install root');
  WriteLn('==================================================');

  ProbeRoot := BuildTempRoot('test_builder_install_root_data_root_');
  ForceDirectories(ProbeRoot);
  Settings := ConfigManager.GetSettings;
  SavedInstallRoot := Settings.InstallRoot;
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  try
    Settings.InstallRoot := '';
    ConfigManager.SetSettings(Settings);
    SetPortableMode(False);
    unset_env('XDG_DATA_HOME');
    set_env('FPDEV_DATA_ROOT', ProbeRoot);

    SourceDir := BuildFPCSourceInstallPathCore(GetDataRoot, '9.9.9');
    ForceDirectories(SourceDir);
    with TStringList.Create do
    try
      Add('REQUIREDVERSION=30202');
      SaveToFile(SourceDir + PathDelim + 'Makefile');
    finally
      Free;
    end;

    LocalSourceBuilder := TFPCSourceBuilder.Create(ConfigManager.AsConfigManager);
    try
      AssertEqualsStr('3.2.2',
        LocalSourceBuilder.GetRequiredBootstrapVersion('9.9.9'),
        'GetRequiredBootstrapVersion should read source tree under FPDEV_DATA_ROOT');
    finally
      LocalSourceBuilder.Free;
    end;
  finally
    Settings.InstallRoot := SavedInstallRoot;
    ConfigManager.SetSettings(Settings);
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    CleanupTempDir(ProbeRoot);
  end;
end;

function TProbeBuilderGitManager.Initialize: Boolean;
begin
  Result := InitializeResult;
end;

procedure TProbeBuilderGitManager.Finalize;
begin
end;

function TProbeBuilderGitManager.OpenRepository(const APath: string): IGitRepository;
begin
  if APath <> '' then;
  Result := nil;
end;

function TProbeBuilderGitManager.CloneRepository(const AURL,
  ALocalPath: string): IGitRepository;
begin
  LastCloneURL := AURL;
  LastClonePath := ALocalPath;
  Result := CloneResult;
end;

function TProbeBuilderGitManager.InitRepository(const APath: string;
  ABare: Boolean): IGitRepository;
begin
  if APath <> '' then;
  if ABare then;
  Result := nil;
end;

function TProbeBuilderGitManager.IsRepository(const APath: string): Boolean;
begin
  if APath <> '' then;
  Result := False;
end;

function TProbeBuilderGitManager.DiscoverRepository(const AStartPath: string): string;
begin
  if AStartPath <> '' then;
  Result := '';
end;

function TProbeBuilderGitManager.GetGlobalConfig(const AKey: string): string;
begin
  if AKey <> '' then;
  Result := '';
end;

function TProbeBuilderGitManager.SetGlobalConfig(const AKey, AValue: string): Boolean;
begin
  if AKey <> '' then;
  if AValue <> '' then;
  Result := True;
end;

function TProbeBuilderGitManager.Version: string;
begin
  Result := 'probe';
end;

procedure TProbeBuilderGitManager.SetVerifySSL(AEnabled: Boolean);
begin
  if AEnabled then;
end;

procedure TProbeBuilderGitManager.SetCredentialAcquireHandler(
  AHandler: TCredentialAcquireEvent);
begin
  if Assigned(AHandler) then;
end;

procedure TProbeBuilderGitManager.SetCertificateCheckHandler(
  AHandler: TCertificateCheckEvent);
begin
  if Assigned(AHandler) then;
end;

function TProbeBuilderGitManager.Initialized: Boolean;
begin
  Result := InitializeResult;
end;

function TProbeBuilderGitManager.VerifySSL: Boolean;
begin
  Result := True;
end;

{ Test: DownloadSource prefers libgit2 when available }
procedure Test_DownloadSource_PrefersLibgit2;
var
  Result: TOperationResult;
  TargetDir: string;
  LocalBuilder: TFPCBuilder;
  LocalGitManager: TMockGitManager;
  Repo: TMockGitRepository;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Prefers libgit2');
  WriteLn('==================================================');

  ResetMocks;
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2-libgit2';

  // Ensure CLI path would fail if used
  MockProcessRunner.SetDefaultResult(1, '', 'should not call git CLI');

  LocalGitManager := TMockGitManager.Create;
  LocalGitManager.SetInitializeOk(True);
  Repo := TMockGitRepository.Create(TargetDir);
  Repo.SetCheckoutOk(True);
  LocalGitManager.SetCloneRepositoryResult(Repo as IGitRepository);

  LocalBuilder := TFPCBuilder.Create(VersionManager, ConfigManager,
    MockFileSystem, MockProcessRunner, LocalGitManager as IGitManager);
  try
    Result := LocalBuilder.DownloadSource('3.2.2', TargetDir);

    AssertTrue(Result.Success, 'DownloadSource should succeed via libgit2');
    AssertTrue(MockProcessRunner.GetExecutedCommands.Count = 0, 'Git CLI should not be executed');
    AssertTrue(MockFileSystem.DirectoryExists(TargetDir), 'Target directory should be created');
  finally
    LocalBuilder.Free;
  end;
end;

procedure Test_DownloadSource_UsesRegistryRepository_Libgit2;
var
  Result: TOperationResult;
  TargetDir: string;
  LocalBuilder: TFPCBuilder;
  ProbeGitManager: TProbeBuilderGitManager;
  Repo: TMockGitRepository;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomRepoURL: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Uses registry repository with libgit2');
  WriteLn('==================================================');

  ResetMocks;
  CustomRepoURL := 'https://mirror.example.invalid/fpc-source.git';
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestInstallRoot + PathDelim + 'versions-fpc-builder-libgit2.json';
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2-builder-libgit2';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
    Add('    "repository": "' + CustomRepoURL + '",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.2.2",');
    Add('        "release_date": "2021-05-19",');
    Add('        "git_tag": "custom_release_3_2_2",');
    Add('        "branch": "custom_fixes_3_2",');
    Add('        "channel": "stable",');
    Add('        "lts": true');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  ProbeGitManager := TProbeBuilderGitManager.Create;
  ProbeGitManager.InitializeResult := True;
  Repo := TMockGitRepository.Create(TargetDir);
  Repo.SetCheckoutOk(True);
  ProbeGitManager.CloneResult := Repo as IGitRepository;

  LocalBuilder := TFPCBuilder.Create(VersionManager, ConfigManager,
    MockFileSystem, MockProcessRunner, ProbeGitManager as IGitManager);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom builder registry data reloads for libgit2 path');

    Result := LocalBuilder.DownloadSource('3.2.2', TargetDir);

    AssertTrue(Result.Success, 'DownloadSource should succeed via libgit2 with registry repository');
    AssertEqualsStr(CustomRepoURL, ProbeGitManager.LastCloneURL,
      'DownloadSource should clone from registry repository URL');
    AssertEqualsStr(TargetDir, ProbeGitManager.LastClonePath,
      'DownloadSource should clone into requested target directory');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    LocalBuilder.Free;
  end;
end;

procedure Test_DownloadSource_EmptyRegistryFallsBackToStaticCatalog_Libgit2;
var
  Result: TOperationResult;
  TargetDir: string;
  LocalBuilder: TFPCBuilder;
  ProbeGitManager: TProbeBuilderGitManager;
  Repo: TMockGitRepository;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Empty registry falls back to static catalog with libgit2');
  WriteLn('==================================================');

  ResetMocks;
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestInstallRoot + PathDelim + 'versions-fpc-builder-empty-libgit2.json';
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2-empty-libgit2';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
    Add('    "releases": []');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  ProbeGitManager := TProbeBuilderGitManager.Create;
  ProbeGitManager.InitializeResult := True;
  Repo := TMockGitRepository.Create(TargetDir);
  Repo.SetCheckoutOk(True);
  ProbeGitManager.CloneResult := Repo as IGitRepository;

  LocalBuilder := TFPCBuilder.Create(VersionManager, ConfigManager,
    MockFileSystem, MockProcessRunner, ProbeGitManager as IGitManager);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Empty builder registry data reloads for libgit2 path');

    Result := LocalBuilder.DownloadSource('3.2.2', TargetDir);

    AssertTrue(Result.Success,
      'DownloadSource should succeed with static catalog fallback when registry releases are empty');
    AssertEqualsStr(FPC_OFFICIAL_REPO, ProbeGitManager.LastCloneURL,
      'Empty registry should still clone from default FPC repository');
    AssertTrue(MockProcessRunner.GetExecutedCommands.Count = 0,
      'libgit2 fallback path should not execute git CLI');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    LocalBuilder.Free;
  end;
end;

{ Test: UpdateSources prefers libgit2 when available }
procedure Test_UpdateSources_PrefersLibgit2;
var
  Result: TOperationResult;
  SourceDir, GitDir: string;
  LocalBuilder: TFPCBuilder;
  LocalGitManager: TMockGitManager;
  Repo: TMockGitRepository;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - Prefers libgit2');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
  GitDir := SourceDir + PathDelim + '.git';

  MockFileSystem.AddDirectory(SourceDir);
  MockFileSystem.AddDirectory(GitDir);

  // Ensure CLI path would fail if used
  MockProcessRunner.SetDefaultResult(1, '', 'should not call git CLI');

  LocalGitManager := TMockGitManager.Create;
  LocalGitManager.SetInitializeOk(True);
  Repo := TMockGitRepository.Create(SourceDir);
  Repo.SetPullResult(gpffUpToDate, '');
  LocalGitManager.SetOpenRepositoryResult(Repo as IGitRepository);

  LocalBuilder := TFPCBuilder.Create(VersionManager, ConfigManager,
    MockFileSystem, MockProcessRunner, LocalGitManager as IGitManager);
  try
    Result := LocalBuilder.UpdateSources('3.2.2');

    AssertTrue(Result.Success, 'UpdateSources should succeed via libgit2');
    AssertTrue(MockProcessRunner.GetExecutedCommands.Count = 0, 'Git CLI should not be executed');
  finally
    LocalBuilder.Free;
  end;
end;

{ Test: DownloadSource succeeds with valid version }
procedure Test_DownloadSource_Success;
var
  Result: TOperationResult;
  TargetDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Success');
  WriteLn('==================================================');

  ResetMocks;
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';

  // Setup mock: git clone succeeds
  MockProcessRunner.SetResult('git', 0, 'Cloning into...', '');

  Result := Builder.DownloadSource('3.2.2', TargetDir);

  AssertTrue(Result.Success, 'DownloadSource should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
  AssertTrue(MockFileSystem.DirectoryExists(TargetDir), 'Target directory should be created');
  AssertTrue(MockProcessRunner.GetExecutedCommands.Count > 0, 'Git command should be executed');
end;

{ Test: DownloadSource CLI fallback goes through injected runner via GitOps }
procedure Test_DownloadSource_CliFallbackUsesInjectedRunner;
var
  Result: TOperationResult;
  TargetDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - CLI fallback uses injected runner');
  WriteLn('==================================================');

  ResetMocks;
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2-cli-probe';

  MockProcessRunner.SetResult('git', 0, 'git version 2.43.0', '');

  Result := Builder.DownloadSource('3.2.2', TargetDir);

  AssertTrue(Result.Success, 'DownloadSource should succeed through CLI fallback');
  AssertTrue(MockProcessRunner.GetExecutedCommands.Count >= 2,
    'CLI fallback should probe git and then clone through the injected runner');
  if MockProcessRunner.GetExecutedCommands.Count >= 1 then
    AssertEqualsStr('git --version', MockProcessRunner.GetExecutedCommands[0],
      'CLI fallback should probe git availability through injected runner');
  if MockProcessRunner.GetExecutedCommands.Count >= 2 then
    AssertTrue(Pos('git clone', MockProcessRunner.GetExecutedCommands[1]) = 1,
      'CLI fallback should clone through injected runner');
end;

procedure Test_DownloadSource_CliFallbackUsesRegistryRepository;
var
  Result: TOperationResult;
  TargetDir: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomRepoURL: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - CLI fallback uses registry repository');
  WriteLn('==================================================');

  ResetMocks;
  CustomRepoURL := 'https://mirror.example.invalid/fpc-source.git';
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestInstallRoot + PathDelim + 'versions-fpc-builder-cli.json';
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2-cli-registry';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
    Add('    "repository": "' + CustomRepoURL + '",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.2.2",');
    Add('        "release_date": "2021-05-19",');
    Add('        "git_tag": "custom_release_3_2_2",');
    Add('        "branch": "custom_fixes_3_2",');
    Add('        "channel": "stable",');
    Add('        "lts": true');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  MockProcessRunner.SetResult('git', 0, 'git version 2.43.0', '');

  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom builder registry data reloads for CLI path');

    Result := Builder.DownloadSource('3.2.2', TargetDir);

    AssertTrue(Result.Success, 'DownloadSource should succeed through CLI fallback with registry repository');
    AssertTrue(MockProcessRunner.GetExecutedCommands.Count >= 2,
      'CLI fallback should execute git probe and clone commands');
    if MockProcessRunner.GetExecutedCommands.Count >= 2 then
      AssertTrue(
        Pos('git clone --depth 1 --branch custom_release_3_2_2 ' + CustomRepoURL + ' ', MockProcessRunner.GetExecutedCommands[1]) = 1,
        'CLI fallback should clone from registry repository URL'
      );
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
  end;
end;

procedure Test_DownloadSource_EmptyRegistryCliFallbackUsesStaticGitTag;
var
  Result: TOperationResult;
  TargetDir: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - CLI fallback uses static git tag when registry is empty');
  WriteLn('==================================================');

  ResetMocks;
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestInstallRoot + PathDelim + 'versions-fpc-builder-empty-cli.json';
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2-empty-cli';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
    Add('    "releases": []');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  MockGitManager.SetInitializeOk(False);
  MockGitManager.Finalize;
  MockProcessRunner.SetResult('git', 0, 'git version 2.43.0', '');

  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Empty builder registry data reloads for CLI path');

    Result := Builder.DownloadSource('3.2.2', TargetDir);

    AssertTrue(Result.Success,
      'DownloadSource should succeed through CLI fallback when registry releases are empty');
    AssertTrue(MockProcessRunner.GetExecutedCommands.Count >= 2,
      'CLI fallback should execute git probe and clone commands');
    if MockProcessRunner.GetExecutedCommands.Count >= 2 then
      AssertTrue(
        Pos('git clone --depth 1 --branch release_3_2_2 ' + FPC_OFFICIAL_REPO + ' ', MockProcessRunner.GetExecutedCommands[1]) = 1,
        'CLI fallback should use static git tag when registry releases are empty'
      );
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
  end;
end;

{ Test: DownloadSource fails with invalid version }
procedure Test_DownloadSource_InvalidVersion;
var
  Result: TOperationResult;
  TargetDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Invalid Version');
  WriteLn('==================================================');

  ResetMocks;
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-invalid';

  // Version 'invalid' should not have a valid Git tag
  Result := Builder.DownloadSource('invalid', TargetDir);

  AssertFalse(Result.Success, 'DownloadSource should fail for invalid version');
  AssertEquals(Ord(ecVersionNotFound), Ord(Result.ErrorCode), 'ErrorCode should be ecVersionNotFound');
end;

{ Test: DownloadSource fails when git clone fails }
procedure Test_DownloadSource_GitFailed;
var
  Result: TOperationResult;
  TargetDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: DownloadSource - Git Failed');
  WriteLn('==================================================');

  ResetMocks;
  TargetDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';

  // Setup mock: git clone fails
  MockProcessRunner.SetResult('git', 128, '', 'fatal: repository not found');

  Result := Builder.DownloadSource('3.2.2', TargetDir);

  AssertFalse(Result.Success, 'DownloadSource should fail when git fails');
  AssertEquals(Ord(ecDownloadFailed), Ord(Result.ErrorCode), 'ErrorCode should be ecDownloadFailed');
  AssertTrue(Pos('Git clone failed', Result.ErrorMessage) > 0, 'Error message should mention git clone');
end;

{ Test: BuildFromSource succeeds }
procedure Test_BuildFromSource_Success;
var
  Result: TOperationResult;
  SourceDir, InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: BuildFromSource - Success');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // Setup mock: source directory exists, make succeeds
  MockFileSystem.AddDirectory(SourceDir);
  MockProcessRunner.SetResult('make', 0, 'Build complete', '');

  Result := Builder.BuildFromSource(SourceDir, InstallDir);

  AssertTrue(Result.Success, 'BuildFromSource should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
  AssertTrue(MockFileSystem.DirectoryExists(InstallDir), 'Install directory should be created');
end;

{ Test: BuildFromSource fails when source directory does not exist }
procedure Test_BuildFromSource_SourceNotExist;
var
  Result: TOperationResult;
  SourceDir, InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: BuildFromSource - Source Not Exist');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'nonexistent';
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // Source directory does not exist (not added to mock)

  Result := Builder.BuildFromSource(SourceDir, InstallDir);

  AssertFalse(Result.Success, 'BuildFromSource should fail when source does not exist');
  AssertEquals(Ord(ecBuildFailed), Ord(Result.ErrorCode), 'ErrorCode should be ecBuildFailed');
  AssertTrue(Pos('does not exist', Result.ErrorMessage) > 0, 'Error message should mention directory not exist');
end;

{ Test: BuildFromSource fails when make fails }
procedure Test_BuildFromSource_MakeFailed;
var
  Result: TOperationResult;
  SourceDir, InstallDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: BuildFromSource - Make Failed');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc-3.2.2';
  InstallDir := TestInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';

  // Setup mock: source directory exists, make fails
  MockFileSystem.AddDirectory(SourceDir);
  MockProcessRunner.SetResult('make', 2, '', 'Error: compilation failed');

  Result := Builder.BuildFromSource(SourceDir, InstallDir);

  AssertFalse(Result.Success, 'BuildFromSource should fail when make fails');
  AssertEquals(Ord(ecBuildFailed), Ord(Result.ErrorCode), 'ErrorCode should be ecBuildFailed');
  AssertTrue(Pos('Build failed', Result.ErrorMessage) > 0, 'Error message should mention build failed');
end;

{ Test: UpdateSources succeeds }
procedure Test_UpdateSources_Success;
var
  Result: TOperationResult;
  SourceDir, GitDir: string;
  LocalBuilder: TFPCBuilder;
  LocalGitManager: TMockGitManager;
  Repo: TMockGitRepository;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - Success');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
  GitDir := SourceDir + PathDelim + '.git';

  // Setup mock: source directory and .git exist, git commands succeed
  MockFileSystem.AddDirectory(SourceDir);
  MockFileSystem.AddDirectory(GitDir);

  LocalGitManager := TMockGitManager.Create;
  LocalGitManager.SetInitializeOk(True);
  Repo := TMockGitRepository.Create(SourceDir);
  Repo.SetPullResult(gpffFastForwarded, '');
  LocalGitManager.SetOpenRepositoryResult(Repo as IGitRepository);

  LocalBuilder := TFPCBuilder.Create(VersionManager, ConfigManager,
    MockFileSystem, MockProcessRunner, LocalGitManager as IGitManager);
  try
    Result := LocalBuilder.UpdateSources('3.2.2');

    AssertTrue(Result.Success, 'UpdateSources should succeed on fast-forward');
    AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
    AssertEquals(0, MockProcessRunner.GetExecutedCommands.Count,
      'Fast-forward success should not execute git CLI');
  finally
    LocalBuilder.Free;
  end;
end;

procedure AssertUpdateSourcesFastForwardOnly(const AScenario: string;
  APullResult: TGitPullFastForwardResult; const APullError: string);
var
  Result: TOperationResult;
  SourceDir, GitDir: string;
  LocalBuilder: TFPCBuilder;
  LocalGitManager: TMockGitManager;
  Repo: TMockGitRepository;
  LowerErr: string;
begin
  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
  GitDir := SourceDir + PathDelim + '.git';

  MockFileSystem.AddDirectory(SourceDir);
  MockFileSystem.AddDirectory(GitDir);
  MockProcessRunner.SetDefaultResult(0, 'Already up to date.', '');

  LocalGitManager := TMockGitManager.Create;
  LocalGitManager.SetInitializeOk(True);
  Repo := TMockGitRepository.Create(SourceDir);
  Repo.SetPullResult(APullResult, APullError);
  LocalGitManager.SetOpenRepositoryResult(Repo as IGitRepository);

  LocalBuilder := TFPCBuilder.Create(VersionManager, ConfigManager,
    MockFileSystem, MockProcessRunner, LocalGitManager as IGitManager);
  try
    Result := LocalBuilder.UpdateSources('3.2.2');

    AssertFalse(Result.Success, AScenario + ' should fail instead of falling back to CLI pull');
    AssertEquals(Ord(ecDownloadFailed), Ord(Result.ErrorCode),
      AScenario + ' should return ecDownloadFailed');
    AssertEquals(0, MockProcessRunner.GetExecutedCommands.Count,
      AScenario + ' should not execute git CLI');

    LowerErr := LowerCase(Result.ErrorMessage);
    AssertTrue(
      ((APullError <> '') and (Pos(APullError, Result.ErrorMessage) > 0)) or
      (Pos('fast-forward', LowerErr) > 0) or
      (Pos('manual', LowerErr) > 0) or
      (Pos('reconcile', LowerErr) > 0),
      AScenario + ' should return actionable error text'
    );
  finally
    LocalBuilder.Free;
  end;
end;

procedure Test_UpdateSources_NeedsMergeFailsFastForwardOnly;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - NeedsMerge fails fast-forward-only');
  WriteLn('==================================================');

  AssertUpdateSourcesFastForwardOnly(
    'Needs merge',
    gpffNeedsMerge,
    'Branches diverged; reconcile manually before retrying.'
  );
end;

procedure Test_UpdateSources_DetachedHeadFailsFastForwardOnly;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - Detached head fails fast-forward-only');
  WriteLn('==================================================');

  AssertUpdateSourcesFastForwardOnly(
    'Detached head',
    gpffDetachedHead,
    'Repository is in detached HEAD state; switch to a branch before updating.'
  );
end;

procedure Test_UpdateSources_DirtyFailsFastForwardOnly;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - Dirty worktree fails fast-forward-only');
  WriteLn('==================================================');

  AssertUpdateSourcesFastForwardOnly(
    'Dirty worktree',
    gpffDirty,
    'Working tree has local changes; commit or stash them before updating.'
  );
end;

{ Test: UpdateSources fails when directory is not a git repo }
procedure Test_UpdateSources_NotGitRepo;
var
  Result: TOperationResult;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - Not Git Repo');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';

  // Setup mock: source directory exists but no .git
  MockFileSystem.AddDirectory(SourceDir);
  // .git directory NOT added

  Result := Builder.UpdateSources('3.2.2');

  AssertFalse(Result.Success, 'UpdateSources should fail when not a git repo');
  AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode), 'ErrorCode should be ecFileSystemError');
  AssertTrue(Pos('not a git repository', Result.ErrorMessage) > 0, 'Error message should mention not a git repo');
end;

procedure Test_UpdateSources_UsesSameProcessInstallRootFallback;
var
  Result: TOperationResult;
  Settings: TFPDevSettings;
  ProbeHome: string;
  ExpectedSourceDir: string;
  SavedInstallRoot: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
  {$IFDEF MSWINDOWS}
  SavedUserProfile: string;
  SavedAppData: string;
  {$ELSE}
  SavedHome: string;
  {$ENDIF}
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - Same-Process Install Root Fallback');
  WriteLn('==================================================');

  ResetMocks;
  ProbeHome := BuildTempRoot('test_builder_update_home_');
  ForceDirectories(ProbeHome);

  Settings := ConfigManager.GetSettings;
  SavedInstallRoot := Settings.InstallRoot;
  Settings.InstallRoot := '';
  ConfigManager.SetSettings(Settings);

  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  {$IFDEF MSWINDOWS}
  SavedUserProfile := get_env('USERPROFILE');
  SavedAppData := get_env('APPDATA');
  {$ELSE}
  SavedHome := get_env('HOME');
  {$ENDIF}
  try
    SetPortableMode(False);
    unset_env('FPDEV_DATA_ROOT');
    unset_env('XDG_DATA_HOME');
    {$IFDEF MSWINDOWS}
    set_env('USERPROFILE', ProbeHome);
    set_env('APPDATA', ProbeHome);
    {$ELSE}
    set_env('HOME', ProbeHome);
    {$ENDIF}

    ExpectedSourceDir := BuildFPCSourceInstallPathCore(GetDataRoot, '3.2.2');
    MockFileSystem.AddDirectory(ExpectedSourceDir);

    Result := Builder.UpdateSources('3.2.2');

    AssertFalse(Result.Success,
      'UpdateSources should fail cleanly when same-process fallback source dir lacks .git');
    AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode),
      'Same-process fallback should still return ecFileSystemError');
    AssertTrue(
      Pos('not a git repository: ' + ExpectedSourceDir, Result.ErrorMessage) > 0,
      'UpdateSources should report same-process fallback source dir'
    );
  finally
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := SavedInstallRoot;
    ConfigManager.SetSettings(Settings);
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    {$IFDEF MSWINDOWS}
    RestoreEnv('USERPROFILE', SavedUserProfile);
    RestoreEnv('APPDATA', SavedAppData);
    {$ELSE}
    RestoreEnv('HOME', SavedHome);
    {$ENDIF}
    CleanupTempDir(ProbeHome);
  end;
end;

procedure Test_UpdateSources_UsesFPDEVDataRootOverride;
var
  Result: TOperationResult;
  Settings: TFPDevSettings;
  ProbeRoot: string;
  ExpectedSourceDir: string;
  SavedInstallRoot: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: UpdateSources - FPDEV_DATA_ROOT Override');
  WriteLn('==================================================');

  ResetMocks;
  ProbeRoot := BuildTempRoot('test_builder_update_data_root_');
  ForceDirectories(ProbeRoot);

  Settings := ConfigManager.GetSettings;
  SavedInstallRoot := Settings.InstallRoot;
  Settings.InstallRoot := '';
  ConfigManager.SetSettings(Settings);

  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  try
    SetPortableMode(False);
    unset_env('XDG_DATA_HOME');
    set_env('FPDEV_DATA_ROOT', ProbeRoot);

    ExpectedSourceDir := BuildFPCSourceInstallPathCore(GetDataRoot, '3.2.2');
    MockFileSystem.AddDirectory(ExpectedSourceDir);

    Result := Builder.UpdateSources('3.2.2');

    AssertFalse(Result.Success,
      'UpdateSources should fail cleanly when FPDEV_DATA_ROOT source dir lacks .git');
    AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode),
      'FPDEV_DATA_ROOT override should still return ecFileSystemError');
    AssertTrue(
      Pos('not a git repository: ' + ExpectedSourceDir, Result.ErrorMessage) > 0,
      'UpdateSources should report FPDEV_DATA_ROOT source dir'
    );
  finally
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := SavedInstallRoot;
    ConfigManager.SetSettings(Settings);
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    CleanupTempDir(ProbeRoot);
  end;
end;

{ Test: CleanSources succeeds }
procedure Test_CleanSources_Success;
var
  Result: TOperationResult;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources - Success');
  WriteLn('==================================================');

  ResetMocks;
  SourceDir := TestInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';

  // Setup mock: source directory exists
  MockFileSystem.AddDirectory(SourceDir);

  Result := Builder.CleanSources('3.2.2');

  AssertTrue(Result.Success, 'CleanSources should succeed');
  AssertEquals(Ord(ecNone), Ord(Result.ErrorCode), 'ErrorCode should be ecNone');
end;

{ Test: CleanSources fails when directory does not exist }
procedure Test_CleanSources_DirNotExist;
var
  Result: TOperationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources - Dir Not Exist');
  WriteLn('==================================================');

  ResetMocks;
  // Source directory does not exist (not added to mock)

  Result := Builder.CleanSources('nonexistent');

  AssertFalse(Result.Success, 'CleanSources should fail when directory does not exist');
  AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode), 'ErrorCode should be ecFileSystemError');
  AssertTrue(Pos('does not exist', Result.ErrorMessage) > 0, 'Error message should mention directory not exist');
end;

procedure Test_CleanSources_UsesSameProcessInstallRootFallback;
var
  Result: TOperationResult;
  Settings: TFPDevSettings;
  ProbeHome: string;
  ExpectedSourceDir: string;
  SavedInstallRoot: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
  {$IFDEF MSWINDOWS}
  SavedUserProfile: string;
  SavedAppData: string;
  {$ELSE}
  SavedHome: string;
  {$ENDIF}
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources - Same-Process Install Root Fallback');
  WriteLn('==================================================');

  ResetMocks;
  ProbeHome := BuildTempRoot('test_builder_clean_home_');
  ForceDirectories(ProbeHome);

  Settings := ConfigManager.GetSettings;
  SavedInstallRoot := Settings.InstallRoot;
  Settings.InstallRoot := '';
  ConfigManager.SetSettings(Settings);

  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  {$IFDEF MSWINDOWS}
  SavedUserProfile := get_env('USERPROFILE');
  SavedAppData := get_env('APPDATA');
  {$ELSE}
  SavedHome := get_env('HOME');
  {$ENDIF}
  try
    SetPortableMode(False);
    unset_env('FPDEV_DATA_ROOT');
    unset_env('XDG_DATA_HOME');
    {$IFDEF MSWINDOWS}
    set_env('USERPROFILE', ProbeHome);
    set_env('APPDATA', ProbeHome);
    {$ELSE}
    set_env('HOME', ProbeHome);
    {$ENDIF}

    ExpectedSourceDir := BuildFPCSourceInstallPathCore(GetDataRoot, '3.2.2');
    Result := Builder.CleanSources('3.2.2');

    AssertFalse(Result.Success,
      'CleanSources should fail cleanly when same-process fallback source dir is missing');
    AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode),
      'Same-process fallback missing source dir should return ecFileSystemError');
    AssertTrue(
      Pos('Source directory does not exist: ' + ExpectedSourceDir, Result.ErrorMessage) > 0,
      'CleanSources should report same-process fallback source dir'
    );
  finally
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := SavedInstallRoot;
    ConfigManager.SetSettings(Settings);
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    {$IFDEF MSWINDOWS}
    RestoreEnv('USERPROFILE', SavedUserProfile);
    RestoreEnv('APPDATA', SavedAppData);
    {$ELSE}
    RestoreEnv('HOME', SavedHome);
    {$ENDIF}
    CleanupTempDir(ProbeHome);
  end;
end;

procedure Test_CleanSources_UsesFPDEVDataRootOverride;
var
  Result: TOperationResult;
  Settings: TFPDevSettings;
  ProbeRoot: string;
  ExpectedSourceDir: string;
  SavedInstallRoot: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: CleanSources - FPDEV_DATA_ROOT Override');
  WriteLn('==================================================');

  ResetMocks;
  ProbeRoot := BuildTempRoot('test_builder_clean_data_root_');
  ForceDirectories(ProbeRoot);

  Settings := ConfigManager.GetSettings;
  SavedInstallRoot := Settings.InstallRoot;
  Settings.InstallRoot := '';
  ConfigManager.SetSettings(Settings);

  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  try
    SetPortableMode(False);
    unset_env('XDG_DATA_HOME');
    set_env('FPDEV_DATA_ROOT', ProbeRoot);

    ExpectedSourceDir := BuildFPCSourceInstallPathCore(GetDataRoot, '3.2.2');
    Result := Builder.CleanSources('3.2.2');

    AssertFalse(Result.Success,
      'CleanSources should fail cleanly when FPDEV_DATA_ROOT source dir is missing');
    AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode),
      'FPDEV_DATA_ROOT missing source dir should return ecFileSystemError');
    AssertTrue(
      Pos('Source directory does not exist: ' + ExpectedSourceDir, Result.ErrorMessage) > 0,
      'CleanSources should report FPDEV_DATA_ROOT source dir'
    );
  finally
    Settings := ConfigManager.GetSettings;
    Settings.InstallRoot := SavedInstallRoot;
    ConfigManager.SetSettings(Settings);
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    CleanupTempDir(ProbeRoot);
  end;
end;

{ Test: Builder uses injected dependencies }
procedure Test_Builder_UsesDependencies;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Builder uses injected dependencies');
  WriteLn('==================================================');

  AssertTrue(Builder.VersionManager = VersionManager, 'Builder should use provided VersionManager');
  AssertTrue(Builder.ConfigManager = ConfigManager, 'Builder should use provided ConfigManager');
  AssertTrue(Builder.FileSystem = IFileSystem(MockFileSystem), 'Builder should use provided FileSystem');
  AssertTrue(Builder.ProcessRunner = IProcessRunner(MockProcessRunner), 'Builder should use provided ProcessRunner');
end;

{ Test: Error codes are correct }
procedure Test_ErrorCodes;
var
  Result: TOperationResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test: Error codes are correct');
  WriteLn('==================================================');

  ResetMocks;

  // Test ecVersionNotFound
  Result := Builder.DownloadSource('invalid_version_xyz', '/tmp/test');
  AssertEquals(Ord(ecVersionNotFound), Ord(Result.ErrorCode), 'Invalid version should return ecVersionNotFound');

  // Test ecBuildFailed for missing source
  Result := Builder.BuildFromSource('/nonexistent/path', '/tmp/install');
  AssertEquals(Ord(ecBuildFailed), Ord(Result.ErrorCode), 'Missing source should return ecBuildFailed');

  // Test ecFileSystemError for missing source in CleanSources
  Result := Builder.CleanSources('nonexistent_version');
  AssertEquals(Ord(ecFileSystemError), Ord(Result.ErrorCode), 'Missing source in CleanSources should return ecFileSystemError');
end;

begin
  WriteLn('========================================');
  WriteLn('  TFPCBuilder Unit Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    // Initialize config manager
    TestInstallRoot := BuildTempRoot('test_builder_root_');
    ForceDirectories(TestInstallRoot);
    ConfigManager := TFPDevConfigManager.Create(IncludeTrailingPathDelimiter(TestInstallRoot) + 'config.json');
    try
      if not ConfigManager.LoadConfig then
        ConfigManager.CreateDefaultConfig;

      // Setup test environment
      SetupTestEnvironment;
      try
        TestTempPathsUseSystemTempRoot;
        // Create version manager
        VersionManager := TFPCVersionManager.Create(ConfigManager.AsConfigManager);
        try
          // Create mock dependencies
          MockFileSystem := TMockFileSystem.Create;
          MockProcessRunner := TMockProcessRunner.Create;
          MockGitManager := TMockGitManager.Create;

          // Create builder with mock dependencies
          Builder := TFPCBuilder.Create(VersionManager, ConfigManager,
            MockFileSystem, MockProcessRunner, MockGitManager as IGitManager);
          try
            // Run tests
            Test_DownloadSource_PrefersLibgit2;
            Test_DownloadSource_UsesRegistryRepository_Libgit2;
            Test_DownloadSource_EmptyRegistryFallsBackToStaticCatalog_Libgit2;
            Test_DownloadSource_Success;
            Test_DownloadSource_CliFallbackUsesInjectedRunner;
            Test_DownloadSource_CliFallbackUsesRegistryRepository;
            Test_DownloadSource_EmptyRegistryCliFallbackUsesStaticGitTag;
            Test_DownloadSource_InvalidVersion;
            Test_DownloadSource_GitFailed;
            Test_GetBootstrapCompilerPath_UsesSameProcessUserHome;
            Test_GetBootstrapCompilerPath_UsesFPDEVDataRootOverride;
            Test_GetRequiredBootstrapVersion_UsesFPDEVDataRootInstallRoot;
            Test_BuildFromSource_Success;
            Test_BuildFromSource_SourceNotExist;
            Test_BuildFromSource_MakeFailed;
            Test_UpdateSources_PrefersLibgit2;
            Test_UpdateSources_Success;
            Test_UpdateSources_NeedsMergeFailsFastForwardOnly;
            Test_UpdateSources_DetachedHeadFailsFastForwardOnly;
            Test_UpdateSources_DirtyFailsFastForwardOnly;
            Test_UpdateSources_NotGitRepo;
            Test_UpdateSources_UsesSameProcessInstallRootFallback;
            Test_UpdateSources_UsesFPDEVDataRootOverride;
            Test_CleanSources_Success;
            Test_CleanSources_DirNotExist;
            Test_CleanSources_UsesSameProcessInstallRootFallback;
            Test_CleanSources_UsesFPDEVDataRootOverride;
            Test_Builder_UsesDependencies;
            Test_ErrorCodes;

            // Summary
            WriteLn;
            WriteLn('========================================');
            WriteLn('  Test Summary');
            WriteLn('========================================');
            WriteLn('  Passed: ', TestsPassed);
            WriteLn('  Failed: ', TestsFailed);
            WriteLn('  Total:  ', TestsPassed + TestsFailed);
            WriteLn;

            if TestsFailed > 0 then
            begin
              WriteLn('  SOME TESTS FAILED');
              ExitCode := 1;
            end
            else
            begin
              WriteLn('  ALL TESTS PASSED');
              ExitCode := 0;
            end;

          finally
            Builder.Free;
            // Note: MockFileSystem and MockProcessRunner are freed by Builder
            // since they are interface references
          end;
        finally
          VersionManager.Free;
        end;
      finally
        TeardownTestEnvironment;
      end;
    finally
      ConfigManager.Free;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite failed with exception');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
