program test_resource_repo_lifecyclesurfaceflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson,
  test_temp_paths,
  fpdev.git.types,
  fpdev.resource.repo.lifecycleflow;

type
  TResourceLifecycleHarness = class
  public
    CloneResult: Boolean;
    PullResult: Boolean;
    RaiseOnPackageQuery: Boolean;
    PackageResult: Boolean;
    EnsureResult: Boolean;
    CloneCalls: Integer;
    PullCalls: Integer;
    PackageCalls: Integer;
    LastCloneURL: string;
    LastClonePath: string;
    LastCloneBranch: string;
    LastPullPath: string;
    EnsuredDirs: TStringList;
    Logs: TStringList;
    constructor Create;
    destructor Destroy; override;
    function Clone(const AURL, ALocalPath, ABranch: string): Boolean;
    function Pull(const ALocalPath: string): Boolean;
    function GetLastError: string;
    function EnsureManifestLoaded: Boolean;
    function QueryHasPackage(const ALocalPath, AName, AVersion: string): Boolean;
    procedure EnsureDir(const APath: string);
    procedure LogLine(const AMsg: string);
    procedure LogFmt(const AFormat: string; const AArgs: array of const);
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

constructor TResourceLifecycleHarness.Create;
begin
  inherited Create;
  EnsuredDirs := TStringList.Create;
  Logs := TStringList.Create;
  EnsureResult := True;
end;

destructor TResourceLifecycleHarness.Destroy;
begin
  Logs.Free;
  EnsuredDirs.Free;
  inherited Destroy;
end;

function TResourceLifecycleHarness.Clone(const AURL, ALocalPath, ABranch: string): Boolean;
begin
  Inc(CloneCalls);
  LastCloneURL := AURL;
  LastClonePath := ALocalPath;
  LastCloneBranch := ABranch;
  Result := CloneResult;
end;

function TResourceLifecycleHarness.Pull(const ALocalPath: string): Boolean;
begin
  Inc(PullCalls);
  LastPullPath := ALocalPath;
  Result := PullResult;
end;

function TResourceLifecycleHarness.GetLastError: string;
begin
  Result := 'git boom';
end;

function TResourceLifecycleHarness.EnsureManifestLoaded: Boolean;
begin
  Result := EnsureResult;
end;

function TResourceLifecycleHarness.QueryHasPackage(const ALocalPath, AName, AVersion: string): Boolean;
begin
  Inc(PackageCalls);
  if ALocalPath = '' then;
  if AName = '' then;
  if AVersion = '' then;
  if RaiseOnPackageQuery then
    raise Exception.Create('package boom');
  Result := PackageResult;
end;

procedure TResourceLifecycleHarness.EnsureDir(const APath: string);
begin
  EnsuredDirs.Add(APath);
end;

procedure TResourceLifecycleHarness.LogLine(const AMsg: string);
begin
  Logs.Add(AMsg);
end;

procedure TResourceLifecycleHarness.LogFmt(const AFormat: string; const AArgs: array of const);
begin
  Logs.Add(Format(AFormat, AArgs));
end;

procedure TestExecuteResourceRepoGitCloneCoreFailsWithoutBackend;
var
  Harness: TResourceLifecycleHarness;
  OK: Boolean;
begin
  Harness := TResourceLifecycleHarness.Create;
  try
    OK := ExecuteResourceRepoGitCloneCore(
      'https://example.invalid/repo.git',
      '/tmp/fpdev/repo',
      'main',
      gbNone,
      @Harness.Clone,
      @Harness.GetLastError,
      @Harness.EnsureDir,
      @Harness.LogLine
    );

    Check('lifecycle surface clone returns false without backend', not OK, 'expected failure');
    Check('lifecycle surface clone does not call git clone when backend missing', Harness.CloneCalls = 0,
      'clone calls=' + IntToStr(Harness.CloneCalls));
    Check('lifecycle surface clone logs backend error',
      Pos('No Git backend available', Harness.Logs.Text) > 0,
      Harness.Logs.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestExecuteResourceRepoGitCloneCoreEnsuresParentDir;
var
  Harness: TResourceLifecycleHarness;
  TempRoot: string;
  LocalPath: string;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('resource-lifecycle-clone');
  Harness := TResourceLifecycleHarness.Create;
  try
    Harness.CloneResult := True;
    LocalPath := TempRoot + PathDelim + 'repos' + PathDelim + 'fpdev-repo';

    OK := ExecuteResourceRepoGitCloneCore(
      'https://example.invalid/repo.git',
      LocalPath,
      'stable',
      gbCommandLine,
      @Harness.Clone,
      @Harness.GetLastError,
      @Harness.EnsureDir,
      @Harness.LogLine
    );

    Check('lifecycle surface clone returns true on success', OK, 'expected success');
    Check('lifecycle surface clone ensures parent dir',
      Harness.EnsuredDirs.IndexOf(ExtractFileDir(LocalPath)) >= 0,
      Harness.EnsuredDirs.Text);
    Check('lifecycle surface clone forwards branch',
      Harness.LastCloneBranch = 'stable', Harness.LastCloneBranch);
    Check('lifecycle surface clone logs backend',
      Pos('Using backend: git (command-line)', Harness.Logs.Text) > 0,
      Harness.Logs.Text);
  finally
    CleanupTempDir(TempRoot);
    Harness.Free;
  end;
end;

procedure TestExecuteResourceRepoGitPullCoreLogsWarningWithoutBackend;
var
  Harness: TResourceLifecycleHarness;
  OK: Boolean;
begin
  Harness := TResourceLifecycleHarness.Create;
  try
    OK := ExecuteResourceRepoGitPullCore(
      '/tmp/fpdev/repo',
      gbNone,
      @Harness.Pull,
      @Harness.GetLastError,
      @Harness.LogLine
    );

    Check('lifecycle surface pull returns false without backend', not OK, 'expected failure');
    Check('lifecycle surface pull skips git call without backend', Harness.PullCalls = 0,
      'pull calls=' + IntToStr(Harness.PullCalls));
    Check('lifecycle surface pull logs warning',
      Pos('Warning: No Git backend available, skipping update', Harness.Logs.Text) > 0,
      Harness.Logs.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestLoadResourceRepoManifestSurfaceCoreLoadsManifest;
var
  TempRoot: string;
  ManifestData: TJSONObject;
  ManifestLoaded: Boolean;
  Harness: TResourceLifecycleHarness;
  OK: Boolean;
  Lines: TStringList;
begin
  TempRoot := CreateUniqueTempDir('resource-lifecycle-manifest');
  Harness := TResourceLifecycleHarness.Create;
  try
    Lines := TStringList.Create;
    try
      Lines.Text := '{"version":"2026.04","packages":[]}';
      Lines.SaveToFile(TempRoot + PathDelim + 'manifest.json');
    finally
      Lines.Free;
    end;

    OK := LoadResourceRepoManifestSurfaceCore(
      TempRoot,
      @Harness.LogLine,
      ManifestData,
      ManifestLoaded
    );

    try
      Check('lifecycle surface manifest load returns true', OK, 'expected success');
      Check('lifecycle surface manifest load marks loaded', ManifestLoaded, 'expected loaded');
      Check('lifecycle surface manifest exposes version',
        Assigned(ManifestData) and (ManifestData.Get('version', 'unknown') = '2026.04'),
        'version mismatch');
    finally
      ManifestData.Free;
    end;
  finally
    CleanupTempDir(TempRoot);
    Harness.Free;
  end;
end;

procedure TestGetResourceRepoManifestVersionSurfaceCoreFallsBackToUnknown;
var
  Harness: TResourceLifecycleHarness;
  Manifest: TJSONObject;
  Version: string;
begin
  Harness := TResourceLifecycleHarness.Create;
  Manifest := TJSONObject.Create(['version', '2026.04']);
  try
    Harness.EnsureResult := False;
    Version := GetResourceRepoManifestVersionSurfaceCore(
      Manifest,
      @Harness.EnsureManifestLoaded
    );
    Check('lifecycle surface manifest version returns unknown when ensure fails',
      Version = 'unknown', Version);

    Harness.EnsureResult := True;
    Version := GetResourceRepoManifestVersionSurfaceCore(
      Manifest,
      @Harness.EnsureManifestLoaded
    );
    Check('lifecycle surface manifest version returns manifest value when loaded',
      Version = '2026.04', Version);
  finally
    Manifest.Free;
    Harness.Free;
  end;
end;

procedure TestExecuteResourceRepoHasPackageSurfaceCoreHandlesExceptions;
var
  Harness: TResourceLifecycleHarness;
  OK: Boolean;
begin
  Harness := TResourceLifecycleHarness.Create;
  try
    Harness.RaiseOnPackageQuery := True;
    OK := ExecuteResourceRepoHasPackageSurfaceCore(
      '/tmp/fpdev/repo',
      'jwt',
      '1.0.0',
      @Harness.LogFmt,
      @Harness.QueryHasPackage
    );

    Check('lifecycle surface has-package returns false on exception', not OK, 'expected failure');
    Check('lifecycle surface has-package logs exception',
      Pos('Error checking package availability: package boom', Harness.Logs.Text) > 0,
      Harness.Logs.Text);
  finally
    Harness.Free;
  end;
end;

begin
  TestExecuteResourceRepoGitCloneCoreFailsWithoutBackend;
  TestExecuteResourceRepoGitCloneCoreEnsuresParentDir;
  TestExecuteResourceRepoGitPullCoreLogsWarningWithoutBackend;
  TestLoadResourceRepoManifestSurfaceCoreLoadsManifest;
  TestGetResourceRepoManifestVersionSurfaceCoreFallsBackToUnknown;
  TestExecuteResourceRepoHasPackageSurfaceCoreHandlesExceptions;

  WriteLn;
  WriteLn('Pass: ', PassCount, ' Fail: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
