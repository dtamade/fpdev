unit fpdev.git.operations.mutationflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.git.types, fpdev.utils.process;

type
  TGitMutationCliRunnerFunc = function(const AParams: array of string;
    const AWorkDir: string): TProcessResult of object;
  TGitMutationCheckoutLibgit2Func = function(const ARepoPath, AName: string;
    const AForce: Boolean; out AError: string): Boolean of object;
  TGitMutationAddAllLibgit2Func = function(const ARepoPath: string;
    out AError: string; out ANeedsFallback: Boolean): Boolean of object;
  TGitMutationAddPathspecLibgit2Func = function(const ARepoPath,
    APathSpec: string; out AError: string;
    out ANeedsFallback: Boolean): Boolean of object;
  TGitMutationCommitLibgit2Func = function(const ARepoPath, AMessage: string;
    out AError: string; out ANeedsFallback: Boolean): Boolean of object;
  TGitMutationPushLibgit2Func = function(const ARepoPath, ARemote, ABranch: string;
    out AError: string; out ANeedsFallback: Boolean): Boolean of object;
  TGitMutationCurrentBranchFunc = function(const ARepoPath: string): string of object;

function ExecuteGitCheckoutSurfaceCore(
  const ARepoPath, AName: string;
  const AForce: Boolean;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Checkout: TGitMutationCheckoutLibgit2Func;
  AExecuteGitCli: TGitMutationCliRunnerFunc;
  out AError: string
): Boolean;

function ExecuteGitAddSurfaceCore(
  const ARepoPath, APathSpec: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2AddAll: TGitMutationAddAllLibgit2Func;
  ALibgit2AddPathspec: TGitMutationAddPathspecLibgit2Func;
  AExecuteGitCli: TGitMutationCliRunnerFunc;
  out AError: string
): Boolean;

function ExecuteGitCommitSurfaceCore(
  const ARepoPath, AMessage: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Commit: TGitMutationCommitLibgit2Func;
  AExecuteGitCli: TGitMutationCliRunnerFunc;
  out AError: string
): Boolean;

function ExecuteGitPushSurfaceCore(
  const ARepoPath, ARemote, ABranch: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Push: TGitMutationPushLibgit2Func;
  AGetCurrentBranch: TGitMutationCurrentBranchFunc;
  AExecuteGitCli: TGitMutationCliRunnerFunc;
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
  AExecuteGitCli: TGitMutationCliRunnerFunc;
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

function CliRefExists(const ARepoPath, ARefName: string;
  AExecuteGitCli: TGitMutationCliRunnerFunc): Boolean;
var
  LResult: TProcessResult;
begin
  Result := False;
  if (Trim(ARefName) = '') or (not Assigned(AExecuteGitCli)) then
    Exit(False);
  LResult := AExecuteGitCli(['show-ref', '--verify', '--quiet', ARefName], ARepoPath);
  Result := LResult.Success and (LResult.ExitCode = 0);
end;

function ExecuteGitCheckoutSurfaceCore(
  const ARepoPath, AName: string;
  const AForce: Boolean;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Checkout: TGitMutationCheckoutLibgit2Func;
  AExecuteGitCli: TGitMutationCliRunnerFunc;
  out AError: string
): Boolean;
var
  LCheckoutTarget: string;
  LDetach: Boolean;
  LCreateLocalBranch: Boolean;
  LCheckoutStartPoint: string;
begin
  Result := False;
  AError := '';

  if Trim(AName) = '' then
    Exit(True);

  if ABackend = gbNone then
  begin
    AError := 'No Git backend available';
    Exit(False);
  end;

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Checkout) then
  begin
    try
      Result := ALibgit2Checkout(ARepoPath, AName, AForce, AError);
      if Result then
        Exit(True);
    except
      // Fall back to command-line checkout.
    end;
  end;

  if not ACommandLineGitAvailable then
  begin
    if AError = '' then
      AError := 'No command-line git available';
    Exit(False);
  end;

  LCheckoutTarget := AName;
  LDetach := False;
  LCreateLocalBranch := False;
  LCheckoutStartPoint := '';

  if Pos('refs/', AName) = 1 then
  begin
    if Pos('refs/heads/', AName) = 1 then
      LCheckoutTarget := Copy(AName, Length('refs/heads/') + 1, MaxInt)
    else if (Pos('refs/remotes/', AName) = 1) or (Pos('refs/tags/', AName) = 1) then
      LDetach := True;
  end
  else
  begin
    if CliRefExists(ARepoPath, 'refs/heads/' + AName, AExecuteGitCli) then
      LCheckoutTarget := AName
    else if CliRefExists(ARepoPath, 'refs/remotes/origin/' + AName, AExecuteGitCli) then
    begin
      LCheckoutTarget := AName;
      LCheckoutStartPoint := 'origin/' + AName;
      LCreateLocalBranch := True;
    end
    else if CliRefExists(ARepoPath, 'refs/tags/' + AName, AExecuteGitCli) then
    begin
      LCheckoutTarget := 'refs/tags/' + AName;
      LDetach := True;
    end;
  end;

  if LCreateLocalBranch then
  begin
    if AForce then
      Exit(ExecuteGitCliAction('git checkout',
        ['checkout', '-f', '-B', LCheckoutTarget, LCheckoutStartPoint],
        ARepoPath, AExecuteGitCli, AError))
    else
      Exit(ExecuteGitCliAction('git checkout',
        ['checkout', '-b', LCheckoutTarget, LCheckoutStartPoint],
        ARepoPath, AExecuteGitCli, AError));
  end;

  if AForce then
  begin
    if LDetach then
      Exit(ExecuteGitCliAction('git checkout',
        ['checkout', '-f', '--detach', LCheckoutTarget],
        ARepoPath, AExecuteGitCli, AError))
    else
      Exit(ExecuteGitCliAction('git checkout',
        ['checkout', '-f', LCheckoutTarget],
        ARepoPath, AExecuteGitCli, AError));
  end;

  if LDetach then
    Result := ExecuteGitCliAction('git checkout',
      ['checkout', '--detach', LCheckoutTarget],
      ARepoPath, AExecuteGitCli, AError)
  else
    Result := ExecuteGitCliAction('git checkout',
      ['checkout', LCheckoutTarget],
      ARepoPath, AExecuteGitCli, AError);
end;

function ExecuteGitAddSurfaceCore(
  const ARepoPath, APathSpec: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2AddAll: TGitMutationAddAllLibgit2Func;
  ALibgit2AddPathspec: TGitMutationAddPathspecLibgit2Func;
  AExecuteGitCli: TGitMutationCliRunnerFunc;
  out AError: string
): Boolean;
var
  LNeedsFallback: Boolean;
  LPathSpec: string;
begin
  Result := False;
  AError := '';

  if ABackend = gbNone then
  begin
    AError := 'No Git backend available';
    Exit(False);
  end;

  if Trim(ARepoPath) = '' then
  begin
    AError := 'Repository path is empty';
    Exit(False);
  end;

  if Trim(APathSpec) = '' then
  begin
    AError := 'Pathspec is empty';
    Exit(False);
  end;

  LPathSpec := Trim(APathSpec);

  if (LPathSpec = '.') and (ABackend = gbLibgit2) and Assigned(ALibgit2AddAll) then
  begin
    LNeedsFallback := False;
    Result := ALibgit2AddAll(ARepoPath, AError, LNeedsFallback);
    if Result then
      Exit(True);
    if not LNeedsFallback then
    begin
      if AError = '' then
        AError := 'libgit2 add-all failed';
      Exit(False);
    end;
  end;

  if (LPathSpec <> '.') and (ABackend = gbLibgit2) and Assigned(ALibgit2AddPathspec) then
  begin
    LNeedsFallback := False;
    Result := ALibgit2AddPathspec(ARepoPath, APathSpec, AError, LNeedsFallback);
    if Result then
      Exit(True);
    if not LNeedsFallback then
    begin
      if AError = '' then
        AError := 'libgit2 add failed';
      Exit(False);
    end;
  end;

  if not ACommandLineGitAvailable then
  begin
    if AError = '' then
      AError := 'No command-line git available';
    Exit(False);
  end;

  if LPathSpec = '.' then
    Result := ExecuteGitCliAction('git add', ['add', '-A'], ARepoPath, AExecuteGitCli, AError)
  else
    Result := ExecuteGitCliAction('git add', ['add', APathSpec], ARepoPath, AExecuteGitCli, AError);
end;

function ExecuteGitCommitSurfaceCore(
  const ARepoPath, AMessage: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Commit: TGitMutationCommitLibgit2Func;
  AExecuteGitCli: TGitMutationCliRunnerFunc;
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

  if Trim(ARepoPath) = '' then
  begin
    AError := 'Repository path is empty';
    Exit(False);
  end;

  if Trim(AMessage) = '' then
  begin
    AError := 'Commit message is empty';
    Exit(False);
  end;

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Commit) then
  begin
    LNeedsFallback := False;
    Result := ALibgit2Commit(ARepoPath, AMessage, AError, LNeedsFallback);
    if Result then
      Exit(True);
    if not LNeedsFallback then
    begin
      if AError = '' then
        AError := 'libgit2 commit failed';
      Exit(False);
    end;
  end;

  if not ACommandLineGitAvailable then
  begin
    if AError = '' then
      AError := 'Command-line git is required for commit; please install git';
    Exit(False);
  end;

  Result := ExecuteGitCliAction('git commit', ['commit', '-m', AMessage],
    ARepoPath, AExecuteGitCli, AError);
end;

function ExecuteGitPushSurfaceCore(
  const ARepoPath, ARemote, ABranch: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Push: TGitMutationPushLibgit2Func;
  AGetCurrentBranch: TGitMutationCurrentBranchFunc;
  AExecuteGitCli: TGitMutationCliRunnerFunc;
  out AError: string
): Boolean;
var
  LNeedsFallback: Boolean;
  LRemoteName: string;
  LBranchParam: string;
begin
  Result := False;
  AError := '';

  if ABackend = gbNone then
  begin
    AError := 'No Git backend available';
    Exit(False);
  end;

  if Trim(ARepoPath) = '' then
  begin
    AError := 'Repository path is empty';
    Exit(False);
  end;

  LRemoteName := Trim(ARemote);
  if LRemoteName = '' then
    LRemoteName := 'origin';

  LBranchParam := ABranch;
  if (Trim(LBranchParam) = '') and Assigned(AGetCurrentBranch) then
    LBranchParam := AGetCurrentBranch(ARepoPath);
  if Trim(LBranchParam) = '' then
    LBranchParam := 'HEAD';

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Push) then
  begin
    LNeedsFallback := False;
    Result := ALibgit2Push(ARepoPath, LRemoteName, LBranchParam, AError, LNeedsFallback);
    if Result then
      Exit(True);
    if not LNeedsFallback then
    begin
      if AError = '' then
        AError := 'libgit2 push failed';
      Exit(False);
    end;
  end;

  if not ACommandLineGitAvailable then
  begin
    if AError = '' then
      AError := 'Command-line git is required for push; please install git';
    Exit(False);
  end;

  Result := ExecuteGitCliAction('git push', ['push', LRemoteName, LBranchParam],
    ARepoPath, AExecuteGitCli, AError);
end;

end.
