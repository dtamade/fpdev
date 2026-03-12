unit fpdev.build.fullbuildflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types,
  fpdev.build.pipeline;

type
  TBuildSummaryProc = procedure(
    const AVersion, AContext, AResult: string;
    AElapsedMs: Integer
  ) of object;

function RunFullBuildCore(
  const AVersion: string;
  APreflight, ABuildCompiler, ABuildRTL, ABuildPackages,
  AInstallPackages, AInstall, ATestResults: TBuildPhaseProc;
  ASetCurrentStep: TBuildStepSetterProc;
  ALogLine: TBuildLogLineProc;
  ALogSummary: TBuildSummaryProc
): Boolean;

implementation

uses
  SysUtils, DateUtils;

function RunFullBuildCore(
  const AVersion: string;
  APreflight, ABuildCompiler, ABuildRTL, ABuildPackages,
  AInstallPackages, AInstall, ATestResults: TBuildPhaseProc;
  ASetCurrentStep: TBuildStepSetterProc;
  ALogLine: TBuildLogLineProc;
  ALogSummary: TBuildSummaryProc
): Boolean;
var
  LStart: TDateTime;
  LMs: Integer;
  LFailedPhase: string;
  LPhases: TBuildPhaseSpecArray;
begin
  LStart := Now;
  if Assigned(ALogLine) then
    ALogLine('== FullBuild START version=' + AVersion);

  LPhases := CreateDefaultBuildPhaseSequenceCore(
    APreflight,
    ABuildCompiler,
    ABuildRTL,
    ABuildPackages,
    AInstallPackages,
    AInstall,
    ATestResults
  );

  if not ExecuteBuildPhaseSequenceCore(
    AVersion,
    LPhases,
    ASetCurrentStep,
    ALogLine,
    LFailedPhase
  ) then
    Exit(False);

  if Assigned(ASetCurrentStep) then
    ASetCurrentStep(bsComplete);

  LMs := MilliSecondsBetween(Now, LStart);
  if Assigned(ALogLine) then
    ALogLine('== FullBuild END OK elapsed_ms=' + IntToStr(LMs));
  if Assigned(ALogSummary) then
    ALogSummary(AVersion, 'fullbuild', 'OK', LMs);
  Result := True;
end;

end.
