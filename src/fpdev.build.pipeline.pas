unit fpdev.build.pipeline;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types;

type
  TBuildPhaseProc = function(const AVersion: string): Boolean of object;
  TBuildStepSetterProc = procedure(AStep: TBuildStep) of object;
  TBuildLogLineProc = procedure(const ALine: string) of object;

  TBuildPhaseSpec = record
    ApplyBeforeStep: Boolean;
    BeforeStep: TBuildStep;
    AbortLabel: string;
    Handler: TBuildPhaseProc;
  end;

  TBuildPhaseSpecArray = array of TBuildPhaseSpec;

function CreateDefaultBuildPhaseSequenceCore(
  APreflight, ABuildCompiler, ABuildRTL, ABuildPackages,
  AInstallPackages, AInstall, ATestResults: TBuildPhaseProc
): TBuildPhaseSpecArray;

function ExecuteBuildPhaseSequenceCore(
  const AVersion: string;
  const APhases: array of TBuildPhaseSpec;
  ASetCurrentStep: TBuildStepSetterProc;
  ALogLine: TBuildLogLineProc;
  out AFailedPhase: string
): Boolean;

implementation

function CreateDefaultBuildPhaseSequenceCore(
  APreflight, ABuildCompiler, ABuildRTL, ABuildPackages,
  AInstallPackages, AInstall, ATestResults: TBuildPhaseProc
): TBuildPhaseSpecArray;
begin
  Initialize(Result);
  SetLength(Result, 10);

  Result[0].ApplyBeforeStep := False;
  Result[0].BeforeStep := bsIdle;
  Result[0].AbortLabel := 'Preflight';
  Result[0].Handler := APreflight;

  Result[1].ApplyBeforeStep := False;
  Result[1].BeforeStep := bsIdle;
  Result[1].AbortLabel := 'BuildCompiler';
  Result[1].Handler := ABuildCompiler;

  Result[2].ApplyBeforeStep := True;
  Result[2].BeforeStep := bsCompilerInstall;
  Result[2].AbortLabel := '';
  Result[2].Handler := nil;

  Result[3].ApplyBeforeStep := False;
  Result[3].BeforeStep := bsIdle;
  Result[3].AbortLabel := 'BuildRTL';
  Result[3].Handler := ABuildRTL;

  Result[4].ApplyBeforeStep := True;
  Result[4].BeforeStep := bsRTLInstall;
  Result[4].AbortLabel := '';
  Result[4].Handler := nil;

  Result[5].ApplyBeforeStep := False;
  Result[5].BeforeStep := bsIdle;
  Result[5].AbortLabel := 'BuildPackages';
  Result[5].Handler := ABuildPackages;

  Result[6].ApplyBeforeStep := False;
  Result[6].BeforeStep := bsIdle;
  Result[6].AbortLabel := 'InstallPackages';
  Result[6].Handler := AInstallPackages;

  Result[7].ApplyBeforeStep := False;
  Result[7].BeforeStep := bsIdle;
  Result[7].AbortLabel := 'Install';
  Result[7].Handler := AInstall;

  Result[8].ApplyBeforeStep := True;
  Result[8].BeforeStep := bsVerify;
  Result[8].AbortLabel := '';
  Result[8].Handler := nil;

  Result[9].ApplyBeforeStep := False;
  Result[9].BeforeStep := bsIdle;
  Result[9].AbortLabel := 'TestResults';
  Result[9].Handler := ATestResults;
end;

function ExecuteBuildPhaseSequenceCore(
  const AVersion: string;
  const APhases: array of TBuildPhaseSpec;
  ASetCurrentStep: TBuildStepSetterProc;
  ALogLine: TBuildLogLineProc;
  out AFailedPhase: string
): Boolean;
var
  I: Integer;
begin
  AFailedPhase := '';

  for I := Low(APhases) to High(APhases) do
  begin
    if APhases[I].ApplyBeforeStep and Assigned(ASetCurrentStep) then
      ASetCurrentStep(APhases[I].BeforeStep);

    if not Assigned(APhases[I].Handler) then
      Continue;

    if not APhases[I].Handler(AVersion) then
    begin
      AFailedPhase := APhases[I].AbortLabel;
      if Assigned(ALogLine) then
        ALogLine('== FullBuild ABORT at ' + AFailedPhase);
      if Assigned(ASetCurrentStep) then
        ASetCurrentStep(bsIdle);
      Exit(False);
    end;
  end;

  Result := True;
end;

end.
