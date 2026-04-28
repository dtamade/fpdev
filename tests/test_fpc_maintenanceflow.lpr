program test_fpc_maintenanceflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.fpc.maintenanceflow,
  fpdev.fpc.runtimeflow,
  test_temp_paths;

type
  TGitRuntimeProbe = class(TInterfacedObject, IFPCGitRuntime)
  public
    BackendOk: Boolean;
    RepoOk: Boolean;
    HasRemoteResult: Boolean;
    PullResult: Boolean;
    LastRepoPath: string;
    LastPullPath: string;
    LastErrorText: string;
    function BackendAvailable: Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function GetLastError: string;
  end;

  TMaintenanceProbe = class
  public
    CurrentVersion: string;
    InstallPath: string;
    InstalledResult: Boolean;
    SourceExistsResult: Boolean;
    CleanArtifactsResult: Integer;
    CurrentVersionCalls: Integer;
    DeleteCalls: Integer;
    RemoveToolchainCalls: Integer;
    CleanCalls: Integer;
    LastDeletedPath: string;
    LastRemovedToolchain: string;
    LastExistsPath: string;
    LastCleanPath: string;
    GitProbe: IFPCGitRuntime;
    function GetCurrentVersion: string;
    function GetVersionInstallPath(const AVersion: string): string;
    function IsVersionInstalled(const AVersion: string): Boolean;
    procedure DeleteDir(const APath: string);
    procedure RemoveToolchain(const AName: string);
    function DirectoryExistsAt(const APath: string): Boolean;
    function CleanSourceArtifacts(const ASourceDir: string): Integer;
    function CreateGitRuntime: IFPCGitRuntime;
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

function TGitRuntimeProbe.BackendAvailable: Boolean;
begin
  Result := BackendOk;
end;

function TGitRuntimeProbe.IsRepository(const APath: string): Boolean;
begin
  LastRepoPath := APath;
  Result := RepoOk;
end;

function TGitRuntimeProbe.HasRemote(const APath: string): Boolean;
begin
  LastRepoPath := APath;
  Result := HasRemoteResult;
end;

function TGitRuntimeProbe.Pull(const APath: string): Boolean;
begin
  LastPullPath := APath;
  Result := PullResult;
end;

function TGitRuntimeProbe.GetLastError: string;
begin
  Result := LastErrorText;
end;

function TMaintenanceProbe.GetCurrentVersion: string;
begin
  Inc(CurrentVersionCalls);
  Result := CurrentVersion;
end;

function TMaintenanceProbe.GetVersionInstallPath(const AVersion: string): string;
begin
  if AVersion = '' then;
  Result := InstallPath;
end;

function TMaintenanceProbe.IsVersionInstalled(const AVersion: string): Boolean;
begin
  if AVersion = '' then;
  Result := InstalledResult;
end;

procedure TMaintenanceProbe.DeleteDir(const APath: string);
begin
  Inc(DeleteCalls);
  LastDeletedPath := APath;
end;

procedure TMaintenanceProbe.RemoveToolchain(const AName: string);
begin
  Inc(RemoveToolchainCalls);
  LastRemovedToolchain := AName;
end;

function TMaintenanceProbe.DirectoryExistsAt(const APath: string): Boolean;
begin
  LastExistsPath := APath;
  Result := SourceExistsResult;
end;

function TMaintenanceProbe.CleanSourceArtifacts(const ASourceDir: string): Integer;
begin
  Inc(CleanCalls);
  LastCleanPath := ASourceDir;
  Result := CleanArtifactsResult;
end;

function TMaintenanceProbe.CreateGitRuntime: IFPCGitRuntime;
begin
  Result := GitProbe;
end;

procedure TestManagedUninstallSkipsMissingVersion;
var
  Probe: TMaintenanceProbe;
begin
  Probe := TMaintenanceProbe.Create;
  try
    Probe.InstalledResult := False;

    Check(
      'maintenanceflow uninstall returns success for missing version',
      ExecuteManagedFPCUninstallCore(
        '3.2.2',
        @Probe.IsVersionInstalled,
        @Probe.GetVersionInstallPath,
        @Probe.DeleteDir,
        @Probe.RemoveToolchain
      ),
      'expected true'
    );
    Check('maintenanceflow uninstall skips delete callback when missing',
      Probe.DeleteCalls = 0,
      'delete calls=' + IntToStr(Probe.DeleteCalls));
    Check('maintenanceflow uninstall skips toolchain removal when missing',
      Probe.RemoveToolchainCalls = 0,
      'remove calls=' + IntToStr(Probe.RemoveToolchainCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestManagedUninstallRemovesInstallDirAndToolchain;
var
  Probe: TMaintenanceProbe;
  InstallPath: string;
begin
  Probe := TMaintenanceProbe.Create;
  InstallPath := CreateUniqueTempDir('test_fpc_maintenanceflow_uninstall');
  try
    Probe.InstalledResult := True;
    Probe.InstallPath := InstallPath;

    Check(
      'maintenanceflow uninstall removes installed version',
      ExecuteManagedFPCUninstallCore(
        '3.2.2',
        @Probe.IsVersionInstalled,
        @Probe.GetVersionInstallPath,
        @Probe.DeleteDir,
        @Probe.RemoveToolchain
      ),
      'expected true'
    );
    Check('maintenanceflow uninstall deletes resolved install path',
      Probe.LastDeletedPath = Probe.InstallPath,
      'deleted=' + Probe.LastDeletedPath);
    Check('maintenanceflow uninstall removes version toolchain name',
      Probe.LastRemovedToolchain = 'fpc-3.2.2',
      'toolchain=' + Probe.LastRemovedToolchain);
  finally
    Probe.Free;
    CleanupTempDir(InstallPath);
  end;
end;

procedure TestManagedUpdateUsesCurrentVersionFallback;
var
  Probe: TMaintenanceProbe;
  GitProbe: TGitRuntimeProbe;
  InstallRoot: string;
  SourceDir: string;
begin
  InstallRoot := CreateUniqueTempDir('test_fpc_maintenanceflow_update');
  SourceDir := InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-currentver';
  ForceDirectories(SourceDir);

  Probe := TMaintenanceProbe.Create;
  try
    GitProbe := TGitRuntimeProbe.Create;
    GitProbe.BackendOk := True;
    GitProbe.RepoOk := True;
    GitProbe.HasRemoteResult := False;
    Probe.GitProbe := GitProbe;
    Probe.CurrentVersion := 'currentver';
    Probe.SourceExistsResult := True;

    Check(
      'maintenanceflow update uses current version fallback',
      ExecuteManagedFPCUpdateSourcesCore(
        '',
        InstallRoot,
        nil,
        nil,
        @Probe.GetCurrentVersion,
        @Probe.DirectoryExistsAt,
        @Probe.CreateGitRuntime
      ),
      'expected success'
    );
    Check('maintenanceflow update calls current version provider once',
      Probe.CurrentVersionCalls = 1,
      'calls=' + IntToStr(Probe.CurrentVersionCalls));
    Check('maintenanceflow update resolves current version source dir',
      Pos('fpc-currentver', Probe.LastExistsPath) > 0,
      Probe.LastExistsPath);
    Check('maintenanceflow update passes resolved path to git runtime',
      Pos('fpc-currentver', GitProbe.LastRepoPath) > 0,
      GitProbe.LastRepoPath);
  finally
    Probe.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

procedure TestManagedCleanUsesCurrentVersionFallback;
var
  Probe: TMaintenanceProbe;
  InstallRoot: string;
  SourceDir: string;
begin
  InstallRoot := CreateUniqueTempDir('test_fpc_maintenanceflow_clean');
  SourceDir := InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-currentver';
  ForceDirectories(SourceDir);

  Probe := TMaintenanceProbe.Create;
  try
    Probe.CurrentVersion := 'currentver';
    Probe.SourceExistsResult := True;
    Probe.CleanArtifactsResult := 3;

    Check(
      'maintenanceflow clean uses current version fallback',
      ExecuteManagedFPCCleanSourcesCore(
        '',
        InstallRoot,
        nil,
        nil,
        @Probe.GetCurrentVersion,
        @Probe.DirectoryExistsAt,
        @Probe.CleanSourceArtifacts
      ),
      'expected success'
    );
    Check('maintenanceflow clean calls current version provider once',
      Probe.CurrentVersionCalls = 1,
      'calls=' + IntToStr(Probe.CurrentVersionCalls));
    Check('maintenanceflow clean resolves current version source dir',
      Pos('fpc-currentver', Probe.LastCleanPath) > 0,
      Probe.LastCleanPath);
    Check('maintenanceflow clean invokes cleaner once',
      Probe.CleanCalls = 1,
      'clean calls=' + IntToStr(Probe.CleanCalls));
  finally
    Probe.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

begin
  WriteLn('=== FPC Maintenanceflow Tests ===');

  TestManagedUninstallSkipsMissingVersion;
  TestManagedUninstallRemovesInstallDirAndToolchain;
  TestManagedUpdateUsesCurrentVersionFallback;
  TestManagedCleanUsesCurrentVersionFallback;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
