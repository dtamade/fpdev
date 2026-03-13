unit git2.impl;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils,
  git2.api, git2.types,
  libgit2, fpdev.git2; // Reuse unified external interface, internally still implemented by modern wrapper

type
  // Adapter implementation using existing TGit* classes as backend
  TGitManagerImpl = class(TInterfacedObject, IGitManager)
  private
    FMgr: TGitManager;
  public
    constructor Create;
    destructor Destroy; override;

    function Initialize: Boolean;
    procedure Finalize;

    function OpenRepository(const APath: string): IGitRepository;
    function CloneRepository(const AURL, ALocalPath: string): IGitRepository;
    function InitRepository(const APath: string; ABare: Boolean = False): IGitRepository;
    function IsRepository(const APath: string): Boolean;
    function DiscoverRepository(const AStartPath: string): string;

    function GetGlobalConfig(const AKey: string): string;
    function SetGlobalConfig(const AKey, AValue: string): Boolean;
    function Version: string;

    procedure SetVerifySSL(AEnabled: Boolean);
    procedure SetCredentialAcquireHandler({%H-} AHandler: TCredentialAcquireEvent);
    procedure SetCertificateCheckHandler({%H-} AHandler: TCertificateCheckEvent);

    function Initialized: Boolean;
    function VerifySSL: Boolean;
  end;

  TGitRepositoryImpl = class(TInterfacedObject, IGitRepository, IGitRepositoryExt)
  private
    FRepo: TGitRepository;
  public
    constructor Create(Repo: TGitRepository);
    destructor Destroy; override;

    function Path: string;
    function WorkDir: string;
    function IsBare: Boolean;
    function IsEmpty: Boolean;

    function Head: IGitReference;
    function CurrentBranch: string;
    function ListBranches(Kind: TGitBranchKind = gbLocal): TStringArray;

    function CommitByHash(const Hash: string): IGitCommit;
    function HeadCommit: IGitCommit;

    function Remote(const Name: string = 'origin'): IGitRemote;
    function Fetch(const RemoteName: string = 'origin'): Boolean;
    function CheckoutBranch(const Branch: string): Boolean;
    function CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;


    function Status: TStringArray;
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function HasUncommittedChanges: Boolean;

    // Extended operations
    function ListRemotes: TStringArray;
    function PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
  end;

  TGitCommitImpl = class(TInterfacedObject, IGitCommit)
  private
    FRepo: TGitRepository;
    FCommit: TGitCommit;
  public
    constructor Create(ARepo: TGitRepository; C: TGitCommit);
    destructor Destroy; override;

    function Message: string;
    function ShortMessage: string;
    function AuthorString: string;
    function CommitterString: string;
    function Time: TDateTime;
    function ParentCount: Integer;
    function OIDString: string;
  end;

  TGitReferenceImpl = class(TInterfacedObject, IGitReference)
  private
    FRef: TGitReference;
  public
    constructor Create(R: TGitReference);
    destructor Destroy; override;

    function Name: string;
    function ShortName: string;
    function TargetOIDString: string;
    function IsBranch: Boolean;
    function IsRemote: Boolean;
    function IsTag: Boolean;
  end;

  TGitRemoteImpl = class(TInterfacedObject, IGitRemote)
  private
    FRemote: TGitRemote;
  public
    constructor Create(R: TGitRemote);
    destructor Destroy; override;

    function Name: string;
    function URL: string;
    function Fetch: Boolean;
  end;

function NewGitManager: IGitManager;

implementation

{ TGitManagerImpl }

constructor TGitManagerImpl.Create;
begin
  inherited Create;
  FMgr := TGitManager.Create;
end;

destructor TGitManagerImpl.Destroy;
begin
  FMgr.Free;
  inherited Destroy;
end;

function TGitManagerImpl.Initialize: Boolean;
begin
  Result := FMgr.Initialize;
end;

procedure TGitManagerImpl.Finalize;
begin
  FMgr.Finalize;
end;

function TGitManagerImpl.OpenRepository(const APath: string): IGitRepository;
begin
  Result := TGitRepositoryImpl.Create(FMgr.OpenRepository(APath));
end;

function TGitManagerImpl.CloneRepository(const AURL, ALocalPath: string): IGitRepository;
begin
  Result := TGitRepositoryImpl.Create(FMgr.CloneRepository(AURL, ALocalPath));
end;

function TGitManagerImpl.InitRepository(const APath: string; ABare: Boolean): IGitRepository;
begin
  Result := TGitRepositoryImpl.Create(FMgr.InitRepository(APath, ABare));
end;

function TGitManagerImpl.IsRepository(const APath: string): Boolean;
begin
  Result := FMgr.IsRepository(APath);
end;

function TGitManagerImpl.DiscoverRepository(const AStartPath: string): string;
var
  p, prev: string;
begin
  // Use pure Pascal fallback first to avoid instability due to header signature differences
  p := ExpandFileName(AStartPath);
  prev := '';
  while (p <> '') and (p <> prev) do
  begin
    if DirectoryExists(IncludeTrailingPathDelimiter(p) + '.git') then
    begin
      Exit(p);
    end;
    prev := p;
    p := ExtractFileDir(p);
  end;
  // If not found, try calling underlying layer (wrap exceptions to avoid crashes)
  try
    Result := FMgr.DiscoverRepository(AStartPath);
  except
    Result := '';
  end;
end;

function TGitManagerImpl.GetGlobalConfig(const AKey: string): string;
begin
  Result := FMgr.GetGlobalConfig(AKey);
end;

function TGitManagerImpl.SetGlobalConfig(const AKey, AValue: string): Boolean;
begin
  Result := FMgr.SetGlobalConfig(AKey, AValue);
end;

function TGitManagerImpl.Version: string;
begin
  Result := FMgr.GetVersion;
end;

procedure TGitManagerImpl.SetVerifySSL(AEnabled: Boolean);
begin
  FMgr.SetVerifySSL(AEnabled);
end;

procedure TGitManagerImpl.SetCredentialAcquireHandler({%H-} AHandler: TCredentialAcquireEvent);
begin
  if Assigned(AHandler) then;
  // AHandler parameter reserved for future callback adapter implementation
  // Currently no direct mapping in fpdev.git2
end;

procedure TGitManagerImpl.SetCertificateCheckHandler({%H-} AHandler: TCertificateCheckEvent);
begin
  if Assigned(AHandler) then;
  // AHandler parameter reserved for future callback adapter implementation
  // Currently no direct mapping in fpdev.git2
end;

function TGitManagerImpl.Initialized: Boolean;
begin
  Result := FMgr.Initialized;
end;

function TGitManagerImpl.VerifySSL: Boolean;
begin
  Result := FMgr.VerifySSL;
end;

{ TGitRepositoryImpl }

constructor TGitRepositoryImpl.Create(Repo: TGitRepository);
begin
  inherited Create;
  FRepo := Repo;
end;

destructor TGitRepositoryImpl.Destroy;
begin
  FRepo.Free;
  inherited Destroy;
end;

function TGitRepositoryImpl.Path: string;
begin
  Result := FRepo.Path;
end;

function TGitRepositoryImpl.WorkDir: string;
begin
  Result := FRepo.WorkDir;
end;

function TGitRepositoryImpl.IsBare: Boolean;
begin
  Result := FRepo.IsBare;
end;

function TGitRepositoryImpl.IsEmpty: Boolean;
begin
  Result := FRepo.IsEmpty;
end;

function TGitRepositoryImpl.Head: IGitReference;
begin
  Result := TGitReferenceImpl.Create(FRepo.GetHead);
end;

function TGitRepositoryImpl.CurrentBranch: string;
begin
  Result := FRepo.GetCurrentBranch;
end;

function TGitRepositoryImpl.ListBranches(Kind: TGitBranchKind): TStringArray;
var
  t: git_branch_t;
begin
  case Kind of
    gbLocal:  t := GIT_BRANCH_LOCAL;
    gbRemote: t := GIT_BRANCH_REMOTE;
  else
    t := GIT_BRANCH_ALL;
  end;
  Result := FRepo.ListBranches(t);
end;

function TGitRepositoryImpl.CommitByHash(const Hash: string): IGitCommit;
var
  oid: TGitOID;
  c: TGitCommit;
begin
  oid := CreateGitOIDFromString(Hash);
  c := FRepo.GetCommit(oid);
  Result := TGitCommitImpl.Create(FRepo, c);
end;

function TGitRepositoryImpl.HeadCommit: IGitCommit;
begin
  Result := TGitCommitImpl.Create(FRepo, FRepo.GetHeadCommit);
end;

function TGitRepositoryImpl.Remote(const Name: string): IGitRemote;
begin
  Result := TGitRemoteImpl.Create(FRepo.GetRemote(Name));
end;

function TGitRepositoryImpl.Fetch(const RemoteName: string): Boolean;
begin
  Result := FRepo.Fetch(RemoteName);
end;
function TGitRepositoryImpl.CheckoutBranchEx(const Branch: string; Force: Boolean): Boolean;
begin
  Result := FRepo.CheckoutBranchEx(Branch, Force);
end;


function TGitRepositoryImpl.CheckoutBranch(const Branch: string): Boolean;
begin
  Result := FRepo.CheckoutBranch(Branch);
end;

function TGitRepositoryImpl.Status: TStringArray;
begin
  Result := FRepo.Status;
end;

function TGitRepositoryImpl.IsClean: Boolean;
begin
  Result := FRepo.IsClean;
end;

function TGitRepositoryImpl.StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
begin
  Result := FRepo.StatusEntries(Filter);
end;

function TGitRepositoryImpl.HasUncommittedChanges: Boolean;
begin
  Result := FRepo.HasUncommittedChanges;
end;

function TGitRepositoryImpl.ListRemotes: TStringArray;
begin
  Result := FRepo.ListRemotes;
end;

function TGitRepositoryImpl.PullFastForward(const RemoteName: string; out Error: string): TGitPullFastForwardResult;
begin
  Result := FRepo.PullFastForward(RemoteName, Error);
end;

{ TGitCommitImpl }

constructor TGitCommitImpl.Create(ARepo: TGitRepository; C: TGitCommit);
begin
  inherited Create;
  FRepo := ARepo;
  FCommit := C;
end;

destructor TGitCommitImpl.Destroy;
begin
  FCommit.Free;
  inherited Destroy;
end;

function TGitCommitImpl.Message: string;
begin
  Result := FCommit.Message;
end;

function TGitCommitImpl.ShortMessage: string;
begin
  Result := FCommit.ShortMessage;
end;

function TGitCommitImpl.AuthorString: string;
begin
  if Assigned(FCommit.Author) then
    Result := FCommit.Author.ToString
  else
    Result := '';
end;

function TGitCommitImpl.CommitterString: string;
begin
  if Assigned(FCommit.Committer) then
    Result := FCommit.Committer.ToString
  else
    Result := '';
end;

function TGitCommitImpl.Time: TDateTime;
begin
  Result := FCommit.Time;
end;

function TGitCommitImpl.ParentCount: Integer;
begin
  Result := FCommit.ParentCount;
end;

function TGitCommitImpl.OIDString: string;
begin
  Result := GitOIDToString(FCommit.OID);
end;

{ TGitReferenceImpl }

constructor TGitReferenceImpl.Create(R: TGitReference);
begin
  inherited Create;
  FRef := R;
end;

destructor TGitReferenceImpl.Destroy;
begin
  FRef.Free;
  inherited Destroy;
end;

function TGitReferenceImpl.Name: string;
begin
  Result := FRef.Name;
end;

function TGitReferenceImpl.ShortName: string;
begin
  Result := FRef.ShortName;
end;

function TGitReferenceImpl.TargetOIDString: string;
begin
  Result := GitOIDToString(FRef.OID);
end;

function TGitReferenceImpl.IsBranch: Boolean;
begin
  Result := (Pos('refs/heads/', FRef.Name) = 1);
end;

function TGitReferenceImpl.IsRemote: Boolean;
begin
  Result := (Pos('refs/remotes/', FRef.Name) = 1);
end;

function TGitReferenceImpl.IsTag: Boolean;
begin
  Result := (Pos('refs/tags/', FRef.Name) = 1);
end;

{ TGitRemoteImpl }

constructor TGitRemoteImpl.Create(R: TGitRemote);
begin
  inherited Create;
  FRemote := R;
end;

destructor TGitRemoteImpl.Destroy;
begin
  FRemote.Free;
  inherited Destroy;
end;

function TGitRemoteImpl.Name: string;
begin
  Result := FRemote.Name;
end;

function TGitRemoteImpl.URL: string;
begin
  Result := FRemote.URL;
end;

function TGitRemoteImpl.Fetch: Boolean;
begin
  Result := FRemote.Fetch;
end;

function NewGitManager: IGitManager;
begin
  Result := TGitManagerImpl.Create;
end;

end.
