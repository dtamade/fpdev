program test_lazarus_update;

{$mode objfpc}{$H+}

uses
  SysUtils, test_config_isolation, Classes, Process,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.cmd.lazarus, fpdev.config.interfaces, fpdev.config.managers, fpdev.git2,
  fpdev.utils, fpdev.utils.git, fpdev.constants, fpdev.version.registry, fpdev.lazarus.source,
  fpdev.lazarus.config, fpdev.lazarus.commandflow, fpdev.output.intf,
  fpdev.i18n, fpdev.i18n.strings,
  test_temp_paths;

var
  TestRootDir: string;
  ConfigManager: IConfigManager;
  LazarusManager: fpdev.cmd.lazarus.TLazarusManager;
  TestsPassed: Integer;
  TestsFailed: Integer;

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Contains(const S: string): Boolean;
    function Text: string;
  end;

  TProbeLazarusGitClient = class(TInterfacedObject, ILazarusGitClient, ILazarusSourceGitClient)
  public
    BackendValue: TGitBackend;
    CloneResult: Boolean;
    AutoCreateSourceTree: Boolean;
    AutoCreateLegacyExecutableOnBuild: Boolean;
    BuildPathCaptureFileName: string;
    LastErrorValue: string;
    FetchResult: Boolean;
    CheckoutResult: Boolean;
    IsRepositoryResult: Boolean;
    HasRemoteResult: Boolean;
    PullResult: Boolean;
    PullCalls: Integer;
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
    function HasRemote(const ARepoPath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function GetLastError: string;
  end;

  TTestLazarusManager = class(fpdev.cmd.lazarus.TLazarusManager)
  public
    LastCliOnly: Boolean;
    DownloadClient: ILazarusGitClient;
    function CreateGitClient(const ACliOnly: Boolean): ILazarusGitClient; override;
    function InvokeDownloadSource(const AVersion, ATargetDir: string): Boolean;
  end;

  TTestLazarusSourceManager = class(fpdev.lazarus.source.TLazarusSourceManager)
  public
    SourceClient: ILazarusSourceGitClient;
    function CreateGitClient: ILazarusSourceGitClient; override;
    function RunGetVersionFromBranch(const ABranch: string): string;
  end;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TProbeLazarusGitClient.GetBackend: TGitBackend;
begin
  Result := BackendValue;
end;

function TProbeLazarusGitClient.BackendAvailable: Boolean;
begin
  Result := BackendValue <> gbNone;
end;

function TProbeLazarusGitClient.Clone(const AURL, ALocalPath: string;
  const ABranch: string): Boolean;
var
  MakefileLines: TStringList;
begin
  Inc(CloneCalls);
  LastCloneURL := AURL;
  LastClonePath := ALocalPath;
  LastCloneBranch := ABranch;
  Result := CloneResult;

  if Result and AutoCreateSourceTree then
  begin
    ForceDirectories(ALocalPath);
    ForceDirectories(ALocalPath + PathDelim + 'ide');
    ForceDirectories(ALocalPath + PathDelim + 'lcl');
    ForceDirectories(ALocalPath + PathDelim + 'packager');
    MakefileLines := TStringList.Create;
    try
      MakefileLines.Add('clean:');
      MakefileLines.Add(#9 + '@true');
      MakefileLines.Add('all:');
      if BuildPathCaptureFileName <> '' then
      begin
        {$IFDEF MSWINDOWS}
        MakefileLines.Add(#9 + 'echo %PATH%> "' + BuildPathCaptureFileName + '"');
        {$ELSE}
        MakefileLines.Add(#9 + 'printf ''%s\n'' "$$PATH" > "' + BuildPathCaptureFileName + '"');
        {$ENDIF}
      end;
      if AutoCreateLegacyExecutableOnBuild then
      begin
        {$IFDEF MSWINDOWS}
        MakefileLines.Add(#9 + 'echo @echo off> "lazarus.exe"');
        {$ELSE}
        MakefileLines.Add(#9 + 'echo ''#!/bin/sh'' > "lazarus"');
        MakefileLines.Add(#9 + 'echo ''exit 0'' >> "lazarus"');
        MakefileLines.Add(#9 + 'chmod +x "lazarus"');
        {$ENDIF}
      end
      else
        MakefileLines.Add(#9 + '@true');
      MakefileLines.Add('install:');
      {$IFDEF MSWINDOWS}
      MakefileLines.Add(#9 + 'if not exist "$(INSTALL_PREFIX)\\bin" mkdir "$(INSTALL_PREFIX)\\bin"');
      MakefileLines.Add(#9 + 'echo @echo off> "$(INSTALL_PREFIX)\\bin\\lazarus.exe"');
      {$ELSE}
      MakefileLines.Add(#9 + 'mkdir -p "$(INSTALL_PREFIX)/bin"');
      MakefileLines.Add(#9 + 'echo ''#!/bin/sh'' > "$(INSTALL_PREFIX)/bin/lazarus-ide"');
      MakefileLines.Add(#9 + 'echo ''exit 0'' >> "$(INSTALL_PREFIX)/bin/lazarus-ide"');
      {$ENDIF}
      MakefileLines.SaveToFile(ALocalPath + PathDelim + 'Makefile');
    finally
      MakefileLines.Free;
    end;
  end;
end;

function TProbeLazarusGitClient.Fetch(const ARepoPath: string;
  const ARemote: string): Boolean;
begin
  if ARepoPath <> '' then;
  if ARemote <> '' then;
  Result := FetchResult;
end;

function TProbeLazarusGitClient.Checkout(const ARepoPath, AName: string;
  const Force: Boolean): Boolean;
begin
  if ARepoPath <> '' then;
  if AName <> '' then;
  if Force then;
  Result := CheckoutResult;
end;

function TProbeLazarusGitClient.IsRepository(const APath: string): Boolean;
begin
  if APath <> '' then;
  Result := IsRepositoryResult;
end;

function TProbeLazarusGitClient.HasRemote(const ARepoPath: string): Boolean;
begin
  if ARepoPath <> '' then;
  Result := HasRemoteResult;
end;

function TProbeLazarusGitClient.Pull(const ARepoPath: string): Boolean;
begin
  if ARepoPath <> '' then;
  Inc(PullCalls);
  Result := PullResult;
end;

function TProbeLazarusGitClient.GetLastError: string;
begin
  Result := LastErrorValue;
end;

function TTestLazarusManager.CreateGitClient(
  const ACliOnly: Boolean): ILazarusGitClient;
begin
  LastCliOnly := ACliOnly;
  Result := DownloadClient;
end;

function TTestLazarusManager.InvokeDownloadSource(
  const AVersion, ATargetDir: string): Boolean;
begin
  Result := DownloadSource(AVersion, ATargetDir);
end;

function TTestLazarusSourceManager.CreateGitClient: ILazarusSourceGitClient;
begin
  Result := SourceClient;
end;

function TTestLazarusSourceManager.RunGetVersionFromBranch(const ABranch: string): string;
begin
  Result := ProtectedGetVersionFromBranch(ABranch);
end;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
  SettingsMgr: ISettingsManager;
begin
  // Create test root directory in temp
  TestRootDir := CreateUniqueTempDir('test_lazarus_update');
  if not PathUsesSystemTempRoot(TestRootDir) then
    raise Exception.Create('Test root dir should use system temp root');

  // Initialize config manager
  ConfigManager := CreateIsolatedConfigManager;

  // Override install root to test directory
  SettingsMgr := ConfigManager.GetSettingsManager;
  Settings := SettingsMgr.GetSettings;
  Settings.InstallRoot := TestRootDir;
  SettingsMgr.SetSettings(Settings);

  // Create Lazarus manager
  LazarusManager := fpdev.cmd.lazarus.TLazarusManager.Create(ConfigManager);

  TestsPassed := 0;
  TestsFailed := 0;
end;

procedure CleanupTestEnvironment;
begin
  if Assigned(LazarusManager) then
    LazarusManager.Free;
  ConfigManager := nil;

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

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure AssertFalse(const Condition: Boolean; const TestName, Message: string);
begin
  AssertTrue(not Condition, TestName, Message);
end;

function WaitForFile(const APath: string; const ATimeoutMs: Integer = 1000): Boolean;
var
  Deadline: QWord;
begin
  Deadline := GetTickCount64 + QWord(ATimeoutMs);
  repeat
    if FileExists(APath) then
      Exit(True);
    Sleep(50);
  until GetTickCount64 >= Deadline;
  Result := FileExists(APath);
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

procedure MakeExecutable(const APath: string);
begin
  {$IFDEF UNIX}
  if fpchmod(APath, &755) <> 0 then
    raise Exception.Create('Failed to mark executable: ' + APath);
  {$ENDIF}
end;

procedure WriteMockExecutable(const APath, ALabel: string);
begin
  with TStringList.Create do
  try
    Add('#!/bin/sh');
    Add('echo "' + ALabel + '"');
    SaveToFile(APath);
  finally
    Free;
  end;
  MakeExecutable(APath);
end;


procedure TestConfigManagerUsesIsolatedDefaultConfigPath;
var
  ConfigPath: string;
  TempRoot: string;
  ExpectedPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Config Manager Uses Isolated Config Path');
  WriteLn('==================================================');

  try
    ConfigPath := ExpandFileName(ConfigManager.GetConfigPath);
    TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
    ExpectedPath := ExpandFileName(GetIsolatedDefaultConfigPath);

    AssertTrue(Pos(TempRoot, ConfigPath) = 1,
      'Config path uses system temp root',
      'Expected config path under temp root "' + TempRoot + '", got "' + ConfigPath + '"');

    AssertTrue(ConfigPath = ExpectedPath,
      'Config path uses isolated default override',
      'Expected config path "' + ExpectedPath + '", got "' + ConfigPath + '"');
  except
    on E: Exception do
      AssertTrue(False, 'Config path isolation check',
        'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 1: UpdateSources refreshes the source repository
// ============================================================================
procedure TestUpdateRefreshesSourceRepository;
var
  SourceDir: string;
  GitManager: TGitManager;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: UpdateSources Refreshes Source Repository');
  WriteLn('==================================================');

  try
    // Setup: Create a mock Lazarus source directory with git
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-3.0';
    ForceDirectories(SourceDir);
    ForceDirectories(SourceDir + PathDelim + 'ide');
    ForceDirectories(SourceDir + PathDelim + 'lcl');
    ForceDirectories(SourceDir + PathDelim + 'packager');

    // Initialize git repository
    GitManager := TGitManager.Create;
    try
      if GitManager.Initialize then
      begin
        // Create a mock git repository
        GitManager.InitRepository(SourceDir);

        // Create a dummy file to simulate source code
        with TStringList.Create do
        try
          Add('// Mock Lazarus source');
          SaveToFile(SourceDir + PathDelim + 'lazarus.lpr');
        finally
          Free;
        end;
      end;
    finally
      GitManager.Free;
    end;

    // Execute: Call UpdateSources
    Success := LazarusManager.UpdateSources('3.0');

    // Assert: UpdateSources should update the repository and return true
    AssertTrue(Success, 'UpdateSources refreshes repository state',
      'UpdateSources should update the source repository when git metadata is available');

  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources succeeds', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: UpdateSources rejects invalid repositories
// ============================================================================
procedure TestUpdateRejectsInvalidRepository;
var
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: UpdateSources Rejects Invalid Repository');
  WriteLn('==================================================');

  try
    // Setup: Create a source directory without .git (invalid repository scenario)
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-conflict';
    ForceDirectories(SourceDir);

    // Create some local files, but keep the directory non-repository
    with TStringList.Create do
    try
      Add('// Modified local file');
      SaveToFile(SourceDir + PathDelim + 'modified.pas');
    finally
      Free;
    end;

    // Execute: Call UpdateSources on a non-git directory
    Success := LazarusManager.UpdateSources('conflict');

    // Assert: UpdateSources should detect the issue and return false
    AssertFalse(Success, 'UpdateSources rejects invalid repository',
      'UpdateSources should return false when the source directory is not a git repository');

  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources rejects invalid repository', 'Exception: ' + E.Message);
  end;
end;

procedure TestUpdateReportsMissingSourceDirectory;
var
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2b: UpdateSources Reports Missing Source Directory');
  WriteLn('==================================================');

  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := LazarusManager.UpdateSources(Outp, Errp, 'missing');

    AssertFalse(Success, 'UpdateSources reports missing source directory',
      'Expected UpdateSources(missing) to fail when source directory does not exist');
    AssertTrue(Errp.Contains(_Fmt(CMD_LAZARUS_SOURCE_DIR_NOT_FOUND, [
      TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-missing'
    ])), 'UpdateSources emits missing source directory error',
      'Expected missing source directory error, got: ' + Errp.Text);
  finally
    Outp.Free;
    Errp.Free;
  end;
end;

// ============================================================================
// Test 3: UpdateSources triggers rebuild notification
// ============================================================================
procedure TestUpdateTriggersRebuildNotification;
var
  SourceDir: string;
  GitManager: TGitManager;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: UpdateSources Triggers Rebuild Notification');
  WriteLn('==================================================');

  try
    // Setup: Create a mock Lazarus source directory
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-rebuild';
    ForceDirectories(SourceDir);
    ForceDirectories(SourceDir + PathDelim + 'ide');
    ForceDirectories(SourceDir + PathDelim + 'lcl');
    ForceDirectories(SourceDir + PathDelim + 'packager');

    // Initialize git repository
    GitManager := TGitManager.Create;
    try
      if GitManager.Initialize then
      begin
        GitManager.InitRepository(SourceDir);

        // Create source files
        with TStringList.Create do
        try
          Add('// Lazarus source v1');
          SaveToFile(SourceDir + PathDelim + 'lazarus.lpr');
        finally
          Free;
        end;
      end;
    finally
      GitManager.Free;
    end;

    // Execute: Call UpdateSources
    Success := LazarusManager.UpdateSources('rebuild');

    // Assert: UpdateSources should inform user about rebuild requirement
    // (For now, we just check it returns true if source is updated)
    AssertTrue(Success, 'UpdateSources notifies rebuild requirement',
      'UpdateSources should notify user to rebuild after update');

  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources triggers rebuild', 'Exception: ' + E.Message);
  end;
end;

procedure TestUpdateRejectsNonSourceGitRepository;
var
  SourceDir: string;
  OriginDir: string;
  WorkDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: UpdateSources Rejects Non-Source Git Repository');
  WriteLn('==================================================');

  try
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-nonsource';
    OriginDir := TestRootDir + PathDelim + 'lazarus-update-origin.git';
    WorkDir := TestRootDir + PathDelim + 'lazarus-update-work';

    AssertTrue(RunCommandInDir('git', ['init', '--bare', OriginDir], TestRootDir),
      'UpdateSources setup creates bare origin for non-source repo',
      'Expected git init --bare to succeed for ' + OriginDir);

    ForceDirectories(WorkDir);
    with TStringList.Create do
    try
      Add('not a lazarus source tree');
      SaveToFile(WorkDir + PathDelim + 'README.txt');
    finally
      Free;
    end;

    AssertTrue(RunCommandInDir('git', ['init'], WorkDir),
      'UpdateSources setup initializes non-source work repo',
      'Expected git init to succeed in ' + WorkDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'UpdateSources setup configures git email for non-source repo',
      'Expected git config user.email to succeed');
    AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'UpdateSources setup configures git user for non-source repo',
      'Expected git config user.name to succeed');
    AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], WorkDir),
      'UpdateSources setup stages file for non-source repo',
      'Expected git add to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
      'UpdateSources setup commits file for non-source repo',
      'Expected git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'UpdateSources setup renames branch for non-source repo',
      'Expected git branch -M main to succeed');
    AssertTrue(RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'UpdateSources setup adds origin for non-source repo',
      'Expected git remote add origin to succeed');
    AssertTrue(RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'UpdateSources setup pushes origin for non-source repo',
      'Expected git push -u origin main to succeed');
    AssertTrue(RunCommandInDir('git', ['clone', OriginDir, SourceDir], TestRootDir),
      'UpdateSources setup clones non-source repo into lazarus path',
      'Expected git clone to succeed into ' + SourceDir);

    Success := LazarusManager.UpdateSources('nonsource');

    AssertFalse(Success, 'UpdateSources rejects non-source git repository',
      'Expected UpdateSources(nonsource) to fail for git repo without ide/lcl/packager');
  except
    on E: Exception do
      AssertTrue(False, 'UpdateSources rejects non-source git repository',
        'Exception: ' + E.Message);
  end;
end;

procedure TestUpdateReportsInvalidSourceDirectory;
var
  SourceDir: string;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4b: UpdateSources Reports Invalid Source Directory');
  WriteLn('==================================================');

  SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-invalid';
  ForceDirectories(SourceDir);

  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    with TStringList.Create do
    try
      Add('not a lazarus source tree');
      SaveToFile(SourceDir + PathDelim + 'README.txt');
    finally
      Free;
    end;

    Success := LazarusManager.UpdateSources(Outp, Errp, 'invalid');

    AssertFalse(Success, 'UpdateSources reports invalid source directory',
      'Expected UpdateSources(invalid) to fail for directory without ide/lcl/packager');
    AssertTrue(Errp.Contains(_Fmt(CMD_LAZARUS_INVALID_SOURCE_DIR, [SourceDir])),
      'UpdateSources emits invalid source directory error',
      'Expected invalid source directory error, got: ' + Errp.Text);
  finally
    Outp.Free;
    Errp.Free;
  end;
end;

procedure TestDownloadSourcePrefersLibgit2WhenCLIUnavailable;
var
  Manager: TTestLazarusManager;
  Client: TProbeLazarusGitClient;
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: DownloadSource Prefers Libgit2 When CLI Unavailable');
  WriteLn('==================================================');

  Manager := TTestLazarusManager.Create(ConfigManager);
  try
    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Manager.DownloadClient := Client;
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-3.6';

    Success := Manager.InvokeDownloadSource('3.6', SourceDir);

    AssertTrue(Success, 'DownloadSource succeeds with libgit2-only backend',
      'DownloadSource should not require command-line git when libgit2 backend is available');
    AssertFalse(Manager.LastCliOnly, 'DownloadSource does not force cli-only backend',
      'DownloadSource should request default git backend selection instead of cli-only');
    AssertTrue(Client.CloneCalls = 1, 'DownloadSource clones once through git client',
      'Expected exactly one clone call');
    AssertTrue(Client.LastCloneURL = LAZARUS_OFFICIAL_REPO,
      'DownloadSource uses official repository URL',
      'Actual URL: ' + Client.LastCloneURL);
    AssertTrue(Client.LastCloneBranch = 'lazarus_3_6',
      'DownloadSource uses release git tag',
      'Actual branch/tag: ' + Client.LastCloneBranch);
  finally
    Manager.Free;
  end;
end;

procedure TestDownloadSourceUsesRegistryRepositoryURL;
var
  Manager: TTestLazarusManager;
  Client: TProbeLazarusGitClient;
  SourceDir: string;
  Success: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomRepoURL: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: DownloadSource Uses Registry Repository URL');
  WriteLn('==================================================');

  CustomRepoURL := 'https://mirror.example.invalid/lazarus.git';
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-mirror.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.6",');
    Add('    "repository": "' + CustomRepoURL + '",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.6",');
    Add('        "release_date": "2024-10-14",');
    Add('        "git_tag": "custom_lazarus_3_6",');
    Add('        "branch": "custom_lazarus_3_6",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusManager.Create(ConfigManager);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom Lazarus registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Manager.DownloadClient := Client;
    SourceDir := TestRootDir + PathDelim + 'sources' + PathDelim + 'lazarus-3.6-mirror';

    Success := Manager.InvokeDownloadSource('3.6', SourceDir);

    AssertTrue(Success, 'DownloadSource succeeds with registry-backed repository',
      'DownloadSource should still succeed when repository URL comes from registry data');
    AssertTrue(Client.LastCloneURL = CustomRepoURL,
      'DownloadSource uses repository URL from version registry',
      'Expected URL "' + CustomRepoURL + '", got "' + Client.LastCloneURL + '"');
    AssertTrue(Client.LastCloneBranch = 'custom_lazarus_3_6',
      'DownloadSource uses git tag from reloaded registry',
      'Actual branch/tag: ' + Client.LastCloneBranch);
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestInstallVersionPersistsRegistryRepositoryURL;
var
  Manager: TTestLazarusManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  Found: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomRepoURL: string;
  LazarusInfo: TLazarusInfo;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6: InstallVersion Persists Registry Repository URL');
  WriteLn('==================================================');

  CustomRepoURL := 'https://mirror.example.invalid/lazarus-install.git';
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-install.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.6",');
    Add('    "repository": "' + CustomRepoURL + '",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.6",');
    Add('        "release_date": "2024-10-14",');
    Add('        "git_tag": "install_lazarus_3_6",');
    Add('        "branch": "install_lazarus_3_6",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusManager.Create(ConfigManager);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom Lazarus install registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Manager.DownloadClient := Client;

    Success := Manager.InstallVersion('3.6', '', True, False);
    Found := ConfigManager.GetLazarusManager.GetLazarusVersion('lazarus-3.6', LazarusInfo);

    AssertTrue(Success, 'InstallVersion succeeds with mock source tree',
      'InstallVersion should succeed when clone prepares a minimal buildable source tree');
    AssertTrue(Client.LastCloneURL = CustomRepoURL,
      'InstallVersion clones from registry repository URL',
      'Expected URL "' + CustomRepoURL + '", got "' + Client.LastCloneURL + '"');
    AssertTrue(Found, 'InstallVersion registers Lazarus version in config',
      'Expected lazarus-3.6 entry to be written to config manager');
    if Found then
      AssertTrue(LazarusInfo.SourceURL = CustomRepoURL,
        'InstallVersion persists registry repository URL into config',
        'Expected source url "' + CustomRepoURL + '", got "' + LazarusInfo.SourceURL + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestInstallVersionUsesSameProcessPathForBuildEnv;
var
  Manager: TTestLazarusManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  SavedPath: string;
  ProbePathDir: string;
  EffectivePath: string;
  CapturedPathFileName: string;
  CapturedPathFile: string;
  CapturedPath: string;
  ExpectedFPCBinDir: string;
  ExpectedPrefix: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6b: InstallVersion Uses Same-Process PATH For Build Env');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-build-path.json';
  SavedPath := get_env('PATH');
  ProbePathDir := TestRootDir + PathDelim + 'same-process-build-path-probe';
  CapturedPathFileName := 'build-path.txt';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.7",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.7",');
    Add('        "release_date": "2024-10-14",');
    Add('        "git_tag": "build_path_lazarus_3_7",');
    Add('        "branch": "build_path_lazarus_3_7",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  ForceDirectories(ProbePathDir);
  if SavedPath <> '' then
    EffectivePath := ProbePathDir + PathSeparator + SavedPath
  else
    EffectivePath := ProbePathDir;

  Manager := TTestLazarusManager.Create(ConfigManager);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Build env registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Client.BuildPathCaptureFileName := CapturedPathFileName;
    Manager.DownloadClient := Client;

    AssertTrue(set_env('PATH', EffectivePath),
      'InstallVersion sets same-process PATH probe',
      'Expected PATH to be set to "' + EffectivePath + '"');

    Success := Manager.InstallVersion('3.7', '', True, False);
    CapturedPathFile := Client.LastClonePath + PathDelim + CapturedPathFileName;
    CapturedPath := Trim(ReadAllTextIfExists(CapturedPathFile));
    ExpectedFPCBinDir := TestRootDir + PathDelim + 'toolchains' + PathDelim + 'fpc' +
      PathDelim + '3.2.2' + PathDelim + 'bin';
    {$IFDEF MSWINDOWS}
    ExpectedPrefix := ExpectedFPCBinDir + PathSeparator + ProbePathDir;
    {$ELSE}
    ExpectedPrefix := ExpectedFPCBinDir + PathSeparator + '/usr/bin' +
      PathSeparator + '/bin' + PathSeparator + ProbePathDir;
    {$ENDIF}

    AssertTrue(Success,
      'InstallVersion succeeds while probing same-process PATH build env',
      'Expected InstallVersion(3.7, from-source) to succeed with mock build tree');
    AssertTrue(WaitForFile(CapturedPathFile),
      'InstallVersion writes child PATH capture file during build',
      'Expected captured PATH file under "' + CapturedPathFile + '"');
    AssertTrue(Pos(ExpectedPrefix, CapturedPath) = 1,
      'InstallVersion passes same-process PATH override into build child env',
      'Expected PATH prefix "' + ExpectedPrefix + '", got "' + CapturedPath + '"');
  finally
    RestoreEnv('PATH', SavedPath);
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerUsesRegistryRepositoryURL;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  CustomRepoURL: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 7: Legacy Source Manager Uses Registry Repository URL');
  WriteLn('==================================================');

  CustomRepoURL := 'https://mirror.example.invalid/lazarus-source-manager.git';
  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-manager.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.6",');
    Add('    "repository": "' + CustomRepoURL + '",');
    Add('    "releases": []');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-sources');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom legacy source registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Manager.SourceClient := Client;

    Success := Manager.CloneLazarusSource('3.0');

    AssertTrue(Success, 'Legacy source manager clone succeeds with injected git client',
      'Expected CloneLazarusSource to succeed through injected git client');
    AssertTrue(Client.LastCloneURL = CustomRepoURL,
      'Legacy source manager uses repository URL from version registry',
      'Expected URL "' + CustomRepoURL + '", got "' + Client.LastCloneURL + '"');
    AssertTrue(Client.LastCloneBranch = 'lazarus_3_0',
      'Legacy source manager keeps static branch fallback when registry is empty',
      'Actual branch/tag: ' + Client.LastCloneBranch);
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerListsRegistryVersion;
var
  Manager: TTestLazarusSourceManager;
  Versions: TStringArray;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 8: Legacy Source Manager Lists Registry Version');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-list.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.6",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.6",');
    Add('        "release_date": "2024-10-14",');
    Add('        "git_tag": "list_lazarus_3_6",');
    Add('        "branch": "list_lazarus_3_6",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-list');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom legacy list registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Versions := Manager.ListAvailableVersions;

    AssertTrue(ArrayContainsValue(Versions, '3.6'),
      'Legacy source manager lists registry version 3.6',
      'Expected ListAvailableVersions to contain 3.6');
    AssertTrue(Manager.IsVersionAvailable('3.6'),
      'Legacy source manager recognizes registry version as available',
      'Expected IsVersionAvailable(3.6) to be true');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerDoesNotListStaticOnlyVersionWhenRegistryPresent;
var
  Manager: TTestLazarusSourceManager;
  Versions: TStringArray;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 8b: Legacy Source Manager Does Not List Static-Only Version When Registry Present');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-authoritative-list.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "9.9",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "9.9",');
    Add('        "release_date": "2099-09-09",');
    Add('        "git_tag": "lazarus_9_9",');
    Add('        "branch": "lazarus_9_9",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-authoritative-list');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom authoritative legacy list registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Versions := Manager.ListAvailableVersions;

    AssertTrue(ArrayContainsValue(Versions, '9.9'),
      'Legacy source manager keeps registry-only version in authoritative list',
      'Expected ListAvailableVersions to contain 9.9');
    AssertFalse(ArrayContainsValue(Versions, '3.0'),
      'Legacy source manager excludes static-only version when registry is present',
      'Expected ListAvailableVersions to exclude static-only 3.0 when registry already provides releases');
    AssertFalse(Manager.IsVersionAvailable('3.0'),
      'Legacy source manager does not report static-only version available when registry is present',
      'Expected IsVersionAvailable(3.0) to be false when registry omits 3.0');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerKeepsStaticBranchOpaqueWhenRegistryPresent;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 8c: Legacy Source Manager Keeps Static Branch Opaque When Registry Present');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-authoritative-ref.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "9.9",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "9.9",');
    Add('        "release_date": "2099-09-09",');
    Add('        "git_tag": "lazarus_9_9",');
    Add('        "branch": "lazarus_9_9",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-authoritative-ref');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom authoritative legacy ref registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Manager.SourceClient := Client;

    Success := Manager.CloneLazarusSource('3.0');

    AssertTrue(Success, 'Legacy source manager clone succeeds with authoritative registry data',
      'Expected CloneLazarusSource to succeed through injected git client');
    AssertTrue(Client.LastCloneBranch = '3.0',
      'Legacy source manager keeps static-only version opaque when registry is present',
      'Expected raw version ref "3.0", got "' + Client.LastCloneBranch + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerUsesRegistryBranchForVersion;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 9: Legacy Source Manager Uses Registry Branch Fallback');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-branch.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.6",');
    Add('    "repository": "https://mirror.example.invalid/lazarus-source-branch.git",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.6",');
    Add('        "release_date": "2024-10-14",');
    Add('        "branch": "registry_branch_3_6",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-branch');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom legacy branch registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Manager.SourceClient := Client;

    Success := Manager.CloneLazarusSource('3.6');

    AssertTrue(Success, 'Legacy source manager clone succeeds for branch-backed version',
      'Expected CloneLazarusSource(3.6) to succeed');
    AssertTrue(Client.LastCloneBranch = 'registry_branch_3_6',
      'Legacy source manager falls back to branch from version registry',
      'Expected branch "registry_branch_3_6", got "' + Client.LastCloneBranch + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerPrefersRegistryGitTagForVersion;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 10: Legacy Source Manager Prefers Registry Git Tag');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-gittag.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.6",');
    Add('    "repository": "https://mirror.example.invalid/lazarus-source-gittag.git",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.6",');
    Add('        "release_date": "2024-10-14",');
    Add('        "git_tag": "tag_lazarus_3_6",');
    Add('        "branch": "registry_branch_3_6",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-gittag');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom legacy git-tag registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Manager.SourceClient := Client;

    Success := Manager.CloneLazarusSource('3.6');

    AssertTrue(Success, 'Legacy source manager clone succeeds for git-tag-backed version',
      'Expected CloneLazarusSource(3.6) to succeed');
    AssertTrue(Client.LastCloneBranch = 'tag_lazarus_3_6',
      'Legacy source manager prefers git tag from version registry',
      'Expected ref "tag_lazarus_3_6", got "' + Client.LastCloneBranch + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerRejectsCloneWithoutValidSourceTree;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 10b: Legacy Source Manager Rejects Clone Without Valid Source Tree');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-invalid-clone');
  try
    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := False;
    Manager.SourceClient := Client;

    Success := Manager.CloneLazarusSource('3.0');

    AssertFalse(Success,
      'Legacy source manager rejects clone success without valid source tree',
      'Expected CloneLazarusSource(3.0) to fail when clone does not create ide/lcl/packager');
    AssertTrue(Manager.GetCurrentVersion = '',
      'Legacy source manager keeps current version unchanged on invalid clone',
      'Expected current version to stay empty, got "' + Manager.GetCurrentVersion + '"');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerFallsBackToCloneForInvalidInstalledDirectory;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 11: Legacy Source Manager Falls Back To Clone For Invalid Installed Directory');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-switch');
  try
    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := False;
    Manager.SourceClient := Client;

    SourceDir := Manager.GetLazarusSourcePath('3.0');
    ForceDirectories(SourceDir);

    Success := Manager.SwitchLazarusVersion('3.0');

    AssertFalse(Success,
      'Legacy source manager does not report success for invalid installed directory',
      'Expected switch to fail when invalid directory forces clone fallback and clone fails');
    AssertTrue(Client.CloneCalls = 1,
      'Legacy source manager falls back to clone for invalid installed directory',
      'Expected one clone attempt for invalid directory, got ' + IntToStr(Client.CloneCalls));
    AssertTrue(Manager.GetCurrentVersion = '',
      'Legacy source manager keeps current version unchanged on invalid switch',
      'Expected current version to stay empty, got "' + Manager.GetCurrentVersion + '"');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerSwitchesExistingGitRepoToRequestedRef;
var
  Manager: TLazarusSourceManager;
  SourceRoot: string;
  SourceDir: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
  Success: Boolean;
  ReadmePath: string;
  ReadmeContent: TStringList;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 11b: Legacy Source Manager Switches Existing Git Repo To Requested Ref');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-switch-existing-repo.json';
  SourceRoot := TestRootDir + PathDelim + 'legacy-lazarus-switch-existing-repo';
  SourceDir := SourceRoot + PathDelim + 'lazarus-3.0';
  ReadmePath := SourceDir + PathDelim + 'README.txt';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.0",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "3.0",');
    Add('        "release_date": "2024-01-01",');
    Add('        "git_tag": "tag_lazarus_3_0",');
    Add('        "branch": "branch_lazarus_3_0",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  ForceDirectories(SourceDir + PathDelim + 'ide');
  ForceDirectories(SourceDir + PathDelim + 'lcl');
  ForceDirectories(SourceDir + PathDelim + 'packager');
  with TStringList.Create do
  try
    Add('main source tree');
    SaveToFile(ReadmePath);
  finally
    Free;
  end;
  with TStringList.Create do
  try
    Add('ide fixture');
    SaveToFile(SourceDir + PathDelim + 'ide' + PathDelim + 'fixture.txt');
    Add('lcl fixture');
    SaveToFile(SourceDir + PathDelim + 'lcl' + PathDelim + 'fixture.txt');
    Add('packager fixture');
    SaveToFile(SourceDir + PathDelim + 'packager' + PathDelim + 'fixture.txt');
  finally
    Free;
  end;

  AssertTrue(RunCommandInDir('git', ['init'], SourceDir),
    'Existing Lazarus repo initializes for switch recheck test',
    'Expected git init to succeed in ' + SourceDir);
  AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], SourceDir),
    'Existing Lazarus repo configures git email for switch recheck test',
    'Expected git config user.email to succeed');
  AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], SourceDir),
    'Existing Lazarus repo configures git user for switch recheck test',
    'Expected git config user.name to succeed');
  AssertTrue(RunCommandInDir('git', ['add', 'README.txt', 'ide/fixture.txt', 'lcl/fixture.txt',
    'packager/fixture.txt'], SourceDir),
    'Existing Lazarus repo stages valid source tree for switch recheck test',
    'Expected git add to succeed');
  AssertTrue(RunCommandInDir('git', ['commit', '-m', 'main tree'], SourceDir),
    'Existing Lazarus repo creates main commit for switch recheck test',
    'Expected initial git commit to succeed');
  AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], SourceDir),
    'Existing Lazarus repo renames default branch to main for switch recheck test',
    'Expected git branch -M main to succeed');
  AssertTrue(RunCommandInDir('git', ['checkout', '-b', 'tag_lazarus_3_0'], SourceDir),
    'Existing Lazarus repo creates requested ref branch for switch recheck test',
    'Expected git checkout -b tag_lazarus_3_0 to succeed');
  with TStringList.Create do
  try
    Add('release source tree');
    SaveToFile(ReadmePath);
  finally
    Free;
  end;
  AssertTrue(RunCommandInDir('git', ['add', 'README.txt'], SourceDir),
    'Existing Lazarus repo stages release content for switch recheck test',
    'Expected git add README.txt to succeed');
  AssertTrue(RunCommandInDir('git', ['commit', '-m', 'release tree'], SourceDir),
    'Existing Lazarus repo creates requested-ref commit for switch recheck test',
    'Expected release git commit to succeed');
  AssertTrue(RunCommandInDir('git', ['checkout', 'main'], SourceDir),
    'Existing Lazarus repo returns to wrong ref before switch recheck test',
    'Expected git checkout main to succeed');

  Manager := TLazarusSourceManager.Create(SourceRoot);
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Existing Lazarus switch registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Success := Manager.SwitchLazarusVersion('3.0');

    AssertTrue(Success,
      'Legacy source manager accepts existing valid git source tree on switch',
      'Expected SwitchLazarusVersion(3.0) to succeed for an existing valid repo');

    ReadmeContent := TStringList.Create;
    try
      ReadmeContent.LoadFromFile(ReadmePath);
      AssertTrue((ReadmeContent.Count > 0) and (Trim(ReadmeContent[0]) = 'release source tree'),
        'Legacy source manager switches existing git repo to requested ref',
        'Expected existing Lazarus repo to be switched to registry ref content before reporting success');
    finally
      ReadmeContent.Free;
    end;
    AssertTrue(Manager.GetCurrentVersion = '3.0',
      'Legacy source manager updates current version after repo ref switch succeeds',
      'Expected current version to be 3.0 after successful repo ref switch');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerDoesNotTreatEmptyDirectoryAsInstalled;
var
  Manager: TTestLazarusSourceManager;
  SourceDir: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 12: Legacy Source Manager Does Not Treat Empty Directory As Installed');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-installed');
  try
    SourceDir := Manager.GetLazarusSourcePath('3.0');
    ForceDirectories(SourceDir);

    AssertFalse(Manager.IsVersionInstalled('3.0'),
      'Legacy source manager rejects empty directory as installed version',
      'Expected IsVersionInstalled(3.0) to be false for an empty directory');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerListsOnlyValidLocalVersions;
var
  Manager: TTestLazarusSourceManager;
  InvalidDir: string;
  ValidDir: string;
  Versions: TStringArray;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 13: Legacy Source Manager Lists Only Valid Local Versions');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-local');
  try
    InvalidDir := Manager.GetLazarusSourcePath('3.0');
    ForceDirectories(InvalidDir);

    ValidDir := Manager.GetLazarusSourcePath('main');
    ForceDirectories(ValidDir + PathDelim + 'ide');
    ForceDirectories(ValidDir + PathDelim + 'lcl');
    ForceDirectories(ValidDir + PathDelim + 'packager');

    Versions := Manager.ListLocalVersions;

    AssertTrue(ArrayContainsValue(Versions, 'main'),
      'Legacy source manager keeps valid local version in list',
      'Expected ListLocalVersions to contain main for a valid source tree');
    AssertFalse(ArrayContainsValue(Versions, '3.0'),
      'Legacy source manager excludes invalid local version from list',
      'Expected ListLocalVersions to exclude empty lazarus-3.0 directory');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerRejectsInvalidDirectoryOnUpdate;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 14: Legacy Source Manager Rejects Invalid Directory On Update');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-update');
  try
    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.PullResult := True;
    Manager.SourceClient := Client;

    SourceDir := Manager.GetLazarusSourcePath('3.0');
    ForceDirectories(SourceDir);

    Success := Manager.UpdateLazarusSource('3.0');

    AssertFalse(Success,
      'Legacy source manager rejects invalid directory on update',
      'Expected UpdateLazarusSource(3.0) to fail for directory without ide/lcl/packager');
    AssertTrue(Client.PullCalls = 0,
      'Legacy source manager skips pull for invalid update directory',
      'Expected pull to be skipped for invalid directory, got ' + IntToStr(Client.PullCalls) + ' call(s)');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerRejectsNonConflictingDivergedUpdate;
var
  Manager: TLazarusSourceManager;
  SourceDir: string;
  OriginDir: string;
  WorkDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 14b: Legacy Source Manager Rejects Non-Conflicting Diverged Update');
  WriteLn('==================================================');

  Manager := TLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-update-ffonly');
  try
    SourceDir := Manager.GetLazarusSourcePath('main');
    OriginDir := TestRootDir + PathDelim + 'legacy-lazarus-update-ffonly-origin.git';
    WorkDir := TestRootDir + PathDelim + 'legacy-lazarus-update-ffonly-work';

    AssertTrue(RunCommandInDir('git', ['init', '--bare', OriginDir], TestRootDir),
      'Legacy ff-only update setup creates bare origin repo',
      'Expected git init --bare to succeed for ' + OriginDir);

    ForceDirectories(WorkDir + PathDelim + 'ide');
    ForceDirectories(WorkDir + PathDelim + 'lcl');
    ForceDirectories(WorkDir + PathDelim + 'packager');
    with TStringList.Create do
    try
      Add('initial source tree');
      SaveToFile(WorkDir + PathDelim + 'README.txt');
      Add('ide fixture');
      SaveToFile(WorkDir + PathDelim + 'ide' + PathDelim + 'fixture.txt');
      Add('lcl fixture');
      SaveToFile(WorkDir + PathDelim + 'lcl' + PathDelim + 'fixture.txt');
      Add('packager fixture');
      SaveToFile(WorkDir + PathDelim + 'packager' + PathDelim + 'fixture.txt');
    finally
      Free;
    end;

    AssertTrue(RunCommandInDir('git', ['init'], WorkDir),
      'Legacy ff-only update setup initializes work repo',
      'Expected git init to succeed in ' + WorkDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Legacy ff-only update setup configures git email',
      'Expected git config user.email to succeed');
    AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Legacy ff-only update setup configures git user',
      'Expected git config user.name to succeed');
    AssertTrue(RunCommandInDir('git', ['add', 'README.txt', 'ide/fixture.txt', 'lcl/fixture.txt',
      'packager/fixture.txt'], WorkDir),
      'Legacy ff-only update setup stages source tree',
      'Expected git add to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
      'Legacy ff-only update setup creates initial commit',
      'Expected git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Legacy ff-only update setup renames branch to main',
      'Expected git branch -M main to succeed');
    AssertTrue(RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Legacy ff-only update setup adds origin',
      'Expected git remote add origin to succeed');
    AssertTrue(RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Legacy ff-only update setup pushes initial main',
      'Expected git push -u origin main to succeed');
    AssertTrue(RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, SourceDir], TestRootDir),
      'Legacy ff-only update setup clones source repo',
      'Expected git clone -b main to succeed into ' + SourceDir);

    with TStringList.Create do
    try
      Add('local only');
      SaveToFile(SourceDir + PathDelim + 'local-only.txt');
    finally
      Free;
    end;
    AssertTrue(RunCommandInDir('git', ['add', 'local-only.txt'], SourceDir),
      'Legacy ff-only update setup stages local-only file',
      'Expected git add local-only.txt to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'local change'], SourceDir),
      'Legacy ff-only update setup creates local commit',
      'Expected local git commit to succeed');

    with TStringList.Create do
    try
      Add('remote only');
      SaveToFile(WorkDir + PathDelim + 'remote-only.txt');
    finally
      Free;
    end;
    AssertTrue(RunCommandInDir('git', ['add', 'remote-only.txt'], WorkDir),
      'Legacy ff-only update setup stages remote-only file',
      'Expected git add remote-only.txt to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'remote change'], WorkDir),
      'Legacy ff-only update setup creates remote commit',
      'Expected remote git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['push'], WorkDir),
      'Legacy ff-only update setup pushes remote commit',
      'Expected git push to succeed');

    Success := Manager.UpdateLazarusSource('main');

    AssertFalse(Success,
      'Legacy source manager rejects non-conflicting diverged update',
      'Expected UpdateLazarusSource(main) to fail instead of creating an implicit merge');
    AssertTrue(FileExists(SourceDir + PathDelim + 'local-only.txt'),
      'Legacy source manager keeps local-only file after ff-only rejection',
      'Expected local-only.txt to remain after rejected update');
    AssertFalse(FileExists(SourceDir + PathDelim + 'remote-only.txt'),
      'Legacy source manager does not materialize remote-only file after ff-only rejection',
      'Expected remote-only.txt to be absent after rejected update');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerTracksUpdatedVersionForEmptyArgFollowUp;
var
  Manager: TLazarusSourceManager;
  SourceDir: string;
  OriginDir: string;
  WorkDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 14c: Legacy Source Manager Tracks Updated Version For Empty-Arg Follow-Up');
  WriteLn('==================================================');

  Manager := TLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-update-current');
  try
    SourceDir := Manager.GetLazarusSourcePath('3.0');
    OriginDir := TestRootDir + PathDelim + 'legacy-lazarus-update-current-origin.git';
    WorkDir := TestRootDir + PathDelim + 'legacy-lazarus-update-current-work';

    AssertTrue(RunCommandInDir('git', ['init', '--bare', OriginDir], TestRootDir),
      'Legacy current-version update setup creates bare origin repo',
      'Expected git init --bare to succeed for ' + OriginDir);

    ForceDirectories(WorkDir + PathDelim + 'ide');
    ForceDirectories(WorkDir + PathDelim + 'lcl');
    ForceDirectories(WorkDir + PathDelim + 'packager');
    with TStringList.Create do
    try
      Add('current version update fixture');
      SaveToFile(WorkDir + PathDelim + 'README.txt');
      Add('ide fixture');
      SaveToFile(WorkDir + PathDelim + 'ide' + PathDelim + 'fixture.txt');
      Add('lcl fixture');
      SaveToFile(WorkDir + PathDelim + 'lcl' + PathDelim + 'fixture.txt');
      Add('packager fixture');
      SaveToFile(WorkDir + PathDelim + 'packager' + PathDelim + 'fixture.txt');
    finally
      Free;
    end;

    AssertTrue(RunCommandInDir('git', ['init'], WorkDir),
      'Legacy current-version update setup initializes work repo',
      'Expected git init to succeed in ' + WorkDir);
    AssertTrue(RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Legacy current-version update setup configures git email',
      'Expected git config user.email to succeed');
    AssertTrue(RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Legacy current-version update setup configures git user',
      'Expected git config user.name to succeed');
    AssertTrue(RunCommandInDir('git', ['add', 'README.txt', 'ide/fixture.txt', 'lcl/fixture.txt',
      'packager/fixture.txt'], WorkDir),
      'Legacy current-version update setup stages source tree',
      'Expected git add to succeed');
    AssertTrue(RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
      'Legacy current-version update setup creates initial commit',
      'Expected git commit to succeed');
    AssertTrue(RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Legacy current-version update setup renames branch to main',
      'Expected git branch -M main to succeed');
    AssertTrue(RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Legacy current-version update setup adds origin',
      'Expected git remote add origin to succeed');
    AssertTrue(RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Legacy current-version update setup pushes initial main',
      'Expected git push -u origin main to succeed');
    AssertTrue(RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, SourceDir], TestRootDir),
      'Legacy current-version update setup clones source repo',
      'Expected git clone -b main to succeed into ' + SourceDir);

    Success := Manager.UpdateLazarusSource('3.0');

    AssertTrue(Success,
      'Legacy source manager update succeeds for current-version alignment contract',
      'Expected UpdateLazarusSource(3.0) to succeed for valid source repo');
    AssertTrue(Manager.GetCurrentVersion = '3.0',
      'Legacy source manager records updated version after successful update',
      'Expected current version to be 3.0 after update, got "' + Manager.GetCurrentVersion + '"');
    AssertTrue(Manager.GetLazarusSourcePath('') = SourceDir,
      'Legacy source manager empty-arg path follows updated current version',
      'Expected empty-arg source path to resolve to "' + SourceDir + '", got "' +
      Manager.GetLazarusSourcePath('') + '"');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerRejectsInvalidDirectoryOnBuild;
var
  Manager: TTestLazarusSourceManager;
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 15: Legacy Source Manager Rejects Invalid Directory On Build');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-build');
  try
    SourceDir := Manager.GetLazarusSourcePath('3.0');
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

    Success := Manager.BuildLazarus('3.0');

    AssertFalse(Success,
      'Legacy source manager rejects invalid directory on build',
      'Expected BuildLazarus(3.0) to fail for directory without ide/lcl/packager');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerBuildsValidSourceDirectory;
var
  Manager: TTestLazarusSourceManager;
  SourceDir: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 16: Legacy Source Manager Builds Valid Source Directory');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-build-valid');
  try
    SourceDir := Manager.GetLazarusSourcePath('3.0');
    ForceDirectories(SourceDir + PathDelim + 'ide');
    ForceDirectories(SourceDir + PathDelim + 'lcl');
    ForceDirectories(SourceDir + PathDelim + 'packager');
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

    Success := Manager.BuildLazarus('3.0');

    AssertTrue(Success,
      'Legacy source manager builds valid source directory',
      'Expected BuildLazarus(3.0) to succeed for minimal valid source tree');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerInstallRejectsMissingExecutableAfterBuild;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 16b: Legacy Source Manager Install Rejects Missing Executable After Build');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-install-missing-exe');
  try
    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Manager.SourceClient := Client;

    Success := Manager.InstallLazarusVersion('3.0');

    AssertFalse(Success,
      'Legacy source manager install rejects missing executable after build',
      'Expected InstallLazarusVersion(3.0) to fail when build does not produce Lazarus executable');
    AssertTrue(Manager.GetCurrentVersion = '',
      'Legacy source manager keeps current version unchanged when executable is missing',
      'Expected current version to stay empty, got "' + Manager.GetCurrentVersion + '"');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerInstallSucceedsWhenExecutableBuilt;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  ExecutablePath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 16c: Legacy Source Manager Install Succeeds When Executable Built');
  WriteLn('==================================================');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-install-valid');
  try
    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Client.AutoCreateLegacyExecutableOnBuild := True;
    Manager.SourceClient := Client;

    Success := Manager.InstallLazarusVersion('3.0');
    ExecutablePath := Manager.GetLazarusExecutablePath('3.0');

    AssertTrue(Success,
      'Legacy source manager install succeeds when executable is built',
      'Expected InstallLazarusVersion(3.0) to succeed when build creates Lazarus executable');
    AssertTrue(FileExists(ExecutablePath),
      'Legacy source manager install leaves built executable in source tree',
      'Expected executable to exist at "' + ExecutablePath + '"');
    AssertTrue(Manager.GetCurrentVersion = '3.0',
      'Legacy source manager install updates current version after success',
      'Expected current version to be 3.0, got "' + Manager.GetCurrentVersion + '"');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerInstallConfiguresCustomFPCPath;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  ConfigRoot: string;
  OriginalConfigRoot: string;
  ConfigDir: string;
  SourcePath: string;
  FPCPath: string;
  IDEConfig: TLazarusIDEConfig;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 16d: Legacy Source Manager Install Configures Custom FPC Path');
  WriteLn('==================================================');

  ConfigRoot := IncludeTrailingPathDelimiter(TestRootDir) + 'legacy-lazarus-config-root';
  OriginalConfigRoot := GetEnvironmentVariable('FPDEV_LAZARUS_CONFIG_ROOT');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-install-config');
  try
    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Client.AutoCreateLegacyExecutableOnBuild := True;
    Manager.SourceClient := Client;

    ForceDirectories(TestRootDir + PathDelim + 'mock-fpc' + PathDelim + 'bin');
    {$IFDEF MSWINDOWS}
    FPCPath := TestRootDir + PathDelim + 'mock-fpc' + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCPath := TestRootDir + PathDelim + 'mock-fpc' + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}
    WriteMockExecutable(FPCPath, 'mock fpc');

    AssertTrue(set_env('FPDEV_LAZARUS_CONFIG_ROOT', ConfigRoot),
      'Legacy source manager install sets isolated config root',
      'Expected isolated config root "' + ConfigRoot + '" to be set');

    Manager.SetFPCPath(FPCPath);
    Success := Manager.InstallLazarusVersion('3.0');
    SourcePath := Manager.GetLazarusSourcePath('3.0');
    ConfigDir := ResolveLazarusConfigDirCore(
      '3.0',
      ConfigRoot,
      GetEnvironmentVariable('HOME'),
      GetEnvironmentVariable('APPDATA')
    );

    AssertTrue(Success,
      'Legacy source manager install succeeds with custom FPC path',
      'Expected InstallLazarusVersion(3.0) to succeed when custom FPC path is provided');
    AssertTrue(FileExists(ConfigDir + PathDelim + 'environmentoptions.xml'),
      'Legacy source manager install writes environment options for custom FPC path',
      'Expected environmentoptions.xml under "' + ConfigDir + '"');

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      AssertTrue(IDEConfig.GetCompilerPath = FPCPath,
        'Legacy source manager install records custom compiler path',
        'Expected compiler path "' + FPCPath + '", got "' + IDEConfig.GetCompilerPath + '"');
      AssertTrue(IDEConfig.GetLibraryPath = SourcePath,
        'Legacy source manager install records source tree as Lazarus directory',
        'Expected Lazarus directory "' + SourcePath + '", got "' + IDEConfig.GetLibraryPath + '"');
      AssertTrue(IDEConfig.ValidateConfig,
        'Legacy source manager install produces valid config for custom FPC path',
        'Expected Lazarus IDE config in "' + ConfigDir + '" to validate');
    finally
      IDEConfig.Free;
    end;
  finally
    if OriginalConfigRoot <> '' then
      set_env('FPDEV_LAZARUS_CONFIG_ROOT', OriginalConfigRoot)
    else
      unset_env('FPDEV_LAZARUS_CONFIG_ROOT');
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerInstallUsesSameProcessHomeWhenConfigRootUnset;
var
  Manager: TTestLazarusSourceManager;
  Client: TProbeLazarusGitClient;
  Success: Boolean;
  SavedConfigRoot: string;
  SavedHome: string;
  SavedAppData: string;
  ProbeConfigBase: string;
  ConfigDir: string;
  SourcePath: string;
  FPCPath: string;
  IDEConfig: TLazarusIDEConfig;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 16d2: Legacy Source Manager Install Uses Same-Process HOME/APPDATA When Config Root Is Unset');
  WriteLn('==================================================');

  SavedConfigRoot := get_env('FPDEV_LAZARUS_CONFIG_ROOT');
  SavedHome := get_env('HOME');
  SavedAppData := get_env('APPDATA');

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-install-config-home');
  try
    Client := TProbeLazarusGitClient.Create;
    Client.BackendValue := gbLibgit2;
    Client.CloneResult := True;
    Client.AutoCreateSourceTree := True;
    Client.AutoCreateLegacyExecutableOnBuild := True;
    Manager.SourceClient := Client;

    unset_env('FPDEV_LAZARUS_CONFIG_ROOT');
    ProbeConfigBase := IncludeTrailingPathDelimiter(TestRootDir) + 'legacy-lazarus-home-config-root';
    ForceDirectories(ProbeConfigBase);

    {$IFDEF MSWINDOWS}
    AssertTrue(set_env('APPDATA', ProbeConfigBase),
      'Legacy source manager install sets same-process APPDATA',
      'Expected APPDATA to be set to "' + ProbeConfigBase + '"');
    ConfigDir := ExcludeTrailingPathDelimiter(ProbeConfigBase) + PathDelim + 'lazarus-3.0';
    {$ELSE}
    AssertTrue(set_env('HOME', ProbeConfigBase),
      'Legacy source manager install sets same-process HOME',
      'Expected HOME to be set to "' + ProbeConfigBase + '"');
    ConfigDir := ExcludeTrailingPathDelimiter(ProbeConfigBase) + PathDelim + '.lazarus-3.0';
    {$ENDIF}

    ForceDirectories(TestRootDir + PathDelim + 'mock-fpc-home' + PathDelim + 'bin');
    {$IFDEF MSWINDOWS}
    FPCPath := TestRootDir + PathDelim + 'mock-fpc-home' + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCPath := TestRootDir + PathDelim + 'mock-fpc-home' + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}
    WriteMockExecutable(FPCPath, 'mock fpc home');

    Manager.SetFPCPath(FPCPath);
    Success := Manager.InstallLazarusVersion('3.0');
    SourcePath := Manager.GetLazarusSourcePath('3.0');

    AssertTrue(Success,
      'Legacy source manager install succeeds with same-process HOME/APPDATA override',
      'Expected InstallLazarusVersion(3.0) to succeed when config root is unset');
    AssertTrue(FileExists(ConfigDir + PathDelim + 'environmentoptions.xml'),
      'Legacy source manager install writes config under same-process HOME/APPDATA override',
      'Expected environmentoptions.xml under "' + ConfigDir + '"');

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      AssertTrue(IDEConfig.GetCompilerPath = FPCPath,
        'Legacy source manager install records compiler path under same-process HOME/APPDATA override',
        'Expected compiler path "' + FPCPath + '", got "' + IDEConfig.GetCompilerPath + '"');
      AssertTrue(IDEConfig.GetLibraryPath = SourcePath,
        'Legacy source manager install records source path under same-process HOME/APPDATA override',
        'Expected Lazarus directory "' + SourcePath + '", got "' + IDEConfig.GetLibraryPath + '"');
      AssertTrue(IDEConfig.ValidateConfig,
        'Legacy source manager install keeps config valid under same-process HOME/APPDATA override',
        'Expected Lazarus IDE config in "' + ConfigDir + '" to validate');
    finally
      IDEConfig.Free;
    end;
  finally
    RestoreEnv('FPDEV_LAZARUS_CONFIG_ROOT', SavedConfigRoot);
    RestoreEnv('HOME', SavedHome);
    RestoreEnv('APPDATA', SavedAppData);
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerLaunchesBuiltExecutableWithoutWaiting;
{$IFDEF UNIX}
var
  Manager: TTestLazarusSourceManager;
  SourceDir: string;
  MarkerPath: string;
  Success: Boolean;
  StartedAt: QWord;
  ElapsedMs: QWord;
{$ENDIF}
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 16e: Legacy Source Manager Launches Built Executable Without Waiting');
  WriteLn('==================================================');

  {$IFNDEF UNIX}
  AssertTrue(True, 'Legacy source manager launch contract skipped on non-UNIX',
    'This runtime launch contract uses a POSIX shell script fixture.');
  Exit;
  {$ENDIF}

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-launch-runtime');
  try
    SourceDir := Manager.GetLazarusSourcePath('3.0');
    MarkerPath := TestRootDir + PathDelim + 'legacy-lazarus-launch.marker';
    ForceDirectories(SourceDir + PathDelim + 'ide');
    ForceDirectories(SourceDir + PathDelim + 'lcl');
    ForceDirectories(SourceDir + PathDelim + 'packager');
    with TStringList.Create do
    try
      Add('clean:');
      Add(#9 + '@true');
      Add('all:');
      Add(#9 + 'echo ''#!/bin/sh'' > "lazarus"');
      Add(#9 + 'echo ''sleep 1'' >> "lazarus"');
      Add(#9 + 'echo ''printf "%s" "legacy launch" > "' + MarkerPath + '"'' >> "lazarus"');
      Add(#9 + 'chmod +x "lazarus"');
      SaveToFile(SourceDir + PathDelim + 'Makefile');
    finally
      Free;
    end;

    AssertTrue(Manager.BuildLazarus('3.0'),
      'Legacy source manager builds executable before launch contract',
      'Expected BuildLazarus(3.0) to succeed for launch runtime contract setup');

    StartedAt := GetTickCount64;
    Success := Manager.LaunchLazarus('3.0');
    ElapsedMs := GetTickCount64 - StartedAt;

    AssertTrue(Success,
      'Legacy source manager launches built executable',
      'Expected LaunchLazarus(3.0) to start the built Lazarus executable');
    AssertTrue(ElapsedMs < 800,
      'Legacy source manager launch returns without waiting for executable exit',
      'Expected LaunchLazarus(3.0) to return quickly, but it took ' + IntToStr(ElapsedMs) + ' ms');
    AssertFalse(FileExists(MarkerPath),
      'Legacy source manager launch does not block until marker is written',
      'Expected marker "' + MarkerPath + '" to be absent immediately after launch returns');
    AssertTrue(WaitForFile(MarkerPath, 2500),
      'Legacy source manager launch executes built executable from source tree',
      'Expected launch marker "' + MarkerPath + '" to be created by the built executable');
  finally
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerDescribesRegistryOnlyVersion;
var
  Manager: TTestLazarusSourceManager;
  Description: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 13: Legacy Source Manager Describes Registry-Only Version');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-description.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "9.9",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "9.9",');
    Add('        "release_date": "2099-09-09",');
    Add('        "git_tag": "lazarus_9_9",');
    Add('        "branch": "lazarus_9_9",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-description');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom legacy description registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Description := Manager.GetLazarusVersion('9.9');

    AssertTrue(Description = 'Lazarus 9.9 (stable)',
      'Legacy source manager describes registry-only version',
      'Expected "Lazarus 9.9 (stable)", got "' + Description + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerKeepsStaticDescriptionOpaqueWhenRegistryPresent;
var
  Manager: TTestLazarusSourceManager;
  Description: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 13b: Legacy Source Manager Keeps Static Description Opaque When Registry Present');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-authoritative-description.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "9.9",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "9.9",');
    Add('        "release_date": "2099-09-09",');
    Add('        "git_tag": "lazarus_9_9",');
    Add('        "branch": "lazarus_9_9",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-authoritative-description');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom authoritative legacy description registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Description := Manager.GetLazarusVersion('3.0');

    AssertTrue(Description = '3.0',
      'Legacy source manager keeps static-only description opaque when registry is present',
      'Expected "3.0", got "' + Description + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerUsesStaticDescriptionWhenRegistryEmpty;
var
  Manager: TTestLazarusSourceManager;
  Description: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 13c: Legacy Source Manager Uses Static Description When Registry Empty');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-empty-description.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.0",');
    Add('    "releases": []');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-empty-description');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom empty legacy description registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    Description := Manager.GetLazarusVersion('3.0');

    AssertTrue(Description = 'Lazarus 3.0 (stable)',
      'Legacy source manager keeps static description fallback when registry is empty',
      'Expected "Lazarus 3.0 (stable)", got "' + Description + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerKeepsStaticBranchReadbackOpaqueWhenRegistryPresent;
var
  Manager: TTestLazarusSourceManager;
  VersionName: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 13d: Legacy Source Manager Keeps Static Branch Readback Opaque When Registry Present');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-authoritative-readback.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "9.9",');
    Add('    "releases": [');
    Add('      {');
    Add('        "version": "9.9",');
    Add('        "release_date": "2099-09-09",');
    Add('        "git_tag": "lazarus_9_9",');
    Add('        "branch": "lazarus_9_9",');
    Add('        "channel": "stable",');
    Add('        "fpc_compatible": ["3.2.2"]');
    Add('      }');
    Add('    ]');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-authoritative-readback');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom authoritative legacy readback registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    VersionName := Manager.RunGetVersionFromBranch('lazarus_3_0');

    AssertTrue(VersionName = 'lazarus_3_0',
      'Legacy source manager keeps static-only branch readback opaque when registry is present',
      'Expected "lazarus_3_0", got "' + VersionName + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

procedure TestLegacySourceManagerResolvesStaticBranchReadbackWhenRegistryEmpty;
var
  Manager: TTestLazarusSourceManager;
  VersionName: string;
  OriginalRegistryPath: string;
  VersionsJSONPath: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 13e: Legacy Source Manager Resolves Static Branch Readback When Registry Empty');
  WriteLn('==================================================');

  OriginalRegistryPath := TVersionRegistry.Instance.DataPath;
  VersionsJSONPath := TestRootDir + PathDelim + 'versions-lazarus-source-empty-readback.json';

  with TStringList.Create do
  try
    Add('{');
    Add('  "schema_version": "1.0",');
    Add('  "updated_at": "test",');
    Add('  "lazarus": {');
    Add('    "default_version": "3.0",');
    Add('    "releases": []');
    Add('  }');
    Add('}');
    SaveToFile(VersionsJSONPath);
  finally
    Free;
  end;

  Manager := TTestLazarusSourceManager.Create(TestRootDir + PathDelim + 'legacy-lazarus-empty-readback');
  try
    TVersionRegistry.Instance.DataPath := VersionsJSONPath;
    AssertTrue(TVersionRegistry.Instance.Reload,
      'Custom empty legacy readback registry data reloads',
      'Expected registry reload to succeed for ' + VersionsJSONPath);

    VersionName := Manager.RunGetVersionFromBranch('lazarus_3_0');

    AssertTrue(VersionName = '3.0',
      'Legacy source manager resolves static branch readback when registry is empty',
      'Expected "3.0", got "' + VersionName + '"');
  finally
    TVersionRegistry.Instance.DataPath := OriginalRegistryPath;
    TVersionRegistry.Instance.Reload;
    Manager.Free;
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  Lazarus Update Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
  TestConfigManagerUsesIsolatedDefaultConfigPath;
  TestUpdateRefreshesSourceRepository;
  TestUpdateRejectsInvalidRepository;
  TestUpdateReportsMissingSourceDirectory;
  TestUpdateTriggersRebuildNotification;
  TestUpdateRejectsNonSourceGitRepository;
  TestUpdateReportsInvalidSourceDirectory;
  TestDownloadSourcePrefersLibgit2WhenCLIUnavailable;
  TestDownloadSourceUsesRegistryRepositoryURL;
  TestInstallVersionPersistsRegistryRepositoryURL;
  TestInstallVersionUsesSameProcessPathForBuildEnv;
  TestLegacySourceManagerUsesRegistryRepositoryURL;
  TestLegacySourceManagerListsRegistryVersion;
  TestLegacySourceManagerDoesNotListStaticOnlyVersionWhenRegistryPresent;
  TestLegacySourceManagerKeepsStaticBranchOpaqueWhenRegistryPresent;
  TestLegacySourceManagerUsesRegistryBranchForVersion;
  TestLegacySourceManagerPrefersRegistryGitTagForVersion;
  TestLegacySourceManagerRejectsCloneWithoutValidSourceTree;
  TestLegacySourceManagerFallsBackToCloneForInvalidInstalledDirectory;
  TestLegacySourceManagerSwitchesExistingGitRepoToRequestedRef;
  TestLegacySourceManagerDoesNotTreatEmptyDirectoryAsInstalled;
  TestLegacySourceManagerListsOnlyValidLocalVersions;
  TestLegacySourceManagerRejectsInvalidDirectoryOnUpdate;
  TestLegacySourceManagerRejectsNonConflictingDivergedUpdate;
  TestLegacySourceManagerTracksUpdatedVersionForEmptyArgFollowUp;
  TestLegacySourceManagerRejectsInvalidDirectoryOnBuild;
  TestLegacySourceManagerBuildsValidSourceDirectory;
  TestLegacySourceManagerInstallRejectsMissingExecutableAfterBuild;
  TestLegacySourceManagerInstallSucceedsWhenExecutableBuilt;
  TestLegacySourceManagerInstallConfiguresCustomFPCPath;
  TestLegacySourceManagerInstallUsesSameProcessHomeWhenConfigRootUnset;
  TestLegacySourceManagerLaunchesBuiltExecutableWithoutWaiting;
  TestLegacySourceManagerDescribesRegistryOnlyVersion;
  TestLegacySourceManagerKeepsStaticDescriptionOpaqueWhenRegistryPresent;
  TestLegacySourceManagerUsesStaticDescriptionWhenRegistryEmpty;
  TestLegacySourceManagerKeepsStaticBranchReadbackOpaqueWhenRegistryPresent;
  TestLegacySourceManagerResolvesStaticBranchReadbackWhenRegistryEmpty;

      // Exit with error if any tests failed
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
