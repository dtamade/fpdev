unit fpdev.git.errors;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TGitPullFailureKind = (
    gpfkUnknown,
    gpfkDirtyWorktree,
    gpfkDetachedHead,
    gpfkDivergedHistory
  );

function ClassifyGitPullFailure(const AError: string): TGitPullFailureKind;
function NormalizeGitPullErrorDetail(const AError: string): string;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function ClassifyGitPullFailure(const AError: string): TGitPullFailureKind;
var
  LError: string;
begin
  LError := LowerCase(Trim(AError));
  if LError = '' then
    Exit(gpfkUnknown);

  if (Pos('detached head', LError) > 0) or
     (Pos('not currently on a branch', LError) > 0) or
     (Pos('specify which branch you want to merge with', LError) > 0) then
    Exit(gpfkDetachedHead);

  if (Pos('working tree has local changes', LError) > 0) or
     (Pos('your local changes to the following files would be overwritten by merge', LError) > 0) or
     (Pos('untracked working tree files would be overwritten by merge', LError) > 0) or
     (Pos('please commit your changes or stash them before you merge', LError) > 0) or
     (Pos('please move or remove them before you merge', LError) > 0) then
    Exit(gpfkDirtyWorktree);

  if (Pos('non-fast-forward update requires merge/rebase', LError) > 0) or
     (Pos('not possible to fast-forward', LError) > 0) or
     (Pos('merge has conflicts', LError) > 0) or
     (Pos('manual resolution required', LError) > 0) or
     (Pos('automatic merge failed', LError) > 0) or
     (Pos('merge conflict', LError) > 0) or
     (Pos('conflict (content)', LError) > 0) or
     (Pos('reconcile divergent branches', LError) > 0) or
     (Pos('branches diverged', LError) > 0) or
     (Pos('refusing to merge unrelated histories', LError) > 0) then
    Exit(gpfkDivergedHistory);

  Result := gpfkUnknown;
end;

function NormalizeGitPullErrorDetail(const AError: string): string;
var
  LError: string;
begin
  LError := Trim(AError);
  case ClassifyGitPullFailure(LError) of
    gpfkDirtyWorktree:
      Exit(_(MSG_GIT_UPDATE_DIRTY_WORKTREE));
    gpfkDetachedHead:
      Exit(_(MSG_GIT_UPDATE_DETACHED_HEAD));
    gpfkDivergedHistory:
      Exit(_(MSG_GIT_UPDATE_DIVERGED_HISTORY));
    gpfkUnknown:
      ;
  end;

  if LError = '' then
    Result := _(MSG_FAILED)
  else
    Result := LError;
end;

end.
