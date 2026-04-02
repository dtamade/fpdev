program test_git_env_credentials;

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

procedure TestFPDevCredentialEnvVisibleInSameProcess;
var
  SavedUser: string;
  SavedPassword: string;
  SavedToken: string;
  SavedSshUser: string;
  SavedGitUser: string;
  SavedGitPassword: string;
  SavedGitToken: string;
  SavedGitSshUser: string;
  UserName: string;
  Password: string;
  SshUser: string;
begin
  SavedUser := get_env('FPDEV_GIT_USERNAME');
  SavedPassword := get_env('FPDEV_GIT_PASSWORD');
  SavedToken := get_env('FPDEV_GIT_TOKEN');
  SavedSshUser := get_env('FPDEV_GIT_SSH_USERNAME');
  SavedGitUser := get_env('GIT_USERNAME');
  SavedGitPassword := get_env('GIT_PASSWORD');
  SavedGitToken := get_env('GIT_TOKEN');
  SavedGitSshUser := get_env('GIT_SSH_USERNAME');
  try
    unset_env('GIT_USERNAME');
    unset_env('GIT_PASSWORD');
    unset_env('GIT_TOKEN');
    unset_env('GIT_SSH_USERNAME');

    Check('set FPDEV_GIT_USERNAME',
      set_env('FPDEV_GIT_USERNAME', 'fpdev-user'));
    Check('set FPDEV_GIT_PASSWORD',
      set_env('FPDEV_GIT_PASSWORD', 'fpdev-pass'));
    Check('set FPDEV_GIT_SSH_USERNAME',
      set_env('FPDEV_GIT_SSH_USERNAME', 'fpdev-ssh'));
    unset_env('FPDEV_GIT_TOKEN');

    ResolveGitCredentialEnv(UserName, Password, SshUser);
    Check('same-process FPDEV_GIT_USERNAME is visible',
      UserName = 'fpdev-user', 'got="' + UserName + '"');
    Check('same-process FPDEV_GIT_PASSWORD is visible',
      Password = 'fpdev-pass', 'got="' + Password + '"');
    Check('same-process FPDEV_GIT_SSH_USERNAME is visible',
      SshUser = 'fpdev-ssh', 'got="' + SshUser + '"');
  finally
    RestoreEnv('FPDEV_GIT_USERNAME', SavedUser);
    RestoreEnv('FPDEV_GIT_PASSWORD', SavedPassword);
    RestoreEnv('FPDEV_GIT_TOKEN', SavedToken);
    RestoreEnv('FPDEV_GIT_SSH_USERNAME', SavedSshUser);
    RestoreEnv('GIT_USERNAME', SavedGitUser);
    RestoreEnv('GIT_PASSWORD', SavedGitPassword);
    RestoreEnv('GIT_TOKEN', SavedGitToken);
    RestoreEnv('GIT_SSH_USERNAME', SavedGitSshUser);
  end;
end;

procedure TestTokenFallbackAndFPDevPrecedence;
var
  SavedUser: string;
  SavedPassword: string;
  SavedToken: string;
  SavedSshUser: string;
  SavedGitUser: string;
  SavedGitPassword: string;
  SavedGitToken: string;
  SavedGitSshUser: string;
  UserName: string;
  Password: string;
  SshUser: string;
begin
  SavedUser := get_env('FPDEV_GIT_USERNAME');
  SavedPassword := get_env('FPDEV_GIT_PASSWORD');
  SavedToken := get_env('FPDEV_GIT_TOKEN');
  SavedSshUser := get_env('FPDEV_GIT_SSH_USERNAME');
  SavedGitUser := get_env('GIT_USERNAME');
  SavedGitPassword := get_env('GIT_PASSWORD');
  SavedGitToken := get_env('GIT_TOKEN');
  SavedGitSshUser := get_env('GIT_SSH_USERNAME');
  try
    unset_env('FPDEV_GIT_USERNAME');
    unset_env('FPDEV_GIT_PASSWORD');
    unset_env('FPDEV_GIT_SSH_USERNAME');
    Check('set GIT_USERNAME',
      set_env('GIT_USERNAME', 'generic-user'));
    Check('set GIT_PASSWORD',
      set_env('GIT_PASSWORD', 'generic-pass'));
    Check('set GIT_SSH_USERNAME',
      set_env('GIT_SSH_USERNAME', 'generic-ssh'));
    Check('set GIT_TOKEN',
      set_env('GIT_TOKEN', 'generic-token'));
    Check('set FPDEV_GIT_TOKEN',
      set_env('FPDEV_GIT_TOKEN', 'fpdev-token'));

    ResolveGitCredentialEnv(UserName, Password, SshUser);
    Check('generic username fallback stays visible',
      UserName = 'generic-user', 'got="' + UserName + '"');
    Check('generic password keeps precedence over tokens',
      Password = 'generic-pass', 'got="' + Password + '"');
    Check('generic ssh username fallback stays visible',
      SshUser = 'generic-ssh', 'got="' + SshUser + '"');

    unset_env('GIT_PASSWORD');
    ResolveGitCredentialEnv(UserName, Password, SshUser);
    Check('FPDEV_GIT_TOKEN beats generic GIT_TOKEN when password missing',
      Password = 'fpdev-token', 'got="' + Password + '"');
  finally
    RestoreEnv('FPDEV_GIT_USERNAME', SavedUser);
    RestoreEnv('FPDEV_GIT_PASSWORD', SavedPassword);
    RestoreEnv('FPDEV_GIT_TOKEN', SavedToken);
    RestoreEnv('FPDEV_GIT_SSH_USERNAME', SavedSshUser);
    RestoreEnv('GIT_USERNAME', SavedGitUser);
    RestoreEnv('GIT_PASSWORD', SavedGitPassword);
    RestoreEnv('GIT_TOKEN', SavedGitToken);
    RestoreEnv('GIT_SSH_USERNAME', SavedGitSshUser);
  end;
end;

begin
  TestFPDevCredentialEnvVisibleInSameProcess;
  TestTokenFallbackAndFPDevPrecedence;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Git Env Credential Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
