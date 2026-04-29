unit fpdev.git2;

{$mode objfpc}{$H+}

{$I fpdev.config.inc}

{
  This unit remains the legacy compatibility wrapper over the shared git2.core backend.

  DEPRECATED: This unit exposes the old concrete class surface.
  For new code, use the modern interface-based API: git2.api + git2.impl.
  This unit is maintained for backward compatibility only.
}

interface

uses
  SysUtils, git2.types, libgit2, git2.core;

type
  EGitError = git2.core.EGitError;
  TGitOID = git2.core.TGitOID;
  TGitTime = git2.core.TGitTime;
  TGitSignature = git2.core.TGitSignature;
  TGitRepository = git2.core.TGitRepository;
  TGitCommit = git2.core.TGitCommit;
  TGitReference = git2.core.TGitReference;
  TGitRemote = git2.core.TGitRemote;
  TGitManager = git2.core.TGitManager;
  TGit2Manager = git2.core.TGit2Manager;

procedure CheckGitResult(AResult: Integer; const AOperation: string = '');
function GetGitErrorMessage: string;

function CreateGitOIDFromString(const AHashString: string): TGitOID;
function GitOIDToString(const AOID: TGitOID): string;
function GitOIDToShortString(const AOID: TGitOID): string;
function GitOIDEquals(const A, B: TGitOID): Boolean;
function IsGitOIDZero(const AOID: TGitOID): Boolean;
function CreateGitTimeFromGitTime(const AGitTime: git_time): TGitTime;
function GitTimeToString(const ATime: TGitTime): string;

implementation

procedure CheckGitResult(AResult: Integer; const AOperation: string);
begin
  git2.core.CheckGitResult(AResult, AOperation);
end;

function GetGitErrorMessage: string;
begin
  Result := git2.core.GetGitErrorMessage;
end;

function CreateGitOIDFromString(const AHashString: string): TGitOID;
begin
  Result := git2.core.CreateGitOIDFromString(AHashString);
end;

function GitOIDToString(const AOID: TGitOID): string;
begin
  Result := git2.core.GitOIDToString(AOID);
end;

function GitOIDToShortString(const AOID: TGitOID): string;
begin
  Result := git2.core.GitOIDToShortString(AOID);
end;

function GitOIDEquals(const A, B: TGitOID): Boolean;
begin
  Result := git2.core.GitOIDEquals(A, B);
end;

function IsGitOIDZero(const AOID: TGitOID): Boolean;
begin
  Result := git2.core.IsGitOIDZero(AOID);
end;

function CreateGitTimeFromGitTime(const AGitTime: git_time): TGitTime;
begin
  Result := git2.core.CreateGitTimeFromGitTime(AGitTime);
end;

function GitTimeToString(const ATime: TGitTime): string;
begin
  Result := git2.core.GitTimeToString(ATime);
end;

end.
