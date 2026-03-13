unit fpdev.lazarus.source;

{$mode objfpc}{$H+}
// acq:allow-debug-output-file
// acq:allow-hardcoded-constants-file

interface

uses
  SysUtils, Classes, fpdev.utils.fs, fpdev.utils.process, fpdev.utils.git, fpdev.constants;

type
  { TLazarusSourceManager }
  TLazarusSourceManager = class
  private
    FSourceRoot: string;
    FCurrentVersion: string;
    FFPCPath: string;
    FParallelJobs: Integer;
    FGitOps: TGitOperations;

    function GetSourcePath(const AVersion: string): string;
    function GetVersionFromBranch(const ABranch: string): string;
    function ExecuteCommand(const AExecutable: string; const AParams: array of string;
      const AWorkingDir: string = ''): Boolean;

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

  FGitOps := TGitOperations.Create;
end;

destructor TLazarusSourceManager.Destroy;
begin
  if Assigned(FGitOps) then
    FreeAndNil(FGitOps);
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
  i: Integer;
begin
  Result := ABranch;

  // Infer version from branch name
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Branch, ABranch) then
    begin
      Result := LAZARUS_VERSIONS[i].Version;
      Break;
    end;
  end;
end;

function TLazarusSourceManager.ExecuteCommand(const AExecutable: string;
  const AParams: array of string; const AWorkingDir: string): Boolean;
var
  LResult: TProcessResult;
  LParams: array of string;
  i: Integer;
begin
  // Convert open array to dynamic array
  LParams := nil;
  SetLength(LParams, Length(AParams));
  for i := 0 to High(AParams) do
    LParams[i] := AParams[i];

  LResult := TProcessExecutor.Execute(AExecutable, LParams, AWorkingDir);
  if not LResult.Success and (LResult.ErrorMessage <> '') then
    WriteLn('Error executing command: ', LResult.ErrorMessage);
  Result := LResult.Success;
end;

function TLazarusSourceManager.CloneLazarusSource(const AVersion: string): Boolean;
var
  Version, Branch, SourcePath: string;
  i: Integer;
begin
  Result := False;

  Version := AVersion;
  if Version = '' then
    Version := 'main';

  // Find corresponding branch
  Branch := Version;
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Version, Version) then
    begin
      Branch := LAZARUS_VERSIONS[i].Branch;
      Break;
    end;
  end;

  SourcePath := GetSourcePath(Version);

  WriteLn('Cloning Lazarus source...');
  WriteLn('  Version: ', Version);
  WriteLn('  Branch: ', Branch);
  WriteLn('  Target: ', SourcePath);
  WriteLn;

  if (not Assigned(FGitOps)) or (FGitOps.Backend = gbNone) then
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

  WriteLn('Using backend: ', GitBackendToString(FGitOps.Backend));

  // Clone repository (libgit2-first; CLI shallow clone fallback inside TGitOperations)
  Result := FGitOps.Clone(LAZARUS_GIT_URL, SourcePath, Branch);

  if Result then
  begin
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
  Version, SourcePath: string;
begin
  Result := False;

  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  SourcePath := GetSourcePath(Version);

  if not DirectoryExists(SourcePath) then
  begin
    WriteLn('Error: Source directory does not exist: ', SourcePath);
    WriteLn('Please clone the source first.');
    Exit;
  end;

  WriteLn('Updating Lazarus source...');
  WriteLn('  Version: ', Version);
  WriteLn('  Path: ', SourcePath);

  if (not Assigned(FGitOps)) or (FGitOps.Backend = gbNone) then
  begin
    WriteLn('Error: No Git backend available (neither libgit2 nor git command found)');
    Exit(False);
  end;

  WriteLn('Using backend: ', GitBackendToString(FGitOps.Backend));
  Result := FGitOps.Pull(SourcePath);

  if Result then
    WriteLn('Lazarus source updated successfully.')
  else
  begin
    WriteLn('Error: Failed to update Lazarus source.');
    WriteLn('  ', FGitOps.LastError);
  end;
end;

function TLazarusSourceManager.SwitchLazarusVersion(const AVersion: string): Boolean;
begin
  Result := False;

  if not IsVersionInstalled(AVersion) then
  begin
    WriteLn('Version ', AVersion, ' not installed, cloning...');
    Result := CloneLazarusSource(AVersion);
  end
  else
  begin
    WriteLn('Switching to Lazarus version: ', AVersion);
    FCurrentVersion := AVersion;
    Result := True;
  end;
end;

function TLazarusSourceManager.ListAvailableVersions: TStringArray;
var
  i: Integer;
begin
  Result := nil;
  SetLength(Result, Length(LAZARUS_VERSIONS));
  for i := 0 to High(LAZARUS_VERSIONS) do
    Result[i] := LAZARUS_VERSIONS[i].Version;
end;

function TLazarusSourceManager.ListLocalVersions: TStringArray;
var
  SearchRec: TSearchRec;
  VersionList: TStringList;
  DirName, Version: string;
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
  i: Integer;
begin
  Result := False;
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Version, AVersion) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TLazarusSourceManager.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Result := DirectoryExists(GetSourcePath(AVersion));
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

  if not DirectoryExists(SourcePath) then
  begin
    WriteLn('Error: Lazarus source directory not found: ', SourcePath);
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
  Result := ExecuteCommand(ExecutablePath, [], '');
  {$ENDIF}

  if Result then
    WriteLn('Lazarus launched successfully.')
  else
    WriteLn('Error: Failed to launch Lazarus.');
end;

function TLazarusSourceManager.GetLazarusVersion(const AVersion: string): string;
var
  i: Integer;
  Version: string;
begin
  Version := AVersion;
  if Version = '' then
    Version := FCurrentVersion;
  if Version = '' then
    Version := 'main';

  Result := Version;

  // Find detailed version information
  for i := 0 to High(LAZARUS_VERSIONS) do
  begin
    if SameText(LAZARUS_VERSIONS[i].Version, Version) then
    begin
      Result := LAZARUS_VERSIONS[i].Description;
      Break;
    end;
  end;
end;

function TLazarusSourceManager.InstallLazarusVersion(const AVersion: string): Boolean;
var
  Version: string;
begin
  Result := False;
  Version := AVersion;

  WriteLn('Installing Lazarus version: ', Version);
  WriteLn('Steps: 1. Clone source -> 2. Build -> 3. Configure environment');
  WriteLn;

  // Step 1: Clone source
  WriteLn('[1/3] Cloning Lazarus source...');
  if not CloneLazarusSource(Version) then
  begin
    WriteLn('Error: Source clone failed, installation aborted.');
    Exit;
  end;

  // Step 2: Build
  WriteLn('[2/3] Building Lazarus IDE...');
  if not BuildLazarus(Version) then
  begin
    WriteLn('Error: Build failed, installation aborted.');
    Exit;
  end;

  // Step 3: Set as current version
  WriteLn('[3/3] Setting as current environment...');
  if SwitchLazarusVersion(Version) then
  begin
    WriteLn('Lazarus ', Version, ' installed successfully!');
    WriteLn('Current Lazarus version: ', Version);
    WriteLn('IDE path: ', GetLazarusExecutablePath(Version));
    Result := True;
  end
  else
  begin
    WriteLn('Error: Environment configuration failed.');
  end;
end;

end.
