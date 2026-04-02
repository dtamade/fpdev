program test_git_env_identity;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.utils,
  fpdev.utils.git;

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

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure TestAuthorEnvVisibleInSameProcess;
var
  SavedAuthorName: string;
  SavedAuthorEmail: string;
  SavedCommitterName: string;
  SavedCommitterEmail: string;
  AuthorName: string;
  AuthorEmail: string;
  CommitterName: string;
  CommitterEmail: string;
begin
  SavedAuthorName := get_env('GIT_AUTHOR_NAME');
  SavedAuthorEmail := get_env('GIT_AUTHOR_EMAIL');
  SavedCommitterName := get_env('GIT_COMMITTER_NAME');
  SavedCommitterEmail := get_env('GIT_COMMITTER_EMAIL');
  try
    Check('set GIT_AUTHOR_NAME',
      set_env('GIT_AUTHOR_NAME', 'Same Process Author'));
    Check('set GIT_AUTHOR_EMAIL',
      set_env('GIT_AUTHOR_EMAIL', 'author@example.invalid'));
    unset_env('GIT_COMMITTER_NAME');
    unset_env('GIT_COMMITTER_EMAIL');

    ResolveGitIdentityEnv(AuthorName, AuthorEmail, CommitterName, CommitterEmail);
    Check('same-process GIT_AUTHOR_NAME is visible',
      AuthorName = 'Same Process Author', 'got="' + AuthorName + '"');
    Check('same-process GIT_AUTHOR_EMAIL is visible',
      AuthorEmail = 'author@example.invalid', 'got="' + AuthorEmail + '"');
    Check('committer name falls back to author when unset',
      CommitterName = 'Same Process Author', 'got="' + CommitterName + '"');
    Check('committer email falls back to author when unset',
      CommitterEmail = 'author@example.invalid', 'got="' + CommitterEmail + '"');
  finally
    RestoreEnv('GIT_AUTHOR_NAME', SavedAuthorName);
    RestoreEnv('GIT_AUTHOR_EMAIL', SavedAuthorEmail);
    RestoreEnv('GIT_COMMITTER_NAME', SavedCommitterName);
    RestoreEnv('GIT_COMMITTER_EMAIL', SavedCommitterEmail);
  end;
end;

procedure TestExplicitCommitterOverridesAuthor;
var
  SavedAuthorName: string;
  SavedAuthorEmail: string;
  SavedCommitterName: string;
  SavedCommitterEmail: string;
  AuthorName: string;
  AuthorEmail: string;
  CommitterName: string;
  CommitterEmail: string;
begin
  SavedAuthorName := get_env('GIT_AUTHOR_NAME');
  SavedAuthorEmail := get_env('GIT_AUTHOR_EMAIL');
  SavedCommitterName := get_env('GIT_COMMITTER_NAME');
  SavedCommitterEmail := get_env('GIT_COMMITTER_EMAIL');
  try
    Check('set author name',
      set_env('GIT_AUTHOR_NAME', 'Primary Author'));
    Check('set author email',
      set_env('GIT_AUTHOR_EMAIL', 'primary@example.invalid'));
    Check('set committer name',
      set_env('GIT_COMMITTER_NAME', 'Release Bot'));
    Check('set committer email',
      set_env('GIT_COMMITTER_EMAIL', 'release-bot@example.invalid'));

    ResolveGitIdentityEnv(AuthorName, AuthorEmail, CommitterName, CommitterEmail);
    Check('explicit committer name stays separate from author',
      CommitterName = 'Release Bot', 'got="' + CommitterName + '"');
    Check('explicit committer email stays separate from author',
      CommitterEmail = 'release-bot@example.invalid', 'got="' + CommitterEmail + '"');
  finally
    RestoreEnv('GIT_AUTHOR_NAME', SavedAuthorName);
    RestoreEnv('GIT_AUTHOR_EMAIL', SavedAuthorEmail);
    RestoreEnv('GIT_COMMITTER_NAME', SavedCommitterName);
    RestoreEnv('GIT_COMMITTER_EMAIL', SavedCommitterEmail);
  end;
end;

begin
  TestAuthorEnvVisibleInSameProcess;
  TestExplicitCommitterOverridesAuthor;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Git Env Identity Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
