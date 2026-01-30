unit git2.modern;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  git2.api, git2.impl, git2.types;

type
  { TGitRepository - Concrete wrapper around IGitRepository }
  TGitRepository = class
  private
    FRepo: IGitRepository;
  public
    constructor Create(ARepo: IGitRepository);
    destructor Destroy; override;

    function GetPath: string;
    function GetWorkDir: string;
    function GetIsBare: Boolean;
    function GetIsEmpty: Boolean;
    function GetCurrentBranch: string;
    function ListBranches(Kind: TGitBranchKind = gbLocal): TStringArray;
    function IsClean: Boolean;
    function HasUncommittedChanges: Boolean;

    property Path: string read GetPath;
    property WorkDir: string read GetWorkDir;
    property IsBare: Boolean read GetIsBare;
    property IsEmpty: Boolean read GetIsEmpty;
    property CurrentBranch: string read GetCurrentBranch;
  end;

  { TGitManagerWrapper - Concrete wrapper around IGitManager }
  TGitManagerWrapper = class
  private
    FManager: IGitManager;
  public
    constructor Create;
    destructor Destroy; override;

    function Initialize: Boolean;
    procedure Finalize;

    function OpenRepository(const APath: string): TGitRepository;
    function CloneRepository(const AURL, ALocalPath: string): TGitRepository;
    function InitRepository(const APath: string; ABare: Boolean = False): TGitRepository;
    function IsRepository(const APath: string): Boolean;
    function DiscoverRepository(const AStartPath: string): string;

    function GetGlobalConfig(const AKey: string): string;
    function SetGlobalConfig(const AKey, AValue: string): Boolean;
    function GetVersion: string;

    function IsInitialized: Boolean;
  end;

var
  GitManager: TGitManagerWrapper;

implementation

{ TGitRepository }

constructor TGitRepository.Create(ARepo: IGitRepository);
begin
  inherited Create;
  FRepo := ARepo;
end;

destructor TGitRepository.Destroy;
begin
  FRepo := nil;
  inherited Destroy;
end;

function TGitRepository.GetPath: string;
begin
  if Assigned(FRepo) then
    Result := FRepo.Path
  else
    Result := '';
end;

function TGitRepository.GetWorkDir: string;
begin
  if Assigned(FRepo) then
    Result := FRepo.WorkDir
  else
    Result := '';
end;

function TGitRepository.GetIsBare: Boolean;
begin
  if Assigned(FRepo) then
    Result := FRepo.IsBare
  else
    Result := False;
end;

function TGitRepository.GetIsEmpty: Boolean;
begin
  if Assigned(FRepo) then
    Result := FRepo.IsEmpty
  else
    Result := True;
end;

function TGitRepository.GetCurrentBranch: string;
begin
  if Assigned(FRepo) then
    Result := FRepo.CurrentBranch
  else
    Result := '';
end;

function TGitRepository.ListBranches(Kind: TGitBranchKind): TStringArray;
begin
  if Assigned(FRepo) then
    Result := FRepo.ListBranches(Kind)
  else
    SetLength(Result, 0);
end;

function TGitRepository.IsClean: Boolean;
begin
  if Assigned(FRepo) then
    Result := FRepo.IsClean
  else
    Result := True;
end;

function TGitRepository.HasUncommittedChanges: Boolean;
begin
  if Assigned(FRepo) then
    Result := FRepo.HasUncommittedChanges
  else
    Result := False;
end;

{ TGitManagerWrapper }

constructor TGitManagerWrapper.Create;
begin
  inherited Create;
  FManager := NewGitManager;
end;

destructor TGitManagerWrapper.Destroy;
begin
  if Assigned(FManager) then
    FManager.Finalize;
  FManager := nil;
  inherited Destroy;
end;

function TGitManagerWrapper.Initialize: Boolean;
begin
  if Assigned(FManager) then
    Result := FManager.Initialize
  else
    Result := False;
end;

procedure TGitManagerWrapper.Finalize;
begin
  if Assigned(FManager) then
    FManager.Finalize;
end;

function TGitManagerWrapper.OpenRepository(const APath: string): TGitRepository;
var
  Repo: IGitRepository;
begin
  Result := nil;
  if Assigned(FManager) then
  begin
    Repo := FManager.OpenRepository(APath);
    if Assigned(Repo) then
      Result := TGitRepository.Create(Repo);
  end;
end;

function TGitManagerWrapper.CloneRepository(const AURL, ALocalPath: string): TGitRepository;
var
  Repo: IGitRepository;
begin
  Result := nil;
  if Assigned(FManager) then
  begin
    Repo := FManager.CloneRepository(AURL, ALocalPath);
    if Assigned(Repo) then
      Result := TGitRepository.Create(Repo);
  end;
end;

function TGitManagerWrapper.InitRepository(const APath: string; ABare: Boolean): TGitRepository;
var
  Repo: IGitRepository;
begin
  Result := nil;
  if Assigned(FManager) then
  begin
    Repo := FManager.InitRepository(APath, ABare);
    if Assigned(Repo) then
      Result := TGitRepository.Create(Repo);
  end;
end;

function TGitManagerWrapper.IsRepository(const APath: string): Boolean;
begin
  if Assigned(FManager) then
    Result := FManager.IsRepository(APath)
  else
    Result := False;
end;

function TGitManagerWrapper.DiscoverRepository(const AStartPath: string): string;
begin
  if Assigned(FManager) then
    Result := FManager.DiscoverRepository(AStartPath)
  else
    Result := '';
end;

function TGitManagerWrapper.GetGlobalConfig(const AKey: string): string;
begin
  if Assigned(FManager) then
    Result := FManager.GetGlobalConfig(AKey)
  else
    Result := '';
end;

function TGitManagerWrapper.SetGlobalConfig(const AKey, AValue: string): Boolean;
begin
  if Assigned(FManager) then
    Result := FManager.SetGlobalConfig(AKey, AValue)
  else
    Result := False;
end;

function TGitManagerWrapper.GetVersion: string;
begin
  if Assigned(FManager) then
    Result := FManager.Version
  else
    Result := '';
end;

function TGitManagerWrapper.IsInitialized: Boolean;
begin
  if Assigned(FManager) then
    Result := FManager.Initialized
  else
    Result := False;
end;

initialization
  GitManager := TGitManagerWrapper.Create;

finalization
  GitManager.Free;

end.
