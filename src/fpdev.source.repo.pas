unit fpdev.source.repo;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  git2.api, git2.impl,
  fpdev.utils.fs, fpdev.constants;

type
  { TSourceRepoManager }
  TSourceRepoManager = class
  private
    FSourceRoot: string;
    function GetSourcePath(const AVersion: string): string;
    function IsValidSourceDirectory(const APath: string): Boolean;
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

implementation

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

function TSourceRepoManager.CloneFPCSource(const AVersion: string): Boolean;
var
  LVersion, LSourcePath: string;
  LRepo: IGitRepository;
  LGitManager: IGitManager;
begin
  Result := False;
  LVersion := AVersion;
  if LVersion = '' then LVersion := 'main';
  LSourcePath := GetSourcePath(LVersion);

  if DirectoryExists(LSourcePath) and IsValidSourceDirectory(LSourcePath) then
    Exit(True);

  if DirectoryExists(LSourcePath) and (not IsValidSourceDirectory(LSourcePath)) then
  begin
    {$IFDEF MSWINDOWS}
    ExecuteProcess('cmd', ['/c', 'rmdir', '/s', '/q', LSourcePath]);
    {$ELSE}
    ExecuteProcess('rm', ['-rf', LSourcePath]);
    {$ENDIF}
  end;

  try
    LGitManager := NewGitManager();
    if not LGitManager.Initialize then Exit(False);
    LRepo := LGitManager.CloneRepository(FPC_GIT_URL, LSourcePath);
    Result := Assigned(LRepo);
  except
    Result := False;
  end;
end;

function TSourceRepoManager.UpdateFPCSource(const AVersion: string): Boolean;
var
  LVersion, LSourcePath: string;
  LRepo: IGitRepository;
  LGitManager: IGitManager;
begin
  Result := False;
  LVersion := AVersion; if LVersion = '' then LVersion := 'main';
  LSourcePath := GetSourcePath(LVersion);
  if not DirectoryExists(LSourcePath) then Exit(False);

  try
    LGitManager := NewGitManager();
    if not LGitManager.Initialize then Exit(False);
    LRepo := LGitManager.OpenRepository(LSourcePath);
    if not Assigned(LRepo) then Exit(False);
    Result := LRepo.Fetch('origin');
  except
    Result := False;
  end;
end;

function TSourceRepoManager.SwitchFPCVersion(const AVersion: string): Boolean;
var
  LSourcePath: string;
  LRepo: IGitRepository;
  LGitManager: IGitManager;
begin
  Result := False;
  LSourcePath := GetSourcePath(AVersion);
  if not DirectoryExists(LSourcePath) then Exit(False);
  try
    LGitManager := NewGitManager();
    if not LGitManager.Initialize then Exit(False);
    LRepo := LGitManager.OpenRepository(LSourcePath);
    if not Assigned(LRepo) then Exit(False);
    Result := LRepo.CheckoutBranch(AVersion);
  except
    Result := False;
  end;
end;

function TSourceRepoManager.GetFPCSourcePath(const AVersion: string): string;
begin
  Result := GetSourcePath(AVersion);
end;

end.
