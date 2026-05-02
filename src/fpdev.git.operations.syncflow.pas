unit fpdev.git.operations.syncflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.git.types, fpdev.git.errors, fpdev.utils.process;

type
  TGitSyncCliRunnerFunc = function(const AParams: array of string;
    const AWorkDir: string): TProcessResult of object;
  TGitSyncCloneLibgit2Func = function(const AURL, ALocalPath: string;
    out AError: string): Boolean of object;
  TGitSyncFetchLibgit2Func = function(const ARepoPath, ARemote: string;
    out AError: string): Boolean of object;
  TGitSyncPullLibgit2Func = function(const ARepoPath: string;
    out AError: string; out ANeedsFallback: Boolean;
    const AAllowMerge: Boolean): Boolean of object;
  TGitSyncCheckoutAfterCloneFunc = function(const ARepoPath, ABranch: string;
    const AForce: Boolean; out AError: string): Boolean of object;

function ExecuteGitCloneSurfaceCore(
  const AURL, ALocalPath, ABranch: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Clone: TGitSyncCloneLibgit2Func;
  ACheckoutAfterClone: TGitSyncCheckoutAfterCloneFunc;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;

function ExecuteGitFetchSurfaceCore(
  const ARepoPath, ARemote: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Fetch: TGitSyncFetchLibgit2Func;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;

function ExecuteGitPullSurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Pull: TGitSyncPullLibgit2Func;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;

function ExecuteGitPullFastForwardOnlySurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Pull: TGitSyncPullLibgit2Func;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;

implementation

procedure SetErrorFromProcessResult(const AAction: string;
  const AResult: TProcessResult; out AError: string);
begin
  if AResult.StdErr <> '' then
    AError := Trim(AResult.StdErr)
  else if AResult.ErrorMessage <> '' then
    AError := Trim(AResult.ErrorMessage)
  else
    AError := AAction + ' failed (exit code ' + IntToStr(AResult.ExitCode) + ')';
end;

function ExecuteGitCliAction(const AAction: string;
  const AParams: array of string;
  const AWorkDir: string;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;
var
  LResult: TProcessResult;
begin
  Result := False;
  AError := '';

  if not Assigned(AExecuteGitCli) then
  begin
    AError := 'No command-line git available';
    Exit(False);
  end;

  LResult := AExecuteGitCli(AParams, AWorkDir);
  Result := LResult.Success;
  if not Result then
    SetErrorFromProcessResult(AAction, LResult, AError);
end;

function ExecuteGitCloneSurfaceCore(
  const AURL, ALocalPath, ABranch: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Clone: TGitSyncCloneLibgit2Func;
  ACheckoutAfterClone: TGitSyncCheckoutAfterCloneFunc;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;
begin
  Result := False;
  AError := '';

  if ABackend = gbNone then
  begin
    AError := 'No Git backend available (neither libgit2 nor git command found)';
    Exit(False);
  end;

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Clone) then
  begin
    try
      Result := ALibgit2Clone(AURL, ALocalPath, AError);
      if Result then
      begin
        if (ABranch <> '') and Assigned(ACheckoutAfterClone) then
          Exit(ACheckoutAfterClone(ALocalPath, ABranch, True, AError));
        Exit(True);
      end;
    except
      // Fall back to command-line clone.
    end;
  end;

  if not ACommandLineGitAvailable then
  begin
    if AError = '' then
      AError := 'No command-line git available';
    Exit(False);
  end;

  if ABranch <> '' then
    Result := ExecuteGitCliAction('git clone',
      ['clone', '--depth', '1', '--branch', ABranch, AURL, ALocalPath],
      '', AExecuteGitCli, AError)
  else
    Result := ExecuteGitCliAction('git clone',
      ['clone', '--depth', '1', AURL, ALocalPath],
      '', AExecuteGitCli, AError);
end;

function ExecuteGitFetchSurfaceCore(
  const ARepoPath, ARemote: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Fetch: TGitSyncFetchLibgit2Func;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;
begin
  Result := False;
  AError := '';

  if ABackend = gbNone then
  begin
    AError := 'No Git backend available';
    Exit(False);
  end;

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Fetch) then
  begin
    try
      Result := ALibgit2Fetch(ARepoPath, ARemote, AError);
      if Result then
        Exit(True);
    except
      // Fall back to command-line fetch.
    end;
  end;

  if not ACommandLineGitAvailable then
  begin
    AError := 'No command-line git available';
    Exit(False);
  end;

  Result := ExecuteGitCliAction('git fetch', ['fetch', ARemote],
    ARepoPath, AExecuteGitCli, AError);
end;

function ExecuteGitPullSurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Pull: TGitSyncPullLibgit2Func;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;
var
  LNeedsFallback: Boolean;
begin
  Result := False;
  AError := '';

  if ABackend = gbNone then
  begin
    AError := 'No Git backend available';
    Exit(False);
  end;

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Pull) then
  begin
    try
      LNeedsFallback := False;
      Result := ALibgit2Pull(ARepoPath, AError, LNeedsFallback, True);
      if Result then
        Exit(True);

      if not LNeedsFallback then
        Exit(False);

      if not ACommandLineGitAvailable then
      begin
        if AError = '' then
          AError := 'Non-fast-forward update requires command-line git; please install git';
        Exit(False);
      end;
    except
      // Fall back to command-line pull.
    end;
  end;

  if not ACommandLineGitAvailable then
  begin
    AError := 'No command-line git available';
    Exit(False);
  end;

  Result := ExecuteGitCliAction('git pull', ['pull'],
    ARepoPath, AExecuteGitCli, AError);
end;

function ExecuteGitPullFastForwardOnlySurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Pull: TGitSyncPullLibgit2Func;
  AExecuteGitCli: TGitSyncCliRunnerFunc;
  out AError: string
): Boolean;
var
  LNeedsFallback: Boolean;
begin
  Result := False;
  AError := '';

  if ABackend = gbNone then
  begin
    AError := 'No Git backend available';
    Exit(False);
  end;

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Pull) then
  begin
    try
      LNeedsFallback := False;
      Result := ALibgit2Pull(ARepoPath, AError, LNeedsFallback, False);
      if Result then
        Exit(True);

      if not LNeedsFallback then
        Exit(False);

      if ClassifyGitPullFailure(AError) <> gpfkUnknown then
        Exit(False);

      if not ACommandLineGitAvailable then
      begin
        if AError = '' then
          AError := 'No command-line git available';
        Exit(False);
      end;
    except
      // Fall back to command-line ff-only pull.
    end;
  end;

  if not ACommandLineGitAvailable then
  begin
    if AError = '' then
      AError := 'No command-line git available';
    Exit(False);
  end;

  Result := ExecuteGitCliAction('git pull', ['pull', '--ff-only'],
    ARepoPath, AExecuteGitCli, AError);
end;

end.
