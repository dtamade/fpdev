unit fpdev.git.env;

{$mode objfpc}{$H+}

interface

procedure ResolveGitCredentialEnv(out AUsername, APassword, ASshUsername: string);
procedure ResolveGitIdentityEnv(var AAuthorName, AAuthorEmail, ACommitterName, ACommitterEmail: string);

implementation

uses
  SysUtils,
  fpdev.utils;

procedure ResolveGitCredentialEnv(out AUsername, APassword, ASshUsername: string);
begin
  AUsername := Trim(get_env('FPDEV_GIT_USERNAME'));
  APassword := Trim(get_env('FPDEV_GIT_PASSWORD'));
  if AUsername = '' then
    AUsername := Trim(get_env('GIT_USERNAME'));
  if APassword = '' then
    APassword := Trim(get_env('GIT_PASSWORD'));

  if APassword = '' then
    APassword := Trim(get_env('FPDEV_GIT_TOKEN'));
  if APassword = '' then
    APassword := Trim(get_env('GIT_TOKEN'));

  ASshUsername := Trim(get_env('FPDEV_GIT_SSH_USERNAME'));
  if ASshUsername = '' then
    ASshUsername := Trim(get_env('GIT_SSH_USERNAME'));
end;

procedure ResolveGitIdentityEnv(var AAuthorName, AAuthorEmail, ACommitterName, ACommitterEmail: string);
var
  EnvAuthorName: string;
  EnvAuthorEmail: string;
begin
  EnvAuthorName := Trim(get_env('GIT_AUTHOR_NAME'));
  EnvAuthorEmail := Trim(get_env('GIT_AUTHOR_EMAIL'));
  if AAuthorName = '' then
    AAuthorName := EnvAuthorName;
  if AAuthorEmail = '' then
    AAuthorEmail := EnvAuthorEmail;

  ACommitterName := Trim(get_env('GIT_COMMITTER_NAME'));
  ACommitterEmail := Trim(get_env('GIT_COMMITTER_EMAIL'));
  if ACommitterName = '' then
    ACommitterName := AAuthorName;
  if ACommitterEmail = '' then
    ACommitterEmail := AAuthorEmail;
end;

end.
