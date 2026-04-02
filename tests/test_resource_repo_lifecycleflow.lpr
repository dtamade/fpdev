program test_resource_repo_lifecycleflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson,
  test_temp_paths,
  fpdev.resource.repo.lifecycle,
  fpdev.resource.repo,
  fpdev.resource.repo.types,
  fpdev.utils.process;

type
  TRepoLifecycleHarness = class
  private
    FCloneResults: TStringList;
  public
    LogLines: TStringList;
    CloneURLs: TStringList;
    IsRepo: Boolean;
    CommitHash: string;
    PullResult: Boolean;
    ManifestLoadResult: Boolean;
    PullCalls: Integer;
    ManifestLoadCalls: Integer;
    TouchCalls: Integer;
    constructor Create;
    destructor Destroy; override;
    function IsGitRepository: Boolean;
    function GetLastCommitHash: string;
    function GitClone(const AURL: string): Boolean;
    function GitPull: Boolean;
    function LoadManifest: Boolean;
    procedure LogLine(const AMsg: string);
    procedure TouchUpdateCheck;
    procedure SetCloneResult(const AURL: string; AValue: Boolean);
  end;

  TManifestLogHarness = class
  public
    Logs: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure LogLine(const AMsg: string);
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TRepoLifecycleHarness.Create;
begin
  inherited Create;
  FCloneResults := TStringList.Create;
  LogLines := TStringList.Create;
  CloneURLs := TStringList.Create;
  IsRepo := False;
  CommitHash := 'unknown';
  PullResult := True;
  ManifestLoadResult := True;
end;

destructor TRepoLifecycleHarness.Destroy;
begin
  CloneURLs.Free;
  LogLines.Free;
  FCloneResults.Free;
  inherited Destroy;
end;

constructor TManifestLogHarness.Create;
begin
  inherited Create;
  Logs := TStringList.Create;
end;

destructor TManifestLogHarness.Destroy;
begin
  Logs.Free;
  inherited Destroy;
end;

procedure TManifestLogHarness.LogLine(const AMsg: string);
begin
  Logs.Add(AMsg);
end;

function TRepoLifecycleHarness.IsGitRepository: Boolean;
begin
  Result := IsRepo;
end;

function TRepoLifecycleHarness.GetLastCommitHash: string;
begin
  Result := CommitHash;
end;

function TRepoLifecycleHarness.GitClone(const AURL: string): Boolean;
var
  Index: Integer;
begin
  CloneURLs.Add(AURL);
  Index := FCloneResults.IndexOfName(AURL);
  Result := (Index >= 0) and SameText(FCloneResults.ValueFromIndex[Index], '1');
end;

function TRepoLifecycleHarness.GitPull: Boolean;
begin
  Inc(PullCalls);
  Result := PullResult;
end;

function TRepoLifecycleHarness.LoadManifest: Boolean;
begin
  Inc(ManifestLoadCalls);
  Result := ManifestLoadResult;
end;

procedure TRepoLifecycleHarness.LogLine(const AMsg: string);
begin
  LogLines.Add(AMsg);
end;

procedure TRepoLifecycleHarness.TouchUpdateCheck;
begin
  Inc(TouchCalls);
end;

procedure TRepoLifecycleHarness.SetCloneResult(const AURL: string; AValue: Boolean);
begin
  if AValue then
    FCloneResults.Values[AURL] := '1'
  else
    FCloneResults.Values[AURL] := '0';
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

procedure WriteTextFile(const APath, AText: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

function RunCommandInDir(const AProgram: string; const AArgs: array of string;
  const AWorkDir: string): Boolean;
var
  ProcResult: TProcessResult;
begin
  ProcResult := TProcessExecutor.Execute(AProgram, AArgs, AWorkDir);
  Result := ProcResult.Success and (ProcResult.ExitCode = 0);
  if not Result then
  begin
    WriteLn('  [CMD FAIL] ', AProgram, ' in ', AWorkDir);
    if ProcResult.StdOut <> '' then
      WriteLn('  stdout: ', ProcResult.StdOut);
    if ProcResult.StdErr <> '' then
      WriteLn('  stderr: ', ProcResult.StdErr);
    if ProcResult.ErrorMessage <> '' then
      WriteLn('  error: ', ProcResult.ErrorMessage);
  end;
end;

procedure TestInitializeUsesExistingRepoAndRefreshesWhenNeeded;
var
  Harness: TRepoLifecycleHarness;
  Mirrors: TStringArray;
  OK: Boolean;
begin
  Harness := TRepoLifecycleHarness.Create;
  try
    Harness.IsRepo := True;
    Harness.CommitHash := 'abc123';
    Harness.PullResult := False;
    Harness.ManifestLoadResult := True;
    SetLength(Mirrors, 0);

    OK := ExecuteResourceRepoInitializeCore(
      '/tmp/fpdev-repo',
      'https://primary/repo.git',
      Mirrors,
      True,
      @Harness.IsGitRepository,
      @Harness.GetLastCommitHash,
      @Harness.GitClone,
      @Harness.GitPull,
      @Harness.LoadManifest,
      @Harness.LogLine,
      @Harness.TouchUpdateCheck
    );

    Check('initialize existing repo returns true', OK, 'expected success');
    Check('initialize existing repo logs location',
      Pos('Resource repository already exists at: /tmp/fpdev-repo', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('initialize existing repo logs commit',
      Pos('Commit: abc123', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('initialize existing repo still pulls when update needed', Harness.PullCalls = 1,
      'pull calls=' + IntToStr(Harness.PullCalls));
    Check('initialize existing repo touches update check', Harness.TouchCalls = 1,
      'touch calls=' + IntToStr(Harness.TouchCalls));
    Check('initialize existing repo loads manifest once', Harness.ManifestLoadCalls = 1,
      'manifest calls=' + IntToStr(Harness.ManifestLoadCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestInitializeFallsBackToMirror;
var
  Harness: TRepoLifecycleHarness;
  Mirrors: TStringArray;
  OK: Boolean;
begin
  Harness := TRepoLifecycleHarness.Create;
  try
    Harness.SetCloneResult('https://primary/repo.git', False);
    Harness.SetCloneResult('https://mirror-one/repo.git', True);
    SetLength(Mirrors, 2);
    Mirrors[0] := 'https://mirror-one/repo.git';
    Mirrors[1] := 'https://mirror-two/repo.git';

    OK := ExecuteResourceRepoInitializeCore(
      '/tmp/fpdev-repo',
      'https://primary/repo.git',
      Mirrors,
      False,
      @Harness.IsGitRepository,
      @Harness.GetLastCommitHash,
      @Harness.GitClone,
      @Harness.GitPull,
      @Harness.LoadManifest,
      @Harness.LogLine,
      @Harness.TouchUpdateCheck
    );

    Check('initialize mirror fallback returns true', OK, 'expected success');
    Check('initialize mirror fallback tries primary then first mirror',
      (Harness.CloneURLs.Count = 2) and
      (Harness.CloneURLs[0] = 'https://primary/repo.git') and
      (Harness.CloneURLs[1] = 'https://mirror-one/repo.git'),
      Harness.CloneURLs.Text);
    Check('initialize mirror fallback logs primary failure',
      Pos('Failed to clone from primary URL, trying mirrors...', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('initialize mirror fallback logs mirror try',
      Pos('Trying mirror 1: https://mirror-one/repo.git', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('initialize mirror fallback touches update check', Harness.TouchCalls = 1,
      'touch calls=' + IntToStr(Harness.TouchCalls));
    Check('initialize mirror fallback loads manifest', Harness.ManifestLoadCalls = 1,
      'manifest calls=' + IntToStr(Harness.ManifestLoadCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestInitializeFailsWhenAllSourcesFail;
var
  Harness: TRepoLifecycleHarness;
  Mirrors: TStringArray;
  OK: Boolean;
begin
  Harness := TRepoLifecycleHarness.Create;
  try
    Harness.SetCloneResult('https://primary/repo.git', False);
    Harness.SetCloneResult('https://mirror-one/repo.git', False);
    SetLength(Mirrors, 1);
    Mirrors[0] := 'https://mirror-one/repo.git';

    OK := ExecuteResourceRepoInitializeCore(
      '/tmp/fpdev-repo',
      'https://primary/repo.git',
      Mirrors,
      False,
      @Harness.IsGitRepository,
      @Harness.GetLastCommitHash,
      @Harness.GitClone,
      @Harness.GitPull,
      @Harness.LoadManifest,
      @Harness.LogLine,
      @Harness.TouchUpdateCheck
    );

    Check('initialize all sources fail returns false', not OK, 'expected failure');
    Check('initialize all sources fail logs terminal error',
      Pos('Failed to clone resource repository from any source', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('initialize all sources fail skips manifest load', Harness.ManifestLoadCalls = 0,
      'manifest calls=' + IntToStr(Harness.ManifestLoadCalls));
    Check('initialize all sources fail skips touch', Harness.TouchCalls = 0,
      'touch calls=' + IntToStr(Harness.TouchCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestUpdateRejectsUninitializedRepo;
var
  Harness: TRepoLifecycleHarness;
  OK: Boolean;
begin
  Harness := TRepoLifecycleHarness.Create;
  try
    OK := ExecuteResourceRepoUpdateCore(
      True,
      False,
      0,
      @Harness.IsGitRepository,
      @Harness.GitPull,
      @Harness.LoadManifest,
      @Harness.LogLine,
      @Harness.TouchUpdateCheck
    );

    Check('update uninitialized repo returns false', not OK, 'expected failure');
    Check('update uninitialized repo logs error',
      Pos('Error: Resource repository not initialized', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestUpdatePullsAndWarnsOnManifestReloadFailure;
var
  Harness: TRepoLifecycleHarness;
  OK: Boolean;
begin
  Harness := TRepoLifecycleHarness.Create;
  try
    Harness.IsRepo := True;
    Harness.PullResult := True;
    Harness.ManifestLoadResult := False;

    OK := ExecuteResourceRepoUpdateCore(
      True,
      False,
      0,
      @Harness.IsGitRepository,
      @Harness.GitPull,
      @Harness.LoadManifest,
      @Harness.LogLine,
      @Harness.TouchUpdateCheck
    );

    Check('update force pull returns true', OK, 'expected success');
    Check('update force pull touches update check', Harness.TouchCalls = 1,
      'touch calls=' + IntToStr(Harness.TouchCalls));
    Check('update force pull reloads manifest once', Harness.ManifestLoadCalls = 1,
      'manifest calls=' + IntToStr(Harness.ManifestLoadCalls));
    Check('update force pull logs reload warning',
      Pos('Warning: Git pull succeeded but manifest reload failed', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestUpdateSkipsPullWhenFresh;
var
  Harness: TRepoLifecycleHarness;
  OK: Boolean;
  LastCheck: TDateTime;
begin
  Harness := TRepoLifecycleHarness.Create;
  try
    Harness.IsRepo := True;
    LastCheck := EncodeDate(2026, 3, 9) + EncodeTime(12, 0, 0, 0);

    OK := ExecuteResourceRepoUpdateCore(
      False,
      False,
      LastCheck,
      @Harness.IsGitRepository,
      @Harness.GitPull,
      @Harness.LoadManifest,
      @Harness.LogLine,
      @Harness.TouchUpdateCheck
    );

    Check('update fresh repo returns true', OK, 'expected success');
    Check('update fresh repo skips pull', Harness.PullCalls = 0,
      'pull calls=' + IntToStr(Harness.PullCalls));
    Check('update fresh repo logs up-to-date message',
      Pos('Resource repository is up to date (last check: ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestUpdateSkipsPullWhenNeverCheckedAndAutoUpdateDisabled;
var
  Harness: TRepoLifecycleHarness;
  OK: Boolean;
begin
  Harness := TRepoLifecycleHarness.Create;
  try
    Harness.IsRepo := True;

    OK := ExecuteResourceRepoUpdateCore(
      False,
      False,
      0,
      @Harness.IsGitRepository,
      @Harness.GitPull,
      @Harness.LoadManifest,
      @Harness.LogLine,
      @Harness.TouchUpdateCheck
    );

    Check('update never-checked repo returns true when no refresh requested', OK, 'expected success');
    Check('update never-checked repo still skips pull', Harness.PullCalls = 0,
      'pull calls=' + IntToStr(Harness.PullCalls));
    Check('update never-checked repo logs never instead of epoch',
      Pos('Resource repository is up to date (last check: never)', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('update never-checked repo does not log epoch date',
      Pos('1899', Harness.LogLines.Text) = 0, Harness.LogLines.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestLoadManifestParsesJson;
var
  RootDir: string;
  ManifestPath: string;
  Logger: TManifestLogHarness;
  ManifestData: TJSONObject;
  Loaded: Boolean;
  OK: Boolean;

begin
  RootDir := CreateUniqueTempDir('repo-lifecycle-manifest-ok');
  Logger := TManifestLogHarness.Create;
  ManifestData := nil;
  Loaded := False;
  try
    ManifestPath := RootDir + PathDelim + 'manifest.json';
    WriteTextFile(ManifestPath, '{"version":"2.1.0","name":"fpdev-repo"}');

    OK := LoadResourceRepoManifestCore(ManifestPath, @Logger.LogLine, ManifestData, Loaded);

    Check('load manifest success returns true', OK, 'expected success');
    Check('load manifest marks loaded', Loaded, 'expected loaded');
    Check('load manifest returns object', Assigned(ManifestData), 'manifest nil');
    Check('load manifest keeps version', Assigned(ManifestData) and
      (ManifestData.Get('version', '') = '2.1.0'), 'version mismatch');
    Check('load manifest logs version',
      Pos('Manifest loaded (version: 2.1.0)', Logger.Logs.Text) > 0, Logger.Logs.Text);
  finally
    if Assigned(ManifestData) then
      ManifestData.Free;
    Logger.Free;
    CleanupTempDir(RootDir);
  end;
end;

procedure TestLoadManifestMissingFile;
var
  RootDir: string;
  Logger: TManifestLogHarness;
  ManifestData: TJSONObject;
  Loaded: Boolean;
  OK: Boolean;

begin
  RootDir := CreateUniqueTempDir('repo-lifecycle-manifest-missing');
  Logger := TManifestLogHarness.Create;
  ManifestData := nil;
  Loaded := False;
  try
    OK := LoadResourceRepoManifestCore(RootDir + PathDelim + 'manifest.json', @Logger.LogLine,
      ManifestData, Loaded);

    Check('load manifest missing file returns false', not OK, 'expected failure');
    Check('load manifest missing file leaves loaded false', not Loaded, 'expected unloaded');
    Check('load manifest missing file returns nil object', not Assigned(ManifestData), 'manifest should be nil');
    Check('load manifest missing file logs warning',
      Pos('Warning: manifest.json not found in resource repository', Logger.Logs.Text) > 0,
      Logger.Logs.Text);
  finally
    if Assigned(ManifestData) then
      ManifestData.Free;
    Logger.Free;
    CleanupTempDir(RootDir);
  end;
end;

procedure TestEnsureManifestLoadedShortCircuits;
var
  Harness: TRepoLifecycleHarness;
  Manifest: TJSONObject;
  OK: Boolean;
begin
  Harness := TRepoLifecycleHarness.Create;
  Manifest := TJSONObject.Create;
  try
    Manifest.Add('version', 'cached');
    OK := EnsureResourceRepoManifestLoadedCore(True, Manifest, @Harness.LoadManifest);
    Check('ensure manifest loaded cached returns true', OK, 'expected success');
    Check('ensure manifest loaded cached skips reload', Harness.ManifestLoadCalls = 0,
      'manifest calls=' + IntToStr(Harness.ManifestLoadCalls));
  finally
    Manifest.Free;
    Harness.Free;
  end;
end;

procedure TestEnsureManifestLoadedDelegatesReload;
var
  Harness: TRepoLifecycleHarness;
  OK: Boolean;
begin
  Harness := TRepoLifecycleHarness.Create;
  try
    Harness.ManifestLoadResult := True;
    OK := EnsureResourceRepoManifestLoadedCore(False, nil, @Harness.LoadManifest);
    Check('ensure manifest loaded delegates when missing', OK, 'expected success');
    Check('ensure manifest loaded calls reload once', Harness.ManifestLoadCalls = 1,
      'manifest calls=' + IntToStr(Harness.ManifestLoadCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestResourceRepositoryUpdateRejectsNonConflictingDivergedHistory;
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalRepoDir: string;
  Repo: TResourceRepository;
  Config: TResourceRepoConfig;
  OK: Boolean;
begin
  RootDir := CreateUniqueTempDir('repo-lifecycle-update-ffonly');
  try
    OriginDir := RootDir + PathDelim + 'resource-origin.git';
    WorkDir := RootDir + PathDelim + 'resource-work';
    LocalRepoDir := RootDir + PathDelim + 'resource-local';

    ForceDirectories(WorkDir);
    Check('resource repo ff-only setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);

    WriteTextFile(WorkDir + PathDelim + 'manifest.json', '{"version":"1.0.0"}');
    Check('resource repo ff-only setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('resource repo ff-only setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('resource repo ff-only setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    Check('resource repo ff-only setup stages manifest',
      RunCommandInDir('git', ['add', 'manifest.json'], WorkDir),
      'Expected git add manifest.json to succeed');
    Check('resource repo ff-only setup commits initial manifest',
      RunCommandInDir('git', ['commit', '-m', 'initial'], WorkDir),
      'Expected git commit to succeed');
    Check('resource repo ff-only setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('resource repo ff-only setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('resource repo ff-only setup pushes initial main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');
    Check('resource repo ff-only setup clones local repo',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, LocalRepoDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalRepoDir);
    Check('resource repo ff-only setup configures local repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], LocalRepoDir),
      'Expected git config user.email to succeed in local repo');
    Check('resource repo ff-only setup configures local repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], LocalRepoDir),
      'Expected git config user.name to succeed in local repo');

    WriteTextFile(LocalRepoDir + PathDelim + 'local-only.txt', 'local only');
    Check('resource repo ff-only setup stages local-only file',
      RunCommandInDir('git', ['add', 'local-only.txt'], LocalRepoDir),
      'Expected git add local-only.txt to succeed');
    Check('resource repo ff-only setup commits local-only file',
      RunCommandInDir('git', ['commit', '-m', 'local change'], LocalRepoDir),
      'Expected local git commit to succeed');

    WriteTextFile(WorkDir + PathDelim + 'remote-only.txt', 'remote only');
    Check('resource repo ff-only setup stages remote-only file',
      RunCommandInDir('git', ['add', 'remote-only.txt'], WorkDir),
      'Expected git add remote-only.txt to succeed');
    Check('resource repo ff-only setup commits remote-only file',
      RunCommandInDir('git', ['commit', '-m', 'remote change'], WorkDir),
      'Expected remote git commit to succeed');
    Check('resource repo ff-only setup pushes remote change',
      RunCommandInDir('git', ['push'], WorkDir),
      'Expected git push to succeed');

    Config := EmptyResourceRepoConfig;
    Config.LocalPath := LocalRepoDir;
    Config.URL := OriginDir;
    Config.Branch := 'main';
    Config.AutoUpdate := False;

    Repo := TResourceRepository.Create(Config);
    try
      OK := Repo.Update(True);
      Check('resource repo update rejects non-conflicting diverged history',
        not OK,
        'Expected Update(True) to fail instead of merge a diverged managed repo');
      Check('resource repo keeps local-only file after ff-only failure',
        FileExists(LocalRepoDir + PathDelim + 'local-only.txt'),
        'Expected local-only.txt to remain after failed ff-only update');
      Check('resource repo does not materialize remote-only file after ff-only failure',
        not FileExists(LocalRepoDir + PathDelim + 'remote-only.txt'),
        'Expected remote-only.txt to stay absent after failed ff-only update');
    finally
      Repo.Free;
    end;
  finally
    CleanupTempDir(RootDir);
  end;
end;

begin
  TestInitializeUsesExistingRepoAndRefreshesWhenNeeded;
  TestInitializeFallsBackToMirror;
  TestInitializeFailsWhenAllSourcesFail;
  TestUpdateRejectsUninitializedRepo;
  TestUpdatePullsAndWarnsOnManifestReloadFailure;
  TestUpdateSkipsPullWhenFresh;
  TestUpdateSkipsPullWhenNeverCheckedAndAutoUpdateDisabled;
  TestLoadManifestParsesJson;
  TestLoadManifestMissingFile;
  TestEnsureManifestLoadedShortCircuits;
  TestEnsureManifestLoadedDelegatesReload;
  TestResourceRepositoryUpdateRejectsNonConflictingDivergedHistory;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
