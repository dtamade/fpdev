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

procedure TestMultipleInstances;
var
  Git1, Git2: TGitOperations;
begin
  WriteLn('');
  WriteLn('=== Test 8: Multiple Instances ===');

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
  WriteLn('=== Test 9: GitBackendToString ===');

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
  TestMultipleInstances;
  TestGitBackendToString;

  WriteLn('');
  WriteLn('========================================');
  WriteLn(Format('  Results: %d passed, %d failed', [TestsPassed, TestsFailed]));
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
