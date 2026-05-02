unit fpdev.git.operations.identityflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, libgit2;

type
  TGitOperationIdentity = record
    AuthorName: string;
    AuthorEmail: string;
    CommitterName: string;
    CommitterEmail: string;
  end;

function TryResolveGitOperationIdentity(
  ARepoHandle: git_repository;
  const ARepoPath: string;
  const AAllowLocalConfigFallback: Boolean;
  out AIdentity: TGitOperationIdentity
): Boolean;

function TryCreateGitOperationSignatures(
  const AIdentity: TGitOperationIdentity;
  out AAuthorSig: git_signature;
  out ACommitterSig: git_signature;
  out AError: string
): Boolean;

implementation

uses
  Classes, ctypes, fpdev.git.env;

function Libgit2LastErrorText: string;
var
  Err: Pgit_error_t;
begin
  Result := '';
  Err := git_error_last;
  if (Err <> nil) and (Err^.message <> nil) then
    Result := string(Err^.message);
end;

function ConfigGetString(ACfg: git_config; const AKey: string): string;
var
  P: PChar;
begin
  Result := '';
  P := nil;
  if (ACfg <> nil) and (git_config_get_string(P, ACfg, PChar(AKey)) = GIT_OK) and (P <> nil) then
    Result := string(P);
end;

procedure ClearIdentity(out AIdentity: TGitOperationIdentity);
begin
  AIdentity.AuthorName := '';
  AIdentity.AuthorEmail := '';
  AIdentity.CommitterName := '';
  AIdentity.CommitterEmail := '';
end;

function TryLoadUserFromConfig(
  ARepoHandle: git_repository;
  out AName, AEmail: string
): Boolean;
var
  Cfg: git_config;
begin
  Result := False;
  AName := '';
  AEmail := '';

  if ARepoHandle = nil then
    Exit(False);

  Cfg := nil;
  if git_repository_config(Cfg, ARepoHandle) = GIT_OK then
  begin
    try
      AName := Trim(ConfigGetString(Cfg, 'user.name'));
      AEmail := Trim(ConfigGetString(Cfg, 'user.email'));
      Result := (AName <> '') and (AEmail <> '');
    finally
      git_config_free(Cfg);
    end;
    if Result then
      Exit(True);
  end;

  Cfg := nil;
  if git_config_open_default(Cfg) = GIT_OK then
  begin
    try
      AName := Trim(ConfigGetString(Cfg, 'user.name'));
      AEmail := Trim(ConfigGetString(Cfg, 'user.email'));
      Result := (AName <> '') and (AEmail <> '');
    finally
      git_config_free(Cfg);
    end;
  end;
end;

function TryLoadUserFromLocalConfig(
  const ARepoPath: string;
  out AName, AEmail: string
): Boolean;
var
  ConfigPath: string;
  Lines: TStringList;
  InUser: Boolean;
  Line: string;
  Key: string;
  Value: string;
  P: Integer;
  i: Integer;
begin
  Result := False;
  AName := '';
  AEmail := '';

  ConfigPath := IncludeTrailingPathDelimiter(ARepoPath) + '.git' + PathDelim + 'config';
  if not FileExists(ConfigPath) then
    Exit(False);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(ConfigPath);
    InUser := False;
    for i := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[i]);
      if Line = '' then
        Continue;
      if (Line[1] = ';') or (Line[1] = '#') then
        Continue;
      if Line[1] = '[' then
      begin
        InUser := SameText(Line, '[user]');
        Continue;
      end;
      if not InUser then
        Continue;

      P := Pos('=', Line);
      if P <= 0 then
        Continue;
      Key := Trim(Copy(Line, 1, P - 1));
      Value := Trim(Copy(Line, P + 1, MaxInt));

      if SameText(Key, 'name') then
        AName := Value
      else if SameText(Key, 'email') then
        AEmail := Value;
    end;
  finally
    Lines.Free;
  end;

  Result := (AName <> '') and (AEmail <> '');
end;

function TryResolveGitOperationIdentity(
  ARepoHandle: git_repository;
  const ARepoPath: string;
  const AAllowLocalConfigFallback: Boolean;
  out AIdentity: TGitOperationIdentity
): Boolean;
var
  EnvAuthorName: string;
  EnvAuthorEmail: string;
  EnvCommitterName: string;
  EnvCommitterEmail: string;
begin
  ClearIdentity(AIdentity);
  EnvAuthorName := '';
  EnvAuthorEmail := '';
  EnvCommitterName := '';
  EnvCommitterEmail := '';

  fpdev.git.env.ResolveGitIdentityEnv(
    EnvAuthorName, EnvAuthorEmail, EnvCommitterName, EnvCommitterEmail);

  if not TryLoadUserFromConfig(ARepoHandle, AIdentity.AuthorName, AIdentity.AuthorEmail) then
  begin
    if AAllowLocalConfigFallback then
    begin
      if not TryLoadUserFromLocalConfig(ARepoPath, AIdentity.AuthorName, AIdentity.AuthorEmail) then
      begin
        AIdentity.AuthorName := '';
        AIdentity.AuthorEmail := '';
      end;
    end;
  end;

  if (AIdentity.AuthorName = '') or (AIdentity.AuthorEmail = '') then
  begin
    AIdentity.AuthorName := EnvAuthorName;
    AIdentity.AuthorEmail := EnvAuthorEmail;
  end;

  AIdentity.CommitterName := EnvCommitterName;
  AIdentity.CommitterEmail := EnvCommitterEmail;
  if AIdentity.CommitterName = '' then
    AIdentity.CommitterName := AIdentity.AuthorName;
  if AIdentity.CommitterEmail = '' then
    AIdentity.CommitterEmail := AIdentity.AuthorEmail;

  Result :=
    (AIdentity.AuthorName <> '') and
    (AIdentity.AuthorEmail <> '') and
    (AIdentity.CommitterName <> '') and
    (AIdentity.CommitterEmail <> '');
end;

function TryCreateGitOperationSignatures(
  const AIdentity: TGitOperationIdentity;
  out AAuthorSig: git_signature;
  out ACommitterSig: git_signature;
  out AError: string
): Boolean;
var
  RC: cint;
  LErr: string;
begin
  Result := False;
  AError := '';
  AAuthorSig := nil;
  ACommitterSig := nil;

  if (AIdentity.AuthorName = '') or (AIdentity.AuthorEmail = '') or
     (AIdentity.CommitterName = '') or (AIdentity.CommitterEmail = '') then
  begin
    AError := 'Git identity not configured (user.name/user.email)';
    Exit(False);
  end;

  RC := git_signature_now(AAuthorSig, PChar(AIdentity.AuthorName), PChar(AIdentity.AuthorEmail));
  if RC <> GIT_OK then
  begin
    LErr := Libgit2LastErrorText;
    if LErr <> '' then
      AError := 'libgit2 signature creation failed: ' + LErr
    else
      AError := 'libgit2 signature creation failed';
    Exit(False);
  end;

  RC := git_signature_now(ACommitterSig, PChar(AIdentity.CommitterName), PChar(AIdentity.CommitterEmail));
  if RC <> GIT_OK then
  begin
    if AAuthorSig <> nil then
    begin
      git_signature_free(AAuthorSig);
      AAuthorSig := nil;
    end;
    LErr := Libgit2LastErrorText;
    if LErr <> '' then
      AError := 'libgit2 signature creation failed: ' + LErr
    else
      AError := 'libgit2 signature creation failed';
    Exit(False);
  end;

  Result := True;
end;

end.
