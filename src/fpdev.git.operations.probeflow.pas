unit fpdev.git.operations.probeflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.git.types, fpdev.utils.process;

type
  TGitProbeDirectoryExistsFunc = function(const APath: string): Boolean of object;
  TGitProbeIsRepositoryFunc = function(const APath: string): Boolean of object;
  TGitProbeVersionFunc = function(out AVersion: string): Boolean of object;
  TGitProbeCliRunnerFunc = function(const AParams: array of string;
    const AWorkDir: string): TProcessResult of object;

function ExecuteGitIsRepositorySurfaceCore(
  const APath: string;
  ABackend: TGitBackend;
  ADirectoryExists: TGitProbeDirectoryExistsFunc;
  AIsRepositoryWithLibgit2: TGitProbeIsRepositoryFunc
): Boolean;

function ExecuteGitVersionSurfaceCore(
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ATryGetVersionWithLibgit2: TGitProbeVersionFunc;
  AExecuteGitCli: TGitProbeCliRunnerFunc;
  out AError: string
): string;

implementation

function ExecuteGitIsRepositorySurfaceCore(
  const APath: string;
  ABackend: TGitBackend;
  ADirectoryExists: TGitProbeDirectoryExistsFunc;
  AIsRepositoryWithLibgit2: TGitProbeIsRepositoryFunc
): Boolean;
var
  GitDir: string;
begin
  Result := False;

  GitDir := IncludeTrailingPathDelimiter(APath) + '.git';
  if Assigned(ADirectoryExists) and ADirectoryExists(GitDir) then
    Exit(True);

  if (ABackend = gbLibgit2) and Assigned(AIsRepositoryWithLibgit2) then
  begin
    try
      Result := AIsRepositoryWithLibgit2(APath);
    except
      Result := False;
    end;
  end;
end;

function ExecuteGitVersionSurfaceCore(
  ABackend: TGitBackend;
  ACommandLineGitAvailable: Boolean;
  ATryGetVersionWithLibgit2: TGitProbeVersionFunc;
  AExecuteGitCli: TGitProbeCliRunnerFunc;
  out AError: string
): string;
var
  LResult: TProcessResult;
begin
  Result := '';
  AError := '';

  if (ABackend = gbLibgit2) and Assigned(ATryGetVersionWithLibgit2) then
    if ATryGetVersionWithLibgit2(Result) then
      Exit(Result);

  if not ACommandLineGitAvailable then
  begin
    AError := 'No command-line git available';
    Exit('');
  end;

  if not Assigned(AExecuteGitCli) then
  begin
    AError := 'No command-line git available';
    Exit('');
  end;

  LResult := AExecuteGitCli(['--version'], '');
  if LResult.Success then
    Result := Trim(LResult.StdOut)
  else if LResult.StdErr <> '' then
    AError := Trim(LResult.StdErr)
  else if LResult.ErrorMessage <> '' then
    AError := Trim(LResult.ErrorMessage)
  else
    AError := 'git --version failed (exit code ' + IntToStr(LResult.ExitCode) + ')';
end;

end.
