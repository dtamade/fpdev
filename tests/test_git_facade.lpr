program test_git_facade;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.git, fpdev.utils.process,
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

function StringArrayContains(const AValues: TStringArray; const AExpected: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(AValues) do
    if SameText(AValues[i], AExpected) then
      Exit(True);
end;

procedure TestCloneRepositoryRespectsRequestedBranchForExistingRepo;
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
  Facade: TGitManager;
  Lines: TStringList;
  CurrentBranch: string;
begin
  RootDir := CreateUniqueTempDir('test_git_facade_branch');
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    Check('git facade setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);

    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main');
    Check('git facade setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git facade setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git facade setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    Check('git facade setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt to succeed');
    Check('git facade setup commits main branch',
      RunCommandInDir('git', ['commit', '-m', 'main branch'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git facade setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git facade setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git facade setup pushes main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');

    Check('git facade setup creates release branch',
      RunCommandInDir('git', ['checkout', '-b', 'release'], WorkDir),
      'Expected git checkout -b release to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'release');
    Check('git facade setup stages release file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt on release branch to succeed');
    Check('git facade setup commits release branch',
      RunCommandInDir('git', ['commit', '-m', 'release branch'], WorkDir),
      'Expected release git commit to succeed');
    Check('git facade setup pushes release branch',
      RunCommandInDir('git', ['push', '-u', 'origin', 'release'], WorkDir),
      'Expected git push -u origin release to succeed');

    Check('git facade setup clones local repo on main',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, LocalDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalDir);

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(VersionPath);
      Check('git facade setup local repo starts on main content',
        Trim(Lines.Text) = 'main',
        'Expected existing local repo to start with main content');
    finally
      Lines.Free;
    end;

    Facade := TGitManager.Create;
    try
      Check('git facade clone existing repo returns success',
        Facade.CloneRepository(OriginDir, LocalDir, 'release'),
        'Expected CloneRepository(existing repo, release) to succeed');
      CurrentBranch := Facade.GetCurrentBranch(LocalDir);
      Check('git facade clone existing repo switches to requested branch',
        SameText(CurrentBranch, 'release'),
        'Expected current branch to be "release", got "' + CurrentBranch + '"');
    finally
      Facade.Free;
    end;

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(VersionPath);
      Check('git facade clone existing repo materializes requested branch content',
        Trim(Lines.Text) = 'release',
        'Expected version.txt to contain release content after requested branch checkout');
    finally
      Lines.Free;
    end;
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCloneRepositoryRespectsRequestedBranchFromDetachedHead;
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
  Facade: TGitManager;
  Lines: TStringList;
begin
  RootDir := CreateUniqueTempDir('test_git_facade_detached');
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    Check('git facade detached setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);

    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main');
    Check('git facade detached setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git facade detached setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git facade detached setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    Check('git facade detached setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt to succeed');
    Check('git facade detached setup commits main branch',
      RunCommandInDir('git', ['commit', '-m', 'main branch'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git facade detached setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git facade detached setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git facade detached setup pushes main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');

    Check('git facade detached setup creates release branch',
      RunCommandInDir('git', ['checkout', '-b', 'release'], WorkDir),
      'Expected git checkout -b release to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'release');
    Check('git facade detached setup stages release file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt on release branch to succeed');
    Check('git facade detached setup commits release branch',
      RunCommandInDir('git', ['commit', '-m', 'release branch'], WorkDir),
      'Expected release git commit to succeed');
    Check('git facade detached setup pushes release branch',
      RunCommandInDir('git', ['push', '-u', 'origin', 'release'], WorkDir),
      'Expected git push -u origin release to succeed');

    Check('git facade detached setup clones local repo on main',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, LocalDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalDir);
    Check('git facade detached setup detaches local HEAD',
      RunCommandInDir('git', ['checkout', '--detach', 'HEAD'], LocalDir),
      'Expected git checkout --detach HEAD to succeed');

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(VersionPath);
      Check('git facade detached setup local repo still has main content',
        Trim(Lines.Text) = 'main',
        'Expected detached local repo to still have main content before requested checkout');
    finally
      Lines.Free;
    end;

    Facade := TGitManager.Create;
    try
      Check('git facade detached clone existing repo returns success',
        Facade.CloneRepository(OriginDir, LocalDir, 'release'),
        'Expected CloneRepository(existing detached repo, release) to succeed');
    finally
      Facade.Free;
    end;

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(VersionPath);
      Check('git facade detached clone materializes requested branch content',
        Trim(Lines.Text) = 'release',
        'Expected version.txt to contain release content after detached-head checkout');
    finally
      Lines.Free;
    end;
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCloneRepositoryRejectsExistingRepoWithDifferentOrigin;
var
  RootDir: string;
  OriginADir: string;
  OriginBDir: string;
  WorkADir: string;
  WorkBDir: string;
  LocalDir: string;
  VersionPath: string;
  Facade: TGitManager;
  Lines: TStringList;
begin
  RootDir := CreateUniqueTempDir('test_git_facade_origin_mismatch');
  try
    OriginADir := RootDir + PathDelim + 'origin-a.git';
    OriginBDir := RootDir + PathDelim + 'origin-b.git';
    WorkADir := RootDir + PathDelim + 'work-a';
    WorkBDir := RootDir + PathDelim + 'work-b';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkADir);
    ForceDirectories(WorkBDir);

    Check('git facade mismatch setup creates bare origin A',
      RunCommandInDir('git', ['init', '--bare', OriginADir], RootDir),
      'Expected git init --bare to succeed for ' + OriginADir);
    Check('git facade mismatch setup creates bare origin B',
      RunCommandInDir('git', ['init', '--bare', OriginBDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginBDir);

    WriteTextFile(WorkADir + PathDelim + 'version.txt', 'main-a');
    Check('git facade mismatch setup initializes work repo A',
      RunCommandInDir('git', ['init'], WorkADir),
      'Expected git init to succeed in ' + WorkADir);
    Check('git facade mismatch setup configures work repo A email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkADir),
      'Expected git config user.email to succeed');
    Check('git facade mismatch setup configures work repo A user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkADir),
      'Expected git config user.name to succeed');
    Check('git facade mismatch setup stages main file A',
      RunCommandInDir('git', ['add', 'version.txt'], WorkADir),
      'Expected git add version.txt to succeed');
    Check('git facade mismatch setup commits main branch A',
      RunCommandInDir('git', ['commit', '-m', 'main branch A'], WorkADir),
      'Expected initial git commit to succeed');
    Check('git facade mismatch setup renames branch A to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkADir),
      'Expected git branch -M main to succeed');
    Check('git facade mismatch setup adds origin A',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginADir], WorkADir),
      'Expected git remote add origin to succeed');
    Check('git facade mismatch setup pushes main to origin A',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkADir),
      'Expected git push -u origin main to succeed');
    Check('git facade mismatch setup creates release branch A',
      RunCommandInDir('git', ['checkout', '-b', 'release'], WorkADir),
      'Expected git checkout -b release to succeed');
    WriteTextFile(WorkADir + PathDelim + 'version.txt', 'release-a');
    Check('git facade mismatch setup stages release file A',
      RunCommandInDir('git', ['add', 'version.txt'], WorkADir),
      'Expected git add version.txt on release branch A to succeed');
    Check('git facade mismatch setup commits release branch A',
      RunCommandInDir('git', ['commit', '-m', 'release branch A'], WorkADir),
      'Expected release git commit to succeed');
    Check('git facade mismatch setup pushes release branch A',
      RunCommandInDir('git', ['push', '-u', 'origin', 'release'], WorkADir),
      'Expected git push -u origin release to succeed');

    WriteTextFile(WorkBDir + PathDelim + 'version.txt', 'main-b');
    Check('git facade mismatch setup initializes work repo B',
      RunCommandInDir('git', ['init'], WorkBDir),
      'Expected git init to succeed in ' + WorkBDir);
    Check('git facade mismatch setup configures work repo B email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkBDir),
      'Expected git config user.email to succeed');
    Check('git facade mismatch setup configures work repo B user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkBDir),
      'Expected git config user.name to succeed');
    Check('git facade mismatch setup stages main file B',
      RunCommandInDir('git', ['add', 'version.txt'], WorkBDir),
      'Expected git add version.txt to succeed');
    Check('git facade mismatch setup commits main branch B',
      RunCommandInDir('git', ['commit', '-m', 'main branch B'], WorkBDir),
      'Expected initial git commit to succeed');
    Check('git facade mismatch setup renames branch B to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkBDir),
      'Expected git branch -M main to succeed');
    Check('git facade mismatch setup adds origin B',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginBDir], WorkBDir),
      'Expected git remote add origin to succeed');
    Check('git facade mismatch setup pushes main to origin B',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkBDir),
      'Expected git push -u origin main to succeed');
    Check('git facade mismatch setup creates release branch B',
      RunCommandInDir('git', ['checkout', '-b', 'release'], WorkBDir),
      'Expected git checkout -b release to succeed');
    WriteTextFile(WorkBDir + PathDelim + 'version.txt', 'release-b');
    Check('git facade mismatch setup stages release file B',
      RunCommandInDir('git', ['add', 'version.txt'], WorkBDir),
      'Expected git add version.txt on release branch B to succeed');
    Check('git facade mismatch setup commits release branch B',
      RunCommandInDir('git', ['commit', '-m', 'release branch B'], WorkBDir),
      'Expected release git commit to succeed');
    Check('git facade mismatch setup pushes release branch B',
      RunCommandInDir('git', ['push', '-u', 'origin', 'release'], WorkBDir),
      'Expected git push -u origin release to succeed');

    Check('git facade mismatch setup clones local repo from origin A on main',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginADir, LocalDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalDir);

    Facade := TGitManager.Create;
    try
      Check('git facade mismatch rejects different origin reuse',
        not Facade.CloneRepository(OriginBDir, LocalDir, 'release'),
        'Expected CloneRepository(existing repo with different origin) to fail');
    finally
      Facade.Free;
    end;

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(VersionPath);
      Check('git facade mismatch keeps original local content unchanged',
        Trim(Lines.Text) = 'main-a',
        'Expected version.txt to remain on original origin content after mismatch rejection');
    finally
      Lines.Free;
    end;
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCloneRepositoryRejectsExistingRepoWithoutOrigin;
var
  RootDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
  Facade: TGitManager;
  Lines: TStringList;
begin
  RootDir := CreateUniqueTempDir('test_git_facade_missing_origin');
  try
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main-local');
    Check('git facade no-origin setup initializes local repo',
      RunCommandInDir('git', ['init', LocalDir], RootDir),
      'Expected git init to succeed in ' + LocalDir);
    Check('git facade no-origin setup configures local repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], LocalDir),
      'Expected git config user.email to succeed');
    Check('git facade no-origin setup configures local repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], LocalDir),
      'Expected git config user.name to succeed');
    WriteTextFile(VersionPath, 'main-local');
    Check('git facade no-origin setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], LocalDir),
      'Expected git add version.txt to succeed');
    Check('git facade no-origin setup commits main branch',
      RunCommandInDir('git', ['commit', '-m', 'main local branch'], LocalDir),
      'Expected initial git commit to succeed');
    Check('git facade no-origin setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], LocalDir),
      'Expected git branch -M main to succeed');
    Check('git facade no-origin setup creates local release branch',
      RunCommandInDir('git', ['checkout', '-b', 'release'], LocalDir),
      'Expected git checkout -b release to succeed');
    WriteTextFile(VersionPath, 'release-local');
    Check('git facade no-origin setup stages release file',
      RunCommandInDir('git', ['add', 'version.txt'], LocalDir),
      'Expected git add version.txt on release branch to succeed');
    Check('git facade no-origin setup commits release branch',
      RunCommandInDir('git', ['commit', '-m', 'release local branch'], LocalDir),
      'Expected release git commit to succeed');
    Check('git facade no-origin setup returns to main',
      RunCommandInDir('git', ['checkout', 'main'], LocalDir),
      'Expected git checkout main to succeed');

    Facade := TGitManager.Create;
    try
      Check('git facade no-origin rejects reuse for requested URL',
        not Facade.CloneRepository('https://example.invalid/repo.git', LocalDir, 'release'),
        'Expected CloneRepository(existing repo without origin) to fail');
    finally
      Facade.Free;
    end;

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(VersionPath);
      Check('git facade no-origin keeps local main content unchanged',
        Trim(Lines.Text) = 'main-local',
        'Expected version.txt to remain on local main content after no-origin rejection');
    finally
      Lines.Free;
    end;
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCloneRepositoryRejectsDivergedExistingRepoWithoutBranch;
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  Facade: TGitManager;
begin
  RootDir := CreateUniqueTempDir('test_git_facade_diverged_nobranch');
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';

    ForceDirectories(WorkDir);

    Check('git facade diverged setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);
    Check('git facade diverged setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git facade diverged setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git facade diverged setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    WriteTextFile(WorkDir + PathDelim + 'base.txt', 'base');
    Check('git facade diverged setup stages base file',
      RunCommandInDir('git', ['add', 'base.txt'], WorkDir),
      'Expected git add base.txt to succeed');
    Check('git facade diverged setup commits base branch',
      RunCommandInDir('git', ['commit', '-m', 'base branch'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git facade diverged setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git facade diverged setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git facade diverged setup pushes main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');

    Check('git facade diverged setup clones local repo on main',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, LocalDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalDir);
    Check('git facade diverged setup configures local repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], LocalDir),
      'Expected git config user.email to succeed');
    Check('git facade diverged setup configures local repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], LocalDir),
      'Expected git config user.name to succeed');

    WriteTextFile(WorkDir + PathDelim + 'remote.txt', 'remote');
    Check('git facade diverged setup stages remote file',
      RunCommandInDir('git', ['add', 'remote.txt'], WorkDir),
      'Expected git add remote.txt to succeed');
    Check('git facade diverged setup commits remote file',
      RunCommandInDir('git', ['commit', '-m', 'remote commit'], WorkDir),
      'Expected remote git commit to succeed');
    Check('git facade diverged setup pushes remote commit',
      RunCommandInDir('git', ['push', 'origin', 'main'], WorkDir),
      'Expected git push origin main to succeed');

    WriteTextFile(LocalDir + PathDelim + 'local.txt', 'local');
    Check('git facade diverged setup stages local file',
      RunCommandInDir('git', ['add', 'local.txt'], LocalDir),
      'Expected git add local.txt to succeed');
    Check('git facade diverged setup commits local file',
      RunCommandInDir('git', ['commit', '-m', 'local commit'], LocalDir),
      'Expected local git commit to succeed');

    Facade := TGitManager.Create;
    try
      Check('git facade diverged no-branch rejects merge-capable reuse',
        not Facade.CloneRepository(OriginDir, LocalDir),
        'Expected CloneRepository(existing diverged repo without branch) to fail');
    finally
      Facade.Free;
    end;

    Check('git facade diverged no-branch keeps local-only file',
      FileExists(LocalDir + PathDelim + 'local.txt'),
      'Expected local-only file to remain after ff-only rejection');
    Check('git facade diverged no-branch does not materialize remote-only file',
      not FileExists(LocalDir + PathDelim + 'remote.txt'),
      'Expected remote-only file to stay absent after ff-only rejection');
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestCloneRepositoryPrefersRequestedBranchOverSameNamedTag;
var
  RootDir: string;
  OriginDir: string;
  WorkDir: string;
  LocalDir: string;
  VersionPath: string;
  Facade: TGitManager;
  Lines: TStringList;
begin
  RootDir := CreateUniqueTempDir('test_git_facade_branch_vs_tag');
  try
    OriginDir := RootDir + PathDelim + 'origin.git';
    WorkDir := RootDir + PathDelim + 'work';
    LocalDir := RootDir + PathDelim + 'local';
    VersionPath := LocalDir + PathDelim + 'version.txt';

    ForceDirectories(WorkDir);

    Check('git facade branch-vs-tag setup creates bare origin',
      RunCommandInDir('git', ['init', '--bare', OriginDir], RootDir),
      'Expected git init --bare to succeed for ' + OriginDir);
    Check('git facade branch-vs-tag setup initializes work repo',
      RunCommandInDir('git', ['init'], WorkDir),
      'Expected git init to succeed in ' + WorkDir);
    Check('git facade branch-vs-tag setup configures work repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], WorkDir),
      'Expected git config user.email to succeed');
    Check('git facade branch-vs-tag setup configures work repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], WorkDir),
      'Expected git config user.name to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'main');
    Check('git facade branch-vs-tag setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt to succeed');
    Check('git facade branch-vs-tag setup commits main branch',
      RunCommandInDir('git', ['commit', '-m', 'main branch'], WorkDir),
      'Expected initial git commit to succeed');
    Check('git facade branch-vs-tag setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], WorkDir),
      'Expected git branch -M main to succeed');
    Check('git facade branch-vs-tag setup adds origin',
      RunCommandInDir('git', ['remote', 'add', 'origin', OriginDir], WorkDir),
      'Expected git remote add origin to succeed');
    Check('git facade branch-vs-tag setup pushes main',
      RunCommandInDir('git', ['push', '-u', 'origin', 'main'], WorkDir),
      'Expected git push -u origin main to succeed');
    Check('git facade branch-vs-tag setup creates same-named tag',
      RunCommandInDir('git', ['tag', 'release'], WorkDir),
      'Expected git tag release to succeed');
    Check('git facade branch-vs-tag setup creates release branch',
      RunCommandInDir('git', ['checkout', '-b', 'release'], WorkDir),
      'Expected git checkout -b release to succeed');
    WriteTextFile(WorkDir + PathDelim + 'version.txt', 'branch-release');
    Check('git facade branch-vs-tag setup stages release branch file',
      RunCommandInDir('git', ['add', 'version.txt'], WorkDir),
      'Expected git add version.txt on release branch to succeed');
    Check('git facade branch-vs-tag setup commits release branch',
      RunCommandInDir('git', ['commit', '-m', 'release branch'], WorkDir),
      'Expected release git commit to succeed');
    Check('git facade branch-vs-tag setup pushes release branch',
      RunCommandInDir('git', ['push', '-u', 'origin', 'refs/heads/release:refs/heads/release'], WorkDir),
      'Expected git push -u origin refs/heads/release:refs/heads/release to succeed');
    Check('git facade branch-vs-tag setup pushes same-named tag',
      RunCommandInDir('git', ['push', 'origin', 'refs/tags/release:refs/tags/release'], WorkDir),
      'Expected git push origin refs/tags/release:refs/tags/release to succeed');

    Check('git facade branch-vs-tag setup clones local repo on main',
      RunCommandInDir('git', ['clone', '-b', 'main', OriginDir, LocalDir], RootDir),
      'Expected git clone -b main to succeed into ' + LocalDir);

    Facade := TGitManager.Create;
    try
      Check('git facade branch-vs-tag prefers branch over tag',
        Facade.CloneRepository(OriginDir, LocalDir, 'release'),
        'Expected CloneRepository(existing repo, release) to succeed when branch and tag share the same name');
    finally
      Facade.Free;
    end;

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(VersionPath);
      Check('git facade branch-vs-tag materializes branch content',
        Trim(Lines.Text) = 'branch-release',
        'Expected version.txt to contain branch-release, proving branch checkout wins over same-named tag');
    finally
      Lines.Free;
    end;
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestListBranchesIncludesLocalBranchesWithoutRemote;
var
  RootDir: string;
  RepoDir: string;
  Facade: TGitManager;
  Branches: TStringArray;
begin
  RootDir := CreateUniqueTempDir('test_git_facade_list_branches_local');
  try
    RepoDir := RootDir + PathDelim + 'repo';
    ForceDirectories(RepoDir);

    Check('git facade list-branches setup initializes repo',
      RunCommandInDir('git', ['init'], RepoDir),
      'Expected git init to succeed in ' + RepoDir);
    Check('git facade list-branches setup configures repo email',
      RunCommandInDir('git', ['config', 'user.email', 'test@example.invalid'], RepoDir),
      'Expected git config user.email to succeed');
    Check('git facade list-branches setup configures repo user',
      RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], RepoDir),
      'Expected git config user.name to succeed');
    WriteTextFile(RepoDir + PathDelim + 'version.txt', 'main');
    Check('git facade list-branches setup stages main file',
      RunCommandInDir('git', ['add', 'version.txt'], RepoDir),
      'Expected git add version.txt to succeed');
    Check('git facade list-branches setup commits main branch',
      RunCommandInDir('git', ['commit', '-m', 'main branch'], RepoDir),
      'Expected initial git commit to succeed');
    Check('git facade list-branches setup renames branch to main',
      RunCommandInDir('git', ['branch', '-M', 'main'], RepoDir),
      'Expected git branch -M main to succeed');
    Check('git facade list-branches setup creates feature branch',
      RunCommandInDir('git', ['checkout', '-b', 'feature'], RepoDir),
      'Expected git checkout -b feature to succeed');

    Facade := TGitManager.Create;
    try
      Branches := Facade.ListBranches(RepoDir);
      Check('git facade list-branches includes main without remote',
        StringArrayContains(Branches, 'main'),
        'Expected ListBranches to include local branch "main" even without any remote');
      Check('git facade list-branches includes feature without remote',
        StringArrayContains(Branches, 'feature'),
        'Expected ListBranches to include local branch "feature" even without any remote');
    finally
      Facade.Free;
    end;
  finally
    CleanupTempDir(RootDir);
  end;
end;

begin
  TestCloneRepositoryRespectsRequestedBranchForExistingRepo;
  TestCloneRepositoryRespectsRequestedBranchFromDetachedHead;
  TestCloneRepositoryRejectsExistingRepoWithDifferentOrigin;
  TestCloneRepositoryRejectsExistingRepoWithoutOrigin;
  TestCloneRepositoryRejectsDivergedExistingRepoWithoutBranch;
  TestCloneRepositoryPrefersRequestedBranchOverSameNamedTag;
  TestListBranchesIncludesLocalBranchesWithoutRemote;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
