program test_fpc_source_repo;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Process,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.git.runtime, fpdev.git.types,
  fpdev.source.repo, fpdev.fpc.source, fpdev.version.registry,
  fpdev.utils.process,
  test_temp_paths;

var
  TestRootDir: string;
  TestsPassed: Integer;
  TestsFailed: Integer;

type
  TProbeGitRuntime = class(TInterfacedObject, IGitRuntime)
  public
    CloneOk: Boolean;
    CheckoutOk: Boolean;
    BackendOk: Boolean;
    PullFFOk: Boolean;
    LastCloneURL: string;
    LastClonePath: string;
    LastCloneBranch: string;
    CheckoutCalls: Integer;
    LastCheckoutBranch: string;
    AutoCreateSourceTree: Boolean;
    constructor Create;
    function GetBackend: TGitBackend;
    function BackendAvailable: Boolean;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Fetch(const ARepoPath: string; const ARemote: string = 'origin'): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const ARepoPath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function PullWithMerge(const ARepoPath: string): Boolean;
    function PullFastForwardOnly(const ARepoPath: string): Boolean;
    function GetLastError: string;
    function GetRemoteURL(const ARepoPath: string; const ARemote: string = 'origin'): string;
    function GetCurrentBranch(const ARepoPath: string): string;
    function GetShortHeadHash(const ARepoPath: string; const ALength: Integer = 7): string;
    function ListBranches(const ARepoPath: string): TStringArray;
    function Add(const ARepoPath, APathSpec: string): Boolean;
    function Commit(const ARepoPath, AMessage: string): Boolean;
    function Push(const ARepoPath: string; const ARemote: string = 'origin'; const ABranch: string = ''): Boolean;
    function GetVersion: string;
  end;

  TTestSourceRepoManager = class(TSourceRepoManager)
  public
    ProbeGitRuntime: IGitRuntime;
  protected
    function CreateGitRuntime: IGitRuntime; override;
  end;

  TTestFPCSourceManager = class(TFPCSourceManager)
  public
    function RunGetVersionFromBranch(const ABranch: string): string;
    function RunBuildFPCCompiler(const AVersion: string): Boolean;
    function RunBuildFPCRTL(const AVersion: string): Boolean;
    function RunBuildFPCPackages(const AVersion: string): Boolean;
  end;

constructor TProbeGitRuntime.Create;
begin
  inherited Create;
  CloneOk := True;
  CheckoutOk := True;
  BackendOk := True;
  PullFFOk := True;
  LastCloneURL := '';
  LastClonePath := '';
  LastCloneBranch := '';
  CheckoutCalls := 0;
  LastCheckoutBranch := '';
  AutoCreateSourceTree := False;
end;

function TProbeGitRuntime.GetBackend: TGitBackend;
begin
  if BackendOk then Result := gbLibgit2 else Result := gbNone;
end;

function TProbeGitRuntime.BackendAvailable: Boolean;
begin
  Result := BackendOk;
end;

function TProbeGitRuntime.Clone(const AURL, ALocalPath: string; const ABranch: string): Boolean;
begin
  LastCloneURL := AURL;
  LastClonePath := ALocalPath;
  LastCloneBranch := ABranch;
  Result := CloneOk;
  if Result and AutoCreateSourceTree then
  begin
    ForceDirectories(ALocalPath + PathDelim + 'compiler');
    ForceDirectories(ALocalPath + PathDelim + 'rtl');
    with TStringList.Create do
    try
      Add('all:');
      Add(#9 + '@true');
      SaveToFile(ALocalPath + PathDelim + 'Makefile');
    finally
      Free;
    end;
  end;
end;

function TProbeGitRuntime.Fetch(const ARepoPath: string; const ARemote: string): Boolean;
begin
  if ARepoPath <> '' then;
  if ARemote <> '' then;
  Result := True;
end;

function TProbeGitRuntime.Checkout(const ARepoPath, AName: string; const Force: Boolean): Boolean;
begin
  if ARepoPath <> '' then;
  Inc(CheckoutCalls);
  LastCheckoutBranch := AName;
  Result := CheckoutOk;
end;

function TProbeGitRuntime.IsRepository(const APath: string): Boolean;
begin
  if APath <> '' then;
  Result := True;
end;

function TProbeGitRuntime.HasRemote(const ARepoPath: string): Boolean;
begin
  if ARepoPath <> '' then;
  Result := True;
end;

function TProbeGitRuntime.Pull(const ARepoPath: string): Boolean;
begin
  if ARepoPath <> '' then;
  Result := PullFFOk;
end;

function TProbeGitRuntime.PullWithMerge(const ARepoPath: string): Boolean;
begin
  if ARepoPath <> '' then;
  Result := PullFFOk;
end;

function TProbeGitRuntime.PullFastForwardOnly(const ARepoPath: string): Boolean;
begin
  if ARepoPath <> '' then;
  Result := PullFFOk;
end;

function TProbeGitRuntime.GetLastError: string;
begin
  Result := '';
end;

function TProbeGitRuntime.GetRemoteURL(const ARepoPath: string; const ARemote: string): string;
begin
  if ARepoPath <> '' then;
  if ARemote <> '' then;
  Result := '';
end;

function TProbeGitRuntime.GetCurrentBranch(const ARepoPath: string): string;
begin
  if ARepoPath <> '' then;
  Result := LastCheckoutBranch;
end;

function TProbeGitRuntime.GetShortHeadHash(const ARepoPath: string; const ALength: Integer): string;
begin
  if ARepoPath <> '' then;
  if ALength > 0 then;
  Result := 'abc1234';
end;

function TProbeGitRuntime.ListBranches(const ARepoPath: string): TStringArray;
begin
  if ARepoPath <> '' then;
  Result := nil;
end;

function TProbeGitRuntime.Add(const ARepoPath, APathSpec: string): Boolean;
begin
  if ARepoPath <> '' then;
  if APathSpec <> '' then;
  Result := True;
end;

function TProbeGitRuntime.Commit(const ARepoPath, AMessage: string): Boolean;
begin
  if ARepoPath <> '' then;
  if AMessage <> '' then;
  Result := True;
end;

function TProbeGitRuntime.Push(const ARepoPath: string; const ARemote: string; const ABranch: string): Boolean;
begin
  if ARepoPath <> '' then;
  if ARemote <> '' then;
  if ABranch <> '' then;
  Result := True;
end;

function TProbeGitRuntime.GetVersion: string;
begin
  Result := 'probe';
end;

function TTestSourceRepoManager.CreateGitRuntime: IGitRuntime;
begin
  Result := ProbeGitRuntime;
end;

function TTestFPCSourceManager.RunGetVersionFromBranch(const ABranch: string): string;
begin
  Result := ProtectedGetVersionFromBranch(ABranch);
end;

function TTestFPCSourceManager.RunBuildFPCCompiler(const AVersion: string): Boolean;
begin
  Result := ProtectedBuildFPCCompiler(AVersion);
end;

function TTestFPCSourceManager.RunBuildFPCRTL(const AVersion: string): Boolean;
begin
  Result := ProtectedBuildFPCRTL(AVersion);
end;

function TTestFPCSourceManager.RunBuildFPCPackages(const AVersion: string): Boolean;
begin
  Result := ProtectedBuildFPCPackages(AVersion);
end;

procedure InitTestEnvironment;
begin
  TestRootDir := CreateUniqueTempDir('test_fpc_source_repo');
  if not PathUsesSystemTempRoot(TestRootDir) then
    raise Exception.Create('Test root dir should use system temp root');
  TestsPassed := 0;
  TestsFailed := 0;
end;

procedure CleanupTestEnvironment;
begin
  CleanupTempDir(TestRootDir);
  WriteLn;
  WriteLn('========================================');
  WriteLn('  Test Results: ', TestsPassed, ' passed, ', TestsFailed, ' failed');
  WriteLn('========================================');
end;

procedure AssertTrue(const Condition: Boolean; const TestName, Message: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    WriteLn('  ', Message);
    Inc(TestsFailed);
  end;
end;

procedure AssertFalse(const Condition: Boolean; const TestName, Message: string);
begin
  AssertTrue(not Condition, TestName, Message);
end;

procedure MakeExecutable(const APath: string);
begin
  {$IFDEF UNIX}
  if fpchmod(APath, &755) <> 0 then
    raise Exception.Create('Failed to mark executable: ' + APath);
  {$ENDIF}
end;

function GetMockCompilerExecutableName: string;
begin
  {$IFDEF MSWINDOWS}
  Result := 'ppcx64.exe';
  {$ELSE}
  Result := 'ppcx64';
  {$ENDIF}
end;

procedure WriteMockVersionExecutable(const APath, AReportedVersion: string);
begin
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    Add('printf "%s\n" "' + AReportedVersion + '"');
    SaveToFile(APath);
  finally
    Free;
  end;
  MakeExecutable(APath);
end;

procedure WriteMockDriverExecutable(const APath: string);
begin
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    Add('echo "raw source fpc"');
    SaveToFile(APath);
  finally
    Free;
  end;
  MakeExecutable(APath);
end;

function ArrayContainsValue(const AItems: array of string; const AValue: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(AItems) to High(AItems) do
  begin
    if SameText(AItems[i], AValue) then
      Exit(True);
  end;
end;

procedure CreateMinimalFPCBuildTree(const ASourceDir: string; AIncludeStructure: Boolean);
begin
  ForceDirectories(ASourceDir);
  if AIncludeStructure then
  begin
    ForceDirectories(ASourceDir + PathDelim + 'compiler');
    ForceDirectories(ASourceDir + PathDelim + 'rtl');
  end;

  with TStringList.Create do
  try
    Add('clean:');
    Add(#9 + '@true');
    Add('all:');
    Add(#9 + '@true');
    Add('compiler:');
    Add(#9 + '@true');
      Add('rtl:');
      Add(#9 + '@true');
      Add('packages:');
      Add(#9 + '@true');
      SaveToFile(ASourceDir + PathDelim + 'Makefile');
  finally
    Free;
  end;
end;

procedure CreateCachedFPCInstallTree(const ASourceDir, AVersion: string;
  AIncludeInstallTarget: Boolean);
var
  MockInstallRoot: string;
begin
  ForceDirectories(ASourceDir + PathDelim + 'compiler');
  ForceDirectories(ASourceDir + PathDelim + 'rtl');

  MockInstallRoot := ASourceDir + PathDelim + 'mock-install';
  if AIncludeInstallTarget then
  begin
    ForceDirectories(MockInstallRoot + PathDelim + 'bin');
    ForceDirectories(MockInstallRoot + PathDelim + 'lib' + PathDelim + 'fpc' +
      PathDelim + AVersion);
    WriteMockDriverExecutable(MockInstallRoot + PathDelim + 'bin' + PathDelim + 'fpc');
    WriteMockVersionExecutable(MockInstallRoot + PathDelim + 'lib' + PathDelim +
      'fpc' + PathDelim + AVersion + PathDelim + GetMockCompilerExecutableName,
      AVersion);
  end;

  with TStringList.Create do
  try
    Add('clean:');
    Add(#9 + '@true');
    Add('compiler:');
    Add(#9 + '@true');
    Add('rtl:');
    Add(#9 + '@true');
    Add('packages:');
    Add(#9 + '@true');
    if AIncludeInstallTarget then
    begin
      Add('install:');
      Add(#9 + 'mkdir -p "$(DESTDIR)/bin" "$(DESTDIR)/lib/fpc/' + AVersion + '"');
      Add(#9 + 'cp "' + MockInstallRoot + '/bin/fpc" "$(DESTDIR)/bin/fpc"');
      Add(#9 + 'cp "' + MockInstallRoot + '/lib/fpc/' + AVersion + '/' +
        GetMockCompilerExecutableName + '" "$(DESTDIR)/lib/fpc/' + AVersion +
        '/' + GetMockCompilerExecutableName + '"');
    end;
    SaveToFile(ASourceDir + PathDelim + 'Makefile');
  finally
    Free;
  end;

  with TStringList.Create do
  try
    Add('cached compiler');
    SaveToFile(ASourceDir + PathDelim + 'compiler' + PathDelim +
      GetMockCompilerExecutableName);
  finally
    Free;
  end;
end;

procedure CreateBuildCacheMarker(const ACachePath, AVersion: string);
begin
  ForceDirectories(ExtractFileDir(ACachePath));
  with TStringList.Create do
  try
    Add('version=' + AVersion);
    Add('built_at=test');
    SaveToFile(ACachePath);
  finally
    Free;
  end;
end;

procedure PrepareCachedFPCInstallFixture(AManager: TFPCSourceManager;
  const AVersion: string; AIncludeInstallTarget: Boolean);
var
  BootstrapVersion: string;
  BootstrapPath: string;
begin
  CreateCachedFPCInstallTree(AManager.GetFPCSourcePath(AVersion), AVersion,
    AIncludeInstallTarget);
  CreateBuildCacheMarker(
    AManager.SourceRoot + PathDelim + 'cache' + PathDelim + 'fpc-' + AVersion + '.cache',
    AVersion
  );

  BootstrapVersion := AManager.GetRequiredBootstrapVersion(AVersion);
  BootstrapPath := AManager.GetBootstrapPath(BootstrapVersion);
  ForceDirectories(ExtractFileDir(BootstrapPath));
  WriteMockVersionExecutable(BootstrapPath, BootstrapVersion);
end;

function RunCommandInDir(const AProgram: string; const AArgs: array of string;
  const AWorkingDir: string): Boolean;
var
  Proc: TProcess;
  i: Integer;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AProgram;
    for i := Low(AArgs) to High(AArgs) do
      Proc.Parameters.Add(AArgs[i]);
    Proc.CurrentDirectory := AWorkingDir;
    Proc.Options := Proc.Options + [poWaitOnExit, poUsePipes];
    try
      Proc.Execute;
      Result := Proc.ExitStatus = 0;
    except
      Result := False;
    end;
  finally
    Proc.Free;
  end;
end;

procedure TestCloneFPCSourceUsesRegistryRepositoryAndGitTag;
var
  Manager: TTestSourceRepoManager;
  ProbeRuntime: TProbeGitRuntime;
  Success: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomRepoURL: string;
  ExpectedSourcePath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: CloneFPCSource Uses Registry Repository And Git Tag');
  WriteLn('==================================================');

  CustomRepoURL := 'https://mirror.example.invalid/fpc-source.git';
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-repo.json';

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

  Manager := TTestSourceRepoManager.Create(TestRootDir + PathDelim + 'fpc-sources');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom FPC source registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    ProbeRuntime := TProbeGitRuntime.Create;
    ProbeRuntime.AutoCreateSourceTree := True;
    Manager.ProbeGitRuntime := ProbeRuntime;
    ExpectedSourcePath := TestRootDir + PathDelim + 'fpc-sources' + PathDelim + 'fpc-3.2.2';

    Success := Manager.CloneFPCSource('3.2.2');

    AssertTrue(Success, 'CloneFPCSource succeeds with injected git runtime',
      'Expected CloneFPCSource to succeed through injected git runtime');
    AssertTrue(ProbeRuntime.LastCloneURL = CustomRepoURL,
      'CloneFPCSource uses repository URL from version registry',
      'Expected URL "' + CustomRepoURL + '", got "' + ProbeRuntime.LastCloneURL + '"');
    AssertTrue(ProbeRuntime.LastClonePath = ExpectedSourcePath,
      'CloneFPCSource clones into version-specific source path',
      'Expected path "' + ExpectedSourcePath + '", got "' + ProbeRuntime.LastClonePath + '"');
    AssertTrue(ProbeRuntime.LastCloneBranch = 'custom_release_3_2_2',
      'CloneFPCSource clones with git tag from version registry',
      'Expected clone branch "custom_release_3_2_2", got "' + ProbeRuntime.LastCloneBranch + '"');
    AssertTrue(ProbeRuntime.CheckoutCalls = 0,
      'CloneFPCSource does not call separate checkout after atomic clone',
      'Expected 0 checkout calls after atomic clone, got ' + IntToStr(ProbeRuntime.CheckoutCalls));
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestCloneFPCSourceFallsBackToStaticGitTagWhenRegistryEmpty;
var
  Manager: TTestSourceRepoManager;
  ProbeRuntime: TProbeGitRuntime;
  Success: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: CloneFPCSource Falls Back To Static Git Tag When Registry Empty');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-empty-registry.json';

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

  Manager := TTestSourceRepoManager.Create(TestRootDir + PathDelim + 'fpc-sources-empty-registry');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Empty FPC source registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    ProbeRuntime := TProbeGitRuntime.Create;
    ProbeRuntime.AutoCreateSourceTree := True;
    Manager.ProbeGitRuntime := ProbeRuntime;

    Success := Manager.CloneFPCSource('3.2.2');

    AssertTrue(Success, 'CloneFPCSource succeeds with static fallback ref',
      'Expected CloneFPCSource to succeed through injected git runtime');
    AssertTrue(ProbeRuntime.LastCloneBranch = 'release_3_2_2',
      'CloneFPCSource falls back to static git tag when registry has no releases',
      'Expected clone branch "release_3_2_2", got "' + ProbeRuntime.LastCloneBranch + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestCloneFPCSourceRechecksExistingGitRepoRef;
var
  Manager: TSourceRepoManager;
  Success: Boolean;
  SourceRoot: string;
  SourceDir: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  ReadmePath: string;
  ReadmeContent: TStringList;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2b: CloneFPCSource Rechecks Existing Git Repo Ref');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-existing-repo.json';
  SourceRoot := TestRootDir + PathDelim + 'fpc-existing-repo-root';
  SourceDir := SourceRoot + PathDelim + 'fpc-3.2.2';
  ReadmePath := SourceDir + PathDelim + 'README.txt';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
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

  ForceDirectories(SourceDir + PathDelim + 'compiler');
  ForceDirectories(SourceDir + PathDelim + 'rtl');
  with TStringList.Create do
  try
    Add('main source tree');
    SaveToFile(ReadmePath);
  finally
    Free;
  end;
  with TStringList.Create do
  try
    Add('all:');
    SaveToFile(SourceDir + PathDelim + 'Makefile');
  finally
    Free;
  end;
  with TStringList.Create do
  try
    Add('compiler fixture');
    SaveToFile(SourceDir + PathDelim + 'compiler' + PathDelim + 'fixture.txt');
    Add('rtl fixture');
    SaveToFile(SourceDir + PathDelim + 'rtl' + PathDelim + 'fixture.txt');
  finally
    Free;
  end;

  AssertTrue(RunCommandInDir('git', ['init'], SourceDir),
    'Existing repo initializes for clone recheck test',
    'Expected git init to succeed in ' + SourceDir);
  AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], SourceDir),
    'Existing repo configures git email for clone recheck test',
    'Expected git config user.email to succeed');
  AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], SourceDir),
    'Existing repo configures git user for clone recheck test',
    'Expected git config user.name to succeed');
  AssertTrue(RunCommandInDir('git', ['add', 'README.txt', 'Makefile', 'compiler/fixture.txt',
    'rtl/fixture.txt'], SourceDir),
    'Existing repo stages valid source tree for clone recheck test',
    'Expected git add to succeed');
  AssertTrue(RunCommandInDir('git', ['commit', '-m', 'main tree'], SourceDir),
    'Existing repo creates main commit for clone recheck test',
    'Expected initial git commit to succeed');
  AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], SourceDir),
    'Existing repo renames default branch to main for clone recheck test',
    'Expected git branch -M main to succeed');
  AssertTrue(RunCommandInDir('git', ['checkout', '-b', 'custom_release_3_2_2'], SourceDir),
    'Existing repo creates requested ref branch for clone recheck test',
    'Expected git checkout -b custom_release_3_2_2 to succeed');
  with TStringList.Create do
  try
    Add('release source tree');
    SaveToFile(ReadmePath);
  finally
    Free;
  end;
  AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], SourceDir),
    'Existing repo stages release content for clone recheck test',
    'Expected git add README.txt to succeed');
  AssertTrue(RunCommandInDir('git', ['commit', '-m', 'release tree'], SourceDir),
    'Existing repo creates requested-ref commit for clone recheck test',
    'Expected release git commit to succeed');
  AssertTrue(RunCommandInDir('git', ['checkout', 'main'], SourceDir),
    'Existing repo returns to wrong ref before clone recheck test',
    'Expected git checkout main to succeed');

  Manager := TSourceRepoManager.Create(SourceRoot);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Existing-repo clone registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Success := Manager.CloneFPCSource('3.2.2');

    AssertTrue(Success,
      'CloneFPCSource accepts existing valid git source tree',
      'Expected CloneFPCSource(3.2.2) to succeed for an existing valid repo');

    ReadmeContent := TStringList.Create;
    try
      ReadmeContent.LoadFromFile(ReadmePath);
      AssertTrue((ReadmeContent.Count > 0) and (Trim(ReadmeContent[0]) = 'release source tree'),
        'CloneFPCSource rechecks requested ref for existing valid git repo',
        'Expected existing repo to be switched to registry ref content before returning success');
    finally
      ReadmeContent.Free;
    end;
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerListsRegistryOnlyVersion;
var
  Manager: TFPCSourceManager;
  Versions: TStringArray;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: FPC Source Manager Lists Registry-Only Version');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-manager.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "9.9",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "9.9",');
    Add('        "release_date": "2099-09-09",');
    Add('        "git_tag": "release_9_9",');
    Add('        "branch": "fixes_9_9",');
    Add('        "channel": "stable",');
    Add('        "lts": false');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-manager');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom FPC source-manager registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Versions := Manager.ListAvailableVersions;

    AssertTrue(ArrayContainsValue(Versions, '9.9'),
      'FPC source manager lists registry-only version',
      'Expected ListAvailableVersions to contain 9.9');
    AssertTrue(Manager.IsVersionAvailable('9.9'),
      'FPC source manager recognizes registry-only version as available',
      'Expected IsVersionAvailable(9.9) to be true');
    AssertFalse(ArrayContainsValue(Versions, '3.2.2'),
      'FPC source manager excludes static-only version when registry is present',
      'Expected ListAvailableVersions to exclude static-only 3.2.2 when registry already provides releases');
    AssertFalse(Manager.IsVersionAvailable('3.2.2'),
      'FPC source manager does not report static-only version available when registry is present',
      'Expected IsVersionAvailable(3.2.2) to be false when registry omits 3.2.2');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerRejectsCloneWithoutValidSourceTree;
var
  Manager: TFPCSourceManager;
  Success: Boolean;
  SourceRoot: string;
  SourceDir: string;
  OriginDir: string;
  WorkDir: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2b: FPC Source Manager Rejects Clone Without Valid Source Tree');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-invalid-clone.json';
  SourceRoot := TestRootDir + PathDelim + 'fpc-source-invalid-clone-root';
  OriginDir := TestRootDir + PathDelim + 'fpc-invalid-clone-origin.git';
  WorkDir := TestRootDir + PathDelim + 'fpc-invalid-clone-work';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
    Add('    "repository": "' + OriginDir + '",');
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

  AssertTrue(RunCommandInDir('git', ['init', '--bare', OriginDir], TestRootDir),
    'Invalid clone setup creates bare origin repo',
    'Expected git init --bare to succeed for ' + OriginDir);

  ForceDirectories(WorkDir);
  with TStringList.Create do
  try
    Add('not an fpc source tree');
    SaveToFile(WorkDir + PathDelim + 'README.txt');
  finally
    Free;
  end;

  AssertTrue(RunCommandInDir('git', ['init'], WorkDir),
    'Invalid clone setup initializes work repo',
    'Expected git init to succeed in ' + WorkDir);
  AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
    'Invalid clone setup configures git email',
    'Expected git config user.email to succeed');
  AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
    'Invalid clone setup configures git user',
    'Expected git config user.name to succeed');
  AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], WorkDir),
    'Invalid clone setup stages file',
    'Expected git add README.txt to succeed');
  AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
    'Invalid clone setup creates initial commit',
    'Expected git commit to succeed');
  AssertTrue(RunCommandInDir('git', ['tag', 'custom_release_3_2_2'], WorkDir),
    'Invalid clone setup creates registry git tag',
    'Expected git tag custom_release_3_2_2 to succeed');
  AssertTrue(RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
    'Invalid clone setup adds origin',
    'Expected git remote add origin to succeed');
  AssertTrue(RunCommandInDir('git', ['push', 'origin', 'HEAD'], WorkDir),
    'Invalid clone setup pushes HEAD to origin',
    'Expected git push origin HEAD to succeed');
  AssertTrue(RunCommandInDir('git', ['push', 'origin', 'custom_release_3_2_2'], WorkDir),
    'Invalid clone setup pushes registry git tag to origin',
    'Expected git push origin custom_release_3_2_2 to succeed');

  Manager := TFPCSourceManager.Create(SourceRoot);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom invalid-clone registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Success := Manager.CloneFPCSource('3.2.2');
    SourceDir := Manager.GetFPCSourcePath('3.2.2');

    AssertFalse(Success,
      'FPC source manager rejects clone success without valid source tree',
      'Expected CloneFPCSource(3.2.2) to fail when cloned repo lacks compiler/rtl/Makefile');
    AssertTrue(Manager.CurrentVersion = '',
      'FPC source manager keeps current version unchanged on invalid clone',
      'Expected CurrentVersion to stay empty, got "' + Manager.CurrentVersion + '"');
    AssertFalse(Manager.IsVersionInstalled('3.2.2'),
      'FPC source manager does not treat invalid clone result as installed source tree',
      'Expected invalid cloned directory "' + SourceDir + '" to fail installed-source validation');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerResolvesRegistryGitTagToVersion;
var
  Manager: TTestFPCSourceManager;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: FPC Source Manager Resolves Registry Git Tag To Version');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-ref-registry.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
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

  Manager := TTestFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-ref-registry');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom FPC ref registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    AssertTrue(Manager.RunGetVersionFromBranch('custom_release_3_2_2') = '3.2.2',
      'FPC source manager resolves registry git tag back to version',
      'Expected git tag custom_release_3_2_2 to map to 3.2.2');
    AssertTrue(Manager.RunGetVersionFromBranch('custom_fixes_3_2') = '3.2.2',
      'FPC source manager resolves registry branch back to version',
      'Expected branch custom_fixes_3_2 to map to 3.2.2');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerKeepsStaticGitTagOpaqueWhenRegistryPresent;
var
  Manager: TTestFPCSourceManager;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: FPC Source Manager Keeps Static Git Tag Opaque When Registry Present');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-ref-authoritative.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "9.9",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "9.9",');
    Add('        "release_date": "2099-09-09",');
    Add('        "git_tag": "release_9_9",');
    Add('        "branch": "fixes_9_9",');
    Add('        "channel": "stable",');
    Add('        "lts": false');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-ref-authoritative');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Authoritative FPC ref registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    AssertTrue(Manager.RunGetVersionFromBranch('release_3_2_2') = 'release_3_2_2',
      'FPC source manager does not remap static git tag when registry already has releases',
      'Expected static git tag to remain opaque when registry omits 3.2.2');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestSwitchFPCVersionUsesRegistryRef;
var
  Manager: TSourceRepoManager;
  Success: Boolean;
  SourceRoot: string;
  SourceDir: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: SwitchFPCVersion Uses Registry Ref');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-switch.json';
  SourceRoot := TestRootDir + PathDelim + 'fpc-switch-root';
  SourceDir := SourceRoot + PathDelim + 'fpc-3.2.2';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
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

  ForceDirectories(SourceDir);
  ForceDirectories(SourceDir + PathDelim + 'compiler');
  ForceDirectories(SourceDir + PathDelim + 'rtl');
  with TStringList.Create do
  try
    Add('test');
    SaveToFile(SourceDir + PathDelim + 'README.txt');
    Add('all:');
    SaveToFile(SourceDir + PathDelim + 'Makefile');
  finally
    Free;
  end;

  AssertTrue(RunCommandInDir('git', ['init'], SourceDir),
    'Local repo initializes for switch test',
    'Expected git init to succeed in ' + SourceDir);
  AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], SourceDir),
    'Local repo configures git email for switch test',
    'Expected git config user.email to succeed');
  AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], SourceDir),
    'Local repo configures git user for switch test',
    'Expected git config user.name to succeed');
  AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], SourceDir),
    'Local repo stages file for switch test',
    'Expected git add to succeed');
  AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], SourceDir),
    'Local repo creates commit for switch test',
    'Expected git commit to succeed');
  AssertTrue(RunCommandInDir('git', ['checkout', '-b', 'custom_release_3_2_2'], SourceDir),
    'Local repo creates registry ref branch for switch test',
    'Expected git checkout -b custom_release_3_2_2 to succeed');

  Manager := TSourceRepoManager.Create(SourceRoot);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom FPC switch registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Success := Manager.SwitchFPCVersion('3.2.2');

    AssertTrue(Success,
      'SwitchFPCVersion uses registry ref instead of raw version',
      'Expected switch to succeed by checking out registry ref "custom_release_3_2_2"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestSwitchFPCVersionFallsBackToStaticGitTagWhenRegistryEmpty;
var
  Manager: TSourceRepoManager;
  Success: Boolean;
  SourceRoot: string;
  SourceDir: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: SwitchFPCVersion Falls Back To Static Git Tag When Registry Empty');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-switch-empty-registry.json';
  SourceRoot := TestRootDir + PathDelim + 'fpc-switch-empty-registry-root';
  SourceDir := SourceRoot + PathDelim + 'fpc-3.2.2';

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

  ForceDirectories(SourceDir);
  ForceDirectories(SourceDir + PathDelim + 'compiler');
  ForceDirectories(SourceDir + PathDelim + 'rtl');
  with TStringList.Create do
  try
    Add('test');
    SaveToFile(SourceDir + PathDelim + 'README.txt');
    Add('all:');
    SaveToFile(SourceDir + PathDelim + 'Makefile');
  finally
    Free;
  end;

  AssertTrue(RunCommandInDir('git', ['init'], SourceDir),
    'Local repo initializes for empty-registry switch test',
    'Expected git init to succeed in ' + SourceDir);
  AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], SourceDir),
    'Local repo configures git email for empty-registry switch test',
    'Expected git config user.email to succeed');
  AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], SourceDir),
    'Local repo configures git user for empty-registry switch test',
    'Expected git config user.name to succeed');
  AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], SourceDir),
    'Local repo stages file for empty-registry switch test',
    'Expected git add to succeed');
  AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], SourceDir),
    'Local repo creates commit for empty-registry switch test',
    'Expected git commit to succeed');
  AssertTrue(RunCommandInDir('git', ['checkout', '-b', 'release_3_2_2'], SourceDir),
    'Local repo creates static fallback ref branch for switch test',
    'Expected git checkout -b release_3_2_2 to succeed');

  Manager := TSourceRepoManager.Create(SourceRoot);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Empty FPC switch registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Success := Manager.SwitchFPCVersion('3.2.2');

    AssertTrue(Success,
      'SwitchFPCVersion falls back to static git tag when registry has no releases',
      'Expected switch to succeed by checking out static ref "release_3_2_2"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerResolvesStaticGitTagWhenRegistryEmpty;
var
  Manager: TTestFPCSourceManager;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: FPC Source Manager Resolves Static Git Tag When Registry Empty');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-ref-empty.json';

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

  Manager := TTestFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-ref-empty');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Empty FPC ref registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    AssertTrue(Manager.RunGetVersionFromBranch('release_3_2_2') = '3.2.2',
      'FPC source manager resolves static git tag when registry has no releases',
      'Expected static git tag release_3_2_2 to map to 3.2.2');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestSwitchFPCVersionRejectsNonSourceGitRepo;
var
  Manager: TSourceRepoManager;
  Success: Boolean;
  SourceRoot: string;
  SourceDir: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 7: SwitchFPCVersion Rejects Non-Source Git Repo');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-fpc-source-switch-invalid.json';
  SourceRoot := TestRootDir + PathDelim + 'fpc-switch-invalid-root';
  SourceDir := SourceRoot + PathDelim + 'fpc-3.2.2';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "fpc": {');
    Add('    "default_version": "3.2.2",');
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

  ForceDirectories(SourceDir);
  with TStringList.Create do
  try
    Add('not an fpc source tree');
    SaveToFile(SourceDir + PathDelim + 'README.txt');
  finally
    Free;
  end;

  AssertTrue(RunCommandInDir('git', ['init'], SourceDir),
    'Invalid local repo initializes for invalid switch test',
    'Expected git init to succeed in ' + SourceDir);
  AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], SourceDir),
    'Invalid local repo configures git email for invalid switch test',
    'Expected git config user.email to succeed');
  AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], SourceDir),
    'Invalid local repo configures git user for invalid switch test',
    'Expected git config user.name to succeed');
  AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], SourceDir),
    'Invalid local repo stages file for invalid switch test',
    'Expected git add to succeed');
  AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], SourceDir),
    'Invalid local repo creates commit for invalid switch test',
    'Expected git commit to succeed');
  AssertTrue(RunCommandInDir('git', ['checkout', '-b', 'custom_release_3_2_2'], SourceDir),
    'Invalid local repo creates ref for invalid switch test',
    'Expected git checkout -b custom_release_3_2_2 to succeed');

  Manager := TSourceRepoManager.Create(SourceRoot);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom invalid-switch registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Success := Manager.SwitchFPCVersion('3.2.2');

    AssertFalse(Success,
      'SwitchFPCVersion rejects non-source git repo',
      'Expected SwitchFPCVersion(3.2.2) to fail for git repo without compiler/rtl/Makefile');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerRejectsInvalidInstalledDirectory;
var
  Manager: TFPCSourceManager;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: FPC Source Manager Rejects Invalid Installed Directory');
  WriteLn('==================================================');

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-installed');
  try
    SourceDir := Manager.GetFPCSourcePath('3.2.2');
    ForceDirectories(SourceDir);

    AssertFalse(Manager.IsVersionInstalled('3.2.2'),
      'FPC source manager rejects empty directory as installed version',
      'Expected IsVersionInstalled(3.2.2) to be false for an empty source directory');
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerListsOnlyValidLocalVersions;
var
  Manager: TFPCSourceManager;
  InvalidDir: string;
  ValidDir: string;
  Versions: TStringArray;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: FPC Source Manager Lists Only Valid Local Versions');
  WriteLn('==================================================');

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-local');
  try
    InvalidDir := Manager.GetFPCSourcePath('3.2.2');
    ForceDirectories(InvalidDir);

    ValidDir := Manager.GetFPCSourcePath('main');
    ForceDirectories(ValidDir + PathDelim + 'compiler');
    ForceDirectories(ValidDir + PathDelim + 'rtl');
    with TStringList.Create do
    try
      Add('all:');
      SaveToFile(ValidDir + PathDelim + 'Makefile');
    finally
      Free;
    end;

    Versions := Manager.ListLocalVersions;

    AssertTrue(ArrayContainsValue(Versions, 'main'),
      'FPC source manager keeps valid local version in list',
      'Expected ListLocalVersions to contain main when source tree is valid');
    AssertFalse(ArrayContainsValue(Versions, '3.2.2'),
      'FPC source manager excludes invalid local version from list',
      'Expected ListLocalVersions to exclude empty fpc-3.2.2 directory');
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerRejectsNonSourceGitRepoOnUpdate;
var
  Manager: TFPCSourceManager;
  OriginDir: string;
  WorkDir: string;
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6: FPC Source Manager Rejects Non-Source Git Repo On Update');
  WriteLn('==================================================');

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-update');
  try
    OriginDir := TestRootDir + PathDelim + 'fpc-update-origin.git';
    WorkDir := TestRootDir + PathDelim + 'fpc-update-work';
    SourceDir := Manager.GetFPCSourcePath('3.2.2');

    AssertTrue(RunCommandInDir('git', ['init', '--bare', OriginDir], TestRootDir),
      'Bare origin repo initializes for update test',
      'Expected git init --bare to succeed for ' + OriginDir);

    ForceDirectories(WorkDir);
    with TStringList.Create do
    try
      Add('not an fpc source tree');
      SaveToFile(WorkDir + PathDelim + 'README.txt');
    finally
      Free;
    end;

    AssertTrue(RunCommandInDir('git', ['init'], WorkDir),
      'Working repo initializes for update test',
      'Expected git init to succeed in ' + WorkDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Working repo configures git email for update test',
      'Expected git config user.email to succeed');
    AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Working repo configures git user for update test',
      'Expected git config user.name to succeed');
    AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], WorkDir),
      'Working repo stages file for update test',
      'Expected git add to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
      'Working repo creates commit for update test',
      'Expected git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Working repo renames branch to main for update test',
      'Expected git branch -M main to succeed');
    AssertTrue(RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Working repo adds origin for update test',
      'Expected git remote add origin to succeed');
    AssertTrue(RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Working repo pushes origin for update test',
      'Expected git push -u origin main to succeed');
    AssertTrue(RunCommandInDir('git', ['clone', OriginDir, SourceDir], TestRootDir),
      'Invalid source repo clone succeeds for update test setup',
      'Expected git clone to succeed into ' + SourceDir);

    Success := Manager.UpdateFPCSource('3.2.2');

    AssertFalse(Success,
      'FPC source manager rejects non-source git repo on update',
      'Expected UpdateFPCSource(3.2.2) to fail for git repo without compiler/rtl/Makefile');
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerRefreshesWorkingTreeOnUpdate;
var
  Manager: TFPCSourceManager;
  OriginDir: string;
  WorkDir: string;
  SourceDir: string;
  ReadmePath: string;
  Success: Boolean;
  ReadmeContent: TStringList;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6b: FPC Source Manager Refreshes Working Tree On Update');
  WriteLn('==================================================');

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-update-working-tree');
  try
    OriginDir := TestRootDir + PathDelim + 'fpc-update-working-tree-origin.git';
    WorkDir := TestRootDir + PathDelim + 'fpc-update-working-tree-work';
    SourceDir := Manager.GetFPCSourcePath('main');
    ReadmePath := SourceDir + PathDelim + 'README.txt';

    AssertTrue(RunCommandInDir('git', ['init', '--bare', OriginDir], TestRootDir),
      'Bare origin repo initializes for working-tree update test',
      'Expected git init --bare to succeed for ' + OriginDir);

    ForceDirectories(WorkDir + PathDelim + 'compiler');
    ForceDirectories(WorkDir + PathDelim + 'rtl');
    with TStringList.Create do
    try
      Add('initial source tree');
      SaveToFile(WorkDir + PathDelim + 'README.txt');
    finally
      Free;
    end;
    with TStringList.Create do
    try
      Add('all:');
      SaveToFile(WorkDir + PathDelim + 'Makefile');
      Add('compiler fixture');
      SaveToFile(WorkDir + PathDelim + 'compiler' + PathDelim + 'fixture.txt');
      Add('rtl fixture');
      SaveToFile(WorkDir + PathDelim + 'rtl' + PathDelim + 'fixture.txt');
    finally
      Free;
    end;

    AssertTrue(RunCommandInDir('git', ['init'], WorkDir),
      'Working repo initializes for working-tree update test',
      'Expected git init to succeed in ' + WorkDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Working repo configures git email for working-tree update test',
      'Expected git config user.email to succeed');
    AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Working repo configures git user for working-tree update test',
      'Expected git config user.name to succeed');
    AssertTrue(RunCommandInDir('git', ['add', 'README.txt', 'Makefile', 'compiler/fixture.txt',
      'rtl/fixture.txt'], WorkDir),
      'Working repo stages valid source tree for working-tree update test',
      'Expected git add to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
      'Working repo creates initial commit for working-tree update test',
      'Expected git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Working repo renames branch to main for working-tree update test',
      'Expected git branch -M main to succeed');
    AssertTrue(RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Working repo adds origin for working-tree update test',
      'Expected git remote add origin to succeed');
    AssertTrue(RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Working repo pushes initial main for working-tree update test',
      'Expected git push -u origin main to succeed');
    AssertTrue(RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, SourceDir], TestRootDir),
      'Valid source repo clone succeeds for working-tree update test setup',
      'Expected git clone -b main to succeed into ' + SourceDir);

    with TStringList.Create do
    try
      Add('updated source tree');
      SaveToFile(WorkDir + PathDelim + 'README.txt');
    finally
      Free;
    end;
    AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], WorkDir),
      'Working repo stages updated README for working-tree update test',
      'Expected git add README.txt to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'update'], WorkDir),
      'Working repo creates update commit for working-tree update test',
      'Expected update git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['push'], WorkDir),
      'Working repo pushes update for working-tree update test',
      'Expected git push to succeed');

    Success := Manager.UpdateFPCSource('main');

    AssertTrue(Success,
      'FPC source manager reports success for valid working-tree update',
      'Expected UpdateFPCSource(main) to succeed for valid branch-based source repo');

    ReadmeContent := TStringList.Create;
    try
      ReadmeContent.LoadFromFile(ReadmePath);
      AssertTrue((ReadmeContent.Count > 0) and (Trim(ReadmeContent[0]) = 'updated source tree'),
        'FPC source manager refreshes local working tree on update',
        'Expected UpdateFPCSource(main) to update worktree content, not just fetch remote refs');
    finally
      ReadmeContent.Free;
    end;
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerTracksUpdatedVersionForEmptyArgFollowUp;
var
  Manager: TFPCSourceManager;
  OriginDir: string;
  WorkDir: string;
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6c: FPC Source Manager Tracks Updated Version For Empty-Arg Follow-Up');
  WriteLn('==================================================');

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-update-current');
  try
    OriginDir := TestRootDir + PathDelim + 'fpc-update-current-origin.git';
    WorkDir := TestRootDir + PathDelim + 'fpc-update-current-work';
    SourceDir := Manager.GetFPCSourcePath('3.2.2');

    AssertTrue(RunCommandInDir('git', ['init', '--bare', OriginDir], TestRootDir),
      'Bare origin repo initializes for current-version update test',
      'Expected git init --bare to succeed for ' + OriginDir);

    ForceDirectories(WorkDir + PathDelim + 'compiler');
    ForceDirectories(WorkDir + PathDelim + 'rtl');
    with TStringList.Create do
    try
      Add('current version update fixture');
      SaveToFile(WorkDir + PathDelim + 'README.txt');
    finally
      Free;
    end;
    with TStringList.Create do
    try
      Add('all:');
      SaveToFile(WorkDir + PathDelim + 'Makefile');
      Add('compiler fixture');
      SaveToFile(WorkDir + PathDelim + 'compiler' + PathDelim + 'fixture.txt');
      Add('rtl fixture');
      SaveToFile(WorkDir + PathDelim + 'rtl' + PathDelim + 'fixture.txt');
    finally
      Free;
    end;

    AssertTrue(RunCommandInDir('git', ['init'], WorkDir),
      'Working repo initializes for current-version update test',
      'Expected git init to succeed in ' + WorkDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Working repo configures git email for current-version update test',
      'Expected git config user.email to succeed');
    AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Working repo configures git user for current-version update test',
      'Expected git config user.name to succeed');
    AssertTrue(RunCommandInDir('git', ['add', 'README.txt', 'Makefile', 'compiler/fixture.txt',
      'rtl/fixture.txt'], WorkDir),
      'Working repo stages valid source tree for current-version update test',
      'Expected git add to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
      'Working repo creates initial commit for current-version update test',
      'Expected git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Working repo renames branch to main for current-version update test',
      'Expected git branch -M main to succeed');
    AssertTrue(RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Working repo adds origin for current-version update test',
      'Expected git remote add origin to succeed');
    AssertTrue(RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Working repo pushes initial main for current-version update test',
      'Expected git push -u origin main to succeed');
    AssertTrue(RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, SourceDir], TestRootDir),
      'Valid source repo clone succeeds for current-version update test setup',
      'Expected git clone -b main to succeed into ' + SourceDir);

    Success := Manager.UpdateFPCSource('3.2.2');

    AssertTrue(Success,
      'FPC source manager update succeeds for current-version alignment contract',
      'Expected UpdateFPCSource(3.2.2) to succeed for valid source repo');
    AssertTrue(Manager.CurrentVersion = '3.2.2',
      'FPC source manager records updated version after successful update',
      'Expected CurrentVersion to be 3.2.2 after update, got "' + Manager.CurrentVersion + '"');
    AssertTrue(Manager.GetFPCSourcePath('') = SourceDir,
      'FPC source manager empty-arg path follows updated current version',
      'Expected empty-arg source path to resolve to "' + SourceDir + '", got "' +
      Manager.GetFPCSourcePath('') + '"');
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerRejectsNonConflictingDivergedUpdate;
var
  Manager: TFPCSourceManager;
  OriginDir: string;
  WorkDir: string;
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6c: FPC Source Manager Rejects Non-Conflicting Diverged Update');
  WriteLn('==================================================');

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-update-ffonly');
  try
    OriginDir := TestRootDir + PathDelim + 'fpc-update-ffonly-origin.git';
    WorkDir := TestRootDir + PathDelim + 'fpc-update-ffonly-work';
    SourceDir := Manager.GetFPCSourcePath('main');

    AssertTrue(RunCommandInDir('git', ['init', '--bare', OriginDir], TestRootDir),
      'Bare origin repo initializes for ff-only update test',
      'Expected git init --bare to succeed for ' + OriginDir);

    ForceDirectories(WorkDir + PathDelim + 'compiler');
    ForceDirectories(WorkDir + PathDelim + 'rtl');
    with TStringList.Create do
    try
      Add('initial source tree');
      SaveToFile(WorkDir + PathDelim + 'README.txt');
      Add('all:');
      SaveToFile(WorkDir + PathDelim + 'Makefile');
      Add('compiler fixture');
      SaveToFile(WorkDir + PathDelim + 'compiler' + PathDelim + 'fixture.txt');
      Add('rtl fixture');
      SaveToFile(WorkDir + PathDelim + 'rtl' + PathDelim + 'fixture.txt');
    finally
      Free;
    end;

    AssertTrue(RunCommandInDir('git', ['init'], WorkDir),
      'Working repo initializes for ff-only update test',
      'Expected git init to succeed in ' + WorkDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Working repo configures git email for ff-only update test',
      'Expected git config user.email to succeed');
    AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Working repo configures git user for ff-only update test',
      'Expected git config user.name to succeed');
    AssertTrue(RunCommandInDir('git', ['add', 'README.txt', 'Makefile', 'compiler/fixture.txt',
      'rtl/fixture.txt'], WorkDir),
      'Working repo stages valid source tree for ff-only update test',
      'Expected git add to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
      'Working repo creates initial commit for ff-only update test',
      'Expected git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Working repo renames branch to main for ff-only update test',
      'Expected git branch -M main to succeed');
    AssertTrue(RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Working repo adds origin for ff-only update test',
      'Expected git remote add origin to succeed');
    AssertTrue(RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Working repo pushes initial main for ff-only update test',
      'Expected git push -u origin main to succeed');
    AssertTrue(RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, SourceDir], TestRootDir),
      'Valid source repo clone succeeds for ff-only update test setup',
      'Expected git clone -b main to succeed into ' + SourceDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], SourceDir),
      'Local clone configures git email for ff-only update test',
      'Expected git config user.email to succeed in ' + SourceDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], SourceDir),
      'Local clone configures git user for ff-only update test',
      'Expected git config user.name to succeed in ' + SourceDir);

    with TStringList.Create do
    try
      Add('local only');
      SaveToFile(SourceDir + PathDelim + 'local-only.txt');
    finally
      Free;
    end;
    AssertTrue(RunCommandInDir('git', ['add', 'local-only.txt'], SourceDir),
      'Local clone stages local-only file for ff-only update test',
      'Expected git add local-only.txt to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'local change'], SourceDir),
      'Local clone creates local commit for ff-only update test',
      'Expected local git commit to succeed');

    with TStringList.Create do
    try
      Add('remote only');
      SaveToFile(WorkDir + PathDelim + 'remote-only.txt');
    finally
      Free;
    end;
    AssertTrue(RunCommandInDir('git', ['add', 'remote-only.txt'], WorkDir),
      'Working repo stages remote-only file for ff-only update test',
      'Expected git add remote-only.txt to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'remote change'], WorkDir),
      'Working repo creates remote commit for ff-only update test',
      'Expected remote git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['push'], WorkDir),
      'Working repo pushes remote commit for ff-only update test',
      'Expected git push to succeed');

    Success := Manager.UpdateFPCSource('main');

    AssertFalse(Success,
      'FPC source manager rejects non-conflicting diverged update',
      'Expected UpdateFPCSource(main) to fail instead of creating an implicit merge');
    AssertTrue(FileExists(SourceDir + PathDelim + 'local-only.txt'),
      'FPC source manager keeps local-only file after ff-only rejection',
      'Expected local-only.txt to remain after rejected update');
    AssertFalse(FileExists(SourceDir + PathDelim + 'remote-only.txt'),
      'FPC source manager does not materialize remote-only file after ff-only rejection',
      'Expected remote-only.txt to be absent after rejected update');
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerRejectsInvalidDirectoryOnBuild;
var
  Manager: TFPCSourceManager;
  SourceDir: string;
  Success: Boolean;
  RaisedError: Boolean;
  ErrorMessage: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 8: FPC Source Manager Rejects Invalid Directory On Build');
  WriteLn('==================================================');

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-build');
  try
    RaisedError := False;
    ErrorMessage := '';
    SourceDir := Manager.GetFPCSourcePath('3.2.2');
    ForceDirectories(SourceDir);
    with TStringList.Create do
    try
      Add('clean:');
      Add(#9 + '@true');
      Add('all:');
      Add(#9 + '@true');
      SaveToFile(SourceDir + PathDelim + 'Makefile');
    finally
      Free;
    end;

    try
      Success := Manager.BuildFPCSource('3.2.2');
    except
      on E: Exception do
      begin
        Success := False;
        RaisedError := True;
        ErrorMessage := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertFalse(RaisedError,
      'FPC source manager fails cleanly on invalid build directory',
      'Expected BuildFPCSource(3.2.2) to return False, but it raised ' + ErrorMessage);

    AssertFalse(Success,
      'FPC source manager rejects invalid directory on build',
      'Expected BuildFPCSource(3.2.2) to fail for directory without compiler/rtl');
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerBuildsValidSourceDirectory;
var
  Manager: TFPCSourceManager;
  SourceDir: string;
  Success: Boolean;
  RaisedError: Boolean;
  ErrorMessage: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 9: FPC Source Manager Builds Valid Source Directory');
  WriteLn('==================================================');

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-build-valid');
  try
    RaisedError := False;
    ErrorMessage := '';
    SourceDir := Manager.GetFPCSourcePath('3.2.2');
    CreateMinimalFPCBuildTree(SourceDir, True);

    try
      Success := Manager.BuildFPCSource('3.2.2');
    except
      on E: Exception do
      begin
        Success := False;
        RaisedError := True;
        ErrorMessage := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertFalse(RaisedError,
      'FPC source manager builds valid source directory without raising',
      'Expected BuildFPCSource(3.2.2) to run cleanly, but it raised ' + ErrorMessage);
    AssertTrue(Success,
      'FPC source manager builds valid source directory',
      'Expected BuildFPCSource(3.2.2) to succeed for directory with compiler/rtl/Makefile');
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerRejectsInvalidDirectoryOnFollowUpBuilds;
var
  Manager: TTestFPCSourceManager;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 10: FPC Source Manager Rejects Invalid Directory On Follow-Up Builds');
  WriteLn('==================================================');

  Manager := TTestFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-followup-invalid');
  try
    SourceDir := Manager.GetFPCSourcePath('3.2.2');
    CreateMinimalFPCBuildTree(SourceDir, False);

    AssertFalse(Manager.RunBuildFPCCompiler('3.2.2'),
      'FPC source manager rejects invalid directory on compiler build',
      'Expected BuildFPCCompiler(3.2.2) to fail for directory without compiler/rtl');
    AssertFalse(Manager.RunBuildFPCRTL('3.2.2'),
      'FPC source manager rejects invalid directory on RTL build',
      'Expected BuildFPCRTL(3.2.2) to fail for directory without compiler/rtl');
    AssertFalse(Manager.RunBuildFPCPackages('3.2.2'),
      'FPC source manager rejects invalid directory on packages build',
      'Expected BuildFPCPackages(3.2.2) to fail for directory without compiler/rtl');
  finally
    Manager.Free;
  end;
end;

procedure TestFPCSourceManagerBuildsValidFollowUpTargets;
var
  Manager: TTestFPCSourceManager;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 11: FPC Source Manager Builds Valid Follow-Up Targets');
  WriteLn('==================================================');

  Manager := TTestFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-followup-valid');
  try
    SourceDir := Manager.GetFPCSourcePath('3.2.2');
    CreateMinimalFPCBuildTree(SourceDir, True);

    AssertTrue(Manager.RunBuildFPCCompiler('3.2.2'),
      'FPC source manager builds compiler target for valid source tree',
      'Expected BuildFPCCompiler(3.2.2) to succeed for valid source tree');
    AssertTrue(Manager.RunBuildFPCRTL('3.2.2'),
      'FPC source manager builds RTL target for valid source tree',
      'Expected BuildFPCRTL(3.2.2) to succeed for valid source tree');
    AssertTrue(Manager.RunBuildFPCPackages('3.2.2'),
      'FPC source manager builds packages target for valid source tree',
      'Expected BuildFPCPackages(3.2.2) to succeed for valid source tree');
  finally
    Manager.Free;
  end;
end;

procedure TestInstallFPCVersionRejectsCachedBuildWithoutInstalledArtifacts;
var
  Manager: TFPCSourceManager;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 12: InstallFPCVersion Rejects Cached Build Without Installed Artifacts');
  WriteLn('==================================================');

  {$IFNDEF UNIX}
  AssertTrue(True,
    'InstallFPCVersion cached-install failure contract skipped on non-UNIX',
    'This fixture uses POSIX shell scripts and make install commands.');
  Exit;
  {$ENDIF}

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-install-cache-fail');
  try
    PrepareCachedFPCInstallFixture(Manager, '3.2.2', False);

    Success := Manager.InstallFPCVersion('3.2.2');

    AssertFalse(Success,
      'FPC source manager rejects cached build without installed artifacts',
      'Expected InstallFPCVersion(3.2.2) to fail when cache exists but install target produces no sandbox output');
  finally
    Manager.Free;
  end;
end;

procedure TestInstallFPCVersionKeepsCurrentVersionWhenCachedInstallFails;
var
  Manager: TFPCSourceManager;
  PreviousSourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 13: InstallFPCVersion Keeps Current Version When Cached Install Fails');
  WriteLn('==================================================');

  {$IFNDEF UNIX}
  AssertTrue(True,
    'InstallFPCVersion current-version rollback contract skipped on non-UNIX',
    'This fixture uses POSIX shell scripts and make install commands.');
  Exit;
  {$ENDIF}

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-install-cache-rollback');
  try
    PreviousSourceDir := Manager.GetFPCSourcePath('main');
    CreateMinimalFPCBuildTree(PreviousSourceDir, True);
    AssertTrue(Manager.CloneFPCSource('main'),
      'FPC source manager seeds previous current version before cached install failure',
      'Expected CloneFPCSource(main) to succeed from the pre-created valid source tree');
    AssertTrue(Manager.CurrentVersion = 'main',
      'FPC source manager records seeded current version before cached install failure',
      'Expected CurrentVersion to be main after seeding the existing source tree');

    PrepareCachedFPCInstallFixture(Manager, '3.2.2', False);

    Success := Manager.InstallFPCVersion('3.2.2');

    AssertFalse(Success,
      'FPC source manager reports cached install failure before checking rollback',
      'Expected InstallFPCVersion(3.2.2) to fail when install target is missing');
    AssertTrue(Manager.CurrentVersion = 'main',
      'FPC source manager keeps current version unchanged when cached install fails',
      'Expected CurrentVersion to remain main after failed cached install, got "' +
        Manager.CurrentVersion + '"');
  finally
    Manager.Free;
  end;
end;

procedure TestInstallFPCVersionInstallsCachedBuildIntoSandbox;
var
  Manager: TFPCSourceManager;
  SandboxRoot: string;
  InstalledCompilerPath: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 14: InstallFPCVersion Installs Cached Build Into Sandbox');
  WriteLn('==================================================');

  {$IFNDEF UNIX}
  AssertTrue(True,
    'InstallFPCVersion cached-install success contract skipped on non-UNIX',
    'This fixture uses POSIX shell scripts and make install commands.');
  Exit;
  {$ENDIF}

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-install-cache-success');
  try
    PrepareCachedFPCInstallFixture(Manager, '3.2.2', True);
    SandboxRoot := Manager.SourceRoot + PathDelim + 'sandbox';
    InstalledCompilerPath := SandboxRoot + PathDelim + 'fpc-3.2.2' +
      PathDelim + 'bin' + PathDelim + GetMockCompilerExecutableName;

    Success := Manager.InstallFPCVersion('3.2.2');

    AssertTrue(Success,
      'FPC source manager installs cached build into sandbox',
      'Expected InstallFPCVersion(3.2.2) to succeed when cache exists and install target writes sandbox artifacts');
    AssertTrue(FileExists(InstalledCompilerPath),
      'FPC source manager writes installed compiler artifact into source-local sandbox',
      'Expected installed compiler at "' + InstalledCompilerPath + '"');
    AssertTrue(Manager.CurrentVersion = '3.2.2',
      'FPC source manager updates current version after cached install succeeds',
      'Expected CurrentVersion to be 3.2.2 after successful cached install, got "' +
        Manager.CurrentVersion + '"');
  finally
    Manager.Free;
  end;
end;

procedure TestInstallFPCVersionConfiguresCachedBuildIntoManagedLayout;
var
  Manager: TFPCSourceManager;
  SandboxRoot: string;
  InstalledRoot: string;
  WrapperPath: string;
  WrapperContent: string;
  ProcResult: TProcessResult;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 15: InstallFPCVersion Configures Cached Build Into Managed Layout');
  WriteLn('==================================================');

  {$IFNDEF UNIX}
  AssertTrue(True,
    'InstallFPCVersion managed-layout contract skipped on non-UNIX',
    'This fixture uses POSIX shell scripts and wrapper generation.');
  Exit;
  {$ENDIF}

  Manager := TFPCSourceManager.Create(TestRootDir + PathDelim + 'fpc-source-install-cache-configure');
  try
    PrepareCachedFPCInstallFixture(Manager, '3.2.2', True);
    SandboxRoot := Manager.SourceRoot + PathDelim + 'sandbox';
    InstalledRoot := SandboxRoot + PathDelim + 'fpc-3.2.2';
    WrapperPath := InstalledRoot + PathDelim + 'bin' + PathDelim + 'fpc';

    AssertTrue(Manager.InstallFPCVersion('3.2.2'),
      'FPC source manager configures cached install into managed layout',
      'Expected InstallFPCVersion(3.2.2) to succeed for raw install layout');

    AssertTrue(FileExists(InstalledRoot + PathDelim + 'bin' + PathDelim + 'fpc.cfg'),
      'FPC source manager writes fpc.cfg for cached install',
      'Expected fpc.cfg under sandbox install bin directory');
    AssertTrue(FileExists(InstalledRoot + PathDelim + 'bin' + PathDelim + 'fpc.orig'),
      'FPC source manager preserves raw driver as fpc.orig',
      'Expected wrapper backup under sandbox install bin directory');
    AssertTrue(FileExists(InstalledRoot + PathDelim + 'bin' + PathDelim +
      GetMockCompilerExecutableName),
      'FPC source manager exposes native compiler in bin directory',
      'Expected native compiler entry in sandbox bin directory');

    with TStringList.Create do
    try
      LoadFromFile(WrapperPath);
      WrapperContent := Text;
    finally
      Free;
    end;

    AssertTrue(Pos('fpc.cfg', WrapperContent) > 0,
      'FPC source manager wrapper references generated config',
      'Expected wrapper script to include fpc.cfg');
    AssertTrue(Pos(GetMockCompilerExecutableName, WrapperContent) > 0,
      'FPC source manager wrapper references native compiler',
      'Expected wrapper script to include native compiler name');

    ProcResult := TProcessExecutor.Execute(WrapperPath, ['-iV'], '');
    AssertTrue(ProcResult.Success and (Trim(ProcResult.StdOut) = '3.2.2'),
      'FPC source manager wrapper resolves configured compiler version',
      'stdout=' + Trim(ProcResult.StdOut) + ' stderr=' + Trim(ProcResult.StdErr));
  finally
    Manager.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  FPC Source Repo Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      TestCloneFPCSourceUsesRegistryRepositoryAndGitTag;
      TestCloneFPCSourceFallsBackToStaticGitTagWhenRegistryEmpty;
      TestCloneFPCSourceRechecksExistingGitRepoRef;
      TestFPCSourceManagerRejectsCloneWithoutValidSourceTree;
      TestFPCSourceManagerListsRegistryOnlyVersion;
      TestFPCSourceManagerResolvesRegistryGitTagToVersion;
      TestFPCSourceManagerKeepsStaticGitTagOpaqueWhenRegistryPresent;
      TestSwitchFPCVersionUsesRegistryRef;
      TestSwitchFPCVersionFallsBackToStaticGitTagWhenRegistryEmpty;
      TestFPCSourceManagerResolvesStaticGitTagWhenRegistryEmpty;
      TestFPCSourceManagerRejectsInvalidInstalledDirectory;
      TestFPCSourceManagerListsOnlyValidLocalVersions;
      TestFPCSourceManagerRejectsNonSourceGitRepoOnUpdate;
      TestFPCSourceManagerRefreshesWorkingTreeOnUpdate;
      TestFPCSourceManagerTracksUpdatedVersionForEmptyArgFollowUp;
      TestFPCSourceManagerRejectsNonConflictingDivergedUpdate;
      TestSwitchFPCVersionRejectsNonSourceGitRepo;
      TestFPCSourceManagerRejectsInvalidDirectoryOnBuild;
      TestFPCSourceManagerBuildsValidSourceDirectory;
      TestFPCSourceManagerRejectsInvalidDirectoryOnFollowUpBuilds;
      TestFPCSourceManagerBuildsValidFollowUpTargets;
      TestInstallFPCVersionRejectsCachedBuildWithoutInstalledArtifacts;
      TestInstallFPCVersionKeepsCurrentVersionWhenCachedInstallFails;
      TestInstallFPCVersionInstallsCachedBuildIntoSandbox;
      TestInstallFPCVersionConfiguresCachedBuildIntoManagedLayout;

      if TestsFailed > 0 then
        ExitCode := 1
      else
        ExitCode := 0;
    finally
      CleanupTestEnvironment;
    end;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite crashed');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
