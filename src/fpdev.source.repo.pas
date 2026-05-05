unit fpdev.source.repo;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.utils.fs, fpdev.git.runtime, fpdev.constants;

type
  { TSourceRepoManager }
  TSourceRepoManager = class
  private
    FSourceRoot: string;
    function GetSourcePath(const AVersion: string): string;
    function IsValidSourceDirectory(const APath: string): Boolean;
  protected
    function CreateGitRuntime: IGitRuntime; virtual;
  public
    constructor Create(const ASourceRoot: string);
    property SourceRoot: string read FSourceRoot write FSourceRoot;

    function CloneFPCSource(const AVersion: string): Boolean;
    function UpdateFPCSource(const AVersion: string): Boolean;
    function SwitchFPCVersion(const AVersion: string): Boolean;
    function GetFPCSourcePath(const AVersion: string = ''): string;
  end;

const
  FPC_GIT_URL = FPC_OFFICIAL_REPO;  // Use central constant
  {$IFDEF MSWINDOWS}
  WINDOWS_CMD_EXECUTABLE = 'cmd';
  WINDOWS_CMD_SWITCH_EXECUTE = '/c';
  WINDOWS_CMD_SWITCH_RECURSIVE = '/s';
  WINDOWS_CMD_SWITCH_QUIET = '/q';
  {$ENDIF}

implementation

uses
  fpdev.fpc.types, fpdev.version.registry;

function RegistryHasFPCReleases(const AReleases: TFPCReleaseArray): Boolean;
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

function ResolveStaticFPCCloneRef(const AVersion: string): string;
var
  i: Integer;
begin
  for i := 0 to High(FPC_RELEASES) do
  begin
    if SameText(FPC_RELEASES[i].Version, AVersion) then
    begin
      if Trim(FPC_RELEASES[i].GitTag) <> '' then
        Exit(FPC_RELEASES[i].GitTag);
      if Trim(FPC_RELEASES[i].Branch) <> '' then
        Exit(FPC_RELEASES[i].Branch);
      Break;
    end;
  end;

  Result := AVersion;
end;

function ResolveFPCCloneRef(const AVersion: string): string;
var
  Releases: TFPCReleaseArray;
begin
  Result := TVersionRegistry.Instance.GetFPCGitTag(AVersion);
  if Result <> '' then
    Exit;

  Result := TVersionRegistry.Instance.GetFPCBranch(AVersion);
  if Result <> '' then
    Exit;

  Releases := TVersionRegistry.Instance.GetFPCReleases;
  if not RegistryHasFPCReleases(Releases) then
    Exit(ResolveStaticFPCCloneRef(AVersion));

  Result := AVersion;
end;

function HasGitRepositoryMetadata(const APath: string): Boolean;
var
  LGitPath: string;
begin
  LGitPath := IncludeTrailingPathDelimiter(APath) + '.git';
  Result := DirectoryExists(LGitPath) or FileExists(LGitPath);
end;

{ TSourceRepoManager }

constructor TSourceRepoManager.Create(const ASourceRoot: string);
begin
  inherited Create;
  if ASourceRoot <> '' then
    FSourceRoot := ASourceRoot
  else
    FSourceRoot := 'sources' + PathDelim + 'fpc';
  if not DirectoryExists(FSourceRoot) then
    EnsureDir(FSourceRoot);
end;

function TSourceRepoManager.GetSourcePath(const AVersion: string): string;
var
  LVersion: string;
begin
  LVersion := AVersion;
  if LVersion = '' then
    LVersion := 'main';
  Result := FSourceRoot + PathDelim + 'fpc-' + LVersion;
end;

function TSourceRepoManager.IsValidSourceDirectory(const APath: string): Boolean;
var
  LCompilerPath, LRTLPath, LMakefilePath: string;
begin
  Result := False;
  if not DirectoryExists(APath) then Exit;
  LCompilerPath := APath + PathDelim + 'compiler';
  LRTLPath := APath + PathDelim + 'rtl';
  LMakefilePath := APath + PathDelim + 'Makefile';
  Result := DirectoryExists(LCompilerPath) and DirectoryExists(LRTLPath) and FileExists(LMakefilePath);
end;

function TSourceRepoManager.CreateGitRuntime: IGitRuntime;
begin
  Result := NewGitRuntime;
end;

function TSourceRepoManager.CloneFPCSource(const AVersion: string): Boolean;
var
  LVersion, LSourcePath, LRepoURL, LRefName: string;
  LGit: IGitRuntime;
begin
  Result := False;
  LVersion := AVersion;
  if LVersion = '' then LVersion := 'main';
  LSourcePath := GetSourcePath(LVersion);
  LRepoURL := TVersionRegistry.Instance.GetFPCRepository;
  if LRepoURL = '' then
    LRepoURL := FPC_GIT_URL;
  LRefName := ResolveFPCCloneRef(LVersion);

  if DirectoryExists(LSourcePath) and IsValidSourceDirectory(LSourcePath) then
  begin
    if not HasGitRepositoryMetadata(LSourcePath) then
      Exit(True);

    try
      LGit := CreateGitRuntime;
      if not LGit.BackendAvailable then
        Exit(False);
      Result := LGit.Checkout(LSourcePath, LRefName, True);
      if Result and (not IsValidSourceDirectory(LSourcePath)) then
        Result := False;
      Exit(Result);
    except
      Exit(False);
    end;
  end;

  if DirectoryExists(LSourcePath) and (not IsValidSourceDirectory(LSourcePath)) then
  begin
    {$IFDEF MSWINDOWS}
    ExecuteProcess(
      WINDOWS_CMD_EXECUTABLE,
      [
        WINDOWS_CMD_SWITCH_EXECUTE,
        'rmdir',
        WINDOWS_CMD_SWITCH_RECURSIVE,
        WINDOWS_CMD_SWITCH_QUIET,
        LSourcePath
      ]
    );
    {$ELSE}
    ExecuteProcess('rm', ['-rf', LSourcePath]);
    {$ENDIF}
  end;

  try
    LGit := CreateGitRuntime;
    if not LGit.BackendAvailable then
      Exit(False);
    Result := LGit.Clone(LRepoURL, LSourcePath, LRefName);
    if Result and (not IsValidSourceDirectory(LSourcePath)) then
      Result := False;
  except
    Result := False;
  end;
end;

function TSourceRepoManager.UpdateFPCSource(const AVersion: string): Boolean;
var
  LVersion, LSourcePath: string;
  LGit: IGitRuntime;
begin
  Result := False;
  LVersion := AVersion; if LVersion = '' then LVersion := 'main';
  LSourcePath := GetSourcePath(LVersion);
  if not IsValidSourceDirectory(LSourcePath) then Exit(False);

  LGit := CreateGitRuntime;
  try
    Result := LGit.PullFastForwardOnly(LSourcePath);
    if Result and (not IsValidSourceDirectory(LSourcePath)) then
      Result := False;
  except
    Result := False;
  end;
end;

function TSourceRepoManager.SwitchFPCVersion(const AVersion: string): Boolean;
var
  LSourcePath: string;
  LRefName: string;
  LGit: IGitRuntime;
begin
  Result := False;
  LSourcePath := GetSourcePath(AVersion);
  LRefName := ResolveFPCCloneRef(AVersion);
  if not IsValidSourceDirectory(LSourcePath) then Exit(False);
  try
    LGit := CreateGitRuntime;
    if not LGit.BackendAvailable then
      Exit(False);
    Result := LGit.Checkout(LSourcePath, LRefName, True);
  except
    Result := False;
  end;
end;

function TSourceRepoManager.GetFPCSourcePath(const AVersion: string): string;
begin
  Result := GetSourcePath(AVersion);
end;

end.
