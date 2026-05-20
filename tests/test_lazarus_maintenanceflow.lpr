program test_lazarus_maintenanceflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.output.intf,
  fpdev.lazarus.commandflow,
  fpdev.lazarus.maintenanceflow,
  test_cli_helpers,
  test_temp_paths;

type
  TGitRuntimeProbe = class(TInterfacedObject, ILazarusGitRuntime)
  public
    BackendOk: Boolean;
    RepoOk: Boolean;
    HasRemoteResult: Boolean;
    PullResult: Boolean;
    LastRepoPath: string;
    LastPullPath: string;
    LastErrorValue: string;
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
    ConfiguredVersionHit: string;
    InstalledResult: Boolean;
    ConfiguredLookupResult: Boolean;
    SourceDirValidResult: Boolean;
    CleanResult: Integer;
    DeleteCalls: Integer;
    RemoveCalls: Integer;
    CleanCalls: Integer;
    CurrentVersionCalls: Integer;
    LastDeletedPath: string;
    LastRemovedVersion: string;
    LastValidatedSourceDir: string;
    LastCleanSourceDir: string;
    GitRuntime: ILazarusGitRuntime;
    function GetCurrentVersion: string;
    function GetResolvedInstallPath(const AVersion: string): string;
    function IsVersionInstalled(const AVersion: string): Boolean;
    function LookupConfiguredLazarusInfo(const AVersion: string; out ALazarusInfo: TLazarusInfo): Boolean;
    procedure DeleteInstallDir(const APath: string);
    procedure RemoveConfiguredVersion(const AVersion: string);
    function IsValidSourceDirectory(const ASourceDir: string): Boolean;
    function CleanSourceArtifacts(const ASourceDir: string): Integer;
    function CreateGitRuntime(const ACliOnly: Boolean): ILazarusGitRuntime;
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
  Result := LastErrorValue;
end;

function TMaintenanceProbe.GetCurrentVersion: string;
begin
  Inc(CurrentVersionCalls);
  Result := CurrentVersion;
end;

function TMaintenanceProbe.GetResolvedInstallPath(const AVersion: string): string;
begin
  if AVersion <> '' then;
  Result := InstallPath;
end;

function TMaintenanceProbe.IsVersionInstalled(const AVersion: string): Boolean;
begin
  if AVersion <> '' then;
  Result := InstalledResult;
end;

function TMaintenanceProbe.LookupConfiguredLazarusInfo(
  const AVersion: string;
  out ALazarusInfo: TLazarusInfo
): Boolean;
begin
  ALazarusInfo := Default(TLazarusInfo);
  Result := ConfiguredLookupResult and SameText(AVersion, ConfiguredVersionHit);
  if Result then
    ALazarusInfo.Version := AVersion;
end;

procedure TMaintenanceProbe.DeleteInstallDir(const APath: string);
begin
  Inc(DeleteCalls);
  LastDeletedPath := APath;
end;

procedure TMaintenanceProbe.RemoveConfiguredVersion(const AVersion: string);
begin
  Inc(RemoveCalls);
  LastRemovedVersion := AVersion;
end;

function TMaintenanceProbe.IsValidSourceDirectory(const ASourceDir: string): Boolean;
begin
  LastValidatedSourceDir := ASourceDir;
  Result := SourceDirValidResult;
end;

function TMaintenanceProbe.CleanSourceArtifacts(const ASourceDir: string): Integer;
begin
  Inc(CleanCalls);
  LastCleanSourceDir := ASourceDir;
  Result := CleanResult;
end;

function TMaintenanceProbe.CreateGitRuntime(const ACliOnly: Boolean): ILazarusGitRuntime;
begin
  if ACliOnly then;
  Result := GitRuntime;
end;

procedure TestManagedUninstallSucceedsWhenNothingExists;
var
  Probe: TMaintenanceProbe;
begin
  Probe := TMaintenanceProbe.Create;
  try
    Probe.InstalledResult := False;
    Probe.ConfiguredLookupResult := False;

    Check(
      'maintenanceflow uninstall fast succeeds when nothing exists',
      ExecuteManagedLazarusUninstallCore(
        '3.0',
        @Probe.IsVersionInstalled,
        @Probe.GetResolvedInstallPath,
        @Probe.LookupConfiguredLazarusInfo,
        @Probe.DeleteInstallDir,
        @Probe.RemoveConfiguredVersion
      )
    );
    Check('maintenanceflow uninstall skips delete callback on fast success', Probe.DeleteCalls = 0);
    Check('maintenanceflow uninstall skips config removal on fast success', Probe.RemoveCalls = 0);
  finally
    Probe.Free;
  end;
end;

procedure TestManagedUninstallDeletesDirAndRemovesConfig;
var
  Probe: TMaintenanceProbe;
  InstallPath: string;
begin
  Probe := TMaintenanceProbe.Create;
  InstallPath := CreateUniqueTempDir('test_lazarus_maintenanceflow_uninstall');
  try
    Probe.InstalledResult := False;
    Probe.ConfiguredLookupResult := True;
    Probe.ConfiguredVersionHit := '3.0';
    Probe.InstallPath := InstallPath;

    Check(
      'maintenanceflow uninstall deletes install dir and removes config',
      ExecuteManagedLazarusUninstallCore(
        '3.0',
        @Probe.IsVersionInstalled,
        @Probe.GetResolvedInstallPath,
        @Probe.LookupConfiguredLazarusInfo,
        @Probe.DeleteInstallDir,
        @Probe.RemoveConfiguredVersion
      )
    );
    Check('maintenanceflow uninstall deletes resolved install dir',
      Probe.LastDeletedPath = InstallPath);
    Check('maintenanceflow uninstall removes requested version from config',
      Probe.LastRemovedVersion = '3.0');
  finally
    Probe.Free;
    CleanupTempDir(InstallPath);
  end;
end;

procedure TestManagedUpdateSourcesRejectsMissingOrInvalidSourceDir;
var
  Probe: TMaintenanceProbe;
  Outp: TStringOutput;
  Errp: TStringOutput;
  InstallRoot: string;
begin
  InstallRoot := CreateUniqueTempDir('test_lazarus_maintenanceflow_update_guard');
  Probe := TMaintenanceProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Probe.CurrentVersion := '3.0';
    Probe.SourceDirValidResult := False;

    Check(
      'maintenanceflow update fails when source dir is missing',
      not ExecuteManagedLazarusUpdateSourcesCore(
        '',
        InstallRoot,
        Outp,
        Errp,
        @Probe.GetCurrentVersion,
        @Probe.IsValidSourceDirectory,
        @Probe.CreateGitRuntime
      )
    );
    Check('maintenanceflow update uses current version fallback',
      Probe.CurrentVersionCalls = 1);
    Check('maintenanceflow update reports missing source dir',
      Errp.Contains('sources' + PathDelim + 'lazarus'));

    ForceDirectories(InstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus');
    Errp.Clear;

    Check(
      'maintenanceflow update fails when source dir structure is invalid',
      not ExecuteManagedLazarusUpdateSourcesCore(
        '3.0',
        InstallRoot,
        Outp,
        Errp,
        @Probe.GetCurrentVersion,
        @Probe.IsValidSourceDirectory,
        @Probe.CreateGitRuntime
      )
    );
    Check('maintenanceflow update validates resolved source dir',
      Probe.LastValidatedSourceDir = InstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus');
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

procedure TestManagedCleanSourcesUsesCurrentVersionFallbackAndCleanupCallback;
var
  Probe: TMaintenanceProbe;
  InstallRoot: string;
  SourceDir: string;
begin
  InstallRoot := CreateUniqueTempDir('test_lazarus_maintenanceflow_clean');
  SourceDir := InstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus';
  ForceDirectories(SourceDir);

  Probe := TMaintenanceProbe.Create;
  try
    Probe.CurrentVersion := '4.0';
    Probe.SourceDirValidResult := True;
    Probe.CleanResult := 7;

    Check(
      'maintenanceflow clean uses current version fallback',
      ExecuteManagedLazarusCleanSourcesCore(
        '',
        InstallRoot,
        nil,
        @Probe.GetCurrentVersion,
        @Probe.IsValidSourceDirectory,
        @Probe.CleanSourceArtifacts
      )
    );
    Check('maintenanceflow clean asks current version provider once',
      Probe.CurrentVersionCalls = 1);
    Check('maintenanceflow clean validates resolved source dir',
      Probe.LastValidatedSourceDir = SourceDir);
    Check('maintenanceflow clean invokes cleanup callback with resolved dir',
      Probe.LastCleanSourceDir = SourceDir);
  finally
    Probe.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

begin
  TestManagedUninstallSucceedsWhenNothingExists;
  TestManagedUninstallDeletesDirAndRemovesConfig;
  TestManagedUpdateSourcesRejectsMissingOrInvalidSourceDir;
  TestManagedCleanSourcesUsesCurrentVersionFallbackAndCleanupCallback;
  Halt(PrintTestSummary);
end.
