program test_git_operations_transportflow;

{$mode objfpc}{$H+}

uses
  SysUtils, ctypes, libgit2, fpdev.utils, fpdev.git.operations.transportflow;

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

procedure TestCredentialPayloadUsesSharedEnvResolution;
var
  SavedUser: string;
  SavedPassword: string;
  SavedSshUser: string;
  Payload: TGitTransportCredentialPayload;
begin
  SavedUser := get_env('FPDEV_GIT_USERNAME');
  SavedPassword := get_env('FPDEV_GIT_PASSWORD');
  SavedSshUser := get_env('FPDEV_GIT_SSH_USERNAME');
  try
    set_env('FPDEV_GIT_USERNAME', 'transport-user');
    set_env('FPDEV_GIT_PASSWORD', 'transport-pass');
    set_env('FPDEV_GIT_SSH_USERNAME', 'transport-ssh');

    LoadGitTransportCredentialPayload(Payload);
    Check('transportflow payload reads username from shared env helper',
      string(Payload.Username) = 'transport-user', 'got="' + string(Payload.Username) + '"');
    Check('transportflow payload reads password from shared env helper',
      string(Payload.Password) = 'transport-pass', 'got="' + string(Payload.Password) + '"');
    Check('transportflow payload reads ssh username from shared env helper',
      string(Payload.SshUsername) = 'transport-ssh', 'got="' + string(Payload.SshUsername) + '"');
    Check('transportflow payload resets attempt flags',
      (not Payload.TriedDefault) and (not Payload.TriedUserPass) and
      (not Payload.TriedSshAgent) and (not Payload.TriedUsernameOnly),
      'expected fresh flags');
  finally
    RestoreEnv('FPDEV_GIT_USERNAME', SavedUser);
    RestoreEnv('FPDEV_GIT_PASSWORD', SavedPassword);
    RestoreEnv('FPDEV_GIT_SSH_USERNAME', SavedSshUser);
  end;
end;

procedure TestCloneTransportOptionsWireCredentialCallback;
var
  SavedUser: string;
  SavedPassword: string;
  SavedSshUser: string;
  Payload: TGitTransportCredentialPayload;
  CloneOpts: git_clone_options;
  Err: string;
begin
  SavedUser := get_env('FPDEV_GIT_USERNAME');
  SavedPassword := get_env('FPDEV_GIT_PASSWORD');
  SavedSshUser := get_env('FPDEV_GIT_SSH_USERNAME');
  try
    set_env('FPDEV_GIT_USERNAME', 'clone-user');
    set_env('FPDEV_GIT_PASSWORD', 'clone-pass');
    set_env('FPDEV_GIT_SSH_USERNAME', 'clone-ssh');

    Err := '';
    Check('transportflow clone options init succeeds',
      TryInitGitCloneTransportOptions(CloneOpts, Payload, Err), Err);
    Check('transportflow clone options install credential callback',
      Pointer(CloneOpts.fetch_opts.callbacks.credentials) = Pointer(@GitTransportCredentialAcquireCb));
    Check('transportflow clone options keep payload address',
      CloneOpts.fetch_opts.callbacks.payload = @Payload);
    Check('transportflow clone payload keeps username',
      string(Payload.Username) = 'clone-user', 'got="' + string(Payload.Username) + '"');
  finally
    RestoreEnv('FPDEV_GIT_USERNAME', SavedUser);
    RestoreEnv('FPDEV_GIT_PASSWORD', SavedPassword);
    RestoreEnv('FPDEV_GIT_SSH_USERNAME', SavedSshUser);
  end;
end;

procedure TestFetchTransportOptionsWireCredentialCallback;
var
  SavedUser: string;
  SavedPassword: string;
  SavedSshUser: string;
  Payload: TGitTransportCredentialPayload;
  FetchOpts: git_fetch_options;
  Err: string;
begin
  SavedUser := get_env('FPDEV_GIT_USERNAME');
  SavedPassword := get_env('FPDEV_GIT_PASSWORD');
  SavedSshUser := get_env('FPDEV_GIT_SSH_USERNAME');
  try
    set_env('FPDEV_GIT_USERNAME', 'fetch-user');
    set_env('FPDEV_GIT_PASSWORD', 'fetch-pass');
    set_env('FPDEV_GIT_SSH_USERNAME', 'fetch-ssh');

    Err := '';
    Check('transportflow fetch options init succeeds',
      TryInitGitFetchTransportOptions(FetchOpts, Payload, Err), Err);
    Check('transportflow fetch options install credential callback',
      Pointer(FetchOpts.callbacks.credentials) = Pointer(@GitTransportCredentialAcquireCb));
    Check('transportflow fetch options keep payload address',
      FetchOpts.callbacks.payload = @Payload);
    Check('transportflow fetch payload keeps ssh username',
      string(Payload.SshUsername) = 'fetch-ssh', 'got="' + string(Payload.SshUsername) + '"');
  finally
    RestoreEnv('FPDEV_GIT_USERNAME', SavedUser);
    RestoreEnv('FPDEV_GIT_PASSWORD', SavedPassword);
    RestoreEnv('FPDEV_GIT_SSH_USERNAME', SavedSshUser);
  end;
end;

procedure TestPushTransportOptionsWireCredentialCallback;
var
  SavedUser: string;
  SavedPassword: string;
  SavedSshUser: string;
  Payload: TGitTransportCredentialPayload;
  PushOpts: git_push_options;
  Err: string;
begin
  SavedUser := get_env('FPDEV_GIT_USERNAME');
  SavedPassword := get_env('FPDEV_GIT_PASSWORD');
  SavedSshUser := get_env('FPDEV_GIT_SSH_USERNAME');
  try
    set_env('FPDEV_GIT_USERNAME', 'push-user');
    set_env('FPDEV_GIT_PASSWORD', 'push-pass');
    set_env('FPDEV_GIT_SSH_USERNAME', 'push-ssh');

    Err := '';
    Check('transportflow push options init succeeds',
      TryInitGitPushTransportOptions(PushOpts, Payload, Err), Err);
    Check('transportflow push options install credential callback',
      Pointer(PushOpts.callbacks.credentials) = Pointer(@GitTransportCredentialAcquireCb));
    Check('transportflow push options keep payload address',
      PushOpts.callbacks.payload = @Payload);
    Check('transportflow push payload keeps password',
      string(Payload.Password) = 'push-pass', 'got="' + string(Payload.Password) + '"');
  finally
    RestoreEnv('FPDEV_GIT_USERNAME', SavedUser);
    RestoreEnv('FPDEV_GIT_PASSWORD', SavedPassword);
    RestoreEnv('FPDEV_GIT_SSH_USERNAME', SavedSshUser);
  end;
end;

procedure TestCredentialCallbackPassesThroughWithoutPayload;
var
  Cred: Pointer;
  RC: cint;
begin
  Cred := nil;
  RC := GitTransportCredentialAcquireCb(
    Cred,
    nil,
    nil,
    GIT_CREDENTIAL_USERNAME,
    nil
  );
  Check('transportflow credential callback passthrough without payload',
    RC = GIT_PASSTHROUGH, 'rc=' + IntToStr(RC));
  Check('transportflow callback keeps nil credential without payload',
    Cred = nil);
end;

procedure TestCredentialCallbackPassesThroughWhenPasswordMissing;
var
  Payload: TGitTransportCredentialPayload;
  Cred: Pointer;
  RC: cint;
begin
  Payload.TriedDefault := True;
  Payload.TriedUserPass := False;
  Payload.TriedSshAgent := True;
  Payload.TriedUsernameOnly := True;
  Payload.Username := 'userpass-only';
  Payload.Password := '';
  Payload.SshUsername := '';
  Cred := nil;
  RC := GitTransportCredentialAcquireCb(
    Cred,
    nil,
    nil,
    GIT_CREDENTIAL_USERPASS_PLAINTEXT,
    @Payload
  );
  Check('transportflow callback passthrough when plaintext password missing',
    RC = GIT_PASSTHROUGH, 'rc=' + IntToStr(RC));
  Check('transportflow callback keeps nil credential when plaintext password missing',
    Cred = nil);
  Check('transportflow callback marks userpass attempt',
    Payload.TriedUserPass, 'expected TriedUserPass=True');
end;

begin
  TestCredentialPayloadUsesSharedEnvResolution;
  TestCloneTransportOptionsWireCredentialCallback;
  TestFetchTransportOptionsWireCredentialCallback;
  TestPushTransportOptionsWireCredentialCallback;
  TestCredentialCallbackPassesThroughWithoutPayload;
  TestCredentialCallbackPassesThroughWhenPasswordMissing;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Git Operations Transportflow Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
