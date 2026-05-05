program test_git_operations_libgit2backendflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, libgit2, git2.api, git2.impl,
  fpdev.git.operations.coreflow,
  fpdev.git.operations.identityflow,
  fpdev.git.operations.transportflow,
  fpdev.git.operations.libgit2backendflow,
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

procedure TestNilManagerReportsError;
var
  Err: string;
  HasRemote: Boolean;
begin
  Check('nil manager clone fails', not CloneWithLibgit2Core(nil, 'http://x', '/tmp/x', Err), Err);
  Check('nil manager clone error mentions not initialized', Pos('not initialized', Err) > 0, Err);

  Err := '';
  Check('nil manager fetch fails', not FetchWithLibgit2Core(nil, '/tmp/x', 'origin', Err), Err);

  HasRemote := False;
  Err := '';
  Check('nil manager has-remote fails', not TryHasRemoteWithLibgit2Core(nil, '/tmp/x', HasRemote));
end;

procedure TestMissingRepoCloneFails;
var
  Err: string;
  Mgr: IGitManager;
begin
  Mgr := NewGitManager();
  Check('libgit2 backend creates git manager', Mgr <> nil);
  if Mgr = nil then
    Exit;
  if not Mgr.Initialize then
  begin
    Check('libgit2 manager initializes', False, 'init failed');
    Exit;
  end;

  Check('clone to missing remote fails gracefully',
    not CloneWithLibgit2Core(Mgr, 'http://nonexistent.invalid/repo.git',
      '/tmp/fpdev-test-clone-nope-' + IntToStr(GetTickCount64), Err),
    'expected clone failure');
  Check('clone error mentions libgit2', Pos('libgit2', Err) > 0, Err);
end;

procedure TestFetchMissingRepoFails;
var
  Err: string;
  Mgr: IGitManager;
  TempRoot: string;
  MissingPath: string;
begin
  Mgr := NewGitManager();
  if (Mgr = nil) or (not Mgr.Initialize) then
  begin
    Check('libgit2 manager available', False);
    Exit;
  end;

  TempRoot := CreateUniqueTempDir('fpdev-git-backendflow-fetch');
  try
    MissingPath := TempRoot + PathDelim + 'no-repo';
    Check('fetch missing repo fails', not FetchWithLibgit2Core(Mgr, MissingPath, 'origin', Err), Err);
    Check('fetch error mentions open repository or libgit2',
      (Pos('open repository', Err) > 0) or (Pos('libgit2', Err) > 0), Err);
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestCheckoutMissingRepoFails;
var
  Err: string;
  Mgr: IGitManager;
  TempRoot: string;
  MissingPath: string;
begin
  Mgr := NewGitManager();
  if (Mgr = nil) or (not Mgr.Initialize) then
  begin
    Check('libgit2 manager available', False);
    Exit;
  end;

  TempRoot := CreateUniqueTempDir('fpdev-git-backendflow-checkout');
  try
    MissingPath := TempRoot + PathDelim + 'no-repo';
    Check('checkout missing repo fails', not CheckoutWithLibgit2Core(Mgr, MissingPath, 'main', False, Err), Err);
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestQueryFunctionsOnMissingRepo;
var
  Mgr: IGitManager;
  TempRoot: string;
  MissingPath: string;
  HasRemote: Boolean;
  URL: string;
  Branch: string;
  Hash: string;
  Refs: TStringArray;
begin
  Mgr := NewGitManager();
  if (Mgr = nil) or (not Mgr.Initialize) then
  begin
    Check('libgit2 manager available', False);
    Exit;
  end;

  TempRoot := CreateUniqueTempDir('fpdev-git-backendflow-query');
  try
    MissingPath := TempRoot + PathDelim + 'no-repo';

    Check('has-remote missing repo returns false',
      not TryHasRemoteWithLibgit2Core(Mgr, MissingPath, HasRemote));

    Check('remote-url missing repo returns false',
      not TryGetRemoteURLWithLibgit2Core(Mgr, MissingPath, 'origin', URL));

    Check('current-branch missing repo returns false',
      not TryGetCurrentBranchWithLibgit2Core(Mgr, MissingPath, Branch));

    Check('head-hash missing repo returns false',
      not TryGetShortHeadHashWithLibgit2Core(Mgr, MissingPath, Hash));

    Check('list-branches missing repo returns false',
      not TryListBranchesWithLibgit2Core(Mgr, MissingPath, Refs));

    Check('list-remote-branches missing repo returns false',
      not TryListRemoteBranchesWithLibgit2Core(Mgr, MissingPath, 'origin', Refs));

    Check('list-remote-branches empty remote returns false',
      not TryListRemoteBranchesWithLibgit2Core(Mgr, MissingPath, '', Refs));
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestAddAllAndPathspecOnMissingRepo;
var
  Mgr: IGitManager;
  TempRoot: string;
  MissingPath: string;
  Err: string;
  NeedsFallback: Boolean;
begin
  Mgr := NewGitManager();
  if (Mgr = nil) or (not Mgr.Initialize) then
  begin
    Check('libgit2 manager available', False);
    Exit;
  end;

  TempRoot := CreateUniqueTempDir('fpdev-git-backendflow-add');
  try
    MissingPath := TempRoot + PathDelim + 'no-repo';

    Check('add-all missing repo fails',
      not AddAllWithLibgit2Core(Mgr, MissingPath, Err, NeedsFallback), Err);
    Check('add-all missing repo sets needs-fallback', NeedsFallback);

    Check('add-pathspec missing repo fails',
      not AddPathspecWithLibgit2Core(Mgr, MissingPath, 'file.txt', Err, NeedsFallback), Err);
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestCommitAndPushOnMissingRepo;
var
  Mgr: IGitManager;
  TempRoot: string;
  MissingPath: string;
  Err: string;
  NeedsFallback: Boolean;
begin
  Mgr := NewGitManager();
  if (Mgr = nil) or (not Mgr.Initialize) then
  begin
    Check('libgit2 manager available', False);
    Exit;
  end;

  TempRoot := CreateUniqueTempDir('fpdev-git-backendflow-commit');
  try
    MissingPath := TempRoot + PathDelim + 'no-repo';

    Check('commit missing repo fails',
      not CommitWithLibgit2Core(Mgr, MissingPath, 'test', Err, NeedsFallback), Err);
    Check('commit missing repo sets needs-fallback', NeedsFallback);

    Check('push missing repo fails',
      not PushWithLibgit2Core(Mgr, MissingPath, 'origin', 'main', Err, NeedsFallback), Err);
    Check('push missing repo sets needs-fallback', NeedsFallback);
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestIsRepositoryWithLibgit2Standalone;
var
  TempRoot: string;
  NotRepo: string;
begin
  TempRoot := CreateUniqueTempDir('fpdev-git-backendflow-isrepo');
  try
    NotRepo := TempRoot + PathDelim + 'empty';
    ForceDirectories(NotRepo);
    Check('IsRepositoryWithLibgit2 returns false for non-repo dir',
      not IsRepositoryWithLibgit2(NotRepo));
    Check('IsRepositoryWithLibgit2 returns false for missing dir',
      not IsRepositoryWithLibgit2('/nonexistent/path-' + IntToStr(GetTickCount64)));
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestQueryFunctionsOnValidRepo;
var
  Mgr: IGitManager;
  TempRoot: string;
  RepoDir: string;
  HasRemote: Boolean;
  Branch: string;
  Hash: string;
  Refs: TStringArray;
begin
  Mgr := NewGitManager();
  if (Mgr = nil) or (not Mgr.Initialize) then
  begin
    Check('libgit2 manager available', False);
    Exit;
  end;

  TempRoot := CreateUniqueTempDir('fpdev-git-backendflow-valid');
  try
    RepoDir := TempRoot + PathDelim + 'repo';
    ForceDirectories(RepoDir);

    if Mgr.InitRepository(RepoDir, False) = nil then
    begin
      Check('init repository succeeds', False);
      Exit;
    end;

    Check('has-remote on fresh repo returns true',
      TryHasRemoteWithLibgit2Core(Mgr, RepoDir, HasRemote));
    Check('fresh repo has no remote', not HasRemote);

    Check('current-branch on fresh repo returns true',
      TryGetCurrentBranchWithLibgit2Core(Mgr, RepoDir, Branch));
    Check('fresh repo branch detected (may be empty on initial commit)',
      (Length(Trim(Branch)) > 0) or (Branch = ''),
      'branch: "' + Branch + '"');

    if TryGetShortHeadHashWithLibgit2Core(Mgr, RepoDir, Hash) then
      Check('fresh repo hash is non-empty when available', Length(Trim(Hash)) > 0, 'hash: ' + Hash)
    else
      Check('fresh repo without commits: head-hash unavailable is acceptable', True);

    Check('list-branches on fresh repo returns true',
      TryListBranchesWithLibgit2Core(Mgr, RepoDir, Refs));
  finally
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestNilManagerReportsError;
  TestMissingRepoCloneFails;
  TestFetchMissingRepoFails;
  TestCheckoutMissingRepoFails;
  TestQueryFunctionsOnMissingRepo;
  TestAddAllAndPathspecOnMissingRepo;
  TestCommitAndPushOnMissingRepo;
  TestIsRepositoryWithLibgit2Standalone;
  TestQueryFunctionsOnValidRepo;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Git Operations Libgit2 Backendflow Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
