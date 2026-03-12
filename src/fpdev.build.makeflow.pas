unit fpdev.build.makeflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types,
  fpdev.build.pipeline;

type
  TBuildMakeTargetArray = array of string;

  TBuildEnvSnapshotProc = procedure of object;
  TBuildEnsureDirProc = procedure(const APath: string) of object;
  TBuildPerfStartProc = procedure(const AOperation, ACategory: string) of object;
  TBuildPerfMetadataProc = procedure(const AOperation, AMetadata: string) of object;
  TBuildPerfEndProc = procedure(const AOperation: string; ASuccess: Boolean) of object;
  TBuildMakeRunner = function(
    const ASourcePath: string;
    const ATargets: TBuildMakeTargetArray
  ): Boolean of object;

  TBuildMakeStepPlan = record
    ApplyBeforeStep: Boolean;
    BeforeStep: TBuildStep;
    RequiresInstallAllowed: Boolean;
    SkipMessage: string;
    OperationName: string;
    Version: string;
    SourcePath: string;
    DestPath: string;
    PerfMetadata: string;
    Targets: TBuildMakeTargetArray;
  end;

function CreateBuildCompilerStepPlanCore(
  const AVersion, ASourcePath: string
): TBuildMakeStepPlan;

function CreateBuildRTLStepPlanCore(
  const AVersion, ASourcePath: string
): TBuildMakeStepPlan;

function CreateBuildPackagesStepPlanCore(
  const AVersion, ASourcePath: string
): TBuildMakeStepPlan;

function CreateBuildInstallPackagesStepPlanCore(
  const AVersion, ASourcePath, ADestPath: string
): TBuildMakeStepPlan;

function CreateBuildInstallStepPlanCore(
  const AVersion, ASourcePath, ADestPath: string
): TBuildMakeStepPlan;

function ExecuteBuildMakeStepCore(
  const APlan: TBuildMakeStepPlan;
  AAllowInstall: Boolean;
  AVerbosity: Integer;
  ASetCurrentStep: TBuildStepSetterProc;
  AEnsureDir: TBuildEnsureDirProc;
  ARunMake: TBuildMakeRunner;
  ALogLine: TBuildLogLineProc;
  ALogEnvSnapshot: TBuildEnvSnapshotProc;
  APerfStart: TBuildPerfStartProc;
  APerfMetadata: TBuildPerfMetadataProc;
  APerfEnd: TBuildPerfEndProc
): Boolean;

implementation

uses
  SysUtils, DateUtils;

function BuildBaseMakeStepPlan(
  const AOperationName, AVersion, ASourcePath: string;
  AApplyBeforeStep: Boolean;
  ABeforeStep: TBuildStep
): TBuildMakeStepPlan;
begin
  Result := Default(TBuildMakeStepPlan);
  Result.OperationName := AOperationName;
  Result.Version := AVersion;
  Result.SourcePath := ASourcePath;
  Result.ApplyBeforeStep := AApplyBeforeStep;
  Result.BeforeStep := ABeforeStep;
  Result.PerfMetadata := 'version=' + AVersion;
end;

procedure SetMakeTargets(
  out ATargets: TBuildMakeTargetArray;
  const AValues: array of string
);
var
  I: Integer;
begin
  SetLength(ATargets, Length(AValues));
  for I := 0 to High(AValues) do
    ATargets[I] := AValues[I];
end;

function CreateBuildCompilerStepPlanCore(
  const AVersion, ASourcePath: string
): TBuildMakeStepPlan;
begin
  Result := BuildBaseMakeStepPlan(
    'BuildCompiler',
    AVersion,
    ASourcePath,
    True,
    bsCompiler
  );
  SetMakeTargets(Result.Targets, ['clean', 'compiler']);
end;

function CreateBuildRTLStepPlanCore(
  const AVersion, ASourcePath: string
): TBuildMakeStepPlan;
begin
  Result := BuildBaseMakeStepPlan(
    'BuildRTL',
    AVersion,
    ASourcePath,
    True,
    bsRTL
  );
  SetMakeTargets(Result.Targets, ['rtl']);
end;

function CreateBuildPackagesStepPlanCore(
  const AVersion, ASourcePath: string
): TBuildMakeStepPlan;
begin
  Result := BuildBaseMakeStepPlan(
    'BuildPackages',
    AVersion,
    ASourcePath,
    True,
    bsPackages
  );
  SetMakeTargets(Result.Targets, ['packages']);
end;

function CreateBuildInstallPackagesStepPlanCore(
  const AVersion, ASourcePath, ADestPath: string
): TBuildMakeStepPlan;
begin
  Result := BuildBaseMakeStepPlan(
    'InstallPackages',
    AVersion,
    ASourcePath,
    True,
    bsPackagesInstall
  );
  Result.RequiresInstallAllowed := True;
  Result.SkipMessage := 'InstallPackages skipped (FAllowInstall=False)';
  Result.DestPath := ADestPath;
  SetMakeTargets(Result.Targets, [
    'DESTDIR=' + ADestPath,
    'PREFIX=' + ADestPath,
    'INSTALL_PREFIX=' + ADestPath,
    'INSTALL_UNITDIR=' + ADestPath + PathDelim + 'units' + PathDelim + '$$(packagename)',
    'packages_install'
  ]);
end;

function CreateBuildInstallStepPlanCore(
  const AVersion, ASourcePath, ADestPath: string
): TBuildMakeStepPlan;
begin
  Result := BuildBaseMakeStepPlan(
    'Install',
    AVersion,
    ASourcePath,
    False,
    bsIdle
  );
  Result.RequiresInstallAllowed := True;
  Result.SkipMessage := 'Install skipped (FAllowInstall=False)';
  Result.DestPath := ADestPath;
  Result.PerfMetadata := 'version=' + AVersion + ',dest=' + ADestPath;
  SetMakeTargets(Result.Targets, [
    'DESTDIR=' + ADestPath,
    'PREFIX=' + ADestPath,
    'INSTALL_PREFIX=' + ADestPath,
    'install'
  ]);
end;

function BuildStartLine(const APlan: TBuildMakeStepPlan): string;
begin
  Result := '== ' + APlan.OperationName + ' START version=' + APlan.Version +
    ' src=' + APlan.SourcePath;
  if APlan.DestPath <> '' then
    Result := Result + ' dest=' + APlan.DestPath;
end;

function BuildEndLine(const APlan: TBuildMakeStepPlan; ASuccess: Boolean; AElapsedMs: Integer): string;
begin
  if ASuccess then
    Result := '== ' + APlan.OperationName + ' END OK elapsed_ms=' + IntToStr(AElapsedMs)
  else
    Result := '== ' + APlan.OperationName + ' END FAIL elapsed_ms=' + IntToStr(AElapsedMs);
end;

function ExecuteBuildMakeStepCore(
  const APlan: TBuildMakeStepPlan;
  AAllowInstall: Boolean;
  AVerbosity: Integer;
  ASetCurrentStep: TBuildStepSetterProc;
  AEnsureDir: TBuildEnsureDirProc;
  ARunMake: TBuildMakeRunner;
  ALogLine: TBuildLogLineProc;
  ALogEnvSnapshot: TBuildEnvSnapshotProc;
  APerfStart: TBuildPerfStartProc;
  APerfMetadata: TBuildPerfMetadataProc;
  APerfEnd: TBuildPerfEndProc
): Boolean;
var
  LStart: TDateTime;
  LMs: Integer;
begin
  if APlan.ApplyBeforeStep and Assigned(ASetCurrentStep) then
    ASetCurrentStep(APlan.BeforeStep);

  if APlan.RequiresInstallAllowed and (not AAllowInstall) then
  begin
    if Assigned(ALogLine) then
      ALogLine(APlan.SkipMessage);
    Exit(True);
  end;

  if (APlan.DestPath <> '') and Assigned(AEnsureDir) then
    AEnsureDir(APlan.DestPath);

  if Assigned(ALogLine) then
    ALogLine(BuildStartLine(APlan));
  if (AVerbosity > 0) and Assigned(ALogEnvSnapshot) then
    ALogEnvSnapshot;

  LStart := Now;
  if Assigned(APerfStart) then
    APerfStart(APlan.OperationName, 'Build');
  if Assigned(APerfMetadata) then
    APerfMetadata(APlan.OperationName, APlan.PerfMetadata);

  Result := Assigned(ARunMake) and ARunMake(APlan.SourcePath, APlan.Targets);

  if Assigned(APerfEnd) then
    APerfEnd(APlan.OperationName, Result);
  LMs := MilliSecondsBetween(Now, LStart);

  if Assigned(ALogLine) then
    ALogLine(BuildEndLine(APlan, Result, LMs));
end;

end.
