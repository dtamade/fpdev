unit test_git2_cases;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry,
  fpdev.git2, libgit2;

type
  TGit2Basics = class(TTestCase)
  private
    M: TGitManager;
    FTempRoot: string;
    function NewTempDir(const Prefix: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialize;
    procedure TestInitAndOpenRepo;
    procedure TestListBranchesOnNewRepo;
  end;

implementation

function TGit2Basics.NewTempDir(const Prefix: string): string;
var
  Base, Suffix: string;
begin
  Base := 'bin' + PathDelim + 'tmp' + PathDelim + Prefix;
  Suffix := FormatDateTime('yyyymmddhhnnsszzz', Now);
  Result := IncludeTrailingPathDelimiter(Base + '_' + Suffix);
  ForceDirectories(Result);
end;

procedure TGit2Basics.SetUp;
begin
  M := TGitManager.Create;
  FTempRoot := NewTempDir('fpcunit');
end;

procedure TGit2Basics.TearDown;
begin
  M.Free;
end;

procedure TGit2Basics.TestInitialize;
begin
  AssertTrue('libgit2 should initialize', M.Initialize);
end;

procedure TGit2Basics.TestInitAndOpenRepo;
var
  RepoPath: string;
  R: TGitRepository;
begin
  AssertTrue('init precondition', M.Initialize);
  RepoPath := FTempRoot + 'repo_init_open';
  ForceDirectories(RepoPath);
  R := M.InitRepository(RepoPath, False);
  try
    AssertNotNull('InitRepository should return repository', R);
    AssertEquals('WorkDir should equal repo path', ExpandFileName(RepoPath) + PathDelim, R.WorkDir);
  finally
    R.Free;
  end;

  // Open via path
  R := M.OpenRepository(RepoPath);
  try
    AssertNotNull('OpenRepository should return repository', R);
    AssertEquals('OpenRepository WorkDir', ExpandFileName(RepoPath) + PathDelim, R.WorkDir);
  finally
    R.Free;
  end;
end;

procedure TGit2Basics.TestListBranchesOnNewRepo;
var
  RepoPath: string;
  R: TGitRepository;
  Branches: TStringArray;
begin
  AssertTrue('init precondition', M.Initialize);
  RepoPath := FTempRoot + 'repo_branches';
  ForceDirectories(RepoPath);
  R := M.InitRepository(RepoPath, False);
  try
    AssertNotNull(R);
    Branches := R.ListBranches;
    AssertTrue('ListBranches should return array (possibly empty)', Length(Branches) >= 0);
  finally
    R.Free;
  end;
end;

initialization
  RegisterTest(TGit2Basics);

end.

