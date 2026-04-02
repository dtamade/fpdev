program test_git2_adapter;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.git2, fpdev.utils.process, libgit2,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure WriteTextFile(const APath, AText: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

function ReadTrimmedTextFile(const APath: string): string;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(APath);
    Result := Trim(Lines.Text);
  finally
    Lines.Free;
  end;
end;

function RunCommandInDir(const AProgram: string; const AArgs: array of string;
  const AWorkDir: string): Boolean;
var
  ProcResult: TProcessResult;
begin
  ProcResult := TProcessExecutor.Execute(AProgram, AArgs, AWorkDir);
  Result := ProcResult.Success and (ProcResult.ExitCode = 0);
  if not Result then
  begin
    WriteLn('  [CMD FAIL] ', AProgram, ' in ', AWorkDir);
    if ProcResult.StdOut <> '' then
      WriteLn('  stdout: ', ProcResult.StdOut);
    if ProcResult.StdErr <> '' then
      WriteLn('  stderr: ', ProcResult.StdErr);
    if ProcResult.ErrorMessage <> '' then
      WriteLn('  error: ', ProcResult.ErrorMessage);
  end;
end;

function NewTempRepoDir(const Prefix: string): string;
var
  Base: string;
begin
  Base := CreateUniqueTempDir(Prefix);
  Result := Base + PathDelim + 'repo';
  ForceDirectories(Result);
end;

procedure TestAdapterHealth(const Adapter: TGit2Manager);
var
  RepoDir: string;
  Repo: git_repository;
begin
  RepoDir := NewTempRepoDir('adapter_repo');
  try
    if git_repository_init(Repo, PChar(RepoDir), 0) <> GIT_OK then
    begin
      Check('git2 adapter initializes empty repo', False,
        'Expected git_repository_init to succeed for ' + RepoDir);
      Exit;
    end;
    git_repository_free(Repo);

    Check('git2 adapter detects repository',
      Adapter.IsRepository(RepoDir),
      'Expected IsRepository to return true for ' + RepoDir);

    Repo := Adapter.OpenRepository(RepoDir);
    Check('git2 adapter opens repository',
      Repo <> nil,
      'Expected OpenRepository to return a repository handle');
    if Repo <> nil then
      git_repository_free(Repo);
  finally
    CleanupTempDir(ExtractFileDir(RepoDir));
  end;
end;

procedure TestUpdateRepositoryMaterializesRemoteCommit(const Adapter: TGit2Manager);
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
begin
  RootDir := CreateUniqueTempDir('git2_adapter_update');
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    Check('git2 adapter update setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);
    Check('git2 adapter update setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git2 adapter update setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git2 adapter update setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'v1');
    Check('git2 adapter update setup stages seed file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt to succeed');
    Check('git2 adapter update setup commits seed file',
      RunCommandInDir('git', ['commit', '-m', 'seed'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git2 adapter update setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git2 adapter update setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git2 adapter update setup pushes seed branch',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');
    Check('git2 adapter update setup clones local repo',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, LocalDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalDir);

    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'v2');
    Check('git2 adapter update setup stages remote update',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt for remote update to succeed');
    Check('git2 adapter update setup commits remote update',
      RunCommandInDir('git', ['commit', '-m', 'remote update'], WorkDir),
      'Expected remote update commit to succeed');
    Check('git2 adapter update setup pushes remote update',
      RunCommandInDir('git', ['push', 'origin', 'main'], WorkDir),
      'Expected git push origin main to succeed');

    Check('git2 adapter update returns success',
      Adapter.UpdateRepository(LocalDir),
      'Expected UpdateRepository to succeed on a clean fast-forwardable repo');
    Check('git2 adapter update materializes remote content',
      ReadTrimmedTextFile(VersionPath) = 'v2',
      'Expected version.txt to contain v2 after UpdateRepository');
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCloneRepositoryMaterializesRequestedRemoteBranch(const Adapter: TGit2Manager);
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
begin
  RootDir := CreateUniqueTempDir('git2_adapter_clone_branch');
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    Check('git2 adapter clone setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);
    Check('git2 adapter clone setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git2 adapter clone setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git2 adapter clone setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main');
    Check('git2 adapter clone setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt to succeed');
    Check('git2 adapter clone setup commits main file',
      RunCommandInDir('git', ['commit', '-m', 'main'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git2 adapter clone setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git2 adapter clone setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git2 adapter clone setup pushes main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');

    Check('git2 adapter clone setup creates release branch',
      RunCommandInDir('git', ['checkout', '-b', 'release'], WorkDir),
      'Expected git checkout -b release to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'release');
    Check('git2 adapter clone setup stages release file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt on release branch to succeed');
    Check('git2 adapter clone setup commits release file',
      RunCommandInDir('git', ['commit', '-m', 'release'], WorkDir),
      'Expected release commit to succeed');
    Check('git2 adapter clone setup pushes release',
      RunCommandInDir('git', ['push', '-u', 'origin', 'release'], WorkDir),
      'Expected git push -u origin release to succeed');

    Check('git2 adapter clone requested branch returns success',
      Adapter.CloneRepository(OriginDir, LocalDir, 'release'),
      'Expected CloneRepository(origin, local, release) to succeed');
    Check('git2 adapter clone requested branch materializes release content',
      ReadTrimmedTextFile(VersionPath) = 'release',
      'Expected version.txt to contain release after cloning requested branch');
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCloneRepositoryMaterializesRequestedTag(const Adapter: TGit2Manager);
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
begin
  RootDir := CreateUniqueTempDir('git2_adapter_clone_tag');
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    Check('git2 adapter tag setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);
    Check('git2 adapter tag setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git2 adapter tag setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git2 adapter tag setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main');
    Check('git2 adapter tag setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt to succeed');
    Check('git2 adapter tag setup commits main file',
      RunCommandInDir('git', ['commit', '-m', 'main'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git2 adapter tag setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git2 adapter tag setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git2 adapter tag setup pushes main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');

    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'tagged');
    Check('git2 adapter tag setup stages tagged file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt for tagged commit to succeed');
    Check('git2 adapter tag setup commits tagged file',
      RunCommandInDir('git', ['commit', '-m', 'tagged'], WorkDir),
      'Expected tagged commit to succeed');
    Check('git2 adapter tag setup creates tag',
      RunCommandInDir('git', ['tag', 'v1.0.0'], WorkDir),
      'Expected git tag v1.0.0 to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main-after-tag');
    Check('git2 adapter tag setup stages post-tag main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt after tagging to succeed');
    Check('git2 adapter tag setup commits post-tag main file',
      RunCommandInDir('git', ['commit', '-m', 'main-after-tag'], WorkDir),
      'Expected post-tag main commit to succeed');
    Check('git2 adapter tag setup pushes tag',
      RunCommandInDir('git', ['push', 'origin', 'main', '--tags'], WorkDir),
      'Expected git push origin main --tags to succeed');

    Check('git2 adapter clone requested tag returns success',
      Adapter.CloneRepository(OriginDir, LocalDir, 'v1.0.0'),
      'Expected CloneRepository(origin, local, v1.0.0) to succeed');
    Check('git2 adapter clone requested tag materializes tagged content',
      ReadTrimmedTextFile(VersionPath) = 'tagged',
      'Expected version.txt to contain tagged after cloning requested tag');
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCheckoutBranchMaterializesRequestedRemoteBranch(const Adapter: TGit2Manager);
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
  Repo: git_repository;
  CurrentBranch: string;
begin
  RootDir := CreateUniqueTempDir('git2_adapter_checkout_branch');
  Repo := nil;
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    Check('git2 adapter direct branch setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);
    Check('git2 adapter direct branch setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git2 adapter direct branch setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git2 adapter direct branch setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main');
    Check('git2 adapter direct branch setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt to succeed');
    Check('git2 adapter direct branch setup commits main file',
      RunCommandInDir('git', ['commit', '-m', 'main'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git2 adapter direct branch setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git2 adapter direct branch setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git2 adapter direct branch setup pushes main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');

    Check('git2 adapter direct branch setup creates release branch',
      RunCommandInDir('git', ['checkout', '-b', 'release'], WorkDir),
      'Expected git checkout -b release to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'release');
    Check('git2 adapter direct branch setup stages release file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt on release branch to succeed');
    Check('git2 adapter direct branch setup commits release file',
      RunCommandInDir('git', ['commit', '-m', 'release'], WorkDir),
      'Expected release commit to succeed');
    Check('git2 adapter direct branch setup pushes release',
      RunCommandInDir('git', ['push', '-u', 'origin', 'release'], WorkDir),
      'Expected git push -u origin release to succeed');

    Check('git2 adapter direct branch setup clones local repo',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, LocalDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalDir);

    Repo := Adapter.OpenRepository(LocalDir);
    Check('git2 adapter direct branch opens cloned repo',
      Repo <> nil,
      'Expected OpenRepository to return a repository handle for direct branch checkout');
    if Repo <> nil then
    begin
      Check('git2 adapter direct branch returns success',
        Adapter.CheckoutBranch(Repo, 'release'),
        'Expected CheckoutBranch(repo, release) to succeed');
      CurrentBranch := Adapter.GetCurrentBranch(Repo);
      Check('git2 adapter direct branch switches to requested branch',
        SameText(CurrentBranch, 'release'),
        'Expected current branch to be "release", got "' + CurrentBranch + '"');
      Check('git2 adapter direct branch materializes release content',
        ReadTrimmedTextFile(VersionPath) = 'release',
        'Expected version.txt to contain release after direct branch checkout');
    end;
  finally
    if Repo <> nil then
      git_repository_free(Repo);
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCheckoutBranchMaterializesRequestedTag(const Adapter: TGit2Manager);
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
  Repo: git_repository;
begin
  RootDir := CreateUniqueTempDir('git2_adapter_checkout_tag');
  Repo := nil;
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    Check('git2 adapter direct tag setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);
    Check('git2 adapter direct tag setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git2 adapter direct tag setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git2 adapter direct tag setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main');
    Check('git2 adapter direct tag setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt to succeed');
    Check('git2 adapter direct tag setup commits main file',
      RunCommandInDir('git', ['commit', '-m', 'main'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git2 adapter direct tag setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git2 adapter direct tag setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git2 adapter direct tag setup pushes main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');

    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'tagged');
    Check('git2 adapter direct tag setup stages tagged file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt for tagged commit to succeed');
    Check('git2 adapter direct tag setup commits tagged file',
      RunCommandInDir('git', ['commit', '-m', 'tagged'], WorkDir),
      'Expected tagged commit to succeed');
    Check('git2 adapter direct tag setup creates tag',
      RunCommandInDir('git', ['tag', 'v1.0.0'], WorkDir),
      'Expected git tag v1.0.0 to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main-after-tag');
    Check('git2 adapter direct tag setup stages post-tag main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt after tagging to succeed');
    Check('git2 adapter direct tag setup commits post-tag main file',
      RunCommandInDir('git', ['commit', '-m', 'main-after-tag'], WorkDir),
      'Expected post-tag main commit to succeed');
    Check('git2 adapter direct tag setup pushes tag',
      RunCommandInDir('git', ['push', 'origin', 'main', '--tags'], WorkDir),
      'Expected git push origin main --tags to succeed');

    Check('git2 adapter direct tag setup clones local repo',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, LocalDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalDir);
    Check('git2 adapter direct tag setup clone starts from main content',
      ReadTrimmedTextFile(VersionPath) = 'main-after-tag',
      'Expected version.txt to contain main-after-tag before direct tag checkout');

    Repo := Adapter.OpenRepository(LocalDir);
    Check('git2 adapter direct tag opens cloned repo',
      Repo <> nil,
      'Expected OpenRepository to return a repository handle for direct tag checkout');
    if Repo <> nil then
    begin
      Check('git2 adapter direct tag returns success',
        Adapter.CheckoutBranch(Repo, 'v1.0.0'),
        'Expected CheckoutBranch(repo, v1.0.0) to succeed');
      Check('git2 adapter direct tag materializes tagged content',
        ReadTrimmedTextFile(VersionPath) = 'tagged',
        'Expected version.txt to contain tagged after direct tag checkout');
    end;
  finally
    if Repo <> nil then
      git_repository_free(Repo);
    CleanupTempDir(RootDir);
  end;
end;

var
  Adapter: TGit2Manager;
begin
  Adapter := TGit2Manager.Create;
  try
    Check('git2 adapter initializes libgit2',
      Adapter.Initialize,
      'Expected Adapter.Initialize to succeed');
    if PassCount = 1 then
    begin
      TestAdapterHealth(Adapter);
      TestUpdateRepositoryMaterializesRemoteCommit(Adapter);
      TestCloneRepositoryMaterializesRequestedRemoteBranch(Adapter);
      TestCloneRepositoryMaterializesRequestedTag(Adapter);
      TestCheckoutBranchMaterializesRequestedRemoteBranch(Adapter);
      TestCheckoutBranchMaterializesRequestedTag(Adapter);
    end;

    WriteLn;
    WriteLn('Passed: ', PassCount);
    WriteLn('Failed: ', FailCount);
    if FailCount > 0 then
      Halt(1);
  finally
    Adapter.Free;
  end;
end.
