unit fpdev.lazarus.source;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file
// acq:allow-hardcoded-constants-file

interface

uses
  SysUtils, Classes, fpdev.utils.fs, fpdev.utils.process, fpdev.utils.git,
  fpdev.git.runtime, fpdev.constants;

type
  ILazarusSourceGitClient = interface
    ['{3EFDBF4C-5DA8-4ED7-BF32-3E3194971F89}']
    function GetBackend: TGitBackend;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function GetLastError: string;
    property Backend: TGitBackend read GetBackend;
    property LastError: string read GetLastError;
  end;

  { TLazarusSourceManager }
  TLazarusSourceManager = class
  private
    FSourceRoot: string;
    FCurrentVersion: string;
    FFPCPath: string;
    FParallelJobs: Integer;

    function GetSourcePath(const AVersion: string): string;
    function GetVersionFromBranch(const ABranch: string): string;
    function IsValidSourceDirectory(const APath: string): Boolean;
    function ConfigureCustomFPCIDE(const AVersion, ASourcePath: string): Boolean;
    function ExecuteCommand(const AExecutable: string; const AParams: array of string;
      const AWorkingDir: string = ''): Boolean;
  protected
    function CreateGitClient: ILazarusSourceGitClient; virtual;
    function ProtectedGetVersionFromBranch(const ABranch: string): string;

  public
    constructor Create(const ASourceRoot: string = '');
    destructor Destroy; override;

    // Configuration
    procedure SetFPCPath(const APath: string);
    procedure SetParallelJobs(AJobs: Integer);

    // Source management
    function CloneLazarusSource(const AVersion: string = 'main'): Boolean;
    function UpdateLazarusSource(const AVersion: string = ''): Boolean;
    function SwitchLazarusVersion(const AVersion: string): Boolean;
    function ListAvailableVersions: TStringArray;
    function ListLocalVersions: TStringArray;

    // Version information
    function GetCurrentVersion: string;
    function IsVersionAvailable(const AVersion: string): Boolean;
    function IsVersionInstalled(const AVersion: string): Boolean;

    // Path management
    function GetLazarusSourcePath(const AVersion: string = ''): string;
    function GetLazarusBuildPath(const AVersion: string = ''): string;
    function GetLazarusExecutablePath(const AVersion: string = ''): string;

    // Lazarus-specific features
    function BuildLazarus(const AVersion: string = ''): Boolean;
    function LaunchLazarus(const AVersion: string = ''): Boolean;
    function GetLazarusVersion(const AVersion: string = ''): string;
    function InstallLazarusVersion(const AVersion: string): Boolean;

    // Properties
    property SourceRoot: string read FSourceRoot write FSourceRoot;
    property CurrentVersion: string read GetCurrentVersion;
    property FPCPath: string read FFPCPath write FFPCPath;
    property ParallelJobs: Integer read FParallelJobs write FParallelJobs;
  end;

const
  // Lazarus Git repository information - using central constants
  LAZARUS_GIT_URL = LAZARUS_OFFICIAL_REPO;

  // Supported Lazarus version branches
  LAZARUS_VERSIONS: array[0..8] of record
    Version: string;
    Branch: string;
    Description: string;
    FPCVersion: string;
  end = (
    (Version: 'main'; Branch: 'main'; Description: 'Development version (unstable)'; FPCVersion: '3.2.2'),
    (Version: '3.0'; Branch: 'lazarus_3_0'; Description: 'Lazarus 3.0 (stable)'; FPCVersion: '3.2.2'),
    (Version: '2.2.6'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.6 (stable)'; FPCVersion: '3.2.2'),
    (Version: '2.2.4'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.4 (stable)'; FPCVersion: '3.2.2'),
    (Version: '2.2.2'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.2 (stable)'; FPCVersion: '3.2.2'),
    (Version: '2.0.12'; Branch: 'lazarus_2_0'; Description: 'Lazarus 2.0.12 (legacy)'; FPCVersion: '3.2.0'),
    (Version: '2.0.10'; Branch: 'lazarus_2_0'; Description: 'Lazarus 2.0.10 (legacy)'; FPCVersion: '3.2.0'),
    (Version: '1.8.4'; Branch: 'lazarus_1_8'; Description: 'Lazarus 1.8.4 (legacy)'; FPCVersion: '3.0.4'),
    (Version: '1.8.2'; Branch: 'lazarus_1_8'; Description: 'Lazarus 1.8.2 (legacy)'; FPCVersion: '3.0.4')
  );

implementation

uses
  fpdev.version.registry, fpdev.lazarus.config, fpdev.lazarus.commandflow, fpdev.utils;

function FindStaticLazarusVersionIndex(const AVersion: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Version, AVersion) then
      Exit(i);
  end;
end;

function FindStaticLazarusBranchIndex(const ABranch: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Branch, ABranch) then
      Exit(i);
  end;
end;

function RegistryHasLazarusReleases(const AReleases: TLazarusReleaseArray): Boolean; forward;

function ResolveLazarusCloneRefFromRegistryOrStatic(const AVersion: string): string;
var
  Releases: TLazarusReleaseArray;
  StaticIndex: Integer;
begin
  Result := TVersionRegistry.Instance.GetLazarusGitTag(AVersion);
  if Result <> '' then
    Exit;

  Result := TVersionRegistry.Instance.GetLazarusBranch(AVersion);
  if Result <> '' then
    Exit;

  Releases := TVersionRegistry.Instance.GetLazarusReleases;
  if RegistryHasLazarusReleases(Releases) then
    Exit(AVersion);

  StaticIndex := FindStaticLazarusVersionIndex(AVersion);
  if StaticIndex >= 0 then
    Exit(LAZARUS_VERSIONS[StaticIndex].Branch);

  Result := AVersion;
end;

function BuildLazarusDescription(const AVersion, AChannel: string): string;
begin
  if SameText(AVersion, 'main') or SameText(AChannel, 'development') then
    Exit('Development version (unstable)');

  if Trim(AChannel) <> '' then
    Exit('Lazarus ' + AVersion + ' (' + AChannel + ')');

  Result := 'Lazarus ' + AVersion;
end;

function ResolveLazarusDescriptionFromRegistryOrStatic(const AVersion: string): string;
var
  Releases: TLazarusReleaseArray;
  Release: TLazarusReleaseInfo;
  StaticIndex: Integer;
begin
  Release := TVersionRegistry.Instance.GetLazarusRelease(AVersion);
  if Trim(Release.Version) <> '' then
    Exit(BuildLazarusDescription(Release.Version, Release.Channel));

  Releases := TVersionRegistry.Instance.GetLazarusReleases;
  if RegistryHasLazarusReleases(Releases) then
    Exit(AVersion);

  StaticIndex := FindStaticLazarusVersionIndex(AVersion);
  if StaticIndex >= 0 then
    Exit(LAZARUS_VERSIONS[StaticIndex].Description);

  Result := AVersion;
end;

function RegistryHasLazarusReleases(const AReleases: TLazarusReleaseArray): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(AReleases) do
  begin
    if Trim(AReleases[i].Version) <> '' then
      Exit(True);
  end;
end;

function HasGitRepositoryMetadata(const APath: string): Boolean;
var
  LGitPath: string;
begin
  LGitPath := IncludeTrailingPathDelimiter(APath) + '.git';
  Result := DirectoryExists(LGitPath) or FileExists(LGitPath);
end;

type
  TLazarusSourceGitClient = class(TInterfacedObject, ILazarusSourceGitClient)
  private
    FGit: IGitRuntime;
  public
    constructor Create;
    destructor Destroy; override;
    function GetBackend: TGitBackend;
    function Clone(const AURL, ALocalPath: string; const ABranch: string = ''): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean = False): Boolean;
    function IsRepository(const APath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function GetLastError: string;
  end;

constructor TLazarusSourceGitClient.Create;
begin
  inherited Create;
  FGit := TGitRuntime.Create;
end;

destructor TLazarusSourceGitClient.Destroy;
begin
  FGit := nil;
  inherited Destroy;
end;

function TLazarusSourceGitClient.GetBackend: TGitBackend;
begin
  Result := FGit.Backend;
end;

function TLazarusSourceGitClient.Clone(const AURL, ALocalPath: string;
  const ABranch: string): Boolean;
begin
  Result := FGit.Clone(AURL, ALocalPath, ABranch);
end;

function TLazarusSourceGitClient.Checkout(const ARepoPath, AName: string;
  const Force: Boolean): Boolean;
begin
  Result := FGit.Checkout(ARepoPath, AName, Force);
end;

function TLazarusSourceGitClient.IsRepository(const APath: string): Boolean;
begin
  Result := FGit.IsRepository(APath);
end;

function TLazarusSourceGitClient.Pull(const ARepoPath: string): Boolean;
begin
  Result := FGit.PullFastForwardOnly(ARepoPath);
end;

function TLazarusSourceGitClient.GetLastError: string;
begin
  Result := FGit.LastError;
end;

{ TLazarusSourceManager }

constructor TLazarusSourceManager.Create(const ASourceRoot: string);
begin
  inherited Create;

  if ASourceRoot <> '' then
    FSourceRoot := ASourceRoot
  else
    FSourceRoot := 'sources' + PathDelim + 'lazarus';

  FCurrentVersion := '';
  FFPCPath := '';
  FParallelJobs := 4;

  // Ensure the source root directory exists
  if not DirectoryExists(FSourceRoot) then
    EnsureDir(FSourceRoot);
end;

destructor TLazarusSourceManager.Destroy;
begin
  inherited Destroy;
end;

procedure TLazarusSourceManager.SetFPCPath(const APath: string);
begin
  FFPCPath := APath;
end;

procedure TLazarusSourceManager.SetParallelJobs(AJobs: Integer);
begin
  if AJobs < 1 then
    FParallelJobs := 1
  else
    FParallelJobs := AJobs;
end;

function TLazarusSourceManager.GetSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  if AVersion = '' then
    Version := 'main'
  else
    Version := AVersion;

  Result := FSourceRoot + PathDelim + 'lazarus-' + Version;
end;

function TLazarusSourceManager.GetVersionFromBranch(const ABranch: string): string;
var
  Releases: TLazarusReleaseArray;
  i: Integer;
  StaticIndex: Integer;
begin
  Result := ABranch;

  Releases := TVersionRegistry.Instance.GetLazarusReleases;
  for i := 0 to High(Releases) do
  begin
    if SameText(Releases[i].GitTag, ABranch) or SameText(Releases[i].Branch, ABranch) then
      Exit(Releases[i].Version);
  end;

  if RegistryHasLazarusReleases(Releases) then
    Exit(ABranch);

  StaticIndex := FindStaticLazarusBranchIndex(ABranch);
  if StaticIndex >= 0 then
    Result := LAZARUS_VERSIONS[StaticIndex].Version;
end;

function TLazarusSourceManager.IsValidSourceDirectory(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath) and
    DirectoryExists(APath + PathDelim + 'ide') and
    DirectoryExists(APath + PathDelim + 'lcl') and
    DirectoryExists(APath + PathDelim + 'packager');
end;

function TLazarusSourceManager.ConfigureCustomFPCIDE(
  const AVersion, ASourcePath: string): Boolean;
var
  IDEConfig: TLazarusIDEConfig;
  ConfigDir: string;
  ConfigRoot: string;
begin
  Result := True;
  if Trim(FFPCPath) = '' then
    Exit;

  if not FileExists(FFPCPath) then
  begin
    WriteLn('Error: Configured FPC executable not found: ', FFPCPath);
    Exit(False);
  end;

  ConfigRoot := '';
  get_env('FPDEV_LAZARUS_CONFIG_ROOT', ConfigRoot);
  ConfigDir := ResolveLazarusConfigDirCore(
    AVersion,
    ConfigRoot,
    get_env('HOME'),
    get_env('APPDATA')
  );

  IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
  try
    Result := IDEConfig.SetCompilerPath(FFPCPath);
    Result := IDEConfig.SetLibraryPath(ASourcePath) and Result;
    {$IFDEF MSWINDOWS}
    Result := IDEConfig.SetMakePath('make.exe') and Result;
    {$ELSE}
    Result := IDEConfig.SetMakePath(UNIX_MAKE_PATH) and Result;
    {$ENDIF}
    Result := IDEConfig.ValidateConfig and Result;
  finally
    IDEConfig.Free;
  end;
end;

function TLazarusSourceManager.ExecuteCommand(const AExecutable: string;
  const AParams: array of string; const AWorkingDir: string): Boolean;
var
  LResult: TProcessResult;
  LParams: array of string;
  LExecutablePath: string;
  i: Integer;
begin
  // Convert open array to dynamic array
  LParams := nil;
  SetLength(LParams, Length(AParams));
  for i := 0 to High(AParams) do
    LParams[i] := AParams[i];

  LExecutablePath := AExecutable;
  if SameText(AExecutable, 'make') then
  begin
    LExecutablePath := TProcessExecutor.FindExecutable(AExecutable);
    if LExecutablePath = '' then
      LExecutablePath := AExecutable;
    LResult := TProcessExecutor.RunDirect(LExecutablePath, LParams, AWorkingDir);
  end
  else
    LResult := TProcessExecutor.Execute(LExecutablePath, LParams, AWorkingDir);
  if not LResult.Success and (LResult.ErrorMessage <> '') then
    WriteLn('Error executing command: ', LResult.ErrorMessage);
  Result := LResult.Success;
end;

function TLazarusSourceManager.CreateGitClient: ILazarusSourceGitClient;
begin
  Result := TLazarusSourceGitClient.Create;
end;

function TLazarusSourceManager.ProtectedGetVersionFromBranch(
  const ABranch: string): string;
begin
  Result := GetVersionFromBranch(ABranch);
end;

function TLazarusSourceManager.CloneLazarusSource(const AVersion: string): Boolean;
var
  Git: ILazarusSourceGitClient;
  Version, RefName, SourcePath, RepositoryURL: string;
begin
  Result := False;

  Version := AVersion;
  if Version = '' then
    Version := 'main';

  // Match the manager install path: prefer registry git_tag, then branch, then legacy fallback.
  RefName := ResolveLazarusCloneRefFromRegistryOrStatic(Version);

  SourcePath := GetSourcePath(Version);
  RepositoryURL := TVersionRegistry.Instance.GetLazarusRepository;
  if RepositoryURL = '' then
    RepositoryURL := LAZARUS_GIT_URL;

  WriteLn('Cloning Lazarus source...');
  WriteLn('  Version: ', Version);
  WriteLn('  Ref: ', RefName);
  WriteLn('  Target: ', SourcePath);
  WriteLn;

  Git := CreateGitClient;
  if (Git = nil) or (Git.Backend = gbNone) then
  begin
    WriteLn('Error: No Git backend available (neither libgit2 nor git command found)');
    Exit(False);
  end;

  // If directory already exists, delete it first
  if DirectoryExists(SourcePath) then
  begin
    WriteLn('Removing existing source directory...');
    {$IFDEF MSWINDOWS}
    ExecuteCommand('cmd', ['/c', 'rmdir', '/s', '/q', SourcePath], '');
    {$ELSE}
    ExecuteCommand('rm', ['-rf', SourcePath], '');
    {$ENDIF}
  end;

  WriteLn('Using backend: ', GitBackendToString(Git.Backend));

  // Clone repository (libgit2-first; CLI shallow clone fallback inside TGitOperations)
  Result := Git.Clone(RepositoryURL, SourcePath, RefName);

  if Result then
  begin
    if not IsValidSourceDirectory(SourcePath) then
    begin
      WriteLn('Error: Cloned repository is not a valid Lazarus source tree: ', SourcePath);
      Exit(False);
    end;

    WriteLn('Lazarus source cloned successfully.');
    FCurrentVersion := Version;
  end
  else
  begin
    WriteLn('Error: Failed to clone Lazarus source.');
  end;
end;

function TLazarusSourceManager.UpdateLazarusSource(const AVersion: string): Boolean;
var
  Git: ILazarusSourceGitClient;
  Version, SourcePath: string;
begin
  Result := False;

  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  SourcePath := GetSourcePath(Version);

  if not IsValidSourceDirectory(SourcePath) then
  begin
    WriteLn('Error: Invalid Lazarus source directory: ', SourcePath);
    WriteLn('Please clone the source first.');
    Exit;
  end;

  WriteLn('Updating Lazarus source...');
  WriteLn('  Version: ', Version);
  WriteLn('  Path: ', SourcePath);

  Git := CreateGitClient;
  if (Git = nil) or (Git.Backend = gbNone) then
  begin
    WriteLn('Error: No Git backend available (neither libgit2 nor git command found)');
    Exit(False);
  end;

  WriteLn('Using backend: ', GitBackendToString(Git.Backend));
  Result := Git.Pull(SourcePath);

  if Result then
  begin
    FCurrentVersion := Version;
    WriteLn('Lazarus source updated successfully.');
  end
  else
  begin
    WriteLn('Error: Failed to update Lazarus source.');
    WriteLn('  ', Git.LastError);
  end;
end;

function TLazarusSourceManager.SwitchLazarusVersion(const AVersion: string): Boolean;
var
  SourcePath: string;
  RefName: string;
  Git: ILazarusSourceGitClient;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('Version ', AVersion, ' not installed, cloning...');
    Result := CloneLazarusSource(AVersion);
  end
  else
  begin
    SourcePath := GetSourcePath(AVersion);
    if not IsValidSourceDirectory(SourcePath) then
    begin
      WriteLn('Error: Invalid Lazarus source directory: ', SourcePath);
      Exit(False);
    end;

    if HasGitRepositoryMetadata(SourcePath) then
    begin
      RefName := ResolveLazarusCloneRefFromRegistryOrStatic(AVersion);
      Git := CreateGitClient;
      if (Git = nil) or (Git.Backend = gbNone) then
      begin
        WriteLn('Error: No Git backend available (neither libgit2 nor git command found)');
        Exit(False);
      end;

      if not Git.IsRepository(SourcePath) then
      begin
        WriteLn('Error: Existing Lazarus source tree is not an accessible git repository: ', SourcePath);
        Exit(False);
      end;

      if not Git.Checkout(SourcePath, RefName, True) then
      begin
        WriteLn('Error: Failed to switch Lazarus source to ref: ', RefName);
        if Git.LastError <> '' then
          WriteLn('  ', Git.LastError);
        Exit(False);
      end;

      if not IsValidSourceDirectory(SourcePath) then
      begin
        WriteLn('Error: Switched repository is not a valid Lazarus source tree: ', SourcePath);
        Exit(False);
      end;

      WriteLn('Switching to Lazarus version: ', AVersion);
      WriteLn('  Ref: ', RefName);
    end
    else
      WriteLn('Switching to Lazarus version: ', AVersion);

    FCurrentVersion := AVersion;
    Result := True;
  end;
end;

function TLazarusSourceManager.ListAvailableVersions: TStringArray;
var
  Releases: TLazarusReleaseArray;
  Values: TStringList;
  i: Integer;
  UseStaticFallback: Boolean;
begin
  Result := nil;
  Values := TStringList.Create;
  try
    Releases := TVersionRegistry.Instance.GetLazarusReleases;
    UseStaticFallback := not RegistryHasLazarusReleases(Releases);
    for i := 0 to High(Releases) do
    begin
      if (Trim(Releases[i].Version) <> '') and (Values.IndexOf(Releases[i].Version) < 0) then
        Values.Add(Releases[i].Version);
    end;

    if UseStaticFallback then
      for i := 0 to High(LAZARUS_VERSIONS) do
      begin
        if Values.IndexOf(LAZARUS_VERSIONS[i].Version) < 0 then
          Values.Add(LAZARUS_VERSIONS[i].Version);
      end;

    SetLength(Result, Values.Count);
    for i := 0 to Values.Count - 1 do
      Result[i] := Values[i];
  finally
    Values.Free;
  end;
end;

function TLazarusSourceManager.ListLocalVersions: TStringArray;
var
  SearchRec: TSearchRec;
  VersionList: TStringList;
  DirName, Version, SourcePath: string;
  i: Integer;
begin
  Result := nil;
  VersionList := TStringList.Create;
  try
    if FindFirst(FSourceRoot + PathDelim + 'lazarus-*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          DirName := SearchRec.Name;
          if Pos('lazarus-', DirName) = 1 then
          begin
            SourcePath := FSourceRoot + PathDelim + DirName;
            if not IsValidSourceDirectory(SourcePath) then
              Continue;
            Version := Copy(DirName, 9, Length(DirName) - 8);
            VersionList.Add(Version);
          end;
        end;
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;

    SetLength(Result, VersionList.Count);
    for i := 0 to VersionList.Count - 1 do
      Result[i] := VersionList[i];

  finally
    VersionList.Free;
  end;
end;

function TLazarusSourceManager.GetCurrentVersion: string;
begin
  Result := FCurrentVersion;
end;

function TLazarusSourceManager.IsVersionAvailable(const AVersion: string): Boolean;
var
  Releases: TLazarusReleaseArray;
begin
  if TVersionRegistry.Instance.IsLazarusVersionValid(AVersion) then
    Exit(True);

  Releases := TVersionRegistry.Instance.GetLazarusReleases;
  if RegistryHasLazarusReleases(Releases) then
    Exit(False);

  Result := FindStaticLazarusVersionIndex(AVersion) >= 0;
end;

function TLazarusSourceManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := IsValidSourceDirectory(GetSourcePath(AVersion));
end;

function TLazarusSourceManager.GetLazarusSourcePath(const AVersion: string): string;
var
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  Result := GetSourcePath(Version);
end;

function TLazarusSourceManager.GetLazarusBuildPath(const AVersion: string): string;
begin
  Result := GetLazarusSourcePath(AVersion);
end;

function TLazarusSourceManager.GetLazarusExecutablePath(const AVersion: string): string;
var
  SourcePath: string;
begin
  SourcePath := GetLazarusSourcePath(AVersion);
  {$IFDEF MSWINDOWS}
  Result := SourcePath + PathDelim + 'lazarus.exe';
  {$ELSE}
  Result := SourcePath + PathDelim + 'lazarus';
  {$ENDIF}
end;

function TLazarusSourceManager.BuildLazarus(const AVersion: string): Boolean;
var
  SourcePath: string;
  MakeParams: array of string;
begin
  Result := False;
  SourcePath := GetLazarusSourcePath(AVersion);

  if not IsValidSourceDirectory(SourcePath) then
  begin
    WriteLn('Error: Invalid Lazarus source directory: ', SourcePath);
    WriteLn('Please clone the source first.');
    Exit;
  end;

  WriteLn('Building Lazarus...');
  WriteLn('  Source path: ', SourcePath);
  WriteLn('  Parallel jobs: ', FParallelJobs);
  if FFPCPath <> '' then
    WriteLn('  FPC path: ', FFPCPath);
  WriteLn('  Note: Build may take 10-30 minutes');
  WriteLn;

  // Build make parameters
  MakeParams := nil;
  SetLength(MakeParams, 0);

  // Add clean and all targets
  SetLength(MakeParams, Length(MakeParams) + 1);
  MakeParams[High(MakeParams)] := 'clean';
  SetLength(MakeParams, Length(MakeParams) + 1);
  MakeParams[High(MakeParams)] := 'all';

  // Add parallel jobs
  if FParallelJobs > 1 then
  begin
    SetLength(MakeParams, Length(MakeParams) + 1);
    MakeParams[High(MakeParams)] := '-j' + IntToStr(FParallelJobs);
  end;

  // Add FPC path if specified
  if FFPCPath <> '' then
  begin
    SetLength(MakeParams, Length(MakeParams) + 1);
    MakeParams[High(MakeParams)] := 'PP=' + FFPCPath;
  end;

  Result := ExecuteCommand('make', MakeParams, SourcePath);

  if Result then
    WriteLn('Lazarus build successful.')
  else
    WriteLn('Error: Lazarus build failed.');
end;

function TLazarusSourceManager.LaunchLazarus(const AVersion: string): Boolean;
var
  ExecutablePath: string;
begin
  Result := False;
  ExecutablePath := GetLazarusExecutablePath(AVersion);

  if not FileExists(ExecutablePath) then
  begin
    WriteLn('Error: Lazarus executable not found: ', ExecutablePath);
    WriteLn('Please build Lazarus first using BuildLazarus.');
    Exit;
  end;

  WriteLn('Launching Lazarus: ', ExecutablePath);

  {$IFDEF MSWINDOWS}
  Result := ExecuteCommand('cmd', ['/c', 'start', '', ExecutablePath], '');
  {$ELSE}
  Result := TProcessExecutor.Launch(ExecutablePath, [], '');
  {$ENDIF}

  if Result then
    WriteLn('Lazarus launched successfully.')
  else
    WriteLn('Error: Failed to launch Lazarus.');
end;

function TLazarusSourceManager.GetLazarusVersion(const AVersion: string): string;
var
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  Result := ResolveLazarusDescriptionFromRegistryOrStatic(Version);
end;

function TLazarusSourceManager.InstallLazarusVersion(const AVersion: string): Boolean;
var
  Version: string;
  PreviousVersion: string;
  ExecutablePath: string;
  SourcePath: string;
  NeedsIDEConfig: Boolean;
begin
  Result := False;
  Version := AVersion;
  if Version = '' then
    Version := 'main';
  PreviousVersion := FCurrentVersion;
  NeedsIDEConfig := Trim(FFPCPath) <> '';

  WriteLn('Installing Lazarus version: ', Version);
  if NeedsIDEConfig then
    WriteLn('Steps: 1. Clone source -> 2. Build -> 3. Configure IDE -> 4. Activate source tree')
  else
    WriteLn('Steps: 1. Clone source -> 2. Build -> 3. Activate source tree');
  WriteLn;

  // Step 1: Clone source
  WriteLn('[1/3] Cloning Lazarus source...');
  if not CloneLazarusSource(Version) then
  begin
    FCurrentVersion := PreviousVersion;
    WriteLn('Error: Source clone failed, installation aborted.');
    Exit;
  end;

  // Step 2: Build
  WriteLn('[2/3] Building Lazarus IDE...');
  if not BuildLazarus(Version) then
  begin
    FCurrentVersion := PreviousVersion;
    WriteLn('Error: Build failed, installation aborted.');
    Exit;
  end;

  ExecutablePath := GetLazarusExecutablePath(Version);
  if not FileExists(ExecutablePath) then
  begin
    FCurrentVersion := PreviousVersion;
    WriteLn('Error: Lazarus executable not found after build: ', ExecutablePath);
    Exit;
  end;

  SourcePath := GetLazarusSourcePath(Version);
  if NeedsIDEConfig then
  begin
    WriteLn('[3/4] Configuring Lazarus IDE for custom FPC...');
    if not ConfigureCustomFPCIDE(Version, SourcePath) then
    begin
      FCurrentVersion := PreviousVersion;
      WriteLn('Error: Failed to configure Lazarus IDE for custom FPC path.');
      Exit;
    end;
  end;

  if NeedsIDEConfig then
    WriteLn('[4/4] Setting as current source environment...')
  else
    WriteLn('[3/3] Setting as current source environment...');
  if SwitchLazarusVersion(Version) then
  begin
    WriteLn('Lazarus source tree ', Version, ' is ready.');
    WriteLn('Current Lazarus version: ', Version);
    WriteLn('Source path: ', SourcePath);
    WriteLn('Executable path: ', ExecutablePath);
    Result := True;
  end
  else
  begin
    FCurrentVersion := PreviousVersion;
    WriteLn('Error: Failed to activate source tree.');
  end;
end;

end.
