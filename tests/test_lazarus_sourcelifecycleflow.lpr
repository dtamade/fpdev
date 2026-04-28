program test_lazarus_sourcelifecycleflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.git.types,
  fpdev.lazarus.sourceflow,
  fpdev.lazarus.sourcelifecycleflow,
  test_temp_paths;

type
  TLifecycleProbe = class
  public
    BackendValue: TGitBackend;
    CloneResult: Boolean;
    PullResult: Boolean;
    CheckoutResult: Boolean;
    RepoResult: Boolean;
    ValidSourceResult: Boolean;
    VersionInstalledResult: Boolean;
    BuildResult: Boolean;
    ConfigureResult: Boolean;
    SwitchResult: Boolean;
    CloneCalls: Integer;
    PullCalls: Integer;
    CheckoutCalls: Integer;
    DeleteCalls: Integer;
    BuildCalls: Integer;
    ConfigureCalls: Integer;
    SwitchCalls: Integer;
    DelegatedCloneCalls: Integer;
    LastCloneURL: string;
    LastClonePath: string;
    LastCloneRef: string;
    LastPullPath: string;
    LastCheckoutPath: string;
    LastCheckoutRef: string;
    LastDeletePath: string;
    LastBuildVersion: string;
    LastConfigureVersion: string;
    LastConfigureSourcePath: string;
    LastSwitchVersion: string;
    LastDelegatedCloneVersion: string;
    LastErrorText: string;
    AutoCreateValidSourceTree: Boolean;
    Logged: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Log(const AText: string);
    procedure DeleteDir(const APath: string);
    function IsValidSourceDirectory(const APath: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;
    function GetBackend: TGitBackend;
    function Clone(const AURL, ALocalPath, ARef: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function IsRepository(const APath: string): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean): Boolean;
    function GetLastError: string;
    function CloneVersion(const AVersion: string): Boolean;
    function BuildVersion(const AVersion: string): Boolean;
    function ConfigureIDE(const AVersion, ASourcePath: string): Boolean;
    function SwitchVersion(const AVersion: string): Boolean;
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

constructor TLifecycleProbe.Create;
begin
  inherited Create;
  Logged := TStringList.Create;
  BackendValue := gbNone;
  LastErrorText := 'git boom';
end;

destructor TLifecycleProbe.Destroy;
begin
  Logged.Free;
  inherited Destroy;
end;

procedure TLifecycleProbe.Log(const AText: string);
begin
  Logged.Add(AText);
end;

procedure TLifecycleProbe.DeleteDir(const APath: string);
begin
  Inc(DeleteCalls);
  LastDeletePath := APath;
end;

function TLifecycleProbe.IsValidSourceDirectory(const APath: string): Boolean;
begin
  if APath = '' then;
  Result := ValidSourceResult;
end;

function TLifecycleProbe.IsVersionInstalled(const AVersion: string): Boolean;
begin
  if AVersion = '' then;
  Result := VersionInstalledResult;
end;

function TLifecycleProbe.GetBackend: TGitBackend;
begin
  Result := BackendValue;
end;

function TLifecycleProbe.Clone(const AURL, ALocalPath, ARef: string): Boolean;
begin
  Inc(CloneCalls);
  LastCloneURL := AURL;
  LastClonePath := ALocalPath;
  LastCloneRef := ARef;
  Result := CloneResult;
  if Result and AutoCreateValidSourceTree then
  begin
    ForceDirectories(ALocalPath + PathDelim + 'ide');
    ForceDirectories(ALocalPath + PathDelim + 'lcl');
    ForceDirectories(ALocalPath + PathDelim + 'packager');
  end;
end;

function TLifecycleProbe.Pull(const ARepoPath: string): Boolean;
begin
  Inc(PullCalls);
  LastPullPath := ARepoPath;
  Result := PullResult;
end;

function TLifecycleProbe.IsRepository(const APath: string): Boolean;
begin
  LastCheckoutPath := APath;
  Result := RepoResult;
end;

function TLifecycleProbe.Checkout(const ARepoPath, AName: string; const Force: Boolean): Boolean;
begin
  Inc(CheckoutCalls);
  LastCheckoutPath := ARepoPath;
  LastCheckoutRef := AName;
  if Force then;
  Result := CheckoutResult;
end;

function TLifecycleProbe.GetLastError: string;
begin
  Result := LastErrorText;
end;

function TLifecycleProbe.CloneVersion(const AVersion: string): Boolean;
begin
  Inc(DelegatedCloneCalls);
  LastDelegatedCloneVersion := AVersion;
  Result := CloneResult;
end;

function TLifecycleProbe.BuildVersion(const AVersion: string): Boolean;
begin
  Inc(BuildCalls);
  LastBuildVersion := AVersion;
  Result := BuildResult;
end;

function TLifecycleProbe.ConfigureIDE(const AVersion, ASourcePath: string): Boolean;
begin
  Inc(ConfigureCalls);
  LastConfigureVersion := AVersion;
  LastConfigureSourcePath := ASourcePath;
  Result := ConfigureResult;
end;

function TLifecycleProbe.SwitchVersion(const AVersion: string): Boolean;
begin
  Inc(SwitchCalls);
  LastSwitchVersion := AVersion;
  Result := SwitchResult;
end;

procedure TestCloneFailsWithoutGitBackend;
var
  Probe: TLifecycleProbe;
  CurrentVersion: string;
  Plan: TLazarusLegacySourceClonePlan;
begin
  Probe := TLifecycleProbe.Create;
  try
    Probe.BackendValue := gbNone;
    Probe.CloneResult := True;
    Probe.ValidSourceResult := True;
    CurrentVersion := '2.2.6';
    Plan := CreateLazarusLegacyClonePlanCore(
      '3.0', 'main', '/tmp/fpdev-root', 'https://example.invalid/lazarus.git', 'lazarus_3_0'
    );

    Check('lifecycle clone fails without git backend',
      not ExecuteLazarusLegacyCloneCore(
        Plan, CurrentVersion, @Probe.Log, @Probe.DeleteDir, @Probe.IsValidSourceDirectory,
        @Probe.GetBackend, @Probe.Clone
      ),
      'expected failure');
    Check('lifecycle clone keeps current version on backend failure',
      CurrentVersion = '2.2.6',
      'current=' + CurrentVersion);
    Check('lifecycle clone does not call clone callback on backend failure',
      Probe.CloneCalls = 0,
      'clone calls=' + IntToStr(Probe.CloneCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestCloneSuccessUpdatesCurrentVersion;
var
  Probe: TLifecycleProbe;
  CurrentVersion: string;
  TempRoot: string;
  Plan: TLazarusLegacySourceClonePlan;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_sourcelifecycle_clone');
  Probe := TLifecycleProbe.Create;
  try
    Probe.BackendValue := gbCommandLine;
    Probe.CloneResult := True;
    Probe.ValidSourceResult := True;
    Probe.AutoCreateValidSourceTree := True;
    CurrentVersion := '';
    Plan := CreateLazarusLegacyClonePlanCore(
      '3.0', 'main', TempRoot, 'https://example.invalid/lazarus.git', 'lazarus_3_0'
    );

    Check('lifecycle clone success returns true',
      ExecuteLazarusLegacyCloneCore(
        Plan, CurrentVersion, @Probe.Log, @Probe.DeleteDir, @Probe.IsValidSourceDirectory,
        @Probe.GetBackend, @Probe.Clone
      ),
      'expected success');
    Check('lifecycle clone updates current version',
      CurrentVersion = '3.0',
      'current=' + CurrentVersion);
    Check('lifecycle clone passes ref name to git clone',
      Probe.LastCloneRef = 'lazarus_3_0',
      'ref=' + Probe.LastCloneRef);
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestUpdateFailsForInvalidSourceDirectory;
var
  Probe: TLifecycleProbe;
  CurrentVersion: string;
  Plan: TLazarusLegacySourceUpdatePlan;
begin
  Probe := TLifecycleProbe.Create;
  try
    Probe.BackendValue := gbCommandLine;
    Probe.ValidSourceResult := False;
    Probe.PullResult := True;
    CurrentVersion := '2.2.6';
    Plan := CreateLazarusLegacyUpdatePlanCore('3.0', '', 'main', '/tmp/fpdev-root');

    Check('lifecycle update fails for invalid source dir',
      not ExecuteLazarusLegacyUpdateCore(
        Plan, CurrentVersion, @Probe.Log, @Probe.IsValidSourceDirectory,
        @Probe.GetBackend, @Probe.Pull, @Probe.GetLastError
      ),
      'expected failure');
    Check('lifecycle update does not pull when source dir invalid',
      Probe.PullCalls = 0,
      'pull calls=' + IntToStr(Probe.PullCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestSwitchDelegatesCloneWhenVersionMissing;
var
  Probe: TLifecycleProbe;
  CurrentVersion: string;
begin
  Probe := TLifecycleProbe.Create;
  try
    Probe.CloneResult := True;
    Probe.VersionInstalledResult := False;
    CurrentVersion := '';

    Check('lifecycle switch delegates clone when version missing',
      ExecuteLazarusLegacySwitchCore(
        '3.0',
        '/tmp/fpdev-root/lazarus-3.0',
        'lazarus_3_0',
        False,
        CurrentVersion,
        @Probe.Log,
        @Probe.IsVersionInstalled,
        @Probe.CloneVersion,
        @Probe.IsValidSourceDirectory,
        @Probe.GetBackend,
        @Probe.IsRepository,
        @Probe.Checkout,
        @Probe.GetLastError
      ),
      'expected success');
    Check('lifecycle switch calls delegated clone once',
      Probe.DelegatedCloneCalls = 1,
      'clone calls=' + IntToStr(Probe.DelegatedCloneCalls));
    Check('lifecycle switch forwards requested version to clone callback',
      Probe.LastDelegatedCloneVersion = '3.0',
      'version=' + Probe.LastDelegatedCloneVersion);
  finally
    Probe.Free;
  end;
end;

procedure TestSwitchExistingRepoUpdatesCurrentVersion;
var
  Probe: TLifecycleProbe;
  CurrentVersion: string;
begin
  Probe := TLifecycleProbe.Create;
  try
    Probe.VersionInstalledResult := True;
    Probe.ValidSourceResult := True;
    Probe.BackendValue := gbCommandLine;
    Probe.RepoResult := True;
    Probe.CheckoutResult := True;
    CurrentVersion := '2.2.6';

    Check('lifecycle switch existing repo succeeds',
      ExecuteLazarusLegacySwitchCore(
        '3.0',
        '/tmp/fpdev-root/lazarus-3.0',
        'lazarus_3_0',
        True,
        CurrentVersion,
        @Probe.Log,
        @Probe.IsVersionInstalled,
        @Probe.CloneVersion,
        @Probe.IsValidSourceDirectory,
        @Probe.GetBackend,
        @Probe.IsRepository,
        @Probe.Checkout,
        @Probe.GetLastError
      ),
      'expected success');
    Check('lifecycle switch updates current version',
      CurrentVersion = '3.0',
      'current=' + CurrentVersion);
    Check('lifecycle switch uses requested ref for checkout',
      Probe.LastCheckoutRef = 'lazarus_3_0',
      'ref=' + Probe.LastCheckoutRef);
  finally
    Probe.Free;
  end;
end;

procedure TestInstallRestoresPreviousVersionOnBuildFailure;
var
  Probe: TLifecycleProbe;
  CurrentVersion: string;
  TempRoot: string;
begin
  TempRoot := CreateUniqueTempDir('test_lazarus_sourcelifecycle_install');
  Probe := TLifecycleProbe.Create;
  try
    Probe.CloneResult := True;
    Probe.BuildResult := False;
    Probe.ConfigureResult := True;
    Probe.SwitchResult := True;
    CurrentVersion := '2.2.6';

    Check('lifecycle install fails when build fails',
      not ExecuteLazarusLegacyInstallCore(
        '3.0',
        TempRoot + PathDelim + 'lazarus-3.0',
        TempRoot + PathDelim + 'lazarus-3.0' + PathDelim + 'lazarus',
        '2.2.6',
        True,
        CurrentVersion,
        @Probe.Log,
        @Probe.CloneVersion,
        @Probe.BuildVersion,
        @Probe.ConfigureIDE,
        @Probe.SwitchVersion
      ),
      'expected failure');
    Check('lifecycle install restores previous version on failure',
      CurrentVersion = '2.2.6',
      'current=' + CurrentVersion);
    Check('lifecycle install short-circuits configure after build failure',
      Probe.ConfigureCalls = 0,
      'configure calls=' + IntToStr(Probe.ConfigureCalls));
    Check('lifecycle install short-circuits switch after build failure',
      Probe.SwitchCalls = 0,
      'switch calls=' + IntToStr(Probe.SwitchCalls));
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

begin
  WriteLn('=== Lazarus Sourcelifecycleflow Tests ===');

  TestCloneFailsWithoutGitBackend;
  TestCloneSuccessUpdatesCurrentVersion;
  TestUpdateFailsForInvalidSourceDirectory;
  TestSwitchDelegatesCloneWhenVersionMissing;
  TestSwitchExistingRepoUpdatesCurrentVersion;
  TestInstallRestoresPreviousVersionOnBuildFailure;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
