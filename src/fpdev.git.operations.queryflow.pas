unit fpdev.git.operations.queryflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.git.types, fpdev.utils.process;

type
  TGitQueryCliRunnerFunc = function(const AParams: array of string;
    const AWorkDir: string): TProcessResult of object;
  TGitQueryBooleanLibgit2Func = function(const ARepoPath: string;
    out AValue: Boolean): Boolean of object;
  TGitQueryStringLibgit2Func = function(const ARepoPath: string;
    out AValue: string): Boolean of object;
  TGitQueryStringArrayLibgit2Func = function(const ARepoPath: string;
    out AValues: TStringArray): Boolean of object;
  TGitQueryRemoteStringLibgit2Func = function(const ARepoPath, ARemote: string;
    out AValue: string): Boolean of object;
  TGitQueryRemoteStringArrayLibgit2Func = function(
    const ARepoPath, ARemote: string; out AValues: TStringArray
  ): Boolean of object;

function ExecuteGitHasRemoteSurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryBooleanLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc
): Boolean;

function ExecuteGitRemoteURLSurfaceCore(
  const ARepoPath, ARemote: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryRemoteStringLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc;
  out AError: string
): string;

function ExecuteGitCurrentBranchSurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryStringLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc
): string;

function ExecuteGitShortHeadHashSurfaceCore(
  const ARepoPath: string;
  const ALength: Integer;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryStringLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc;
  out AError: string
): string;

function ExecuteGitListBranchesSurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryStringArrayLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc;
  out AError: string
): TStringArray;

function ExecuteGitListRemoteBranchesSurfaceCore(
  const ARepoPath, ARemote: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryRemoteStringArrayLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc;
  out AError: string
): TStringArray;

implementation

function NormalizeCurrentBranchValue(const ARaw: string): string;
begin
  Result := Trim(ARaw);
  if Pos('refs/heads/', Result) = 1 then
    Result := Copy(Result, Length('refs/heads/') + 1, MaxInt)
  else if Pos('heads/', Result) = 1 then
    Result := Copy(Result, Length('heads/') + 1, MaxInt);
end;

function NormalizeBranchRef(const ARef: string): string;
var
  LValue: string;
  LSlashPos: Integer;
begin
  Result := '';
  LValue := Trim(ARef);
  if LValue = '' then
    Exit('');

  if Pos('refs/heads/', LValue) = 1 then
    LValue := Copy(LValue, Length('refs/heads/') + 1, MaxInt)
  else if Pos('refs/remotes/', LValue) = 1 then
  begin
    LValue := Copy(LValue, Length('refs/remotes/') + 1, MaxInt);
    LSlashPos := Pos('/', LValue);
    if LSlashPos > 0 then
      LValue := Copy(LValue, LSlashPos + 1, MaxInt);
  end
  else if Pos('heads/', LValue) = 1 then
    LValue := Copy(LValue, Length('heads/') + 1, MaxInt)
  else if Pos('remotes/', LValue) = 1 then
  begin
    LValue := Copy(LValue, Length('remotes/') + 1, MaxInt);
    LSlashPos := Pos('/', LValue);
    if LSlashPos > 0 then
      LValue := Copy(LValue, LSlashPos + 1, MaxInt);
  end;

  if (LValue = '') or SameText(LValue, 'HEAD') then
    Exit('');

  Result := LValue;
end;

procedure AddUniqueValue(AList: TStringList; const AValue: string);
var
  i: Integer;
begin
  if (AList = nil) or (Trim(AValue) = '') then
    Exit;
  for i := 0 to AList.Count - 1 do
    if SameText(AList[i], AValue) then
      Exit;
  AList.Add(AValue);
end;

function BuildArrayFromList(AList: TStringList): TStringArray;
var
  i: Integer;
begin
  if AList = nil then
    Exit(nil);
  SetLength(Result, AList.Count);
  for i := 0 to AList.Count - 1 do
    Result[i] := AList[i];
end;

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

procedure CollectNormalizedBranches(const ARefs: TStringArray; AList: TStringList);
var
  i: Integer;
  LName: string;
begin
  if AList = nil then
    Exit;
  for i := 0 to High(ARefs) do
  begin
    LName := NormalizeBranchRef(ARefs[i]);
    if LName <> '' then
      AddUniqueValue(AList, LName);
  end;
end;

procedure CollectRemoteBranches(const ARefs: TStringArray; const ARemote: string;
  AList: TStringList);
var
  i: Integer;
  LLine: string;
  LPrefix: string;
begin
  if (AList = nil) or (Trim(ARemote) = '') then
    Exit;
  LPrefix := 'refs/remotes/' + ARemote + '/';
  for i := 0 to High(ARefs) do
  begin
    LLine := Trim(ARefs[i]);
    if (LLine = '') or (Pos(LPrefix, LLine) <> 1) then
      Continue;
    LLine := Copy(LLine, Length(LPrefix) + 1, MaxInt);
    if (LLine = '') or SameText(LLine, 'HEAD') then
      Continue;
    AddUniqueValue(AList, LLine);
  end;
end;

function ExecuteGitHasRemoteSurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryBooleanLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc
): Boolean;
var
  LValue: Boolean;
  LResult: TProcessResult;
begin
  Result := False;

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Query) then
  begin
    try
      if ALibgit2Query(ARepoPath, LValue) then
        Exit(LValue);
    except
      // Fall back to command-line when libgit2 query fails.
    end;
  end;

  if (not ACommandLineGitAvailable) or (not Assigned(AExecuteGitCli)) then
    Exit(False);

  LResult := AExecuteGitCli(['remote'], ARepoPath);
  if LResult.Success then
    Result := Trim(LResult.StdOut) <> '';
end;

function ExecuteGitRemoteURLSurfaceCore(
  const ARepoPath, ARemote: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryRemoteStringLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc;
  out AError: string
): string;
var
  LResult: TProcessResult;
  LValue: string;
begin
  Result := '';
  AError := '';

  if Trim(ARemote) = '' then
    Exit('');

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Query) then
  begin
    try
      if ALibgit2Query(ARepoPath, ARemote, LValue) then
      begin
        Result := Trim(LValue);
        if Result <> '' then
          Exit(Result);
      end;
    except
      // Fall back to command-line when libgit2 remote lookup fails.
    end;
  end;

  if (not ACommandLineGitAvailable) or (not Assigned(AExecuteGitCli)) then
    Exit('');

  LResult := AExecuteGitCli(['remote', 'get-url', ARemote], ARepoPath);
  if LResult.Success then
    Result := Trim(LResult.StdOut)
  else
    SetErrorFromProcessResult('git remote get-url', LResult, AError);
end;

function ExecuteGitCurrentBranchSurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryStringLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc
): string;
var
  LValue: string;
  LResult: TProcessResult;
begin
  Result := '';

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Query) then
  begin
    try
      if ALibgit2Query(ARepoPath, LValue) then
      begin
        Result := NormalizeCurrentBranchValue(LValue);
        if Result <> '' then
          Exit(Result);
      end;
    except
      // Fall back to command-line when libgit2 branch lookup fails.
    end;
  end;

  if (not ACommandLineGitAvailable) or (not Assigned(AExecuteGitCli)) then
    Exit('');

  LResult := AExecuteGitCli(['symbolic-ref', '--quiet', 'HEAD'], ARepoPath);
  if LResult.Success then
  begin
    Result := NormalizeCurrentBranchValue(LResult.StdOut);
    if Result <> '' then
      Exit(Result);
  end;

  LResult := AExecuteGitCli(['rev-parse', '--abbrev-ref', 'HEAD'], ARepoPath);
  if LResult.Success then
    Result := NormalizeCurrentBranchValue(LResult.StdOut);
end;

function ExecuteGitShortHeadHashSurfaceCore(
  const ARepoPath: string;
  const ALength: Integer;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryStringLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc;
  out AError: string
): string;
var
  LValue: string;
  LLen: Integer;
  LResult: TProcessResult;
begin
  Result := '';
  AError := '';
  if ALength <= 0 then
    Exit('');

  if (ABackend = gbLibgit2) and Assigned(ALibgit2Query) then
  begin
    try
      if ALibgit2Query(ARepoPath, LValue) then
      begin
        LLen := ALength;
        if LLen > Length(LValue) then
          LLen := Length(LValue);
        Result := Copy(LValue, 1, LLen);
        if Result <> '' then
          Exit(Result);
      end;
    except
      // Fall back to command-line when libgit2 hash query fails.
    end;
  end;

  if (not ACommandLineGitAvailable) or (not Assigned(AExecuteGitCli)) then
  begin
    AError := 'No command-line git available';
    Exit('');
  end;

  if ALength >= 40 then
    LResult := AExecuteGitCli(['rev-parse', 'HEAD'], ARepoPath)
  else
    LResult := AExecuteGitCli(['rev-parse', '--short=' + IntToStr(ALength), 'HEAD'], ARepoPath);

  if LResult.Success then
    Result := Trim(LResult.StdOut)
  else
    SetErrorFromProcessResult('git rev-parse', LResult, AError);
end;

function ExecuteGitListBranchesSurfaceCore(
  const ARepoPath: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryStringArrayLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc;
  out AError: string
): TStringArray;
var
  LRefs: TStringArray;
  LList: TStringList;
  LResult: TProcessResult;
begin
  Result := nil;
  AError := '';
  LList := TStringList.Create;
  try
    if (ABackend = gbLibgit2) and Assigned(ALibgit2Query) then
    begin
      try
        if ALibgit2Query(ARepoPath, LRefs) then
        begin
          CollectNormalizedBranches(LRefs, LList);
          Exit(BuildArrayFromList(LList));
        end;
      except
        // Fall back to command-line.
      end;
    end;

    if (not ACommandLineGitAvailable) or (not Assigned(AExecuteGitCli)) then
    begin
      AError := 'No command-line git available';
      Exit(nil);
    end;

    LResult := AExecuteGitCli(['for-each-ref', '--format=%(refname)', 'refs/heads', 'refs/remotes'], ARepoPath);
    if not LResult.Success then
    begin
      SetErrorFromProcessResult('git for-each-ref', LResult, AError);
      Exit(nil);
    end;

    LRefs := LResult.StdOut.Split([#10, #13]);
    CollectNormalizedBranches(LRefs, LList);
    Result := BuildArrayFromList(LList);
  finally
    LList.Free;
  end;
end;

function ExecuteGitListRemoteBranchesSurfaceCore(
  const ARepoPath, ARemote: string;
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ALibgit2Query: TGitQueryRemoteStringArrayLibgit2Func;
  AExecuteGitCli: TGitQueryCliRunnerFunc;
  out AError: string
): TStringArray;
var
  LRefs: TStringArray;
  LList: TStringList;
  LLine: string;
  LPrefix: string;
  LResult: TProcessResult;
  i: Integer;
begin
  Result := nil;
  AError := '';

  if Trim(ARemote) = '' then
    Exit(nil);

  LList := TStringList.Create;
  try
    if (ABackend = gbLibgit2) and Assigned(ALibgit2Query) then
    begin
      try
        if ALibgit2Query(ARepoPath, ARemote, LRefs) then
        begin
          CollectRemoteBranches(LRefs, ARemote, LList);
          Exit(BuildArrayFromList(LList));
        end;
      except
        // Fall back to command-line.
      end;
    end;

    if (not ACommandLineGitAvailable) or (not Assigned(AExecuteGitCli)) then
    begin
      AError := 'No command-line git available';
      Exit(nil);
    end;

    LResult := AExecuteGitCli(['branch', '-r'], ARepoPath);
    if not LResult.Success then
    begin
      SetErrorFromProcessResult('git branch -r', LResult, AError);
      Exit(nil);
    end;

    LRefs := LResult.StdOut.Split([#10, #13]);
    LPrefix := ARemote + '/';
    for i := 0 to High(LRefs) do
    begin
      LLine := Trim(LRefs[i]);
      if (LLine = '') or (Pos('->', LLine) > 0) or (Pos(LPrefix, LLine) <> 1) then
        Continue;
      LLine := Copy(LLine, Length(LPrefix) + 1, MaxInt);
      if (LLine = '') or SameText(LLine, 'HEAD') then
        Continue;
      AddUniqueValue(LList, LLine);
    end;

    Result := BuildArrayFromList(LList);
  finally
    LList.Free;
  end;
end;

end.
