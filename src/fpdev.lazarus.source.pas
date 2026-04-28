unit fpdev.lazarus.source;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file
// acq:allow-hardcoded-constants-file

interface

uses
  SysUtils, Classes, fpdev.utils.fs, fpdev.utils.process, fpdev.git.types,
  fpdev.git.runtime, fpdev.constants, fpdev.lazarus.sourceversionflow,
  fpdev.lazarus.sourcelifecycleflow;

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
    function LaunchExecutable(const AExecutablePath: string): Boolean;
    procedure WriteStatus(const AText: string);
    procedure DeleteSourceTree(const APath: string);
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
  LAZARUS_VERSIONS: array[0..8] of TLegacyLazarusStaticVersionInfo = (
    (Version: 'main'; Branch: 'main'; Description: 'Development version (unstable)'),
    (Version: '3.0'; Branch: 'lazarus_3_0'; Description: 'Lazarus 3.0 (stable)'),
    (Version: '2.2.6'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.6 (stable)'),
    (Version: '2.2.4'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.4 (stable)'),
    (Version: '2.2.2'; Branch: 'lazarus_2_2'; Description: 'Lazarus 2.2.2 (stable)'),
    (Version: '2.0.12'; Branch: 'lazarus_2_0'; Description: 'Lazarus 2.0.12 (legacy)'),
    (Version: '2.0.10'; Branch: 'lazarus_2_0'; Description: 'Lazarus 2.0.10 (legacy)'),
    (Version: '1.8.4'; Branch: 'lazarus_1_8'; Description: 'Lazarus 1.8.4 (legacy)'),
    (Version: '1.8.2'; Branch: 'lazarus_1_8'; Description: 'Lazarus 1.8.2 (legacy)')
  );

implementation

uses
  fpdev.version.registry, fpdev.lazarus.commandflow,
  fpdev.lazarus.sourceflow, fpdev.lazarus.sourceruntimeflow, fpdev.utils;

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

  TLazarusSourceGitCallbackAdapter = class
  private
    FClient: ILazarusSourceGitClient;
  public
    constructor Create(const AClient: ILazarusSourceGitClient);
    function GetBackend: TGitBackend;
    function Clone(const AURL, ALocalPath, ARef: string): Boolean;
    function Checkout(const ARepoPath, AName: string; const Force: Boolean): Boolean;
    function IsRepository(const APath: string): Boolean;
    function Pull(const ARepoPath: string): Boolean;
    function GetLastError: string;
  end;

constructor TLazarusSourceGitClient.Create;
begin
  inherited Create;
  FGit := NewGitRuntime;
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

constructor TLazarusSourceGitCallbackAdapter.Create(const AClient: ILazarusSourceGitClient);
begin
  inherited Create;
  FClient := AClient;
end;

function TLazarusSourceGitCallbackAdapter.GetBackend: TGitBackend;
begin
  if FClient = nil then
    Exit(gbNone);
  Result := FClient.Backend;
end;

function TLazarusSourceGitCallbackAdapter.Clone(
  const AURL, ALocalPath, ARef: string
): Boolean;
begin
  Result := Assigned(FClient) and FClient.Clone(AURL, ALocalPath, ARef);
end;

function TLazarusSourceGitCallbackAdapter.Checkout(
  const ARepoPath, AName: string;
  const Force: Boolean
): Boolean;
begin
  Result := Assigned(FClient) and FClient.Checkout(ARepoPath, AName, Force);
end;

function TLazarusSourceGitCallbackAdapter.IsRepository(const APath: string): Boolean;
begin
  Result := Assigned(FClient) and FClient.IsRepository(APath);
end;

function TLazarusSourceGitCallbackAdapter.Pull(const ARepoPath: string): Boolean;
begin
  Result := Assigned(FClient) and FClient.Pull(ARepoPath);
end;

function TLazarusSourceGitCallbackAdapter.GetLastError: string;
begin
  if FClient = nil then
    Exit('');
  Result := FClient.LastError;
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

procedure TLazarusSourceManager.WriteStatus(const AText: string);
begin
  WriteLn(AText);
end;

procedure TLazarusSourceManager.DeleteSourceTree(const APath: string);
begin
  {$IFDEF MSWINDOWS}
  ExecuteCommand('cmd', ['/c', 'rmdir', '/s', '/q', APath], '');
  {$ELSE}
  ExecuteCommand('rm', ['-rf', APath], '');
  {$ENDIF}
end;

function TLazarusSourceManager.GetSourcePath(const AVersion: string): string;
begin
  Result := BuildLazarusLegacySourcePathCore(
    FSourceRoot,
    ResolveLazarusLegacySourceVersionCore(AVersion, '', 'main')
  );
end;

function TLazarusSourceManager.GetVersionFromBranch(const ABranch: string): string;
begin
  Result := ResolveLegacyLazarusVersionFromBranchCore(
    ABranch,
    TVersionRegistry.Instance.GetLazarusReleases,
    LAZARUS_VERSIONS
  );
end;

function TLazarusSourceManager.IsValidSourceDirectory(const APath: string): Boolean;
begin
  Result := IsValidLazarusLegacySourceTreeCore(APath);
end;

function TLazarusSourceManager.ConfigureCustomFPCIDE(
  const AVersion, ASourcePath: string): Boolean;
var
  ConfigRoot: string;
begin
  ConfigRoot := '';
  get_env('FPDEV_LAZARUS_CONFIG_ROOT', ConfigRoot);
  Result := ConfigureLegacyLazarusCustomFPCIDECore(
    AVersion,
    ASourcePath,
    FFPCPath,
    ConfigRoot,
    get_env('HOME'),
    get_env('APPDATA'),
    @WriteStatus
  );
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

function TLazarusSourceManager.LaunchExecutable(const AExecutablePath: string): Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := ExecuteCommand('cmd', ['/c', 'start', '', AExecutablePath], '');
  {$ELSE}
  Result := TProcessExecutor.Launch(AExecutablePath, [], '');
  {$ENDIF}
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
  GitAdapter: TLazarusSourceGitCallbackAdapter;
  UseVersion: string;
  RepositoryURL: string;
  ClonePlan: TLazarusLegacySourceClonePlan;
begin
  Result := False;
  RepositoryURL := TVersionRegistry.Instance.GetLazarusRepository;
  if RepositoryURL = '' then
    RepositoryURL := LAZARUS_GIT_URL;
  UseVersion := ResolveLazarusLegacySourceVersionCore(AVersion, '', 'main');
  ClonePlan := CreateLazarusLegacyClonePlanCore(
    AVersion,
    'main',
    FSourceRoot,
    RepositoryURL,
    ResolveLegacyLazarusCloneRefCore(
      UseVersion,
      TVersionRegistry.Instance.GetLazarusGitTag(UseVersion),
      TVersionRegistry.Instance.GetLazarusBranch(UseVersion),
      TVersionRegistry.Instance.GetLazarusReleases,
      LAZARUS_VERSIONS
    )
  );
  Git := CreateGitClient;
  GitAdapter := TLazarusSourceGitCallbackAdapter.Create(Git);
  try
    Result := ExecuteLazarusLegacyCloneCore(
      ClonePlan,
      FCurrentVersion,
      @WriteStatus,
      @DeleteSourceTree,
      @IsValidSourceDirectory,
      @GitAdapter.GetBackend,
      @GitAdapter.Clone
    );
  finally
    GitAdapter.Free;
  end;
end;

function TLazarusSourceManager.UpdateLazarusSource(const AVersion: string): Boolean;
var
  Git: ILazarusSourceGitClient;
  GitAdapter: TLazarusSourceGitCallbackAdapter;
  UpdatePlan: TLazarusLegacySourceUpdatePlan;
begin
  Result := False;
  UpdatePlan := CreateLazarusLegacyUpdatePlanCore(
    AVersion,
    FCurrentVersion,
    'main',
    FSourceRoot
  );
  Git := CreateGitClient;
  GitAdapter := TLazarusSourceGitCallbackAdapter.Create(Git);
  try
    Result := ExecuteLazarusLegacyUpdateCore(
      UpdatePlan,
      FCurrentVersion,
      @WriteStatus,
      @IsValidSourceDirectory,
      @GitAdapter.GetBackend,
      @GitAdapter.Pull,
      @GitAdapter.GetLastError
    );
  finally
    GitAdapter.Free;
  end;
end;

function TLazarusSourceManager.SwitchLazarusVersion(const AVersion: string): Boolean;
var
  SourcePath: string;
  RefName: string;
  Git: ILazarusSourceGitClient;
  GitAdapter: TLazarusSourceGitCallbackAdapter;
  HasGitMetadata: Boolean;
begin
  Result := False;

  SourcePath := GetSourcePath(AVersion);
  HasGitMetadata := HasGitRepositoryMetadata(SourcePath);
  RefName := ResolveLegacyLazarusCloneRefCore(
    AVersion,
    TVersionRegistry.Instance.GetLazarusGitTag(AVersion),
    TVersionRegistry.Instance.GetLazarusBranch(AVersion),
    TVersionRegistry.Instance.GetLazarusReleases,
    LAZARUS_VERSIONS
  );

  Git := CreateGitClient;
  GitAdapter := TLazarusSourceGitCallbackAdapter.Create(Git);
  try
    Result := ExecuteLazarusLegacySwitchCore(
      AVersion,
      SourcePath,
      RefName,
      HasGitMetadata,
      FCurrentVersion,
      @WriteStatus,
      @IsVersionInstalled,
      @CloneLazarusSource,
      @IsValidSourceDirectory,
      @GitAdapter.GetBackend,
      @GitAdapter.IsRepository,
      @GitAdapter.Checkout,
      @GitAdapter.GetLastError
    );
  finally
    GitAdapter.Free;
  end;
end;

function TLazarusSourceManager.ListAvailableVersions: TStringArray;
begin
  Result := BuildLegacyLazarusAvailableVersionsCore(
    TVersionRegistry.Instance.GetLazarusReleases,
    LAZARUS_VERSIONS
  );
end;

function TLazarusSourceManager.ListLocalVersions: TStringArray;
begin
  Result := ListLegacyLazarusLocalVersionsCore(
    FSourceRoot,
    @IsValidSourceDirectory
  );
end;

function TLazarusSourceManager.GetCurrentVersion: string;
begin
  Result := FCurrentVersion;
end;

function TLazarusSourceManager.IsVersionAvailable(const AVersion: string): Boolean;
begin
  Result := IsLegacyLazarusVersionAvailableCore(
    AVersion,
    TVersionRegistry.Instance.IsLazarusVersionValid(AVersion),
    TVersionRegistry.Instance.GetLazarusReleases,
    LAZARUS_VERSIONS
  );
end;

function TLazarusSourceManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := IsValidSourceDirectory(GetSourcePath(AVersion));
end;

function TLazarusSourceManager.GetLazarusSourcePath(const AVersion: string): string;
begin
  Result := GetSourcePath(
    ResolveLazarusLegacySourceVersionCore(AVersion, FCurrentVersion, 'main')
  );
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
begin
  SourcePath := GetLazarusSourcePath(AVersion);
  Result := ExecuteLegacyLazarusBuildCore(
    SourcePath,
    FFPCPath,
    FParallelJobs,
    @IsValidSourceDirectory,
    @ExecuteCommand,
    @WriteStatus
  );
end;

function TLazarusSourceManager.LaunchLazarus(const AVersion: string): Boolean;
var
  ExecutablePath: string;
begin
  ExecutablePath := GetLazarusExecutablePath(AVersion);
  Result := ExecuteLegacyLazarusLaunchCore(
    ExecutablePath,
    @LaunchExecutable,
    @WriteStatus
  );
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

  Result := ResolveLegacyLazarusDescriptionCore(
    Version,
    TVersionRegistry.Instance.GetLazarusRelease(Version),
    TVersionRegistry.Instance.GetLazarusReleases,
    LAZARUS_VERSIONS
  );
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
  SourcePath := GetLazarusSourcePath(Version);
  ExecutablePath := GetLazarusExecutablePath(Version);

  Result := ExecuteLazarusLegacyInstallCore(
    Version,
    SourcePath,
    ExecutablePath,
    PreviousVersion,
    NeedsIDEConfig,
    FCurrentVersion,
    @WriteStatus,
    @CloneLazarusSource,
    @BuildLazarus,
    @ConfigureCustomFPCIDE,
    @SwitchLazarusVersion
  );
end;

end.
