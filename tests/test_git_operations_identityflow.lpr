program test_git_operations_identityflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, libgit2, fpdev.utils, fpdev.git.operations.identityflow,
  test_temp_paths;

type
  TIdentityCase = record
    AuthorName: string;
    AuthorEmail: string;
    CommitterName: string;
    CommitterEmail: string;
  end;

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

procedure WriteLocalGitConfig(const ARepoDir, AName, AEmail: string);
var
  ConfigDir: string;
  ConfigPath: string;
  Lines: TStringList;
begin
  ConfigDir := IncludeTrailingPathDelimiter(ARepoDir) + '.git';
  ForceDirectories(ConfigDir);
  ConfigPath := IncludeTrailingPathDelimiter(ConfigDir) + 'config';

  Lines := TStringList.Create;
  try
    Lines.Add('[user]');
    Lines.Add('  name = ' + AName);
    Lines.Add('  email = ' + AEmail);
    Lines.SaveToFile(ConfigPath);
  finally
    Lines.Free;
  end;
end;

procedure TestLocalConfigProvidesAuthorIdentity;
var
  TempRoot: string;
  Identity: TGitOperationIdentity;
begin
  TempRoot := CreateUniqueTempDir('gitops-identityflow-local-config');
  try
    WriteLocalGitConfig(TempRoot, 'Config User', 'config@example.invalid');
    Check(
      'local .git/config identity resolves',
      TryResolveGitOperationIdentity(nil, TempRoot, True, Identity)
    );
    Check('author name comes from local config',
      Identity.AuthorName = 'Config User', 'got="' + Identity.AuthorName + '"');
    Check('author email comes from local config',
      Identity.AuthorEmail = 'config@example.invalid', 'got="' + Identity.AuthorEmail + '"');
    Check('committer name falls back to author when env is absent',
      Identity.CommitterName = 'Config User', 'got="' + Identity.CommitterName + '"');
    Check('committer email falls back to author when env is absent',
      Identity.CommitterEmail = 'config@example.invalid', 'got="' + Identity.CommitterEmail + '"');
  finally
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestEnvironmentFallbackProvidesIdentity;
var
  SavedAuthorName: string;
  SavedAuthorEmail: string;
  SavedCommitterName: string;
  SavedCommitterEmail: string;
  TempRoot: string;
  Identity: TGitOperationIdentity;
begin
  SavedAuthorName := get_env('GIT_AUTHOR_NAME');
  SavedAuthorEmail := get_env('GIT_AUTHOR_EMAIL');
  SavedCommitterName := get_env('GIT_COMMITTER_NAME');
  SavedCommitterEmail := get_env('GIT_COMMITTER_EMAIL');
  TempRoot := CreateUniqueTempDir('gitops-identityflow-env');
  try
    set_env('GIT_AUTHOR_NAME', 'Env Author');
    set_env('GIT_AUTHOR_EMAIL', 'env.author@example.invalid');
    unset_env('GIT_COMMITTER_NAME');
    unset_env('GIT_COMMITTER_EMAIL');

    Check(
      'environment fallback identity resolves',
      TryResolveGitOperationIdentity(nil, TempRoot, True, Identity)
    );
    Check('author name falls back to env',
      Identity.AuthorName = 'Env Author', 'got="' + Identity.AuthorName + '"');
    Check('author email falls back to env',
      Identity.AuthorEmail = 'env.author@example.invalid', 'got="' + Identity.AuthorEmail + '"');
    Check('committer name still falls back to author',
      Identity.CommitterName = 'Env Author', 'got="' + Identity.CommitterName + '"');
    Check('committer email still falls back to author',
      Identity.CommitterEmail = 'env.author@example.invalid', 'got="' + Identity.CommitterEmail + '"');
  finally
    RestoreEnv('GIT_AUTHOR_NAME', SavedAuthorName);
    RestoreEnv('GIT_AUTHOR_EMAIL', SavedAuthorEmail);
    RestoreEnv('GIT_COMMITTER_NAME', SavedCommitterName);
    RestoreEnv('GIT_COMMITTER_EMAIL', SavedCommitterEmail);
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestExplicitCommitterEnvOverridesAuthor;
var
  SavedAuthorName: string;
  SavedAuthorEmail: string;
  SavedCommitterName: string;
  SavedCommitterEmail: string;
  TempRoot: string;
  Identity: TGitOperationIdentity;
begin
  SavedAuthorName := get_env('GIT_AUTHOR_NAME');
  SavedAuthorEmail := get_env('GIT_AUTHOR_EMAIL');
  SavedCommitterName := get_env('GIT_COMMITTER_NAME');
  SavedCommitterEmail := get_env('GIT_COMMITTER_EMAIL');
  TempRoot := CreateUniqueTempDir('gitops-identityflow-committer');
  try
    set_env('GIT_AUTHOR_NAME', 'Primary Author');
    set_env('GIT_AUTHOR_EMAIL', 'primary.author@example.invalid');
    set_env('GIT_COMMITTER_NAME', 'Release Bot');
    set_env('GIT_COMMITTER_EMAIL', 'release.bot@example.invalid');

    Check(
      'explicit committer env identity resolves',
      TryResolveGitOperationIdentity(nil, TempRoot, True, Identity)
    );
    Check('committer name stays distinct',
      Identity.CommitterName = 'Release Bot', 'got="' + Identity.CommitterName + '"');
    Check('committer email stays distinct',
      Identity.CommitterEmail = 'release.bot@example.invalid', 'got="' + Identity.CommitterEmail + '"');
  finally
    RestoreEnv('GIT_AUTHOR_NAME', SavedAuthorName);
    RestoreEnv('GIT_AUTHOR_EMAIL', SavedAuthorEmail);
    RestoreEnv('GIT_COMMITTER_NAME', SavedCommitterName);
    RestoreEnv('GIT_COMMITTER_EMAIL', SavedCommitterEmail);
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestMissingIdentityFails;
var
  SavedAuthorName: string;
  SavedAuthorEmail: string;
  SavedCommitterName: string;
  SavedCommitterEmail: string;
  TempRoot: string;
  Identity: TGitOperationIdentity;
begin
  SavedAuthorName := get_env('GIT_AUTHOR_NAME');
  SavedAuthorEmail := get_env('GIT_AUTHOR_EMAIL');
  SavedCommitterName := get_env('GIT_COMMITTER_NAME');
  SavedCommitterEmail := get_env('GIT_COMMITTER_EMAIL');
  TempRoot := CreateUniqueTempDir('gitops-identityflow-missing');
  try
    unset_env('GIT_AUTHOR_NAME');
    unset_env('GIT_AUTHOR_EMAIL');
    unset_env('GIT_COMMITTER_NAME');
    unset_env('GIT_COMMITTER_EMAIL');

    Check(
      'missing identity fails',
      not TryResolveGitOperationIdentity(nil, TempRoot, True, Identity)
    );
  finally
    RestoreEnv('GIT_AUTHOR_NAME', SavedAuthorName);
    RestoreEnv('GIT_AUTHOR_EMAIL', SavedAuthorEmail);
    RestoreEnv('GIT_COMMITTER_NAME', SavedCommitterName);
    RestoreEnv('GIT_COMMITTER_EMAIL', SavedCommitterEmail);
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestSignatureCreationSucceedsForResolvedIdentity;
var
  Identity: TGitOperationIdentity;
  AuthorSig: git_signature;
  CommitterSig: git_signature;
  Err: string;
  InitCount: Integer;
begin
  Identity.AuthorName := 'Sig Author';
  Identity.AuthorEmail := 'sig.author@example.invalid';
  Identity.CommitterName := 'Sig Committer';
  Identity.CommitterEmail := 'sig.committer@example.invalid';
  AuthorSig := nil;
  CommitterSig := nil;
  Err := '';
  InitCount := git_libgit2_init;
  try
    Check('libgit2 init for signature test succeeds', InitCount >= 0);
    Check(
      'signature creation succeeds for valid identity',
      TryCreateGitOperationSignatures(Identity, AuthorSig, CommitterSig, Err),
      Err
    );
    Check('author signature allocated', AuthorSig <> nil);
    Check('committer signature allocated', CommitterSig <> nil);
  finally
    if AuthorSig <> nil then
      git_signature_free(AuthorSig);
    if CommitterSig <> nil then
      git_signature_free(CommitterSig);
    if InitCount >= 0 then
      git_libgit2_shutdown;
  end;
end;

begin
  TestLocalConfigProvidesAuthorIdentity;
  TestEnvironmentFallbackProvidesIdentity;
  TestExplicitCommitterEnvOverridesAuthor;
  TestMissingIdentityFails;
  TestSignatureCreationSucceedsForResolvedIdentity;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Git Operations Identityflow Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
