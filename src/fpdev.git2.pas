unit fpdev.git2;

{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

{$I fpdev.config.inc}

interface

uses
  SysUtils, Classes, DateUtils, ctypes,
  libgit2, git2.types;

type
  EGitError = class(Exception)
  private
    FErrorCode: Integer;
    FErrorClass: Integer;
  public
    constructor Create(AErrorCode: Integer; const AOperation: string = '');
    property ErrorCode: Integer read FErrorCode;
    property ErrorClass: Integer read FErrorClass;
  end;

  TGitOID = record
    Data: git_oid;
  end;

  TGitTime = record
    Time: TDateTime;
    Offset: Integer;
  end;

  TGitSignature = class
  private
    FName: string;
    FEmail: string;
    FWhen: TGitTime;
  public
    constructor Create(const AName, AEmail: string; const AWhen: TGitTime);
    constructor CreateNow(const AName, AEmail: string);
    function ToString: string; override;
    property Name: string read FName;
    property Email: string read FEmail;
    property When: TGitTime read FWhen;
  end;

  TGitRepository = class;
  TGitCommit = class;
  TGitReference = class;

  TGitRemote = class;

  TGitRepository = class
  private
    FHandle: git_repository;
    FPath: string;
    FWorkDir: string;
    procedure CheckResult(AResult: Integer; const AOperation: string = '');
  public
    constructor Create(const APath: string);
    constructor Clone(const AURL, ALocalPath: string);
    destructor Destroy; override;

    function GetPath: string;
    function GetWorkDir: string;

    function GetHead: TGitReference;
    function GetReference(const AName: string): TGitReference;
    function GetCurrentBranch: string;
    function ListBranches(AType: git_branch_t = GIT_BRANCH_LOCAL): TStringArray;
    function CheckoutBranch(const ABranch: string): Boolean;
    function CheckoutBranchEx(const ABranch: string; const Force: Boolean): Boolean;

    // 状态接口（简易与详细）
    // Status: 返回简化的路径字符串数组（不含标志）
    // StatusEntries: 返回带标志的条目数组。Filter 含义：
    //   - WorkingTreeOnly: 仅工作区变更
    //   - IndexOnly: 仅索引/暂存区变更（与 WorkingTreeOnly 互斥时以 IndexOnly 优先）
    //   - IncludeUntracked: 是否包含未跟踪文件
    //   - IncludeIgnored: 是否包含被忽略的文件（受 .gitignore 影响）
    function Status: TStringArray;
    function StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
    function IsClean: Boolean;
    function IsBare: Boolean;
    function IsEmpty: Boolean;
    function HasUncommittedChanges: Boolean;

    function GetCommit(const AOID: TGitOID): TGitCommit;
    function GetHeadCommit: TGitCommit;
    function GetLastCommit: TGitCommit;

    // 兼容旧命名
    function HasUncommit: Boolean;

    function GetRemote(const AName: string): TGitRemote;
    function Fetch(const ARemoteName: string = 'origin'): Boolean;

    property Path: string read GetPath;
    property WorkDir: string read GetWorkDir;
  end;
  TGitReference = class
  private
    FRepository: TGitRepository;
    FHandle: git_reference;
    FName: string;
    FShortName: string;
    FOID: TGitOID;
    FSymbolicTarget: string;
    FType: git_reference_t;
  public
    constructor Create(ARepository: TGitRepository; AHandle: git_reference);
    destructor Destroy; override;
    property Name: string read FName;
    property ShortName: string read FShortName;
    property OID: TGitOID read FOID;
    property SymbolicTarget: string read FSymbolicTarget;
    property RefType: git_reference_t read FType;
  end;


  TGitCommit = class
  private
    FRepository: TGitRepository;
    FOID: TGitOID;
    FHandle: git_commit;
    FMessage: string;
    FShortMessage: string;
    FAuthor: TGitSignature;
    FCommitter: TGitSignature;
    FTime: TDateTime;
    FParentCount: Integer;
    FLoaded: Boolean;
    procedure LoadData;
  public
    constructor Create(ARepository: TGitRepository; const AOID: TGitOID);
    destructor Destroy; override;
    property Message: string read FMessage;
    property ShortMessage: string read FShortMessage;
    property Author: TGitSignature read FAuthor;
    property Committer: TGitSignature read FCommitter;
    property Time: TDateTime read FTime;
    property ParentCount: Integer read FParentCount;
    property OID: TGitOID read FOID;
  end;




  TGitRemote = class
  private
    FRepository: TGitRepository;
    FHandle: git_remote;
    FName: string;
    FURL: string;
  public
    constructor Create(ARepository: TGitRepository; AHandle: git_remote);
    destructor Destroy; override;
    function Fetch: Boolean;
    property Name: string read FName;
    property URL: string read FURL;
  end;

  TGitManager = class
  private
    FInitialized: Boolean;
    FVerifySSL: Boolean;
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
    procedure SetVerifySSL(AEnabled: Boolean);
    function GetVersion: string;
    property Initialized: Boolean read FInitialized;
    property VerifySSL: Boolean read FVerifySSL;
  end;

  // 兼容层：保持旧名称 TGit2Manager（简单代理到 TGitManager）
  TGit2Manager = class
  private
    FInitialized: Boolean;
  public
    constructor Create; destructor Destroy; override;
    function Initialize: Boolean; procedure Finalize;
    function OpenRepository(const APath: string): git_repository;
    function IsRepository(const APath: string): Boolean;
    function CloneRepository(const AURL, ATargetDir: string; const ABranch: string = ''): Boolean;
    function UpdateRepository(const ARepoPath: string): Boolean;
    function GetCurrentBranch(ARepo: git_repository): string;
    function CheckoutBranch(ARepo: git_repository; const ABranch: string): Boolean;
    function ListBranches(ARepo: git_repository): TStringArray;
    function GetLastCommitHash(ARepo: git_repository): string;
  end;

function GitManager: TGitManager;
procedure CheckGitResult(AResult: Integer; const AOperation: string = '');
function GetGitErrorMessage: string;

function CreateGitOIDFromString(const AHashString: string): TGitOID;
function GitOIDToString(const AOID: TGitOID): string;
function GitOIDToShortString(const AOID: TGitOID): string;
function GitOIDEquals(const A, B: TGitOID): Boolean;
function IsGitOIDZero(const AOID: TGitOID): Boolean;
function CreateGitTimeFromGitTime(const AGitTime: git_time): TGitTime;
function GitTimeToString(const ATime: TGitTime): string;

implementation

type
  PStatusListPayload = ^TStatusListPayload;
  TStatusListPayload = record
    List: TStringList;
  end;

  PGitStatusEntry = ^TGitStatusEntry;

  PStatusEntriesPayload = ^TStatusEntriesPayload;
  TStatusEntriesPayload = record
    Filter: TGitStatusFilter;
    Items: TList; // of PGitStatusEntry
  end;

function MapStatusFlags(AFlags: cuint): TGitStatusFlags;
begin
  Result := [];
  if (AFlags and GIT_STATUS_INDEX_NEW) <> 0 then Include(Result, gsIndexNew);
  if (AFlags and GIT_STATUS_INDEX_MODIFIED) <> 0 then Include(Result, gsIndexModified);
  if (AFlags and GIT_STATUS_INDEX_DELETED) <> 0 then Include(Result, gsIndexDeleted);
  if (AFlags and GIT_STATUS_INDEX_RENAMED) <> 0 then Include(Result, gsIndexRenamed);
  if (AFlags and GIT_STATUS_INDEX_TYPECHANGE) <> 0 then Include(Result, gsIndexTypeChange);
  if (AFlags and GIT_STATUS_WT_NEW) <> 0 then Include(Result, gsWtNew);
  if (AFlags and GIT_STATUS_WT_MODIFIED) <> 0 then Include(Result, gsWtModified);
  if (AFlags and GIT_STATUS_WT_DELETED) <> 0 then Include(Result, gsWtDeleted);
  if (AFlags and GIT_STATUS_WT_TYPECHANGE) <> 0 then Include(Result, gsWtTypeChange);
  if (AFlags and GIT_STATUS_WT_RENAMED) <> 0 then Include(Result, gsWtRenamed);
  if (AFlags and GIT_STATUS_IGNORED) <> 0 then Include(Result, gsIgnored);
  if (AFlags and GIT_STATUS_CONFLICTED) <> 0 then Include(Result, gsConflicted);
end;

function AcceptStatus(AFlags: cuint; const Filter: TGitStatusFilter): Boolean;
var
  LHasIndex, LHasWt, LIsUntracked, LIsIgnored: Boolean;
begin
  LHasIndex := (AFlags and (GIT_STATUS_INDEX_NEW or GIT_STATUS_INDEX_MODIFIED or GIT_STATUS_INDEX_DELETED or GIT_STATUS_INDEX_RENAMED or GIT_STATUS_INDEX_TYPECHANGE)) <> 0;
  LHasWt := (AFlags and (GIT_STATUS_WT_NEW or GIT_STATUS_WT_MODIFIED or GIT_STATUS_WT_DELETED or GIT_STATUS_WT_RENAMED or GIT_STATUS_WT_TYPECHANGE)) <> 0;
  LIsUntracked := (AFlags and GIT_STATUS_WT_NEW) <> 0;
  LIsIgnored := (AFlags and GIT_STATUS_IGNORED) <> 0;
  if Filter.IndexOnly and not LHasIndex then Exit(False);
  if Filter.WorkingTreeOnly and not LHasWt then Exit(False);
  if (not Filter.IncludeUntracked) and LIsUntracked then Exit(False);
  if (not Filter.IncludeIgnored) and LIsIgnored then Exit(False);
  Result := (AFlags <> GIT_STATUS_CURRENT);
end;

function StatusListCb(const APath: PChar; AFlags: cuint; APayload: Pointer): cint; cdecl;
begin
  if (AFlags <> GIT_STATUS_CURRENT) and (APayload <> nil) then
    PStatusListPayload(APayload)^.List.Add(string(APath));
  Result := 0;
end;

function StatusEntriesCb(const APath: PChar; AFlags: cuint; APayload: Pointer): cint; cdecl;
var
  LP: PStatusEntriesPayload;
  LItem: PGitStatusEntry;
begin
  LP := PStatusEntriesPayload(APayload);
  if (LP <> nil) and AcceptStatus(AFlags, LP^.Filter) then
  begin
    New(LItem);
    LItem^.Path := string(APath);
    LItem^.Flags := MapStatusFlags(AFlags);
    LP^.Items.Add(LItem);
  end;
  Result := 0;
end;

var
  FGitManager: TGitManager = nil;

function GitManager: TGitManager;
begin
  if not Assigned(FGitManager) then
    FGitManager := TGitManager.Create;
  Result := FGitManager;
end;

procedure CheckGitResult(AResult: Integer; const AOperation: string);
begin
  if AResult <> GIT_OK then
    raise EGitError.Create(AResult, AOperation);
end;

function GetGitErrorMessage: string;
var
  Error: Pgit_error_t;
begin
  Error := git_error_last();
  if Assigned(Error) and Assigned(Error^.message) then
    Result := string(Error^.message)
  else
    Result := 'Unknown error';
end;

constructor EGitError.Create(AErrorCode: Integer; const AOperation: string);
var
  ErrorMsg: string;
begin
  FErrorCode := AErrorCode;
  FErrorClass := 0;
  ErrorMsg := GetGitErrorMessage;
  if AOperation <> '' then
    ErrorMsg := AOperation + ': ' + ErrorMsg;
  inherited Create(ErrorMsg);
end;

constructor TGitSignature.Create(const AName, AEmail: string; const AWhen: TGitTime);
begin
  inherited Create;
  FName := AName;
  FEmail := AEmail;
  FWhen := AWhen;
end;

constructor TGitSignature.CreateNow(const AName, AEmail: string);
var
  GitTime: git_time;
  Tm: TGitTime;
begin
  GitTime.time := DateTimeToUnix(Now);
  GitTime.offset := 0;
  GitTime.sign := Ord('+');
  Tm := CreateGitTimeFromGitTime(GitTime);
  inherited Create;
  FName := AName;
  FEmail := AEmail;
  FWhen := Tm;
end;

function TGitSignature.ToString: string;
begin
  Result := Format('%s <%s> %s', [FName, FEmail, GitTimeToString(FWhen)]);
end;

function TGitRepository.CheckoutBranch(const ABranch: string): Boolean;
var
  LRefName: string;
  LOpts: git_checkout_options;
begin
  // 切换到本地分支并检出到工作区（安全模式）
  // 注意：仅支持本地分支名，如需从远程创建本地分支后续扩展
  Result := False;
  try
    if Trim(ABranch) = '' then
      Exit(False);

    if Pos('refs/', ABranch) = 1 then
      LRefName := ABranch
    else
      LRefName := 'refs/heads/' + ABranch;

    // 设置 HEAD 指向目标分支
    CheckGitResult(git_repository_set_head(FHandle, PChar(LRefName)), 'Set HEAD to ' + LRefName);

    // 安全检出 HEAD 到工作区
    FillByte(LOpts, SizeOf(LOpts), 0);
    CheckGitResult(git_checkout_options_init(@LOpts, 1), 'Init checkout options');
    LOpts.checkout_strategy := GIT_CHECKOUT_SAFE;
    CheckGitResult(git_checkout_head(FHandle, @LOpts), 'Checkout HEAD');

    Result := True;
  except
    on E: Exception do
    begin
      // 转为布尔返回；详细错误已由 EGitError 携带
      Result := False;
    end;
  end;
end;

function TGitRepository.CheckoutBranchEx(const ABranch: string; const Force: Boolean): Boolean;
var
  LRefName: string;
  LOpts: git_checkout_options;
begin
  Result := False;
  try
    if Trim(ABranch) = '' then Exit(False);
    if Pos('refs/', ABranch) = 1 then LRefName := ABranch else LRefName := 'refs/heads/' + ABranch;
    CheckGitResult(git_repository_set_head(FHandle, PChar(LRefName)), 'Set HEAD to ' + LRefName);
    FillByte(LOpts, SizeOf(LOpts), 0);
    CheckGitResult(git_checkout_options_init(@LOpts, 1), 'Init checkout options');
    if Force then
      LOpts.checkout_strategy := GIT_CHECKOUT_FORCE
    else
      LOpts.checkout_strategy := GIT_CHECKOUT_SAFE;
    CheckGitResult(git_checkout_head(FHandle, @LOpts), 'Checkout HEAD');
    Result := True;
  except
    Result := False;
  end;
end;

constructor TGitRepository.Create(const APath: string);
begin
  inherited Create;
  CheckResult(git_repository_open(FHandle, PChar(APath)), 'Open repository');
  FPath := APath;
  FWorkDir := string(git_repository_workdir(FHandle));
end;

constructor TGitRepository.Clone(const AURL, ALocalPath: string);
var
  opts: git_clone_options;
begin
  inherited Create;
  FillByte(opts, SizeOf(opts), 0);
  CheckGitResult(git_clone_options_init(@opts, 1), 'Init clone options');
  opts.checkout_opts.checkout_strategy := GIT_CHECKOUT_SAFE;
  CheckResult(git_clone(FHandle, PChar(AURL), PChar(ALocalPath), @opts), 'Clone repository');
  FPath := ALocalPath;
  FWorkDir := string(git_repository_workdir(FHandle));
end;

destructor TGitRepository.Destroy;
begin
  if Assigned(FHandle) then
    git_repository_free(FHandle);
  inherited Destroy;
end;

procedure TGitRepository.CheckResult(AResult: Integer; const AOperation: string);
begin
  if AResult <> GIT_OK then
    raise EGitError.Create(AResult, AOperation);
end;

function TGitRepository.GetPath: string;
begin
  if FPath = '' then
    FPath := string(git_repository_path(FHandle));
  Result := FPath;
end;

function TGitRepository.GetWorkDir: string;
begin
  if FWorkDir = '' then
    FWorkDir := string(git_repository_workdir(FHandle));
  Result := FWorkDir;
end;

function TGitRepository.GetHead: TGitReference;
var
  RefHandle: git_reference;
  rc: cint;
begin
  rc := git_repository_head(RefHandle, FHandle);
  if rc <> GIT_OK then
    raise EGitError.Create(rc, 'Get HEAD reference');
  Result := TGitReference.Create(Self, RefHandle);
end;

function TGitRepository.GetReference(const AName: string): TGitReference;
var
  RefHandle: git_reference;
begin
  CheckGitResult(git_reference_lookup(RefHandle, FHandle, PChar(AName)), 'Lookup reference');
  Result := TGitReference.Create(Self, RefHandle);
end;

function TGitRepository.GetCurrentBranch: string;
var
  HeadRef: TGitReference;
begin
  HeadRef := GetHead;
  try
    Result := HeadRef.ShortName;
  finally
    HeadRef.Free;
  end;
end;

function TGitRepository.ListBranches(AType: git_branch_t): TStringArray;
var
  Iterator: git_branch_iterator;
  RefHandle: git_reference;
  BranchType: git_branch_t;
  BranchName: string;
  List: TStringList;
  rc: cint;
begin
  SetLength(Result, 0);
  List := TStringList.Create;
  try
    CheckGitResult(git_branch_iterator_new(Iterator, FHandle, AType), 'New branch iterator');
    try
      while True do
      begin
        rc := git_branch_next(RefHandle, BranchType, Iterator);
        if rc = GIT_ITEROVER then Break;
        if rc <> GIT_OK then
          raise EGitError.Create(rc, 'Iterate branches');
        BranchName := string(git_reference_name(RefHandle));
        List.Add(BranchName);
        git_reference_free(RefHandle);
      end;
    finally
      git_branch_iterator_free(Iterator);
    end;
    SetLength(Result, List.Count);
    if List.Count > 0 then
      for rc := 0 to List.Count - 1 do
        Result[rc] := List[rc];
  finally
    List.Free;
  end;
end;

function TGitRepository.GetCommit(const AOID: TGitOID): TGitCommit;
begin
  Result := TGitCommit.Create(Self, AOID);
end;

function TGitRepository.GetHeadCommit: TGitCommit;
var
  HeadRef: TGitReference;
begin
  HeadRef := GetHead;
  try
    Result := TGitCommit.Create(Self, HeadRef.OID);
  finally
    HeadRef.Free;
  end;
end;

function TGitRepository.GetLastCommit: TGitCommit;
begin
  Result := GetHeadCommit;
end;

function TGitRepository.Status: TStringArray;
var
  LList: TStringList;
  LCount: SizeInt;
  LP: TStatusListPayload;
  function StatusCb(const APath: PChar; AFlags: cuint; APayload: Pointer): cint; cdecl;
  begin
    if (AFlags <> GIT_STATUS_CURRENT) then
      LList.Add(string(APath));
    Result := 0; // 继续
  end;
begin
  SetLength(Result, 0);
  LList := TStringList.Create;
  try
    LP.List := LList;
    CheckGitResult(git_status_foreach(FHandle, @StatusListCb, @LP), 'Status foreach');
    LCount := LList.Count;
    if LCount > 0 then
    begin
      SetLength(Result, LCount);
      while LCount > 0 do begin Dec(LCount); Result[LCount] := LList[LCount]; end;
    end;
  finally
    LList.Free;
  end;
end;

function TGitRepository.StatusEntries(const Filter: TGitStatusFilter): TGitStatusEntryArray;
var
  LP: TStatusEntriesPayload;
  LList: TList;
  i: Integer;
  LItem: PGitStatusEntry;
begin
  LList := TList.Create;
  try
    LP.Filter := Filter;
    LP.Items := LList;
    CheckGitResult(git_status_foreach(FHandle, @StatusEntriesCb, @LP), 'Status foreach');
    SetLength(Result, LList.Count);
    for i := 0 to LList.Count-1 do
    begin
      LItem := PGitStatusEntry(LList[i]);
      Result[i] := LItem^;
      Dispose(LItem);
    end;
  finally
    LList.Free;
  end;
  Exit; // keep function structure consistent
end;

function TGitRepository.IsClean: Boolean;
begin
  Result := Length(Status) = 0;
end;

function TGitRepository.HasUncommittedChanges: Boolean;
begin
  Result := not IsClean;
end;

function TGitRepository.HasUncommit: Boolean;
begin
  Result := HasUncommittedChanges;
end;

function TGitRepository.IsBare: Boolean;
begin
  Result := git_repository_is_bare(FHandle) <> 0;
end;

function TGitRepository.IsEmpty: Boolean;
begin
  Result := git_repository_is_empty(FHandle) <> 0;
end;

function TGitRepository.GetRemote(const AName: string): TGitRemote;
var
  RemoteHandle: git_remote;
begin
  CheckGitResult(git_remote_lookup(RemoteHandle, FHandle, PChar(AName)), 'Lookup remote');
  Result := TGitRemote.Create(Self, RemoteHandle);
end;

function TGitRepository.Fetch(const ARemoteName: string): Boolean;
var
  Remote: TGitRemote;
begin
  Result := False;
  Remote := GetRemote(ARemoteName);
  try
    Result := Remote.Fetch;
  finally
    Remote.Free;
  end;
end;

constructor TGitCommit.Create(ARepository: TGitRepository; const AOID: TGitOID);
begin
  inherited Create;
  FRepository := ARepository;
  FOID := AOID;
  FLoaded := False;
end;

destructor TGitCommit.Destroy;
begin
  if Assigned(FAuthor) then FreeAndNil(FAuthor);
  if Assigned(FCommitter) then FreeAndNil(FCommitter);
  if Assigned(FHandle) then
    git_object_free(FHandle);
  inherited Destroy;
end;

procedure TGitCommit.LoadData;
var
  Obj: git_object;
  CommitterSig, AuthorSig: Pgit_signature_t;
  CommitTime: git_time_t;
  AuthorTime, CommitterTime: TGitTime;
begin
  if FLoaded then Exit;
  CheckGitResult(git_object_lookup(Obj, FRepository.FHandle, @FOID.Data, GIT_OBJECT_COMMIT), 'Lookup object');
  try
    FHandle := git_commit(Obj);
    FMessage := string(git_commit_message(FHandle));
    FShortMessage := Trim(Copy(FMessage, 1, Pos(LineEnding, FMessage + LineEnding) - 1));

    CommitterSig := git_commit_committer(FHandle);
    if Assigned(CommitterSig) then
    begin
      CommitterTime := CreateGitTimeFromGitTime(CommitterSig^.when);
      FCommitter := TGitSignature.Create(string(CommitterSig^.name), string(CommitterSig^.email), CommitterTime);
    end;

    AuthorSig := git_commit_author(FHandle);
    if Assigned(AuthorSig) then
    begin
      AuthorTime := CreateGitTimeFromGitTime(AuthorSig^.when);
      FAuthor := TGitSignature.Create(string(AuthorSig^.name), string(AuthorSig^.email), AuthorTime);
    end;

    CommitTime := git_commit_time(FHandle);
    FTime := UnixToDateTime(CommitTime);

    FParentCount := git_commit_parentcount(FHandle);

    FLoaded := True;
  finally
    // Obj freed together with commit
  end;
end;

constructor TGitReference.Create(ARepository: TGitRepository; AHandle: git_reference);
begin
  inherited Create;
  FRepository := ARepository;
  FHandle := AHandle;
  FName := string(git_reference_name(AHandle));
  FType := git_reference_type(AHandle);
  if FType = GIT_REFERENCE_DIRECT then
  begin
    FOID.Data := git_reference_target(AHandle)^;
    FShortName := Copy(FName, LastDelimiter('/', FName) + 1, MaxInt);
  end
  else
  begin
    FSymbolicTarget := string(git_reference_symbolic_target(AHandle));
    FShortName := Copy(FSymbolicTarget, LastDelimiter('/', FSymbolicTarget) + 1, MaxInt);
  end;
end;

destructor TGitReference.Destroy;
begin
  if Assigned(FHandle) then
    git_reference_free(FHandle);
  inherited Destroy;
end;

constructor TGitRemote.Create(ARepository: TGitRepository; AHandle: git_remote);
begin
  inherited Create;
  FRepository := ARepository;
  FHandle := AHandle;
  FName := string(git_remote_name(AHandle));
  FURL := string(git_remote_url(AHandle));
end;

destructor TGitRemote.Destroy;
begin
  if Assigned(FHandle) then
    git_remote_free(FHandle);
  inherited Destroy;
end;

function TGitRemote.Fetch: Boolean;
var
  fetch_opts: git_fetch_options;
begin
  try
    FillByte(fetch_opts, SizeOf(fetch_opts), 0);
    CheckGitResult(git_fetch_options_init(@fetch_opts, 1), 'Init fetch options');
    CheckGitResult(git_remote_init_callbacks(@fetch_opts.callbacks, 1), 'Init remote callbacks');
    Result := git_remote_fetch(FHandle, nil, @fetch_opts, nil) = GIT_OK;
  except
    Result := False;
  end;
end;

constructor TGitManager.Create;
begin
  inherited Create;
  FInitialized := False;
end;

destructor TGitManager.Destroy;
begin
  if FInitialized then
    Finalize;
  inherited Destroy;
end;

function TGitManager.Initialize: Boolean;
begin
  try
    Result := git_libgit2_init >= 0;
    if Result then
      FInitialized := True
    else
      Result := False;
  except
    Result := False;
  end;
end;

procedure TGitManager.Finalize;
begin
  if FInitialized then
  begin
    git_libgit2_shutdown;
    FInitialized := False;
  end;
end;

function TGitManager.OpenRepository(const APath: string): TGitRepository;
begin
  if not FInitialized then
    Initialize;
  Result := TGitRepository.Create(APath);
end;

function TGitManager.CloneRepository(const AURL, ALocalPath: string): TGitRepository;
begin
  if not FInitialized then
    Initialize;
  Result := TGitRepository.Clone(AURL, ALocalPath);
end;

function TGitManager.InitRepository(const APath: string; ABare: Boolean): TGitRepository;
var
  RepoHandle: git_repository;
begin
  if not FInitialized then
    Initialize;
  CheckGitResult(git_repository_init(RepoHandle, PChar(APath), Ord(ABare)), 'Initialize repository');
  git_repository_free(RepoHandle);
  Result := TGitRepository.Create(APath);
end;

function TGitManager.IsRepository(const APath: string): Boolean;
var
  RepoHandle: git_repository;
begin
  if not FInitialized then
    Initialize;
  Result := git_repository_open(RepoHandle, PChar(APath)) = GIT_OK;
  if Result then
    git_repository_free(RepoHandle);
end;

function TGitManager.DiscoverRepository(const AStartPath: string): string;
var
  LPath, LPrev: string;
begin
  // 为避免不同 libgit2 版本的 ABI 差异，这里采用安全的纯Pascal回退：
  // 自 AStartPath 向上查找含 .git 的目录
  if not FInitialized then
    Initialize;
  Result := '';
  LPath := ExpandFileName(AStartPath);
  LPrev := '';
  while (LPath <> '') and (LPath <> LPrev) do
  begin
    if DirectoryExists(IncludeTrailingPathDelimiter(LPath) + '.git') then
      Exit(LPath);
    LPrev := LPath;
    LPath := ExtractFileDir(LPath);
  end;
end;

function TGitManager.GetGlobalConfig(const AKey: string): string;
var
  Config: git_config;
  Value: PChar;
begin
  if not FInitialized then
    Initialize;
  if git_config_open_default(Config) = GIT_OK then
  try
    if git_config_get_string(Value, Config, PChar(AKey)) = GIT_OK then
      Result := string(Value)
    else
      Result := '';
  finally
    git_config_free(Config);
  end
  else
    Result := '';
end;

function TGitManager.SetGlobalConfig(const AKey, AValue: string): Boolean;
var
  Config: git_config;
begin
  if not FInitialized then
    Initialize;
  Result := False;
  if git_config_open_default(Config) = GIT_OK then
  try
    Result := git_config_set_string(Config, PChar(AKey), PChar(AValue)) = GIT_OK;
  finally
    git_config_free(Config);
  end;
end;

procedure TGitManager.SetVerifySSL(AEnabled: Boolean);
var
  Cfg: git_config;
  Val: PChar;
begin
  FVerifySSL := AEnabled;
  if not FInitialized then
    Initialize;
  if git_config_open_default(Cfg) = GIT_OK then
  try
    if AEnabled then Val := 'true' else Val := 'false';
    git_config_set_string(Cfg, 'http.sslVerify', Val);
  finally
    git_config_free(Cfg);
  end;
end;

function TGitManager.GetVersion: string;
var
  Major, Minor, Rev: cint;
begin
  Major := 0; Minor := 0; Rev := 0;
  if not FInitialized then
    Initialize;
  if git_libgit2_version(@Major, @Minor, @Rev) = GIT_OK then
    Result := Format('%d.%d.%d', [Major, Minor, Rev])
  else
    Result := '0.0.0';
end;

constructor TGit2Manager.Create; begin inherited Create; FInitialized := False; end;
destructor TGit2Manager.Destroy; begin if FInitialized then Finalize; inherited Destroy; end;
function TGit2Manager.Initialize: Boolean; begin FInitialized := GitManager.Initialize; Result := FInitialized; end;
procedure TGit2Manager.Finalize; begin if FInitialized then begin GitManager.Finalize; FInitialized := False; end; end;
function TGit2Manager.OpenRepository(const APath: string): git_repository; var R: TGitRepository; begin R := GitManager.OpenRepository(APath); if Assigned(R) then begin Result := R.FHandle; R.Free; end else Result := nil; end;
function TGit2Manager.IsRepository(const APath: string): Boolean; begin Result := GitManager.IsRepository(APath); end;
function TGit2Manager.CloneRepository(const AURL, ATargetDir: string; const ABranch: string): Boolean; var R: TGitRepository; begin Result := False; R := GitManager.CloneRepository(AURL, ATargetDir); try Result := Assigned(R); if Result and (ABranch <> '') then Result := R.CheckoutBranch(ABranch) and Result; finally if Assigned(R) then R.Free; end; end;
function TGit2Manager.UpdateRepository(const ARepoPath: string): Boolean; var R: TGitRepository; begin Result := False; if not IsRepository(ARepoPath) then Exit; R := GitManager.OpenRepository(ARepoPath); if not Assigned(R) then Exit; try Result := R.Fetch('origin'); finally R.Free; end; end;
function TGit2Manager.GetCurrentBranch(ARepo: git_repository): string; var Ref: git_reference; Target: PChar; FullName: string; begin Result := ''; if not Assigned(ARepo) then Exit; if git_repository_head(Ref, ARepo) = GIT_OK then begin try Target := git_reference_symbolic_target(Ref); if Assigned(Target) then FullName := string(Target) else FullName := string(git_reference_name(Ref)); if Pos('refs/heads/', FullName) = 1 then Result := Copy(FullName, 12, Length(FullName)) else Result := FullName; finally git_reference_free(Ref); end; end; end;
function TGit2Manager.CheckoutBranch(ARepo: git_repository; const ABranch: string): Boolean; var RepoObj: TGitRepository; begin Result := False; if not FInitialized then Exit; RepoObj := TGitRepository.Create(string(git_repository_workdir(ARepo))); try Result := RepoObj.CheckoutBranch(ABranch); finally RepoObj.Free; end; end;
function TGit2Manager.ListBranches(ARepo: git_repository): TStringArray; var RepoObj: TGitRepository; Branches: TStringArray; i: Integer; begin SetLength(Result,0); if not FInitialized then Exit; if not Assigned(ARepo) then Exit; RepoObj := TGitRepository.Create(string(git_repository_workdir(ARepo))); try Branches := RepoObj.ListBranches(GIT_BRANCH_ALL); SetLength(Result, Length(Branches)); for i := 0 to High(Branches) do Result[i] := Branches[i]; finally RepoObj.Free; end; end;
function TGit2Manager.GetLastCommitHash(ARepo: git_repository): string; var RepoObj: TGitRepository; Commit: TGitCommit; begin Result := ''; if not FInitialized then Exit; if not Assigned(ARepo) then Exit; RepoObj := TGitRepository.Create(string(git_repository_workdir(ARepo))); try Commit := RepoObj.GetLastCommit; try Result := GitOIDToString(Commit.OID); finally Commit.Free; end; finally RepoObj.Free; end; end;

function CreateGitOIDFromString(const AHashString: string): TGitOID;
begin
  CheckGitResult(git_oid_fromstr(Result.Data, PChar(AHashString)), 'Parse OID from string');
end;

function GitOIDToString(const AOID: TGitOID): string;
const
  Hex: PChar = '0123456789abcdef';
var
  i: Integer;
  s: string;
begin
  SetLength(s, 40);
  for i := 0 to 19 do
  begin
    s[i*2+1] := Hex[(AOID.Data.id[i] shr 4) and $F + 1];
    s[i*2+2] := Hex[(AOID.Data.id[i] and $F) + 1];
  end;
  Result := s;
end;

function GitOIDToShortString(const AOID: TGitOID): string;
const
  Hex: PChar = '0123456789abcdef';
var
  i: Integer;
  s: string;
begin
  SetLength(s, 7);
  for i := 0 to 2 do
  begin
    s[i*2+1] := Hex[(AOID.Data.id[i] shr 4) and $F + 1];
    s[i*2+2] := Hex[(AOID.Data.id[i] and $F) + 1];
  end;
  s[7] := Hex[(AOID.Data.id[3] shr 4) and $F + 1];
  Result := s;
end;

function GitOIDEquals(const A, B: TGitOID): Boolean;
begin
  Result := git_oid_equal(@A.Data, @B.Data) <> 0;
end;

function IsGitOIDZero(const AOID: TGitOID): Boolean;
begin
  Result := git_oid_iszero(@AOID.Data) <> 0;
end;

function CreateGitTimeFromGitTime(const AGitTime: git_time): TGitTime;
begin
  Result.Time := UnixToDateTime(AGitTime.time);
  Result.Offset := AGitTime.offset;
end;

function GitTimeToString(const ATime: TGitTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ATime.Time);
  Result := Result + Format(' %+.2d%.2d', [ATime.Offset div 60, Abs(ATime.Offset) mod 60]);
end;

end.
