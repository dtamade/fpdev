unit fpdev.build.managerflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types,
  fpdev.build.makeflow,
  fpdev.build.pipeline,
  fpdev.build.preflightflow,
  fpdev.build.testresultsflow;

type
  TBuildManagerMakeOperation = (
    bmmBuildCompiler,
    bmmBuildRTL,
    bmmBuildPackages,
    bmmInstallPackages,
    bmmInstall
  );

  TBuildSummaryProc = procedure(
    const AVersion, AContext, AResult: string;
    AElapsedMs: Integer
  ) of object;

function ExecuteBuildManagerMakeOperationCore(
  AOperation: TBuildManagerMakeOperation;
  const AVersion, ASourcePath, ASandboxRoot: string;
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

function ExecuteBuildManagerTestResultsCore(
  const AVersion, ASandboxRoot: string;
  AAllowInstall, AStrictResults: Boolean;
  AVerbosity: Integer;
  AGetSourcePath: TBuildTestResultsSourcePathProc;
  AApplyStrictConfig: TBuildTestResultsStrictConfigProc;
  ADirectoryExists, ADirHasAnyFile, ADirHasAnyEntry: TBuildTestResultsPathCheckProc;
  ALogLine: TBuildTestResultsLogProc;
  ALogDirSample: TBuildTestResultsDirSampleProc;
  ALogSummary: TBuildTestResultsSummaryProc
): Boolean;

function ExecuteBuildManagerPreflightCore(
  const AVersion, ASourceRoot, ASourcePath, ASandboxRoot, ALogDir: string;
  AVerbosity: Integer;
  AToolchainStrict, AAllowInstall: Boolean;
  APolicyCheck: TBuildPreflightPolicyCheckFunc;
  ABuildToolchainJSON: TBuildPreflightToolchainJSONFunc;
  AHasMake: TBuildPreflightHasMakeFunc;
  ACanWriteDir: TBuildPreflightCanWriteDirFunc;
  ASetCurrentStep: TBuildStepSetterProc;
  ALogLine: TBuildLogLineProc;
  ALogEnvSnapshot: TBuildEnvSnapshotProc;
  APerfStart: TBuildPerfStartProc;
  APerfMetadata: TBuildPerfMetadataProc;
  APerfEnd: TBuildPerfEndProc;
  ALogSummary: TBuildSummaryProc
): Boolean;

implementation

uses
  SysUtils, DateUtils,
  fpdev.build.preflight;

function BuildManagerMakePlanCore(
  AOperation: TBuildManagerMakeOperation;
  const AVersion, ASourcePath, ASandboxRoot: string
): TBuildMakeStepPlan;
var
  LDest: string;
begin
  case AOperation of
    bmmBuildCompiler:
      Result := CreateBuildCompilerStepPlanCore(AVersion, ASourcePath);
    bmmBuildRTL:
      Result := CreateBuildRTLStepPlanCore(AVersion, ASourcePath);
    bmmBuildPackages:
      Result := CreateBuildPackagesStepPlanCore(AVersion, ASourcePath);
    bmmInstallPackages:
      begin
        LDest := IncludeTrailingPathDelimiter(ASandboxRoot) + 'fpc-' + AVersion;
        Result := CreateBuildInstallPackagesStepPlanCore(
          AVersion,
          ASourcePath,
          LDest
        );
      end;
    bmmInstall:
      begin
        LDest := IncludeTrailingPathDelimiter(ASandboxRoot) + 'fpc-' + AVersion;
        Result := CreateBuildInstallStepPlanCore(
          AVersion,
          ASourcePath,
          LDest
        );
      end;
  end;
end;

function ExecuteBuildManagerMakeOperationCore(
  AOperation: TBuildManagerMakeOperation;
  const AVersion, ASourcePath, ASandboxRoot: string;
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
  LPlan: TBuildMakeStepPlan;
begin
  LPlan := BuildManagerMakePlanCore(
    AOperation,
    AVersion,
    ASourcePath,
    ASandboxRoot
  );

  Result := ExecuteBuildMakeStepCore(
    LPlan,
    AAllowInstall,
    AVerbosity,
    ASetCurrentStep,
    AEnsureDir,
    ARunMake,
    ALogLine,
    ALogEnvSnapshot,
    APerfStart,
    APerfMetadata,
    APerfEnd
  );
end;

function ExecuteBuildManagerTestResultsCore(
  const AVersion, ASandboxRoot: string;
  AAllowInstall, AStrictResults: Boolean;
  AVerbosity: Integer;
  AGetSourcePath: TBuildTestResultsSourcePathProc;
  AApplyStrictConfig: TBuildTestResultsStrictConfigProc;
  ADirectoryExists, ADirHasAnyFile, ADirHasAnyEntry: TBuildTestResultsPathCheckProc;
  ALogLine: TBuildTestResultsLogProc;
  ALogDirSample: TBuildTestResultsDirSampleProc;
  ALogSummary: TBuildTestResultsSummaryProc
): Boolean;
begin
  Result := ExecuteBuildTestResultsCore(
    AVersion,
    ASandboxRoot,
    AAllowInstall,
    AStrictResults,
    AVerbosity,
    AGetSourcePath,
    AApplyStrictConfig,
    ADirectoryExists,
    ADirHasAnyFile,
    ADirHasAnyEntry,
    ALogLine,
    ALogDirSample,
    ALogSummary
  );
end;

function ExecuteBuildManagerPreflightCore(
  const AVersion, ASourceRoot, ASourcePath, ASandboxRoot, ALogDir: string;
  AVerbosity: Integer;
  AToolchainStrict, AAllowInstall: Boolean;
  APolicyCheck: TBuildPreflightPolicyCheckFunc;
  ABuildToolchainJSON: TBuildPreflightToolchainJSONFunc;
  AHasMake: TBuildPreflightHasMakeFunc;
  ACanWriteDir: TBuildPreflightCanWriteDirFunc;
  ASetCurrentStep: TBuildStepSetterProc;
  ALogLine: TBuildLogLineProc;
  ALogEnvSnapshot: TBuildEnvSnapshotProc;
  APerfStart: TBuildPerfStartProc;
  APerfMetadata: TBuildPerfMetadataProc;
  APerfEnd: TBuildPerfEndProc;
  ALogSummary: TBuildSummaryProc
): Boolean;
var
  LStart: TDateTime;
  LInputs: TBuildPreflightInputs;
  LIssues: TStringArray;
  LFailureLines: TStringArray;
  I: Integer;
begin
  if Assigned(ASetCurrentStep) then
    ASetCurrentStep(bsPreflight);
  if Assigned(APerfStart) then
    APerfStart('Preflight', 'Build');
  if Assigned(APerfMetadata) then
    APerfMetadata('Preflight', 'version=' + AVersion);

  LStart := Now;
  if Assigned(ALogLine) then
    ALogLine(
      '== Preflight START version=' + AVersion +
      ' srcRoot=' + ASourceRoot +
      ' sandbox=' + ASandboxRoot +
      ' logDir=' + ALogDir
    );
  if (AVerbosity > 0) and Assigned(ALogEnvSnapshot) then
    ALogEnvSnapshot;

  LInputs := BuildBuildPreflightInputsCore(
    AVersion,
    ASourcePath,
    ASandboxRoot,
    ALogDir,
    AToolchainStrict,
    AAllowInstall,
    APolicyCheck,
    ABuildToolchainJSON,
    AHasMake,
    ACanWriteDir
  );

  if LInputs.PolicyCheckPassed and (LInputs.PolicyStatus <> 'OK') and
     (AVerbosity > 0) and Assigned(ALogLine) then
    ALogLine(Format('fpc policy %s: current=%s min=%s rec=%s', [
      LInputs.PolicyStatus,
      LInputs.CurrentFpcVersion,
      LInputs.PolicyMin,
      LInputs.PolicyRecommended
    ]));

  LIssues := CollectBuildPreflightIssuesCore(LInputs);
  Result := Length(LIssues) = 0;

  if Assigned(APerfEnd) then
    APerfEnd('Preflight', Result);

  LFailureLines := FormatBuildPreflightLogLinesCore(LIssues, AVerbosity);
  for I := 0 to High(LFailureLines) do
    if Assigned(ALogLine) then
      ALogLine(LFailureLines[I]);

  if Assigned(ALogSummary) then
  begin
    if Result then
      ALogSummary(AVersion, 'preflight', 'OK', MilliSecondsBetween(Now, LStart))
    else
      ALogSummary(AVersion, 'preflight', 'FAIL', MilliSecondsBetween(Now, LStart));
  end;
end;

end.
