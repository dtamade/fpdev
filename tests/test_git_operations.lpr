program test_git_operations;

{$mode objfpc}{$H+}

{ Unit tests for TGitOperations class in fpdev.utils.git }

uses
  SysUtils, Classes, fpdev.utils, fpdev.utils.git, git2.api, git2.types, git2.impl, libgit2, test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ATestName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

procedure TestCreateDestroy;
var
  Git: TGitOperations;
begin
  WriteLn('');
  WriteLn('=== Test 1: TGitOperations Create/Destroy ===');

  Git := TGitOperations.Create;
  try
    Check('Create succeeds', Assigned(Git));
    Check('Backend is set', Git.Backend in [gbLibgit2, gbCommandLine, gbNone]);
    Check('LastError is empty initially', Git.LastError = '');
  finally
    Git.Free;
  end;
end;

procedure TestBackendDetection;
var
  Git: TGitOperations;
  BackendStr: string;
begin
  WriteLn('');
  WriteLn('=== Test 2: Backend Detection ===');

  Git := TGitOperations.Create;
  try
    BackendStr := GitBackendToString(Git.Backend);
    Check('Backend string is not empty', BackendStr <> '');

    case Git.Backend of
      gbLibgit2:
        Check('libgit2 backend detected', BackendStr = 'libgit2');
      gbCommandLine:
        Check('Command-line backend detected', BackendStr = 'git (command-line)');
      gbNone:
        Check('No backend available', BackendStr = 'none');
    end;

    WriteLn('  Detected backend: ', BackendStr);
  finally
    Git.Free;
  end;
end;

procedure TestIsRepository;
var
  Git: TGitOperations;
  ProjectRoot: string;
begin
  WriteLn('');
  WriteLn('=== Test 3: IsRepository ===');

  Git := TGitOperations.Create;
  try
    // Test with current project (should be a git repo)
    // bin/test_git_operations -> go up one level to project root
    ProjectRoot := ExtractFilePath(ParamStr(0));
    ProjectRoot := ExpandFileName(ProjectRoot + '..');

    WriteLn('  Testing path: ', ProjectRoot);

    if Git.Backend <> gbNone then
    begin
      Check('Project root is repository', Git.IsRepository(ProjectRoot));
      Check('Temp dir is not repository', not Git.IsRepository(GetTempDir(False)));
      Check('Non-existent dir is not repository', not Git.IsRepository('/nonexistent/path'));
    end
    else
    begin
      WriteLn('  [SKIP] No git backend available');
      Inc(TestsPassed); // Count as pass since backend unavailability is expected
    end;
  finally
    Git.Free;
  end;
end;

procedure TestGetCurrentBranch;
var
  Git: TGitOperations;
  ProjectRoot: string;
  Branch: string;
begin
  WriteLn('');
  WriteLn('=== Test 4: GetCurrentBranch ===');

  Git := TGitOperations.Create;
  try
    // Test with current project
    // bin/test_git_operations -> go up one level to project root
    ProjectRoot := ExtractFilePath(ParamStr(0));
    ProjectRoot := ExpandFileName(ProjectRoot + '..');

    WriteLn('  Testing path: ', ProjectRoot);

    if Git.Backend <> gbNone then
    begin
      Branch := Git.GetCurrentBranch(ProjectRoot);
      Check('Branch is not empty', Branch <> '');
      WriteLn('  Current branch: ', Branch);
    end
    else
    begin
      WriteLn('  [SKIP] No git backend available');
      Inc(TestsPassed);
    end;
  finally
    Git.Free;
  end;
end;

procedure TestVerboseProperty;
var
  Git: TGitOperations;
begin
  WriteLn('');
  WriteLn('=== Test 5: Verbose Property ===');

  Git := TGitOperations.Create;
  try
    Check('Verbose defaults to False', not Git.Verbose);

    Git.Verbose := True;
    Check('Verbose can be set to True', Git.Verbose);

    Git.Verbose := False;
    Check('Verbose can be set to False', not Git.Verbose);
  finally
    Git.Free;
  end;
end;

procedure EnsureRepoUserConfig(const ARepoDir: string);
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
    Lines.Add('[user]');
    Lines.Add('  name = FPDev Test');
    Lines.Add('  email = fpdev-test@example.invalid');
    Lines.SaveToFile(ConfigPath);
  finally
    Lines.Free;
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

procedure TestCommitLocalRepo;
var
  Git: TGitOperations;
  TempRoot: string;
  RepoDir: string;
  Mgr: IGitManager;
  Repo: IGitRepository;
  SL: TStringList;
  Hash1: string;
  Hash2: string;
  Hash3: string;
  Hash4: string;
  Entries: TGitStatusEntryArray;
  Filter: TGitStatusFilter;
  FoundDeleted: Boolean;
  FoundRenameDeleted: Boolean;
  FoundRenameNew: Boolean;
  OriginalPath: string;
  NoGitPath: string;
  i: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 6: Commit (libgit2) ===');

  Git := TGitOperations.Create;
  TempRoot := '';
  try
    if Git.Backend <> gbLibgit2 then
    begin
      WriteLn('  [SKIP] libgit2 backend not available');
      Inc(TestsPassed);
      Exit;
    end;

    TempRoot := CreateUniqueTempDir('test_gitops_commit');
    RepoDir := TempRoot + PathDelim + 'repo';
    ForceDirectories(RepoDir);

    Mgr := NewGitManager();
    if not Mgr.Initialize then
    begin
      WriteLn('  [SKIP] libgit2 initialize failed');
      Inc(TestsPassed);
      Exit;
    end;

    Repo := Mgr.InitRepository(RepoDir, False);
    Check('InitRepository succeeds', Repo <> nil);
    if Repo = nil then
      Exit;

    EnsureRepoUserConfig(RepoDir);

    SL := TStringList.Create;
    try
      SL.Text := 'hello';
      SL.SaveToFile(RepoDir + PathDelim + 'a.txt');
    finally
      SL.Free;
    end;

    Check('Add a.txt', Git.Add(RepoDir, 'a.txt'));
    Check('Commit 1', Git.Commit(RepoDir, 'test commit 1'));
    Hash1 := Git.GetShortHeadHash(RepoDir, 7);
    Check('HEAD hash not empty', Hash1 <> '');

    SL := TStringList.Create;
    try
      SL.Text := 'hello2';
      SL.SaveToFile(RepoDir + PathDelim + 'a.txt');
      SL.Text := 'world';
      SL.SaveToFile(RepoDir + PathDelim + 'b.txt');
    finally
      SL.Free;
    end;

    Check('Add all', Git.Add(RepoDir, '.'));
    Check('Commit 2', Git.Commit(RepoDir, 'test commit 2'));
    Hash2 := Git.GetShortHeadHash(RepoDir, 7);
    Check('HEAD hash not empty after commit 2', Hash2 <> '');
    Check('HEAD hash changes', (Hash1 <> '') and (Hash2 <> '') and (Hash2 <> Hash1));

    // Stage deletions via libgit2 add-all ('.') without CLI fallback.
    Check('Delete b.txt', DeleteFile(RepoDir + PathDelim + 'b.txt'));

    OriginalPath := get_env('PATH');
    {$IFDEF MSWINDOWS}
    NoGitPath := 'C:\\__fpdev_no_git__';
    {$ELSE}
    NoGitPath := '/__fpdev_no_git__';
    {$ENDIF}

    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Add all after delete (no CLI)', Git.Add(RepoDir, '.'));
    finally
      set_env('PATH', OriginalPath);
    end;

    Filter.IncludeUntracked := True;
    Filter.IncludeIgnored := False;
    Filter.WorkingTreeOnly := False;
    Filter.IndexOnly := True;
    Entries := Repo.StatusEntries(Filter);

    FoundDeleted := False;
    for i := 0 to High(Entries) do
    begin
      if SameText(Entries[i].Path, 'b.txt') and (gsIndexDeleted in Entries[i].Flags) then
      begin
        FoundDeleted := True;
        Break;
      end;
    end;
    Check('b.txt staged as index deleted', FoundDeleted);

    Check('Commit delete', Git.Commit(RepoDir, 'test commit delete'));
    Hash3 := Git.GetShortHeadHash(RepoDir, 7);
    Check('HEAD hash changes after delete', (Hash2 <> '') and (Hash3 <> '') and (Hash3 <> Hash2));
    Check('Repo clean after delete commit', Repo.IsClean);

    Check('Rename a.txt -> a_renamed.txt', RenameFile(
      RepoDir + PathDelim + 'a.txt',
      RepoDir + PathDelim + 'a_renamed.txt'
    ));

    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Add all after rename (no CLI)', Git.Add(RepoDir, '.'));
    finally
      set_env('PATH', OriginalPath);
    end;

    Filter.IncludeUntracked := True;
    Filter.IncludeIgnored := False;
    Filter.WorkingTreeOnly := False;
    Filter.IndexOnly := True;
    Entries := Repo.StatusEntries(Filter);

    FoundRenameDeleted := False;
    FoundRenameNew := False;
    for i := 0 to High(Entries) do
    begin
      if SameText(Entries[i].Path, 'a.txt') and (gsIndexDeleted in Entries[i].Flags) then
        FoundRenameDeleted := True;
      if SameText(Entries[i].Path, 'a_renamed.txt') and (gsIndexNew in Entries[i].Flags) then
        FoundRenameNew := True;
    end;
    Check('a.txt staged as index deleted', FoundRenameDeleted);
    Check('a_renamed.txt staged as index new', FoundRenameNew);

    Check('Commit rename', Git.Commit(RepoDir, 'test commit rename'));
    Hash4 := Git.GetShortHeadHash(RepoDir, 7);
    Check('HEAD hash changes after rename', (Hash3 <> '') and (Hash4 <> '') and (Hash4 <> Hash3));
    Check('Repo clean after rename commit', Repo.IsClean);

  finally
    Git.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestPushLocalBareRemote;
var
  Git: TGitOperations;
  TempRoot: string;
  LocalRepoDir: string;
  RemoteBareDir: string;
  Mgr: IGitManager;
  LocalRepo: IGitRepository;
  RemoteRepo: IGitRepository;
  SL: TStringList;
  Branch: string;
  LocalHandle: git_repository;
  RemoteHandle: git_repository;
  LocalRef: git_reference;
  RemoteRef: git_reference;
  LocalOid: Pgit_oid;
  RemoteOid: Pgit_oid;
  RC: Integer;
  RefName: string;
begin
  WriteLn('');
  WriteLn('=== Test 7: Push (libgit2 local bare remote) ===');

  Git := TGitOperations.Create;
  TempRoot := '';
  try
    if Git.Backend <> gbLibgit2 then
    begin
      WriteLn('  [SKIP] libgit2 backend not available');
      Inc(TestsPassed);
      Exit;
    end;

    TempRoot := CreateUniqueTempDir('test_gitops_push');
    LocalRepoDir := TempRoot + PathDelim + 'local';
    RemoteBareDir := TempRoot + PathDelim + 'remote.git';
    ForceDirectories(LocalRepoDir);
    ForceDirectories(RemoteBareDir);

    Mgr := NewGitManager();
    if not Mgr.Initialize then
    begin
      WriteLn('  [SKIP] libgit2 initialize failed');
      Inc(TestsPassed);
      Exit;
    end;

    LocalRepo := Mgr.InitRepository(LocalRepoDir, False);
    Check('Init local repository succeeds', LocalRepo <> nil);
    if LocalRepo = nil then
      Exit;

    RemoteRepo := Mgr.InitRepository(RemoteBareDir, True);
    Check('Init bare remote repository succeeds', RemoteRepo <> nil);
    if RemoteRepo = nil then
      Exit;

    EnsureRepoUserConfig(LocalRepoDir);
    EnsureRepoRemoteConfig(LocalRepoDir, 'origin', RemoteBareDir);

    SL := TStringList.Create;
    try
      SL.Text := 'push-test';
      SL.SaveToFile(LocalRepoDir + PathDelim + 'p.txt');
    finally
      SL.Free;
    end;

    Check('Add p.txt', Git.Add(LocalRepoDir, 'p.txt'));
    Check('Commit', Git.Commit(LocalRepoDir, 'test push commit'));
    Check('Push to origin', Git.Push(LocalRepoDir, 'origin', ''));

    Branch := Git.GetCurrentBranch(LocalRepoDir);
    Check('Branch is not empty', Branch <> '');
    if Branch = '' then
      Exit;

    RefName := 'refs/heads/' + Branch;

    LocalHandle := nil;
    RemoteHandle := nil;
    LocalRef := nil;
    RemoteRef := nil;
    try
      RC := git_repository_open(LocalHandle, PChar(LocalRepoDir));
      Check('Open local repository handle', RC = GIT_OK);
      if RC <> GIT_OK then
        Exit;

      RC := git_repository_open(RemoteHandle, PChar(RemoteBareDir));
      Check('Open remote repository handle', RC = GIT_OK);
      if RC <> GIT_OK then
        Exit;

      RC := git_reference_lookup(LocalRef, LocalHandle, PChar(RefName));
      Check('Lookup local branch ref', RC = GIT_OK);
      if RC <> GIT_OK then
        Exit;

      RC := git_reference_lookup(RemoteRef, RemoteHandle, PChar(RefName));
      Check('Lookup remote branch ref', RC = GIT_OK);
      if RC <> GIT_OK then
        Exit;

      LocalOid := git_reference_target(LocalRef);
      RemoteOid := git_reference_target(RemoteRef);
      Check('Local branch OID is not nil', LocalOid <> nil);
      Check('Remote branch OID is not nil', RemoteOid <> nil);
      if (LocalOid <> nil) and (RemoteOid <> nil) then
        Check('Remote matches local', git_oid_equal(LocalOid, RemoteOid) <> 0);
    finally
      if RemoteRef <> nil then
        git_reference_free(RemoteRef);
      if LocalRef <> nil then
        git_reference_free(LocalRef);
      if RemoteHandle <> nil then
        git_repository_free(RemoteHandle);
      if LocalHandle <> nil then
        git_repository_free(LocalHandle);
    end;

  finally
    Git.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestAddPathspecDirAndGlob;
var
  Git: TGitOperations;
  TempRoot: string;
  RepoDir: string;
  Mgr: IGitManager;
  Repo: IGitRepository;
  SL: TStringList;
  Entries: TGitStatusEntryArray;
  Filter: TGitStatusFilter;
  FoundDeleted: Boolean;
  FoundModified: Boolean;
  FoundNew: Boolean;
  FoundOutside: Boolean;
  FoundNestedModified: Boolean;
  FoundNestedNew: Boolean;
  OriginalPath: string;
  NoGitPath: string;
  i: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 8: Add pathspec (dir/glob) (libgit2) ===');

  Git := TGitOperations.Create;
  TempRoot := '';
  try
    if Git.Backend <> gbLibgit2 then
    begin
      WriteLn('  [SKIP] libgit2 backend not available');
      Inc(TestsPassed);
      Exit;
    end;

    TempRoot := CreateUniqueTempDir('test_gitops_add_pathspec');
    RepoDir := TempRoot + PathDelim + 'repo';
    ForceDirectories(RepoDir);

    Mgr := NewGitManager();
    if not Mgr.Initialize then
    begin
      WriteLn('  [SKIP] libgit2 initialize failed');
      Inc(TestsPassed);
      Exit;
    end;

    Repo := Mgr.InitRepository(RepoDir, False);
    Check('InitRepository succeeds', Repo <> nil);
    if Repo = nil then
      Exit;

    EnsureRepoUserConfig(RepoDir);

    ForceDirectories(RepoDir + PathDelim + 'dir' + PathDelim + 'sub');
    ForceDirectories(RepoDir + PathDelim + 'outside');

    SL := TStringList.Create;
    try
      SL.Text := 'v1';
      SL.SaveToFile(RepoDir + PathDelim + 'dir' + PathDelim + 'a.txt');
      SL.Text := 'v1';
      SL.SaveToFile(RepoDir + PathDelim + 'dir' + PathDelim + 'sub' + PathDelim + 'b.txt');
      SL.Text := 'v1';
      SL.SaveToFile(RepoDir + PathDelim + 'outside' + PathDelim + 'x.txt');
    finally
      SL.Free;
    end;

    Check('Add all initial', Git.Add(RepoDir, '.'));
    Check('Commit initial', Git.Commit(RepoDir, 'test add pathspec initial'));
    Check('Repo clean after initial commit', Repo.IsClean);

    // Directory pathspec should stage nested changes and deletions within the directory.
    Check('Delete dir/a.txt', DeleteFile(RepoDir + PathDelim + 'dir' + PathDelim + 'a.txt'));

    SL := TStringList.Create;
    try
      SL.Text := 'v2';
      SL.SaveToFile(RepoDir + PathDelim + 'dir' + PathDelim + 'sub' + PathDelim + 'b.txt');
      SL.Text := 'new';
      SL.SaveToFile(RepoDir + PathDelim + 'dir' + PathDelim + 'c.txt');
      SL.Text := 'new-outside';
      SL.SaveToFile(RepoDir + PathDelim + 'outside' + PathDelim + 'y.txt');
    finally
      SL.Free;
    end;

    OriginalPath := get_env('PATH');
    {$IFDEF MSWINDOWS}
    NoGitPath := 'C:\\__fpdev_no_git__';
    {$ELSE}
    NoGitPath := '/__fpdev_no_git__';
    {$ENDIF}

    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Add dir pathspec (no CLI)', Git.Add(RepoDir, 'dir'));
    finally
      set_env('PATH', OriginalPath);
    end;

    Filter.IncludeUntracked := True;
    Filter.IncludeIgnored := False;
    Filter.WorkingTreeOnly := False;
    Filter.IndexOnly := True;
    Entries := Repo.StatusEntries(Filter);

    FoundDeleted := False;
    FoundModified := False;
    FoundNew := False;
    FoundOutside := False;
    for i := 0 to High(Entries) do
    begin
      if SameText(Entries[i].Path, 'dir/a.txt') and (gsIndexDeleted in Entries[i].Flags) then
        FoundDeleted := True;
      if SameText(Entries[i].Path, 'dir/sub/b.txt') and (gsIndexModified in Entries[i].Flags) then
        FoundModified := True;
      if SameText(Entries[i].Path, 'dir/c.txt') and (gsIndexNew in Entries[i].Flags) then
        FoundNew := True;
      if SameText(Entries[i].Path, 'outside/y.txt') and (gsIndexNew in Entries[i].Flags) then
        FoundOutside := True;
    end;
    Check('dir/a.txt staged deleted', FoundDeleted);
    Check('dir/sub/b.txt staged modified', FoundModified);
    Check('dir/c.txt staged new', FoundNew);
    Check('outside/y.txt not staged', not FoundOutside);

    Check('Cleanup outside/y.txt', DeleteFile(RepoDir + PathDelim + 'outside' + PathDelim + 'y.txt'));

    Check('Commit dir pathspec changes', Git.Commit(RepoDir, 'test add dir pathspec'));
    Check('Repo clean after dir pathspec commit', Repo.IsClean);

    // Glob pathspec matching follows git's internal pathspec rules (no shell
    // expansion here), which can match nested paths as well.
    SL := TStringList.Create;
    try
      SL.Text := 'v3';
      SL.SaveToFile(RepoDir + PathDelim + 'dir' + PathDelim + 'c.txt');
      SL.Text := 'v3';
      SL.SaveToFile(RepoDir + PathDelim + 'dir' + PathDelim + 'sub' + PathDelim + 'b.txt');
      SL.Text := 'new2';
      SL.SaveToFile(RepoDir + PathDelim + 'dir' + PathDelim + 'd.txt');
      SL.Text := 'new-nested';
      SL.SaveToFile(RepoDir + PathDelim + 'dir' + PathDelim + 'sub' + PathDelim + 'e.txt');
    finally
      SL.Free;
    end;

    OriginalPath := get_env('PATH');
    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Add glob pathspec (no CLI)', Git.Add(RepoDir, 'dir/*.txt'));
    finally
      set_env('PATH', OriginalPath);
    end;

    Entries := Repo.StatusEntries(Filter);

    FoundModified := False;
    FoundNew := False;
    FoundNestedModified := False;
    FoundNestedNew := False;
    for i := 0 to High(Entries) do
    begin
      if SameText(Entries[i].Path, 'dir/c.txt') and (gsIndexModified in Entries[i].Flags) then
        FoundModified := True;
      if SameText(Entries[i].Path, 'dir/d.txt') and (gsIndexNew in Entries[i].Flags) then
        FoundNew := True;
      if SameText(Entries[i].Path, 'dir/sub/b.txt') and (gsIndexModified in Entries[i].Flags) then
        FoundNestedModified := True;
      if SameText(Entries[i].Path, 'dir/sub/e.txt') and (gsIndexNew in Entries[i].Flags) then
        FoundNestedNew := True;
    end;

    Check('dir/c.txt staged modified (glob)', FoundModified);
    Check('dir/d.txt staged new (glob)', FoundNew);
    Check('dir/sub/b.txt staged modified (glob)', FoundNestedModified);
    Check('dir/sub/e.txt staged new (glob)', FoundNestedNew);

    Check('Commit glob pathspec changes', Git.Commit(RepoDir, 'test add glob pathspec'));
    Check('Repo clean after glob pathspec commit', Repo.IsClean);

  finally
    Git.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestRemoteOpsNoCLI;
var
  Git: TGitOperations;
  TempRoot: string;
  SeedRepoDir: string;
  RemoteBareDir: string;
  CloneDir: string;
  Mgr: IGitManager;
  SeedRepo: IGitRepository;
  RemoteRepo: IGitRepository;
  SL: TStringList;
  Branch: string;
  Hash1: string;
  Hash2: string;
  HashAfterPull: string;
  OriginalPath: string;
  NoGitPath: string;
begin
  WriteLn('');
  WriteLn('=== Test 9: Remote ops without CLI (libgit2) ===');

  Git := TGitOperations.Create;
  TempRoot := '';
  try
    if Git.Backend <> gbLibgit2 then
    begin
      WriteLn('  [SKIP] libgit2 backend not available');
      Inc(TestsPassed);
      Exit;
    end;

    TempRoot := CreateUniqueTempDir('test_gitops_remote_nocli');
    SeedRepoDir := TempRoot + PathDelim + 'seed';
    RemoteBareDir := TempRoot + PathDelim + 'remote.git';
    CloneDir := TempRoot + PathDelim + 'clone';
    ForceDirectories(SeedRepoDir);
    ForceDirectories(RemoteBareDir);

    Mgr := NewGitManager();
    if not Mgr.Initialize then
    begin
      WriteLn('  [SKIP] libgit2 initialize failed');
      Inc(TestsPassed);
      Exit;
    end;

    SeedRepo := Mgr.InitRepository(SeedRepoDir, False);
    Check('Init seed repository succeeds', SeedRepo <> nil);
    if SeedRepo = nil then
      Exit;

    RemoteRepo := Mgr.InitRepository(RemoteBareDir, True);
    Check('Init bare remote repository succeeds', RemoteRepo <> nil);
    if RemoteRepo = nil then
      Exit;

    EnsureRepoUserConfig(SeedRepoDir);
    EnsureRepoRemoteConfig(SeedRepoDir, 'origin', RemoteBareDir);

    SL := TStringList.Create;
    try
      SL.Text := 'seed';
      SL.SaveToFile(SeedRepoDir + PathDelim + 'seed.txt');
    finally
      SL.Free;
    end;

    Check('Seed add all', Git.Add(SeedRepoDir, '.'));
    Check('Seed commit', Git.Commit(SeedRepoDir, 'seed commit'));
    Branch := Git.GetCurrentBranch(SeedRepoDir);
    Check('Seed branch not empty', Branch <> '');

    Hash1 := Git.GetShortHeadHash(SeedRepoDir, 40);
    Check('Seed HEAD hash not empty', Hash1 <> '');
    Check('Seed push to origin', Git.Push(SeedRepoDir, 'origin', ''));

    OriginalPath := get_env('PATH');
    {$IFDEF MSWINDOWS}
    NoGitPath := 'C:\\__fpdev_no_git__';
    {$ELSE}
    NoGitPath := '/__fpdev_no_git__';
    {$ENDIF}

    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Clone from bare remote (no CLI)', Git.Clone(RemoteBareDir, CloneDir, Branch));
    finally
      set_env('PATH', OriginalPath);
    end;

    EnsureRepoUserConfig(CloneDir);

    SL := TStringList.Create;
    try
      SL.Text := 'seed-updated';
      SL.SaveToFile(CloneDir + PathDelim + 'seed.txt');
    finally
      SL.Free;
    end;

    Check('Clone add all', Git.Add(CloneDir, '.'));
    Check('Clone commit', Git.Commit(CloneDir, 'clone commit'));
    Hash2 := Git.GetShortHeadHash(CloneDir, 40);
    Check('Clone HEAD hash changes', (Hash2 <> '') and (Hash2 <> Hash1));

    OriginalPath := get_env('PATH');
    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Push clone changes (no CLI)', Git.Push(CloneDir, 'origin', ''));
    finally
      set_env('PATH', OriginalPath);
    end;

    OriginalPath := get_env('PATH');
    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Fetch origin (no CLI)', Git.Fetch(SeedRepoDir, 'origin'));
      Check('Pull fast-forward (no CLI)', Git.Pull(SeedRepoDir));
    finally
      set_env('PATH', OriginalPath);
    end;

    HashAfterPull := Git.GetShortHeadHash(SeedRepoDir, 40);
    Check('Seed updated after pull', HashAfterPull = Hash2);
  finally
    Git.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestPullFastForwardExtNoCLI;
var
  Git: TGitOperations;
  TempRoot: string;
  SeedRepoDir: string;
  RemoteBareDir: string;
  CloneDir: string;
  Mgr: IGitManager;
  SeedRepo: IGitRepository;
  RemoteRepo: IGitRepository;
  Ext: IGitRepositoryExt;
  SL: TStringList;
  Branch: string;
  OriginalPath: string;
  NoGitPath: string;
  PullRes: TGitPullFastForwardResult;
  PullErr: string;
  RemoteTxt: string;
begin
  WriteLn('');
  WriteLn('=== Test 10: PullFastForward creates missing files (no CLI) ===');

  Git := TGitOperations.Create;
  TempRoot := '';
  try
    if Git.Backend <> gbLibgit2 then
    begin
      WriteLn('  [SKIP] libgit2 backend not available');
      Inc(TestsPassed);
      Exit;
    end;

    TempRoot := CreateUniqueTempDir('test_gitops_pullff_recreate_missing_nocli');
    SeedRepoDir := TempRoot + PathDelim + 'seed';
    RemoteBareDir := TempRoot + PathDelim + 'remote.git';
    CloneDir := TempRoot + PathDelim + 'clone';
    ForceDirectories(SeedRepoDir);
    ForceDirectories(RemoteBareDir);

    Mgr := NewGitManager();
    if not Mgr.Initialize then
    begin
      WriteLn('  [SKIP] libgit2 initialize failed');
      Inc(TestsPassed);
      Exit;
    end;

    SeedRepo := Mgr.InitRepository(SeedRepoDir, False);
    Check('Init seed repository succeeds', SeedRepo <> nil);
    if SeedRepo = nil then
      Exit;

    RemoteRepo := Mgr.InitRepository(RemoteBareDir, True);
    Check('Init bare remote repository succeeds', RemoteRepo <> nil);
    if RemoteRepo = nil then
      Exit;

    EnsureRepoUserConfig(SeedRepoDir);
    EnsureRepoRemoteConfig(SeedRepoDir, 'origin', RemoteBareDir);

    SL := TStringList.Create;
    try
      SL.Text := 'base';
      SL.SaveToFile(SeedRepoDir + PathDelim + 'base.txt');
    finally
      SL.Free;
    end;

    Check('Seed add all', Git.Add(SeedRepoDir, '.'));
    Check('Seed commit base', Git.Commit(SeedRepoDir, 'base commit'));

    Branch := Git.GetCurrentBranch(SeedRepoDir);
    Check('Seed branch not empty', Branch <> '');
    Check('Seed push base to origin', Git.Push(SeedRepoDir, 'origin', ''));

    OriginalPath := get_env('PATH');
    {$IFDEF MSWINDOWS}
    NoGitPath := 'C:\\__fpdev_no_git__';
    {$ELSE}
    NoGitPath := '/__fpdev_no_git__';
    {$ENDIF}

    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Clone from bare remote (no CLI)', Git.Clone(RemoteBareDir, CloneDir, Branch));
    finally
      set_env('PATH', OriginalPath);
    end;

    EnsureRepoUserConfig(CloneDir);

    SL := TStringList.Create;
    try
      SL.Text := 'remote';
      SL.SaveToFile(CloneDir + PathDelim + 'remote.txt');
    finally
      SL.Free;
    end;

    Check('Clone add all', Git.Add(CloneDir, '.'));
    Check('Clone commit remote', Git.Commit(CloneDir, 'remote commit'));

    OriginalPath := get_env('PATH');
    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Push remote commit (no CLI)', Git.Push(CloneDir, 'origin', ''));
    finally
      set_env('PATH', OriginalPath);
    end;

    SeedRepo := Mgr.OpenRepository(SeedRepoDir);
    Check('Open seed repository', SeedRepo <> nil);
    Check('Seed supports IGitRepositoryExt', Supports(SeedRepo, IGitRepositoryExt, Ext));
    if (SeedRepo = nil) or (not Supports(SeedRepo, IGitRepositoryExt, Ext)) then
      Exit;

    PullErr := '';
    OriginalPath := get_env('PATH');
    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      PullRes := Ext.PullFastForward('origin', PullErr);
    finally
      set_env('PATH', OriginalPath);
    end;

    Check('PullFastForward fast-forwarded', PullRes = gpffFastForwarded);
    RemoteTxt := SeedRepoDir + PathDelim + 'remote.txt';
    Check('Seed has remote.txt after PullFastForward', FileExists(RemoteTxt));

    if FileExists(RemoteTxt) then
    begin
      SL := TStringList.Create;
      try
        SL.LoadFromFile(RemoteTxt);
        Check('Seed remote.txt content ok', Trim(SL.Text) = 'remote');
      finally
        SL.Free;
      end;
    end;

    Check('Seed clean after PullFastForward', SeedRepo.IsClean);
  finally
    Git.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestPullMergeNoCLI;
var
  Git: TGitOperations;
  TempRoot: string;
  SeedRepoDir: string;
  RemoteBareDir: string;
  CloneDir: string;
  Mgr: IGitManager;
  SeedRepo: IGitRepository;
  RemoteRepo: IGitRepository;
  SL: TStringList;
  Branch: string;
  OriginalPath: string;
  NoGitPath: string;
  RemoteTxt: string;
  LocalTxt: string;
  PullOk: Boolean;
begin
  WriteLn('');
  WriteLn('=== Test 11: Pull merge without CLI (libgit2) ===');

  Git := TGitOperations.Create;
  TempRoot := '';
  try
    if Git.Backend <> gbLibgit2 then
    begin
      WriteLn('  [SKIP] libgit2 backend not available');
      Inc(TestsPassed);
      Exit;
    end;

    TempRoot := CreateUniqueTempDir('test_gitops_pull_merge_nocli');
    SeedRepoDir := TempRoot + PathDelim + 'seed';
    RemoteBareDir := TempRoot + PathDelim + 'remote.git';
    CloneDir := TempRoot + PathDelim + 'clone';
    ForceDirectories(SeedRepoDir);
    ForceDirectories(RemoteBareDir);

    Mgr := NewGitManager();
    if not Mgr.Initialize then
    begin
      WriteLn('  [SKIP] libgit2 initialize failed');
      Inc(TestsPassed);
      Exit;
    end;

    SeedRepo := Mgr.InitRepository(SeedRepoDir, False);
    Check('Init seed repository succeeds', SeedRepo <> nil);
    if SeedRepo = nil then
      Exit;

    RemoteRepo := Mgr.InitRepository(RemoteBareDir, True);
    Check('Init bare remote repository succeeds', RemoteRepo <> nil);
    if RemoteRepo = nil then
      Exit;

    EnsureRepoUserConfig(SeedRepoDir);
    EnsureRepoRemoteConfig(SeedRepoDir, 'origin', RemoteBareDir);

    SL := TStringList.Create;
    try
      SL.Text := 'base';
      SL.SaveToFile(SeedRepoDir + PathDelim + 'base.txt');
    finally
      SL.Free;
    end;

    Check('Seed add all', Git.Add(SeedRepoDir, '.'));
    Check('Seed commit base', Git.Commit(SeedRepoDir, 'base commit'));

    Branch := Git.GetCurrentBranch(SeedRepoDir);
    Check('Seed branch not empty', Branch <> '');
    Check('Seed push base to origin', Git.Push(SeedRepoDir, 'origin', ''));

    OriginalPath := get_env('PATH');
    {$IFDEF MSWINDOWS}
    NoGitPath := 'C:\\__fpdev_no_git__';
    {$ELSE}
    NoGitPath := '/__fpdev_no_git__';
    {$ENDIF}

    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Clone from bare remote (no CLI)', Git.Clone(RemoteBareDir, CloneDir, Branch));
    finally
      set_env('PATH', OriginalPath);
    end;

    EnsureRepoUserConfig(CloneDir);

    SL := TStringList.Create;
    try
      SL.Text := 'remote';
      SL.SaveToFile(CloneDir + PathDelim + 'remote.txt');
    finally
      SL.Free;
    end;

    Check('Clone add all', Git.Add(CloneDir, '.'));
    Check('Clone commit remote', Git.Commit(CloneDir, 'remote commit'));

    OriginalPath := get_env('PATH');
    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Push remote commit (no CLI)', Git.Push(CloneDir, 'origin', ''));
    finally
      set_env('PATH', OriginalPath);
    end;

    SL := TStringList.Create;
    try
      SL.Text := 'local';
      SL.SaveToFile(SeedRepoDir + PathDelim + 'local.txt');
    finally
      SL.Free;
    end;

    Check('Seed add all (local)', Git.Add(SeedRepoDir, '.'));
    Check('Seed commit local', Git.Commit(SeedRepoDir, 'local commit'));

    OriginalPath := get_env('PATH');
    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      PullOk := Git.Pull(SeedRepoDir);
      if not PullOk then
        WriteLn('  Pull error: ', Git.LastError);
      Check('Pull merge (no CLI)', PullOk);
    finally
      set_env('PATH', OriginalPath);
    end;

    RemoteTxt := SeedRepoDir + PathDelim + 'remote.txt';
    LocalTxt := SeedRepoDir + PathDelim + 'local.txt';

    SL := TStringList.Create;
    try
      if FileExists(RemoteTxt) then
      begin
        SL.LoadFromFile(RemoteTxt);
        Check('Seed has remote.txt', Trim(SL.Text) = 'remote');
      end
      else
        Check('Seed has remote.txt', False);

      if FileExists(LocalTxt) then
      begin
        SL.LoadFromFile(LocalTxt);
        Check('Seed has local.txt', Trim(SL.Text) = 'local');
      end
      else
        Check('Seed has local.txt', False);
    finally
      SL.Free;
    end;

    Check('Seed clean after merge pull', SeedRepo.IsClean);
  finally
    Git.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestForceCheckoutNoCLI;
var
  Git: TGitOperations;
  TempRoot: string;
  RepoDir: string;
  Mgr: IGitManager;
  Repo: IGitRepository;
  SL: TStringList;
  DefaultBranch: string;
  HeadHash: string;
  RepoHandle: git_repository;
  CommitHandle: git_commit;
  BranchRef: git_reference;
  Oid: git_oid;
  OriginalPath: string;
  NoGitPath: string;
  FilePath: string;
  OtherContent: string;
begin
  WriteLn('');
  WriteLn('=== Test 12: Force checkout without CLI (libgit2) ===');

  Git := TGitOperations.Create;
  TempRoot := '';
  try
    if Git.Backend <> gbLibgit2 then
    begin
      WriteLn('  [SKIP] libgit2 backend not available');
      Inc(TestsPassed);
      Exit;
    end;

    TempRoot := CreateUniqueTempDir('test_gitops_force_checkout_nocli');
    RepoDir := TempRoot + PathDelim + 'repo';
    ForceDirectories(RepoDir);

    Mgr := NewGitManager();
    if not Mgr.Initialize then
    begin
      WriteLn('  [SKIP] libgit2 initialize failed');
      Inc(TestsPassed);
      Exit;
    end;

    Repo := Mgr.InitRepository(RepoDir, False);
    Check('Init repository succeeds', Repo <> nil);
    if Repo = nil then
      Exit;

    EnsureRepoUserConfig(RepoDir);

    FilePath := RepoDir + PathDelim + 'file.txt';
    SL := TStringList.Create;
    try
      SL.Text := 'main';
      SL.SaveToFile(FilePath);
    finally
      SL.Free;
    end;

    Check('Add all', Git.Add(RepoDir, '.'));
    Check('Commit initial', Git.Commit(RepoDir, 'initial'));

    DefaultBranch := Git.GetCurrentBranch(RepoDir);
    Check('Default branch not empty', DefaultBranch <> '');

    HeadHash := Git.GetShortHeadHash(RepoDir, 40);
    Check('Full HEAD hash not empty', HeadHash <> '');

    RepoHandle := nil;
    CommitHandle := nil;
    BranchRef := nil;
    try
      Check('Open repo (raw)', git_repository_open(RepoHandle, PChar(RepoDir)) = GIT_OK);
      if RepoHandle = nil then
        Exit;

      FillChar(Oid, SizeOf(Oid), 0);
      Check('OID fromstr', git_oid_fromstr(Oid, PChar(HeadHash)) = GIT_OK);

      Check('Commit lookup', git_commit_lookup(CommitHandle, RepoHandle, @Oid) = GIT_OK);
      if CommitHandle = nil then
        Exit;

      Check('Create branch other', git_branch_create(BranchRef, RepoHandle, PChar('other'), CommitHandle, 0) = GIT_OK);
    finally
      if BranchRef <> nil then
        git_reference_free(BranchRef);
      if CommitHandle <> nil then
        git_object_free(git_object(CommitHandle));
      if RepoHandle <> nil then
        git_repository_free(RepoHandle);
    end;

    Check('Checkout other', Git.Checkout(RepoDir, 'other', False));
    OtherContent := 'other';

    SL := TStringList.Create;
    try
      SL.Text := OtherContent;
      SL.SaveToFile(FilePath);
    finally
      SL.Free;
    end;

    Check('Add all (other)', Git.Add(RepoDir, '.'));
    Check('Commit other', Git.Commit(RepoDir, 'other commit'));

    Check('Checkout back default', Git.Checkout(RepoDir, DefaultBranch, False));

    SL := TStringList.Create;
    try
      SL.Text := 'local-change';
      SL.SaveToFile(FilePath);
    finally
      SL.Free;
    end;

    OriginalPath := get_env('PATH');
    {$IFDEF MSWINDOWS}
    NoGitPath := 'C:\\__fpdev_no_git__';
    {$ELSE}
    NoGitPath := '/__fpdev_no_git__';
    {$ENDIF}

    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      SL := TStringList.Create;
      try
        SL.LoadFromFile(FilePath);
        Check('File has local changes before force checkout', Trim(SL.Text) = 'local-change');
      finally
        SL.Free;
      end;

      Check('Force checkout succeeds (no CLI)', Git.Checkout(RepoDir, 'other', True));
    finally
      set_env('PATH', OriginalPath);
    end;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(FilePath);
      Check('File matches other branch', Trim(SL.Text) = OtherContent);
    finally
      SL.Free;
    end;

    Check('Checkout back default (again)', Git.Checkout(RepoDir, DefaultBranch, False));

    SL := TStringList.Create;
    try
      SL.Text := 'local-change-2';
      SL.SaveToFile(FilePath);
    finally
      SL.Free;
    end;

    OriginalPath := get_env('PATH');
    Check('Hide git from PATH', set_env('PATH', NoGitPath));
    try
      Check('Force checkout via CheckoutBranchEx (no CLI)', Repo.CheckoutBranchEx('other', True));
    finally
      set_env('PATH', OriginalPath);
    end;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(FilePath);
      Check('File matches other branch (CheckoutBranchEx)', Trim(SL.Text) = OtherContent);
    finally
      SL.Free;
    end;
  finally
    Git.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestMultipleInstances;
var
  Git1, Git2: TGitOperations;
begin
  WriteLn('');
  WriteLn('=== Test 13: Multiple Instances ===');

  Git1 := TGitOperations.Create;
  try
    Git2 := TGitOperations.Create;
    try
      Check('Two instances can coexist', Assigned(Git1) and Assigned(Git2));
      Check('Both have same backend', Git1.Backend = Git2.Backend);

      // Verify independent verbose settings
      Git1.Verbose := True;
      Git2.Verbose := False;
      Check('Instances have independent Verbose', Git1.Verbose <> Git2.Verbose);
    finally
      Git2.Free;
    end;
  finally
    Git1.Free;
  end;
end;

procedure TestGitBackendToString;
begin
  WriteLn('');
  WriteLn('=== Test 14: GitBackendToString ===');

  Check('gbLibgit2 -> libgit2', GitBackendToString(gbLibgit2) = 'libgit2');
  Check('gbCommandLine -> git (command-line)', GitBackendToString(gbCommandLine) = 'git (command-line)');
  Check('gbNone -> none', GitBackendToString(gbNone) = 'none');
end;

begin
  WriteLn('========================================');
  WriteLn('  TGitOperations Unit Tests');
  WriteLn('========================================');

  TestCreateDestroy;
  TestBackendDetection;
  TestIsRepository;
  TestGetCurrentBranch;
  TestVerboseProperty;
  TestCommitLocalRepo;
  TestPushLocalBareRemote;
  TestAddPathspecDirAndGlob;
  TestRemoteOpsNoCLI;
  TestPullFastForwardExtNoCLI;
  TestPullMergeNoCLI;
  TestForceCheckoutNoCLI;
  TestMultipleInstances;
  TestGitBackendToString;

  WriteLn('');
  WriteLn('========================================');
  WriteLn(Format('  Results: %d passed, %d failed', [TestsPassed, TestsFailed]));
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
