unit fpdev.build.testresultsflow;

{$mode objfpc}{$H+}

interface

type
  TBuildTestResultsSourcePathProc = function(const AVersion: string): string of object;
  TBuildTestResultsStrictConfigProc = function(const ASandboxDest: string): Boolean of object;
  TBuildTestResultsLogProc = procedure(const ALine: string) of object;
  TBuildTestResultsDirSampleProc = procedure(const ADir: string; ALimit: Integer) of object;
  TBuildTestResultsSummaryProc = procedure(
    const AVersion, AContext, AResult: string;
    AElapsedMs: Integer
  ) of object;
  TBuildTestResultsPathCheckProc = function(const APath: string): Boolean;

function ExecuteBuildTestResultsCore(
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

implementation

uses
  SysUtils, DateUtils;

function ExecuteBuildTestResultsCore(
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
var
  LSourcePath: string;
  LCompilerPath: string;
  LRTLPath: string;
  LDest: string;
  LBin: string;
  LLib: string;
  LStart: TDateTime;

  procedure EmitLog(const ALine: string);
  begin
    if Assigned(ALogLine) then
      ALogLine(ALine);
  end;

  procedure EmitSummary(const AContext, AResult: string);
  begin
    if Assigned(ALogSummary) then
      ALogSummary(AVersion, AContext, AResult, MilliSecondsBetween(Now, LStart));
  end;

begin
  if AAllowInstall then
  begin
    LStart := Now;
    LDest := IncludeTrailingPathDelimiter(ASandboxRoot) + 'fpc-' + AVersion;
    LBin := IncludeTrailingPathDelimiter(LDest) + 'bin';
    LLib := IncludeTrailingPathDelimiter(LDest) + 'lib';

    if not ADirectoryExists(LDest) then
    begin
      EmitLog('TestResults: sandbox root missing: ' + LDest);
      EmitSummary('sandbox', 'FAIL');
      Exit(False);
    end;

    if (not ADirectoryExists(LBin)) and (not ADirectoryExists(LLib)) then
    begin
      EmitLog('TestResults: sandbox missing bin/lib under: ' + LDest);
      EmitSummary('sandbox', 'FAIL');
      Exit(False);
    end;

    if AVerbosity > 0 then
    begin
      if ADirectoryExists(LBin) then
      begin
        EmitLog('sample of sandbox/bin:');
        if Assigned(ALogDirSample) then
          ALogDirSample(LBin, 10);
      end;
      if ADirectoryExists(LLib) then
      begin
        EmitLog('sample of sandbox/lib:');
        if Assigned(ALogDirSample) then
          ALogDirSample(LLib, 10);
      end;
    end;

    if ADirectoryExists(LBin) and (not ADirHasAnyFile(LBin)) then
    begin
      if AStrictResults then
      begin
        EmitLog('FAIL: sandbox bin empty under strict mode: ' + LBin);
        EmitSummary('sandbox/bin', 'FAIL');
        Exit(False);
      end;
      EmitLog('WARN: sandbox bin is empty: ' + LBin);
    end;

    if ADirectoryExists(LLib) and (not ADirHasAnyEntry(LLib)) then
    begin
      if AStrictResults then
      begin
        EmitLog('FAIL: sandbox lib empty under strict mode: ' + LLib);
        EmitSummary('sandbox/lib', 'FAIL');
        Exit(False);
      end;
      EmitLog('WARN: sandbox lib is empty: ' + LLib);
    end;

    if AStrictResults and Assigned(AApplyStrictConfig) then
    begin
      if not AApplyStrictConfig(LDest) then
      begin
        EmitSummary('sandbox/strict', 'FAIL');
        Exit(False);
      end;
    end;

    EmitLog('TestResults: sandbox OK at ' + LDest);
    EmitSummary('sandbox', 'OK');
    Exit(True);
  end;

  if Assigned(AGetSourcePath) then
    LSourcePath := AGetSourcePath(AVersion)
  else
    LSourcePath := '';

  LCompilerPath := LSourcePath + PathDelim + 'compiler';
  LRTLPath := LSourcePath + PathDelim + 'rtl';

  if not ADirectoryExists(LCompilerPath) then
  begin
    EmitLog('TestResults: missing compiler dir: ' + LCompilerPath);
    Exit(False);
  end;

  if not ADirectoryExists(LRTLPath) then
  begin
    EmitLog('TestResults: missing rtl dir: ' + LRTLPath);
    Exit(False);
  end;

  EmitLog('TestResults: source tree OK at ' + LSourcePath);
  Result := True;
end;

end.
