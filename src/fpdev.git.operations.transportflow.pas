unit fpdev.git.operations.transportflow;

{$mode objfpc}{$H+}

interface

uses
  libgit2, ctypes;

type
  TGitTransportCredentialPayload = record
    TriedDefault: Boolean;
    TriedUserPass: Boolean;
    TriedSshAgent: Boolean;
    TriedUsernameOnly: Boolean;
    Username: AnsiString;
    Password: AnsiString;
    SshUsername: AnsiString;
  end;

procedure LoadGitTransportCredentialPayload(out APayload: TGitTransportCredentialPayload);

function GitTransportCredentialAcquireCb(
  out ACred: Pointer;
  const AUrl, AUserFromUrl: PChar;
  AAllowedTypes: cuint;
  APayload: Pointer
): cint; cdecl;

function TryInitGitCloneTransportOptions(
  out ACloneOpts: git_clone_options;
  out APayload: TGitTransportCredentialPayload;
  out AError: string
): Boolean;

function TryInitGitFetchTransportOptions(
  out AFetchOpts: git_fetch_options;
  out APayload: TGitTransportCredentialPayload;
  out AError: string
): Boolean;

function TryInitGitPushTransportOptions(
  out APushOpts: git_push_options;
  out APayload: TGitTransportCredentialPayload;
  out AError: string
): Boolean;

implementation

uses
  SysUtils, fpdev.git.env;

function Libgit2LastErrorText: string;
var
  Err: Pgit_error_t;
begin
  Result := '';
  Err := git_error_last;
  if (Err <> nil) and (Err^.message <> nil) then
    Result := string(Err^.message);
end;

procedure LoadGitTransportCredentialPayload(out APayload: TGitTransportCredentialPayload);
var
  U: string;
  P: string;
  SU: string;
begin
  APayload.TriedDefault := False;
  APayload.TriedUserPass := False;
  APayload.TriedSshAgent := False;
  APayload.TriedUsernameOnly := False;
  APayload.Username := '';
  APayload.Password := '';
  APayload.SshUsername := '';

  fpdev.git.env.ResolveGitCredentialEnv(U, P, SU);

  APayload.Username := AnsiString(U);
  APayload.Password := AnsiString(P);
  APayload.SshUsername := AnsiString(SU);
end;

function GitTransportCredentialAcquireCb(
  out ACred: Pointer;
  const AUrl, AUserFromUrl: PChar;
  AAllowedTypes: cuint;
  APayload: Pointer
): cint; cdecl;
var
  P: ^TGitTransportCredentialPayload;
  UserFromUrl: string;
  UseUser: string;
  RC: cint;
begin
  Result := GIT_PASSTHROUGH;
  ACred := nil;

  P := Pointer(APayload);
  if P = nil then
    Exit(GIT_PASSTHROUGH);

  UserFromUrl := '';
  if AUserFromUrl <> nil then
    UserFromUrl := Trim(string(AUserFromUrl));

  if ((AAllowedTypes and GIT_CREDENTIAL_DEFAULT) <> 0) and (not P^.TriedDefault) then
  begin
    P^.TriedDefault := True;
    RC := git_credential_default_new(ACred);
    if (RC = GIT_OK) and (ACred <> nil) then
      Exit(0);
  end;

  if ((AAllowedTypes and GIT_CREDENTIAL_USERNAME) <> 0) and (not P^.TriedUsernameOnly) then
  begin
    P^.TriedUsernameOnly := True;
    UseUser := UserFromUrl;
    if UseUser = '' then
      UseUser := string(P^.SshUsername);
    if UseUser = '' then
      UseUser := string(P^.Username);
    if UseUser = '' then
      UseUser := 'git';

    RC := git_credential_username_new(ACred, PChar(UseUser));
    if (RC = GIT_OK) and (ACred <> nil) then
      Exit(0);
  end;

  if ((AAllowedTypes and GIT_CREDENTIAL_SSH_KEY) <> 0) and (not P^.TriedSshAgent) then
  begin
    P^.TriedSshAgent := True;
    UseUser := UserFromUrl;
    if UseUser = '' then
      UseUser := string(P^.SshUsername);
    if UseUser = '' then
      UseUser := string(P^.Username);
    if UseUser = '' then
      UseUser := 'git';

    RC := git_credential_ssh_key_from_agent(ACred, PChar(UseUser));
    if (RC = GIT_OK) and (ACred <> nil) then
      Exit(0);
  end;

  if ((AAllowedTypes and GIT_CREDENTIAL_USERPASS_PLAINTEXT) <> 0) and (not P^.TriedUserPass) then
  begin
    P^.TriedUserPass := True;
    UseUser := UserFromUrl;
    if UseUser = '' then
      UseUser := string(P^.Username);
    if UseUser = '' then
      UseUser := 'git';

    if P^.Password <> '' then
    begin
      RC := git_credential_userpass_plaintext_new(ACred, PChar(UseUser), PChar(P^.Password));
      if (RC = GIT_OK) and (ACred <> nil) then
        Exit(0);
    end;
  end;

  Result := GIT_PASSTHROUGH;
  if AUrl <> nil then;
end;

function TryInitGitCloneTransportOptions(
  out ACloneOpts: git_clone_options;
  out APayload: TGitTransportCredentialPayload;
  out AError: string
): Boolean;
var
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';
  ACloneOpts := Default(git_clone_options);
  LoadGitTransportCredentialPayload(APayload);

  RC := git_clone_options_init(@ACloneOpts, GIT_CLONE_OPTIONS_VERSION);
  if RC <> GIT_OK then
  begin
    LErr := Libgit2LastErrorText;
    if LErr <> '' then
      AError := 'libgit2 clone options init failed: ' + LErr
    else
      AError := 'libgit2 clone options init failed';
    Exit(False);
  end;

  ACloneOpts.fetch_opts.callbacks.credentials := @GitTransportCredentialAcquireCb;
  ACloneOpts.fetch_opts.callbacks.payload := @APayload;
  Result := True;
end;

function TryInitGitFetchTransportOptions(
  out AFetchOpts: git_fetch_options;
  out APayload: TGitTransportCredentialPayload;
  out AError: string
): Boolean;
var
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';
  AFetchOpts := Default(git_fetch_options);
  LoadGitTransportCredentialPayload(APayload);

  RC := git_fetch_options_init(@AFetchOpts, GIT_FETCH_OPTIONS_VERSION);
  if RC <> GIT_OK then
  begin
    LErr := Libgit2LastErrorText;
    if LErr <> '' then
      AError := 'libgit2 fetch options init failed: ' + LErr
    else
      AError := 'libgit2 fetch options init failed';
    Exit(False);
  end;

  AFetchOpts.callbacks.credentials := @GitTransportCredentialAcquireCb;
  AFetchOpts.callbacks.payload := @APayload;
  Result := True;
end;

function TryInitGitPushTransportOptions(
  out APushOpts: git_push_options;
  out APayload: TGitTransportCredentialPayload;
  out AError: string
): Boolean;
var
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';
  APushOpts := Default(git_push_options);
  LoadGitTransportCredentialPayload(APayload);

  RC := git_push_options_init(@APushOpts, GIT_PUSH_OPTIONS_VERSION);
  if RC <> GIT_OK then
  begin
    LErr := Libgit2LastErrorText;
    if LErr <> '' then
      AError := 'libgit2 push options init failed: ' + LErr
    else
      AError := 'libgit2 push options init failed';
    Exit(False);
  end;

  APushOpts.callbacks.credentials := @GitTransportCredentialAcquireCb;
  APushOpts.callbacks.payload := @APayload;
  Result := True;
end;

end.
