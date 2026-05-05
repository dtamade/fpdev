unit fpdev.git.operations.libgit2backendflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, git2.api, git2.types, git2.impl,
  libgit2, ctypes, fpdev.git.types,
  fpdev.git.operations.coreflow,
  fpdev.git.operations.identityflow,
  fpdev.git.operations.transportflow;

type
  PGitAddAllStatusPayload = ^TGitAddAllStatusPayload;
  TGitAddAllStatusPayload = record
    AddPaths: TStringList;
    RemovePaths: TStringList;
    WorkDir: string;
    NeedsFallback: Boolean;
    HadError: Boolean;
    ErrorText: string;
  end;

  PIndexMatchPayload = ^TIndexMatchPayload;
  TIndexMatchPayload = record
    MatchCount: Integer;
  end;

function AddAllStatusCb(const APath: PChar; AFlags: cuint; APayload: Pointer): cint; cdecl;
function IndexMatchedCb(const APath: PChar; const AMatchedPathSpec: PChar; APayload: Pointer): cint; cdecl;

function IsRepositoryWithLibgit2(const APath: string): Boolean;

function CloneWithLibgit2Core(
  AGitManager: IGitManager;
  const AURL, ALocalPath: string;
  out AError: string
): Boolean;

function FetchWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, ARemote: string;
  out AError: string
): Boolean;

function PullWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out AError: string;
  out ANeedsFallback: Boolean;
  const AAllowMerge: Boolean = True
): Boolean;

function CheckoutWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, AName: string;
  const Force: Boolean;
  out AError: string
): Boolean;

function TryHasRemoteWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out AHasRemote: Boolean
): Boolean;

function TryGetRemoteURLWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, ARemote: string;
  out AURL: string
): Boolean;

function TryGetCurrentBranchWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out ABranch: string
): Boolean;

function TryGetShortHeadHashWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out AFullHash: string
): Boolean;

function TryListBranchesWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out ARefs: TStringArray
): Boolean;

function TryListRemoteBranchesWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, ARemote: string;
  out ARefs: TStringArray
): Boolean;

function AddAllWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;

function AddPathspecWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, APathSpec: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;

function CommitWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, AMessage: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;

function PushWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, ARemote, ABranch: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;

implementation

function AddAllStatusCb(const APath: PChar; AFlags: cuint; APayload: Pointer): cint; cdecl;
var
  P: PGitAddAllStatusPayload;
  UnsupportedMask: cuint;
  DeleteMask: cuint;
  TypeChangeMask: cuint;
  LPath: string;
  AbsPath: string;
begin
  Result := 0;
  P := PGitAddAllStatusPayload(APayload);
  if (P = nil) or (P^.AddPaths = nil) or (P^.RemovePaths = nil) then
    Exit(0);
  if P^.HadError then
    Exit(-1);

  try
    if (AFlags and GIT_STATUS_IGNORED) <> 0 then
      Exit(0);

    UnsupportedMask := GIT_STATUS_WT_UNREADABLE;

    if (AFlags and UnsupportedMask) <> 0 then
    begin
      P^.NeedsFallback := True;
      Exit(0);
    end;

    if (AFlags = GIT_STATUS_CURRENT) or (APath = nil) then
      Exit(0);

    LPath := string(APath);
    if Trim(LPath) = '' then
      Exit(0);

    DeleteMask := GIT_STATUS_WT_DELETED or GIT_STATUS_INDEX_DELETED;
    if (AFlags and DeleteMask) <> 0 then
    begin
      P^.RemovePaths.Add(LPath);
      Exit(0);
    end;

    TypeChangeMask := GIT_STATUS_WT_TYPECHANGE or GIT_STATUS_INDEX_TYPECHANGE;
    if (AFlags and TypeChangeMask) <> 0 then
    begin
      P^.RemovePaths.Add(LPath);

      AbsPath := '';
      if Trim(P^.WorkDir) <> '' then
        AbsPath := IncludeTrailingPathDelimiter(P^.WorkDir) + StringReplace(LPath, '/', PathDelim, [rfReplaceAll]);

      if (AbsPath = '') or (not DirectoryExists(AbsPath)) then
      begin
        if (AbsPath = '') or FileExists(AbsPath) then
          P^.AddPaths.Add(LPath);
      end;
      Exit(0);
    end;

    if (AFlags <> GIT_STATUS_CURRENT) then
    begin
      P^.AddPaths.Add(LPath);
    end;
  except
    on E: Exception do
    begin
      P^.HadError := True;
      P^.ErrorText := E.Message;
      Result := -1;
    end;
  end;
end;

function IndexMatchedCb(const APath: PChar; const AMatchedPathSpec: PChar; APayload: Pointer): cint; cdecl;
var
  P: PIndexMatchPayload;
begin
  if APath <> nil then;
  if AMatchedPathSpec <> nil then;
  Result := 0;
  P := PIndexMatchPayload(APayload);
  if P <> nil then
    Inc(P^.MatchCount);
end;

function IsRepositoryWithLibgit2(const APath: string): Boolean;
var
  Mgr: IGitManager;
begin
  Result := False;

  try
    Mgr := NewGitManager();
    if not Mgr.Initialize then
      Exit;

    Result := Mgr.IsRepository(APath);
  except
    on E: Exception do
    begin
      Result := False;
    end;
  end;
end;

function CloneWithLibgit2Core(
  AGitManager: IGitManager;
  const AURL, ALocalPath: string;
  out AError: string
): Boolean;
var
  RepoHandle: git_repository;
  CloneOpts: git_clone_options;
  CredPayload: TGitTransportCredentialPayload;
  RC: cint;
begin
  Result := False;
  AError := '';

  if AGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  RepoHandle := nil;
  try
    try
      if not TryInitGitCloneTransportOptions(CloneOpts, CredPayload, AError) then
        Exit(False);

      RC := git_clone(RepoHandle, PChar(AURL), PChar(ALocalPath), @CloneOpts);
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 clone failed');
        Exit(False);
      end;

      Result := True;
    except
      on E: Exception do
      begin
        AError := 'libgit2 clone exception: ' + E.Message;
        Result := False;
      end;
    end;
  finally
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function FetchWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, ARemote: string;
  out AError: string
): Boolean;
var
  RepoHandle: git_repository;
  RemoteHandle: git_remote;
  FetchOpts: git_fetch_options;
  CredPayload: TGitTransportCredentialPayload;
  RemoteName: string;
  RC: cint;
begin
  Result := False;
  AError := '';

  if AGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  RemoteName := Trim(ARemote);
  if RemoteName = '' then
    RemoteName := 'origin';

  RepoHandle := nil;
  RemoteHandle := nil;
  try
    try
      if not TryOpenGitRepositoryCore(ARepoPath, RepoHandle, AError) then
        Exit(False);

      if not TryLookupGitRemoteCore(RepoHandle, RemoteName, RemoteHandle, AError) then
        Exit(False);

      if not TryInitGitFetchTransportOptions(FetchOpts, CredPayload, AError) then
        Exit(False);

      RC := git_remote_fetch(RemoteHandle, nil, @FetchOpts, nil);
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 fetch failed');
        Exit(False);
      end;

      Result := True;
    except
      on E: Exception do
      begin
        AError := 'libgit2 fetch exception: ' + E.Message;
        Result := False;
      end;
    end;
  finally
    if RemoteHandle <> nil then
      git_remote_free(RemoteHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function PullWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out AError: string;
  out ANeedsFallback: Boolean;
  const AAllowMerge: Boolean
): Boolean;
var
  Repo: IGitRepository;
  Branch: string;
  RepoHandle: git_repository;
  RemoteHandle: git_remote;
  FetchOpts: git_fetch_options;
  CheckoutOpts: git_checkout_options;
  CredPayload: TGitTransportCredentialPayload;
  LocalRef: git_reference;
  RemoteRef: git_reference;
  UpdatedRef: git_reference;
  LocalRefName: string;
  RemoteRefName: string;
  Ahead: csize_t;
  Behind: csize_t;
  RemoteOid: Pgit_oid;
  RepoIndex: git_index;
  TargetCommit: git_commit;
  TargetTree: git_tree;
  OurCommit: git_commit;
  TheirCommit: git_commit;
  MergeIndex: git_index;
  MergeTree: git_tree;
  MergeTreeOid: git_oid;
  MergeCommitOid: git_oid;
  Parents: array[0..1] of git_commit;
  ParentsPtr: Pointer;
  ParentCount: csize_t;
  AuthorSig: git_signature;
  CommitterSig: git_signature;
  Identity: TGitOperationIdentity;
  MergeMessage: string;
  RC: cint;
begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  if AGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    ANeedsFallback := True;
    Exit;
  end;

  try
    Repo := AGitManager.OpenRepository(ARepoPath);
    if Repo = nil then
    begin
      AError := 'libgit2 could not open repository: ' + ARepoPath;
      ANeedsFallback := True;
      Exit;
    end;

    if Repo.HasUncommittedChanges then
    begin
      AError := 'Working tree has local changes';
      ANeedsFallback := True;
      Exit(False);
    end;

    Branch := Repo.CurrentBranch;
    if (Trim(Branch) = '') or SameText(Branch, 'HEAD') then
    begin
      AError := 'Detached HEAD';
      ANeedsFallback := True;
      Exit(False);
    end;
  except
    on E: Exception do
    begin
      AError := 'libgit2 pull exception: ' + E.Message;
      ANeedsFallback := True;
      Result := False;
      Exit;
    end;
  end;

  RepoHandle := nil;
  RemoteHandle := nil;
  LocalRef := nil;
  RemoteRef := nil;
  UpdatedRef := nil;
  RepoIndex := nil;
  TargetCommit := nil;
  TargetTree := nil;
  OurCommit := nil;
  TheirCommit := nil;
  MergeIndex := nil;
  MergeTree := nil;
  AuthorSig := nil;
  CommitterSig := nil;
  try
    if not TryOpenGitRepositoryCore(ARepoPath, RepoHandle, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    if not TryLookupGitRemoteCore(RepoHandle, 'origin', RemoteHandle, AError, 'No remote configured') then
    begin
      ANeedsFallback := False;
      Exit(False);
    end;

    if not TryInitGitFetchTransportOptions(FetchOpts, CredPayload, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_remote_fetch(RemoteHandle, nil, @FetchOpts, nil);
    if RC <> GIT_OK then
    begin
      AError := BuildLibgit2Error('libgit2 fetch failed');
      ANeedsFallback := True;
      Exit(False);
    end;

    LocalRefName := 'refs/heads/' + Branch;
    RemoteRefName := 'refs/remotes/origin/' + Branch;

    RC := git_reference_lookup(LocalRef, RepoHandle, PChar(LocalRefName));
    if RC <> GIT_OK then
    begin
      AError := BuildLibgit2Error('libgit2 lookup local branch failed');
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_reference_lookup(RemoteRef, RepoHandle, PChar(RemoteRefName));
    if RC <> GIT_OK then
    begin
      AError := BuildLibgit2Error('libgit2 lookup remote branch failed');
      ANeedsFallback := True;
      Exit(False);
    end;

    Ahead := 0;
    Behind := 0;
    RemoteOid := git_reference_target(RemoteRef);
    if RemoteOid = nil then
    begin
      AError := 'libgit2 remote OID is empty';
      ANeedsFallback := True;
      Exit(False);
    end;
    RC := git_graph_ahead_behind(Ahead, Behind, RepoHandle, git_reference_target(LocalRef), RemoteOid);
    if RC <> GIT_OK then
    begin
      AError := BuildLibgit2Error('libgit2 ahead/behind failed');
      ANeedsFallback := True;
      Exit(False);
    end;

    if (Ahead = 0) and (Behind = 0) then
      Exit(True);

    if (Ahead = 0) and (Behind > 0) then
    begin
      UpdatedRef := nil;
      RC := git_reference_set_target(UpdatedRef, LocalRef, RemoteOid, PChar('fpdev fast-forward'));
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 fast-forward failed');
        ANeedsFallback := True;
        Exit(False);
      end;

      if UpdatedRef <> nil then
        git_reference_free(UpdatedRef);

      TargetCommit := nil;
      RC := git_commit_lookup(TargetCommit, RepoHandle, RemoteOid);
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 lookup target commit failed');
        ANeedsFallback := True;
        Exit(False);
      end;

      TargetTree := nil;
      RC := git_commit_tree(TargetTree, TargetCommit);
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 lookup target tree failed');
        ANeedsFallback := True;
        Exit(False);
      end;

      RepoIndex := nil;
      if not TryOpenGitRepositoryIndexCore(RepoHandle, RepoIndex, AError) then
      begin
        ANeedsFallback := True;
        Exit(False);
      end;

      RC := git_index_read_tree(RepoIndex, TargetTree);
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 update index failed');
        ANeedsFallback := True;
        Exit(False);
      end;

      RC := git_index_write(RepoIndex);
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 write index failed');
        ANeedsFallback := True;
        Exit(False);
      end;

      if not TryInitGitCheckoutOptionsCore(CheckoutOpts, AError) then
      begin
        ANeedsFallback := True;
        Exit(False);
      end;

      CheckoutOpts.checkout_strategy :=
        GIT_CHECKOUT_FORCE or
        GIT_CHECKOUT_RECREATE_MISSING or
        GIT_CHECKOUT_REMOVE_UNTRACKED;
      RC := git_checkout_head(RepoHandle, @CheckoutOpts);
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 checkout failed');
        ANeedsFallback := True;
        Exit(False);
      end;

      Exit(True);
    end;

    if (Ahead > 0) and (Behind = 0) then
      Exit(True);

    if not AAllowMerge then
    begin
      AError := 'Non-fast-forward update requires merge/rebase';
      ANeedsFallback := True;
      Exit(False);
    end;

    if (Ahead > 0) and (Behind > 0) then
    begin
      try
        if not TryResolveGitOperationIdentity(RepoHandle, ARepoPath, True, Identity) then
        begin
          AError := 'Git identity not configured (user.name/user.email)';
          ANeedsFallback := True;
          Exit(False);
        end;

        if not TryCreateGitOperationSignatures(Identity, AuthorSig, CommitterSig, AError) then
        begin
          ANeedsFallback := True;
          Exit(False);
        end;

        RC := git_commit_lookup(OurCommit, RepoHandle, git_reference_target(LocalRef));
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 lookup HEAD commit failed');
          ANeedsFallback := True;
          Exit(False);
        end;

        RC := git_commit_lookup(TheirCommit, RepoHandle, RemoteOid);
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 lookup remote commit failed');
          ANeedsFallback := True;
          Exit(False);
        end;

        MergeIndex := nil;
        RC := git_merge_commits(MergeIndex, RepoHandle, OurCommit, TheirCommit, nil);
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 merge commits failed');
          ANeedsFallback := True;
          Exit(False);
        end;

        if (MergeIndex <> nil) and (git_index_has_conflicts(MergeIndex) <> 0) then
        begin
          AError := 'Merge has conflicts; manual resolution required';
          ANeedsFallback := False;
          Exit(False);
        end;

        MergeTreeOid := Default(git_oid);
        RC := git_index_write_tree_to(MergeTreeOid, MergeIndex, RepoHandle);
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 write merge tree failed');
          ANeedsFallback := True;
          Exit(False);
        end;

        MergeTree := nil;
        if not TryLookupGitTreeCore(
          RepoHandle,
          MergeTreeOid,
          MergeTree,
          AError,
          'libgit2 merge tree lookup failed'
        ) then
        begin
          ANeedsFallback := True;
          Exit(False);
        end;

        Parents[0] := OurCommit;
        Parents[1] := TheirCommit;
        ParentCount := 2;
        ParentsPtr := @Parents[0];

        MergeMessage := 'Merge origin/' + Branch + ' into ' + Branch;
        MergeCommitOid := Default(git_oid);
        RC := git_commit_create(MergeCommitOid, RepoHandle, PChar(LocalRefName),
          AuthorSig, CommitterSig, nil, PChar(MergeMessage),
          MergeTree, ParentCount, ParentsPtr);
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 merge commit failed');
          ANeedsFallback := True;
          Exit(False);
        end;

        RepoIndex := nil;
        if not TryOpenGitRepositoryIndexCore(RepoHandle, RepoIndex, AError) then
        begin
          ANeedsFallback := True;
          Exit(False);
        end;

        RC := git_index_read_tree(RepoIndex, MergeTree);
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 update index failed');
          ANeedsFallback := True;
          Exit(False);
        end;

        RC := git_index_write(RepoIndex);
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 write index failed');
          ANeedsFallback := True;
          Exit(False);
        end;

        if not TryInitGitCheckoutOptionsCore(CheckoutOpts, AError) then
        begin
          ANeedsFallback := True;
          Exit(False);
        end;

        CheckoutOpts.checkout_strategy := GIT_CHECKOUT_SAFE or GIT_CHECKOUT_RECREATE_MISSING;
        RC := git_checkout_head(RepoHandle, @CheckoutOpts);
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 checkout after merge failed');
          ANeedsFallback := True;
          Exit(False);
        end;

        Exit(True);
      finally
        if RepoIndex <> nil then
        begin
          git_index_free(RepoIndex);
          RepoIndex := nil;
        end;
        if CommitterSig <> nil then
        begin
          git_signature_free(CommitterSig);
          CommitterSig := nil;
        end;
        if AuthorSig <> nil then
        begin
          git_signature_free(AuthorSig);
          AuthorSig := nil;
        end;
        if MergeTree <> nil then
        begin
          git_object_free(git_object(MergeTree));
          MergeTree := nil;
        end;
        if MergeIndex <> nil then
        begin
          git_index_free(MergeIndex);
          MergeIndex := nil;
        end;
        if TheirCommit <> nil then
        begin
          git_object_free(git_object(TheirCommit));
          TheirCommit := nil;
        end;
        if OurCommit <> nil then
        begin
          git_object_free(git_object(OurCommit));
          OurCommit := nil;
        end;
      end;
    end;

    AError := 'Non-fast-forward update requires merge/rebase';
    ANeedsFallback := True;
    Result := False;
  finally
    if RepoIndex <> nil then
      git_index_free(RepoIndex);
    if TargetTree <> nil then
      git_object_free(git_object(TargetTree));
    if TargetCommit <> nil then
      git_object_free(git_object(TargetCommit));
    if CommitterSig <> nil then
      git_signature_free(CommitterSig);
    if AuthorSig <> nil then
      git_signature_free(AuthorSig);
    if MergeTree <> nil then
      git_object_free(git_object(MergeTree));
    if MergeIndex <> nil then
      git_index_free(MergeIndex);
    if TheirCommit <> nil then
      git_object_free(git_object(TheirCommit));
    if OurCommit <> nil then
      git_object_free(git_object(OurCommit));
    if RemoteRef <> nil then
      git_reference_free(RemoteRef);
    if LocalRef <> nil then
      git_reference_free(LocalRef);
    if RemoteHandle <> nil then
      git_remote_free(RemoteHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function CheckoutWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, AName: string;
  const Force: Boolean;
  out AError: string
): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  AError := '';

  if AGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit;
  end;

  try
    Repo := AGitManager.OpenRepository(ARepoPath);
    if Repo = nil then
    begin
      AError := 'libgit2 could not open repository: ' + ARepoPath;
      Exit;
    end;

    if Pos('refs/', AName) = 1 then
    begin
      Result := Repo.CheckoutBranchEx(AName, Force);
      if not Result then
        AError := 'libgit2 checkout failed: ' + AName;
      Exit;
    end;

    if Repo.CheckoutBranchEx(AName, Force) then
      Exit(True);

    if Repo.CheckoutBranchEx('refs/remotes/origin/' + AName, Force) then
      Exit(True);

    if Repo.CheckoutBranchEx('refs/tags/' + AName, Force) then
      Exit(True);

    AError := 'libgit2 checkout failed: ' + AName;
    Result := False;
  except
    on E: Exception do
    begin
      AError := 'libgit2 checkout exception: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TryHasRemoteWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out AHasRemote: Boolean
): Boolean;
var
  Repo: IGitRepository;
  Ext: IGitRepositoryExt;
  Remotes: TStringArray;
begin
  Result := False;
  AHasRemote := False;

  if AGitManager = nil then
    Exit(False);

  try
    Repo := AGitManager.OpenRepository(ARepoPath);
    if (Repo <> nil) and Supports(Repo, IGitRepositoryExt, Ext) then
    begin
      Remotes := Ext.ListRemotes;
      AHasRemote := Length(Remotes) > 0;
      Exit(True);
    end;
  except
    AHasRemote := False;
  end;
end;

function TryGetRemoteURLWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, ARemote: string;
  out AURL: string
): Boolean;
var
  Repo: IGitRepository;
  Remote: IGitRemote;
begin
  Result := False;
  AURL := '';

  if AGitManager = nil then
    Exit(False);

  try
    Repo := AGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      Remote := Repo.Remote(ARemote);
      if Remote <> nil then
      begin
        AURL := Trim(Remote.URL);
        Exit(True);
      end;
    end;
  except
    AURL := '';
  end;
end;

function TryGetCurrentBranchWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out ABranch: string
): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  ABranch := '';

  if AGitManager = nil then
    Exit(False);

  try
    Repo := AGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      ABranch := Repo.CurrentBranch;
      Exit(True);
    end;
  except
    ABranch := '';
  end;
end;

function TryGetShortHeadHashWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out AFullHash: string
): Boolean;
var
  Repo: IGitRepository;
  HeadCommit: IGitCommit;
begin
  Result := False;
  AFullHash := '';

  if AGitManager = nil then
    Exit(False);

  try
    Repo := AGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      HeadCommit := Repo.HeadCommit;
      if HeadCommit <> nil then
      begin
        AFullHash := HeadCommit.OIDString;
        Exit(AFullHash <> '');
      end;
    end;
  except
    AFullHash := '';
  end;
end;

function TryListBranchesWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out ARefs: TStringArray
): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  ARefs := nil;

  if AGitManager = nil then
    Exit(False);

  try
    Repo := AGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      ARefs := Repo.ListBranches(gbAll);
      Exit(True);
    end;
  except
    ARefs := nil;
  end;
end;

function TryListRemoteBranchesWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, ARemote: string;
  out ARefs: TStringArray
): Boolean;
var
  Repo: IGitRepository;
begin
  Result := False;
  ARefs := nil;
  if ARemote = '' then
    Exit(False);

  if AGitManager = nil then
    Exit(False);

  try
    Repo := AGitManager.OpenRepository(ARepoPath);
    if Repo <> nil then
    begin
      ARefs := Repo.ListBranches(gbRemote);
      Exit(True);
    end;
  except
    ARefs := nil;
  end;
end;

function AddAllWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
var
  RepoHandle: git_repository;
  IndexHandle: git_index;
  AddPaths: TStringList;
  RemovePaths: TStringList;
  Payload: TGitAddAllStatusPayload;
  WorkDirP: PChar;
  RC: cint;
  i: Integer;
begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  RepoHandle := nil;
  IndexHandle := nil;
  AddPaths := TStringList.Create;
  RemovePaths := TStringList.Create;
  try
    Payload.AddPaths := AddPaths;
    Payload.RemovePaths := RemovePaths;
    Payload.WorkDir := '';
    Payload.NeedsFallback := False;
    Payload.HadError := False;
    Payload.ErrorText := '';

    if not TryOpenGitRepositoryCore(ARepoPath, RepoHandle, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    WorkDirP := git_repository_workdir(RepoHandle);
    if WorkDirP <> nil then
      Payload.WorkDir := StringReplace(string(WorkDirP), '/', PathDelim, [rfReplaceAll]);

    if not TryOpenGitRepositoryIndexCore(RepoHandle, IndexHandle, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_status_foreach(RepoHandle, @AddAllStatusCb, @Payload);
    if Payload.HadError then
    begin
      AError := 'libgit2 status callback error: ' + Payload.ErrorText;
      ANeedsFallback := True;
      Exit(False);
    end;
    if RC <> GIT_OK then
    begin
      AError := BuildLibgit2Error('libgit2 status foreach failed');
      ANeedsFallback := True;
      Exit(False);
    end;

    if Payload.NeedsFallback then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    if (RemovePaths.Count > 0) or (AddPaths.Count > 0) then
    begin
      for i := 0 to RemovePaths.Count - 1 do
      begin
        RC := git_index_remove_bypath(IndexHandle, PChar(RemovePaths[i]));
        if (RC <> GIT_OK) and (RC <> GIT_ENOTFOUND) then
        begin
          AError := BuildLibgit2Error('libgit2 remove failed');
          ANeedsFallback := True;
          Exit(False);
        end;
      end;

      for i := 0 to AddPaths.Count - 1 do
      begin
        RC := git_index_add_bypath(IndexHandle, PChar(AddPaths[i]));
        if RC <> GIT_OK then
        begin
          AError := BuildLibgit2Error('libgit2 add failed');
          ANeedsFallback := True;
          Exit(False);
        end;
      end;

      RC := git_index_write(IndexHandle);
      if RC <> GIT_OK then
      begin
        AError := BuildLibgit2Error('libgit2 index write failed');
        ANeedsFallback := True;
        Exit(False);
      end;
    end;

    Result := True;
  finally
    RemovePaths.Free;
    AddPaths.Free;
    if IndexHandle <> nil then
      git_index_free(IndexHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function AddPathspecWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, APathSpec: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
var
  RepoHandle: git_repository;
  IndexHandle: git_index;
  WorkDirP: PChar;
  WorkDir: string;
  PathSpecAbs: string;
  WorkDirAbs: string;
  RelPath: string;
  RelPathFs: string;
  AbsCandidate: string;
  RC: Integer;
  PathSpecStr: AnsiString;
  PathSpecPtrs: array[0..0] of PChar;
  PathSpecs: git_strarray;
  MatchPayload: TIndexMatchPayload;
begin
  Result := False;
  AError := '';
  ANeedsFallback := True;

  if AGitManager = nil then
  begin
    AError := 'libgit2 not initialized';
    Exit(False);
  end;

  RepoHandle := nil;
  IndexHandle := nil;
  try
    if not TryOpenGitRepositoryCore(ARepoPath, RepoHandle, AError) then
      Exit(False);

    WorkDir := '';
    WorkDirP := git_repository_workdir(RepoHandle);
    if WorkDirP <> nil then
      WorkDir := string(WorkDirP);

    RelPath := APathSpec;

    if WorkDir <> '' then
    begin
      PathSpecAbs := ExpandFileName(APathSpec);
      WorkDirAbs := ExpandFileName(IncludeTrailingPathDelimiter(WorkDir));
      {$IFDEF MSWINDOWS}
      if Pos(AnsiLowerCase(WorkDirAbs), AnsiLowerCase(PathSpecAbs)) = 1 then
      {$ELSE}
      if Pos(WorkDirAbs, PathSpecAbs) = 1 then
      {$ENDIF}
        RelPath := Copy(PathSpecAbs, Length(WorkDirAbs) + 1, MaxInt);
    end;

    RelPath := StringReplace(RelPath, '\', '/', [rfReplaceAll]);

    if not TryOpenGitRepositoryIndexCore(RepoHandle, IndexHandle, AError) then
      Exit(False);

    PathSpecStr := AnsiString(RelPath);
    PathSpecPtrs[0] := PChar(PathSpecStr);
    PathSpecs.strings := @PathSpecPtrs[0];
    PathSpecs.count := 1;

    MatchPayload.MatchCount := 0;

    RC := git_index_update_all(IndexHandle, @PathSpecs, @IndexMatchedCb, @MatchPayload);
    if RC = GIT_OK then
      RC := git_index_add_all(
        IndexHandle,
        @PathSpecs,
        GIT_INDEX_ADD_CHECK_PATHSPEC,
        @IndexMatchedCb,
        @MatchPayload
      );

    if RC = GIT_OK then
    begin
      if MatchPayload.MatchCount = 0 then
      begin
        AbsCandidate := '';
        if (Pos('*', RelPath) = 0) and (Pos('?', RelPath) = 0) and (WorkDir <> '') then
        begin
          RelPathFs := StringReplace(RelPath, '/', PathDelim, [rfReplaceAll]);
          AbsCandidate := IncludeTrailingPathDelimiter(WorkDir) + RelPathFs;
        end;

        if (AbsCandidate <> '') and DirectoryExists(AbsCandidate) then
        begin
          Result := True;
          ANeedsFallback := False;
          Exit(True);
        end;

        AError := Format('libgit2 add failed: pathspec ''%s'' did not match any files', [APathSpec]);
        Exit(False);
      end;

      RC := git_index_write(IndexHandle);
      if RC = GIT_OK then
      begin
        Result := True;
        ANeedsFallback := False;
        Exit(True);
      end;
    end;

    AError := BuildLibgit2Error('libgit2 add failed');
  finally
    if IndexHandle <> nil then
      git_index_free(IndexHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function CommitWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, AMessage: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
var
  RepoHandle: git_repository;
  IndexHandle: git_index;
  TreeHandle: git_tree;
  TreeOid: git_oid;
  CommitOid: git_oid;
  HeadRef: git_reference;
  BranchRef: git_reference;
  ParentCommit: git_commit;
  Parents: array[0..0] of git_commit;
  ParentsPtr: Pointer;
  ParentCount: csize_t;
  AuthorSig: git_signature;
  CommitterSig: git_signature;
  Identity: TGitOperationIdentity;
  UpdateRef: string;
  SymTargetP: PChar;
  TargetOID: Pgit_oid;
  RC: cint;
begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  RepoHandle := nil;
  IndexHandle := nil;
  TreeHandle := nil;
  HeadRef := nil;
  BranchRef := nil;
  ParentCommit := nil;
  AuthorSig := nil;
  CommitterSig := nil;

  try
    if not TryOpenGitRepositoryCore(ARepoPath, RepoHandle, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    UpdateRef := 'HEAD';
    ParentCount := 0;
    RC := git_reference_lookup(HeadRef, RepoHandle, PChar('HEAD'));
    if RC = GIT_OK then
    begin
      SymTargetP := git_reference_symbolic_target(HeadRef);
      if SymTargetP <> nil then
      begin
        UpdateRef := string(SymTargetP);
        RC := git_reference_lookup(BranchRef, RepoHandle, SymTargetP);
        if RC = GIT_OK then
        begin
          TargetOID := git_reference_target(BranchRef);
          if TargetOID <> nil then
          begin
            RC := git_commit_lookup(ParentCommit, RepoHandle, TargetOID);
            if RC = GIT_OK then
            begin
              Parents[0] := ParentCommit;
              ParentCount := 1;
            end;
          end;
        end;
      end
      else
      begin
        TargetOID := git_reference_target(HeadRef);
        if TargetOID <> nil then
        begin
          RC := git_commit_lookup(ParentCommit, RepoHandle, TargetOID);
          if RC = GIT_OK then
          begin
            Parents[0] := ParentCommit;
            ParentCount := 1;
          end;
        end;
      end;
    end;

    if not TryResolveGitOperationIdentity(RepoHandle, ARepoPath, False, Identity) then
    begin
      AError := 'Git identity not configured (user.name/user.email)';
      ANeedsFallback := True;
      Exit(False);
    end;

    if not TryCreateGitOperationSignatures(Identity, AuthorSig, CommitterSig, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    if not TryOpenGitRepositoryIndexCore(RepoHandle, IndexHandle, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_index_write_tree(TreeOid, IndexHandle);
    if RC <> GIT_OK then
    begin
      AError := BuildLibgit2Error('libgit2 write tree failed');
      ANeedsFallback := True;
      Exit(False);
    end;

    TreeHandle := nil;
    if not TryLookupGitTreeCore(RepoHandle, TreeOid, TreeHandle, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    ParentsPtr := nil;
    if ParentCount > 0 then
      ParentsPtr := @Parents[0];

    CommitOid := Default(git_oid);
    RC := git_commit_create(CommitOid, RepoHandle, PChar(UpdateRef),
      AuthorSig, CommitterSig, nil, PChar(AMessage),
      TreeHandle, ParentCount, ParentsPtr);
    if RC <> GIT_OK then
    begin
      AError := BuildLibgit2Error('libgit2 commit failed');
      ANeedsFallback := True;
      Exit(False);
    end;

    Result := True;
  finally
    if BranchRef <> nil then
      git_reference_free(BranchRef);
    if HeadRef <> nil then
      git_reference_free(HeadRef);
    if TreeHandle <> nil then
      git_object_free(git_object(TreeHandle));
    if IndexHandle <> nil then
      git_index_free(IndexHandle);
    if ParentCommit <> nil then
      git_object_free(git_object(ParentCommit));
    if AuthorSig <> nil then
      git_signature_free(AuthorSig);
    if CommitterSig <> nil then
      git_signature_free(CommitterSig);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

function PushWithLibgit2Core(
  AGitManager: IGitManager;
  const ARepoPath, ARemote, ABranch: string;
  out AError: string;
  out ANeedsFallback: Boolean
): Boolean;
var
  RepoHandle: git_repository;
  RemoteHandle: git_remote;
  HeadRef: git_reference;
  SymTargetP: PChar;
  BranchParam: string;
  RemoteName: string;
  LocalRef: string;
  RemoteRef: string;
  RefSpecStr: AnsiString;
  RefSpecPtrs: array[0..0] of PChar;
  RefSpecs: git_strarray;
  PushOpts: git_push_options;
  CredPayload: TGitTransportCredentialPayload;
  RC: cint;
begin
  Result := False;
  AError := '';
  ANeedsFallback := False;

  RepoHandle := nil;
  RemoteHandle := nil;
  HeadRef := nil;

  BranchParam := Trim(ABranch);
  RemoteName := Trim(ARemote);
  if RemoteName = '' then
    RemoteName := 'origin';

  try
    if not TryOpenGitRepositoryCore(ARepoPath, RepoHandle, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    if not TryLookupGitRemoteCore(RepoHandle, RemoteName, RemoteHandle, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    LocalRef := '';
    RemoteRef := '';

    if (BranchParam = '') or SameText(BranchParam, 'HEAD') then
    begin
      RC := git_reference_lookup(HeadRef, RepoHandle, PChar('HEAD'));
      if RC = GIT_OK then
      begin
        SymTargetP := git_reference_symbolic_target(HeadRef);
        if SymTargetP <> nil then
        begin
          LocalRef := string(SymTargetP);
          RemoteRef := LocalRef;
        end;
      end;

      if (LocalRef = '') or (RemoteRef = '') then
      begin
        AError := 'libgit2 push requires a branch (detached HEAD?)';
        ANeedsFallback := True;
        Exit(False);
      end;
    end
    else if Pos('refs/', BranchParam) = 1 then
    begin
      LocalRef := BranchParam;
      RemoteRef := BranchParam;
    end
    else
    begin
      LocalRef := 'refs/heads/' + BranchParam;
      RemoteRef := 'refs/heads/' + BranchParam;
    end;

    RefSpecStr := AnsiString(LocalRef + ':' + RemoteRef);
    RefSpecPtrs[0] := PChar(RefSpecStr);
    RefSpecs.strings := @RefSpecPtrs[0];
    RefSpecs.count := 1;

    if not TryInitGitPushTransportOptions(PushOpts, CredPayload, AError) then
    begin
      ANeedsFallback := True;
      Exit(False);
    end;

    RC := git_remote_push(RemoteHandle, @RefSpecs, @PushOpts);
    if RC <> GIT_OK then
    begin
      AError := BuildLibgit2Error('libgit2 push failed');
      ANeedsFallback := True;
      Exit(False);
    end;

    Result := True;
  finally
    if HeadRef <> nil then
      git_reference_free(HeadRef);
    if RemoteHandle <> nil then
      git_remote_free(RemoteHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
  end;
end;

end.
