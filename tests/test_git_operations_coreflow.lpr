program test_git_operations_coreflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, libgit2, git2.api, git2.impl, fpdev.git.operations.coreflow,
  test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', AName);
    Inc(TestsPassed);
  end
  else
  begin
    if ADetail <> '' then
      WriteLn('[FAIL] ', AName, ': ', ADetail)
    else
      WriteLn('[FAIL] ', AName);
    Inc(TestsFailed);
  end;
end;

procedure EnsureRepoRemoteConfig(const ARepoDir, ARemoteName, ARemoteUrl: string);
var
  ConfigPath: string;
  Lines: TStringList;
begin
  ConfigPath := IncludeTrailingPathDelimiter(ARepoDir) + '.git' + PathDelim + 'config';

  Lines := TStringList.Create;
  try
    if FileExists(ConfigPath) then
      Lines.LoadFromFile(ConfigPath);

    Lines.Add('');
    Lines.Add(Format('[remote "%s"]', [ARemoteName]));
    Lines.Add('  url = ' + ARemoteUrl);
    Lines.Add('  fetch = +refs/heads/*:refs/remotes/' + ARemoteName + '/*');
    Lines.SaveToFile(ConfigPath);
  finally
    Lines.Free;
  end;
end;

procedure TestFormatLibgit2ErrorUsesDetailWhenPresent;
begin
  Check('coreflow formats prefixed libgit2 error with detail',
    FormatLibgit2Error('libgit2 open repository failed', 'missing path') =
      'libgit2 open repository failed: missing path');
end;

procedure TestFormatLibgit2ErrorFallsBackToPrefixWhenDetailMissing;
begin
  Check('coreflow formats prefixed libgit2 error without detail',
    FormatLibgit2Error('libgit2 open repository failed', '') =
      'libgit2 open repository failed');
end;

procedure TestCoreflowReportsMissingRepositoryWithSharedPrefix;
var
  RepoHandle: git_repository;
  Err: string;
  TempRoot: string;
  MissingRepo: string;
begin
  TempRoot := CreateUniqueTempDir('fpdev-git-coreflow-missing');
  try
    MissingRepo := TempRoot + PathDelim + 'no-repo';
    RepoHandle := nil;
    Err := '';
    Check('coreflow open missing repository fails',
      not TryOpenGitRepositoryCore(MissingRepo, RepoHandle, Err),
      'expected open failure');
    Check('coreflow missing repository keeps nil handle', RepoHandle = nil);
    Check('coreflow missing repository uses shared prefix',
      Pos('libgit2 open repository failed', Err) = 1, Err);
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestCoreflowOpensRepoIndexRemoteTreeAndCheckoutOptions;
var
  TempRoot: string;
  RepoDir: string;
  RemoteBareDir: string;
  Err: string;
  RepoHandle: git_repository;
  IndexHandle: git_index;
  RemoteHandle: git_remote;
  MissingRemoteHandle: git_remote;
  TreeHandle: git_tree;
  CheckoutOpts: git_checkout_options;
  TreeOid: git_oid;
  Mgr: IGitManager;
  LocalRepoOk: Boolean;
  RemoteRepoOk: Boolean;
begin
  TempRoot := CreateUniqueTempDir('fpdev-git-coreflow');
  try
    RepoDir := TempRoot + PathDelim + 'repo';
    RemoteBareDir := TempRoot + PathDelim + 'origin.git';
    ForceDirectories(RepoDir);
    ForceDirectories(RemoteBareDir);

    Mgr := NewGitManager();
    Check('coreflow helper creates git manager', Mgr <> nil);
    if Mgr = nil then
      Exit;
    LocalRepoOk := Mgr.InitRepository(RepoDir, False) <> nil;
    Check('coreflow helper initializes local repository', LocalRepoOk);
    if not LocalRepoOk then
      Exit;
    RemoteRepoOk := Mgr.InitRepository(RemoteBareDir, True) <> nil;
    Check('coreflow helper initializes bare remote repository', RemoteRepoOk);
    if not RemoteRepoOk then
      Exit;
    EnsureRepoRemoteConfig(RepoDir, 'origin', RemoteBareDir);

    RepoHandle := nil;
    IndexHandle := nil;
    RemoteHandle := nil;
    MissingRemoteHandle := nil;
    TreeHandle := nil;
    Err := '';

    Check('coreflow opens repository',
      TryOpenGitRepositoryCore(RepoDir, RepoHandle, Err), Err);
    Check('coreflow open repository keeps error empty', Err = '', Err);

    Err := '';
    Check('coreflow opens repository index',
      TryOpenGitRepositoryIndexCore(RepoHandle, IndexHandle, Err), Err);
    Check('coreflow open index keeps error empty', Err = '', Err);

    TreeOid := Default(git_oid);
    Check('coreflow fixture writes tree from index',
      git_index_write_tree(TreeOid, IndexHandle) = GIT_OK,
      BuildLibgit2Error('libgit2 write tree failed'));

    Err := '';
    Check('coreflow looks up tree from tree oid',
      TryLookupGitTreeCore(RepoHandle, TreeOid, TreeHandle, Err), Err);
    Check('coreflow tree lookup keeps error empty', Err = '', Err);

    Err := '';
    Check('coreflow looks up configured origin remote',
      TryLookupGitRemoteCore(RepoHandle, 'origin', RemoteHandle, Err), Err);
    Check('coreflow remote lookup keeps error empty', Err = '', Err);

    Err := '';
    Check('coreflow custom remote prefix is preserved on failure',
      not TryLookupGitRemoteCore(RepoHandle, 'upstream', MissingRemoteHandle, Err, 'No remote configured'),
      'expected missing remote');
    Check('coreflow missing remote keeps nil handle', MissingRemoteHandle = nil);
    Check('coreflow missing remote uses caller prefix',
      Pos('No remote configured', Err) = 1, Err);

    Err := '';
    Check('coreflow initializes checkout options',
      TryInitGitCheckoutOptionsCore(CheckoutOpts, Err), Err);
    Check('coreflow checkout options keep error empty', Err = '', Err);
    Check('coreflow checkout options start without strategy flags',
      CheckoutOpts.checkout_strategy = 0,
      IntToStr(Integer(CheckoutOpts.checkout_strategy)));
  finally
    if TreeHandle <> nil then
      git_object_free(git_object(TreeHandle));
    if MissingRemoteHandle <> nil then
      git_remote_free(MissingRemoteHandle);
    if RemoteHandle <> nil then
      git_remote_free(RemoteHandle);
    if IndexHandle <> nil then
      git_index_free(IndexHandle);
    if RepoHandle <> nil then
      git_repository_free(RepoHandle);
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestFormatLibgit2ErrorUsesDetailWhenPresent;
  TestFormatLibgit2ErrorFallsBackToPrefixWhenDetailMissing;
  TestCoreflowReportsMissingRepositoryWithSharedPrefix;
  TestCoreflowOpensRepoIndexRemoteTreeAndCheckoutOptions;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Git Operations Coreflow Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
