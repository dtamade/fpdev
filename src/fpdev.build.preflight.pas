unit fpdev.build.preflight;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TBuildPreflightInputs = record
    Version: string;
    SourcePath: string;
    SandboxRoot: string;
    LogDir: string;
    SandboxDestRoot: string;
    ToolchainStrict: Boolean;
    AllowInstall: Boolean;
    HasMake: Boolean;
    SourceExists: Boolean;
    SandboxWritable: Boolean;
    LogWritable: Boolean;
    SandboxDestExists: Boolean;
    SandboxDestWritable: Boolean;
    PolicyCheckPassed: Boolean;
    PolicyStatus: string;
    PolicyReason: string;
    PolicyMin: string;
    PolicyRecommended: string;
    CurrentFpcVersion: string;
    ToolchainReportJSON: string;
  end;

function CollectBuildPreflightIssuesCore(
  const AInputs: TBuildPreflightInputs): TStringArray;
function FormatBuildPreflightLogLinesCore(
  const AIssues: TStringArray;
  AVerbosity: Integer
): TStringArray;
function FormatBuildPreflightFailureLogLinesCore(
  const AIssues: TStringArray;
  AVerbosity: Integer
): TStringArray;

implementation

function CollectBuildPreflightIssuesCore(
  const AInputs: TBuildPreflightInputs): TStringArray;

  procedure AddIssue(const AIssue: string);
  var
    Index: Integer;
  begin
    Index := Length(Result);
    SetLength(Result, Index + 1);
    Result[Index] := AIssue;
  end;

begin
  Initialize(Result);
  SetLength(Result, 0);

  if not AInputs.SourceExists then
    AddIssue('source not found: ' + AInputs.SourcePath);

  if AInputs.ToolchainStrict then
  begin
    if not AInputs.PolicyCheckPassed then
      AddIssue(Format(
        'fpc policy FAIL: src=%s current=%s min=%s rec=%s reason=%s',
        [
          AInputs.Version,
          AInputs.CurrentFpcVersion,
          AInputs.PolicyMin,
          AInputs.PolicyRecommended,
          AInputs.PolicyReason
        ]
      ));
    if Pos('"level":"FAIL"', AInputs.ToolchainReportJSON) > 0 then
      AddIssue('toolchain check failed');
  end
  else if not AInputs.HasMake then
    AddIssue('make not available');

  if not AInputs.SandboxWritable then
    AddIssue('sandbox not writable: ' + AInputs.SandboxRoot);
  if not AInputs.LogWritable then
    AddIssue('logs not writable: ' + AInputs.LogDir);

  if AInputs.AllowInstall then
  begin
    if not AInputs.SandboxDestExists then
      AddIssue('cannot create sandbox dest: ' + AInputs.SandboxDestRoot)
    else if not AInputs.SandboxDestWritable then
      AddIssue('sandbox dest not writable: ' + AInputs.SandboxDestRoot);
  end;
end;

function FormatBuildPreflightLogLinesCore(
  const AIssues: TStringArray;
  AVerbosity: Integer
): TStringArray;
begin
  Initialize(Result);
  if Length(AIssues) = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := '== Preflight END OK';
    Exit;
  end;

  Result := FormatBuildPreflightFailureLogLinesCore(AIssues, AVerbosity);
end;

function FormatBuildPreflightFailureLogLinesCore(
  const AIssues: TStringArray;
  AVerbosity: Integer
): TStringArray;
var
  I: Integer;
begin
  Initialize(Result);
  SetLength(Result, 1);
  Result[0] := '== Preflight END FAIL issues=' + IntToStr(Length(AIssues));

  if AVerbosity <= 0 then
    Exit;

  SetLength(Result, Length(AIssues) + 1);
  for I := 0 to High(AIssues) do
    Result[I + 1] := 'issue: ' + AIssues[I];
end;

end.
