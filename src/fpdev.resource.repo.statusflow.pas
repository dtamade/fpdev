unit fpdev.resource.repo.statusflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.utils.process;

type
  TRepoStatusBoolFunc = function: Boolean of object;
  TRepoStatusStringFunc = function: string of object;
  TRepoCommitQueryFunc = function(const AWorkDir: string): TProcessResult of object;

function GetResourceRepoLastCommitHashCore(
  const ALocalPath: string;
  AIsGitRepository: TRepoStatusBoolFunc;
  AQueryShortHead: TRepoCommitQueryFunc
): string;

function FormatResourceRepoLastUpdateCheck(const ALastUpdateCheck: TDateTime): string;

function BuildResourceRepoStatusCore(
  const ALocalPath: string;
  const ALastUpdateCheck: TDateTime;
  AIsGitRepository: TRepoStatusBoolFunc;
  AGetLastCommitHash: TRepoStatusStringFunc
): string;

implementation

function GetResourceRepoLastCommitHashCore(
  const ALocalPath: string;
  AIsGitRepository: TRepoStatusBoolFunc;
  AQueryShortHead: TRepoCommitQueryFunc
): string;
var
  LResult: TProcessResult;
begin
  if (not Assigned(AIsGitRepository)) or (not AIsGitRepository()) then
    Exit('unknown');

  if not Assigned(AQueryShortHead) then
    Exit('unknown');

  LResult := AQueryShortHead(ALocalPath);
  if LResult.Success then
    Result := Trim(LResult.StdOut)
  else
    Result := 'unknown';
end;

function FormatResourceRepoLastUpdateCheck(const ALastUpdateCheck: TDateTime): string;
begin
  if ALastUpdateCheck = 0 then
    Exit('never');

  Result := DateTimeToStr(ALastUpdateCheck);
end;

function BuildResourceRepoStatusCore(
  const ALocalPath: string;
  const ALastUpdateCheck: TDateTime;
  AIsGitRepository: TRepoStatusBoolFunc;
  AGetLastCommitHash: TRepoStatusStringFunc
): string;
begin
  if (not Assigned(AIsGitRepository)) or (not AIsGitRepository()) then
    Exit('Not initialized');

  Result := 'Initialized at: ' + ALocalPath + LineEnding +
            'Commit: ' + AGetLastCommitHash() + LineEnding +
            'Last update check: ' + FormatResourceRepoLastUpdateCheck(ALastUpdateCheck);
end;

end.
