unit fpdev.git.operations.coreflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, libgit2, ctypes;

function Libgit2LastErrorText: string;
function FormatLibgit2Error(const APrefix, ADetail: string): string;
function BuildLibgit2Error(const APrefix: string): string;

function TryOpenGitRepositoryCore(
  const ARepoPath: string;
  out ARepoHandle: git_repository;
  out AError: string;
  const AErrorPrefix: string = 'libgit2 open repository failed'
): Boolean;

function TryOpenGitRepositoryIndexCore(
  ARepoHandle: git_repository;
  out AIndexHandle: git_index;
  out AError: string;
  const AErrorPrefix: string = 'libgit2 open index failed'
): Boolean;

function TryLookupGitRemoteCore(
  ARepoHandle: git_repository;
  const ARemoteName: string;
  out ARemoteHandle: git_remote;
  out AError: string;
  const AErrorPrefix: string = 'libgit2 remote lookup failed'
): Boolean;

function TryLookupGitTreeCore(
  ARepoHandle: git_repository;
  const ATreeOid: git_oid;
  out ATreeHandle: git_tree;
  out AError: string;
  const AErrorPrefix: string = 'libgit2 tree lookup failed'
): Boolean;

function TryInitGitCheckoutOptionsCore(
  out ACheckoutOpts: git_checkout_options;
  out AError: string;
  const AErrorPrefix: string = 'libgit2 checkout options init failed'
): Boolean;

implementation

function Libgit2LastErrorText: string;
var
  Err: Pgit_error_t;
begin
  Result := '';
  Err := git_error_last;
  if (Err <> nil) and (Err^.message <> nil) then
    Result := string(Err^.message);
end;

function FormatLibgit2Error(const APrefix, ADetail: string): string;
begin
  Result := Trim(APrefix);
  if Trim(ADetail) <> '' then
    Result := Result + ': ' + Trim(ADetail);
end;

function BuildLibgit2Error(const APrefix: string): string;
begin
  Result := FormatLibgit2Error(APrefix, Libgit2LastErrorText);
end;

function TryOpenGitRepositoryCore(
  const ARepoPath: string;
  out ARepoHandle: git_repository;
  out AError: string;
  const AErrorPrefix: string
): Boolean;
var
  RC: cint;
begin
  ARepoHandle := nil;
  AError := '';
  RC := git_repository_open(ARepoHandle, PChar(ARepoPath));
  Result := RC = GIT_OK;
  if not Result then
    AError := BuildLibgit2Error(AErrorPrefix);
end;

function TryOpenGitRepositoryIndexCore(
  ARepoHandle: git_repository;
  out AIndexHandle: git_index;
  out AError: string;
  const AErrorPrefix: string
): Boolean;
var
  RC: cint;
begin
  AIndexHandle := nil;
  AError := '';
  RC := git_repository_index(AIndexHandle, ARepoHandle);
  Result := RC = GIT_OK;
  if not Result then
    AError := BuildLibgit2Error(AErrorPrefix);
end;

function TryLookupGitRemoteCore(
  ARepoHandle: git_repository;
  const ARemoteName: string;
  out ARemoteHandle: git_remote;
  out AError: string;
  const AErrorPrefix: string
): Boolean;
var
  RC: cint;
begin
  ARemoteHandle := nil;
  AError := '';
  RC := git_remote_lookup(ARemoteHandle, ARepoHandle, PChar(ARemoteName));
  Result := RC = GIT_OK;
  if not Result then
    AError := BuildLibgit2Error(AErrorPrefix);
end;

function TryLookupGitTreeCore(
  ARepoHandle: git_repository;
  const ATreeOid: git_oid;
  out ATreeHandle: git_tree;
  out AError: string;
  const AErrorPrefix: string
): Boolean;
var
  RC: cint;
begin
  ATreeHandle := nil;
  AError := '';
  RC := git_tree_lookup(ATreeHandle, ARepoHandle, @ATreeOid);
  Result := RC = GIT_OK;
  if not Result then
    AError := BuildLibgit2Error(AErrorPrefix);
end;

function TryInitGitCheckoutOptionsCore(
  out ACheckoutOpts: git_checkout_options;
  out AError: string;
  const AErrorPrefix: string
): Boolean;
var
  RC: cint;
begin
  ACheckoutOpts := Default(git_checkout_options);
  AError := '';
  RC := git_checkout_options_init(@ACheckoutOpts, GIT_CHECKOUT_OPTIONS_VERSION);
  Result := RC = GIT_OK;
  if not Result then
    AError := BuildLibgit2Error(AErrorPrefix);
end;

end.
