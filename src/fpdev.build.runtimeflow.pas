unit fpdev.build.runtimeflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils,
  fpdev.build.config,
  fpdev.utils.process;

type
  TBuildRuntimeConfigState = record
    SourceRoot: string;
    SandboxRoot: string;
    LogDir: string;
    ParallelJobs: Integer;
    Verbose: Boolean;
    AllowInstall: Boolean;
    DryRun: Boolean;
    StrictResults: Boolean;
    StrictConfigPath: string;
    ToolchainStrict: Boolean;
    LogVerbosity: Integer;
    MakeCmd: string;
    CpuTarget: string;
    OsTarget: string;
    Prefix: string;
    InstallPrefix: string;
    SelectedPackages: TStringArray;
    SkippedPackages: TStringArray;
  end;

  TBuildRuntimeLogProc = procedure(const ALine: string) of object;
  TBuildRuntimeSummaryProc = procedure(
    const AVersion, AContext, AResult: string;
    AElapsedMs: Integer
  ) of object;
  TBuildRuntimeEnsureDirProc = procedure(const APath: string) of object;
  TBuildRuntimeToolProbeFunc = function(const ACmd, AProbeArg: string;
    out AOk: Boolean; out ALine: string): Boolean of object;
  TBuildRuntimeResolveMakeCmdFunc = function: string of object;
  TBuildRuntimeFindExecutableFunc = function(const AName: string): string of object;
  TBuildRuntimeRunDirectFunc = function(const AExecutable: string;
    const AParams: array of string; const AWorkDir: string): TProcessResult of object;
  TBuildRuntimeWriteStampProc = procedure(const AFilePath: string;
    const ALines: TStringArray) of object;

function ResolveBuildManagerHostCPUCore: string;
function ResolveBuildManagerHostOSCore: string;

function ExecuteBuildManagerToolchainCheckCore(
  AVerbosity: Integer;
  AProbeTool: TBuildRuntimeToolProbeFunc;
  ALogLine: TBuildRuntimeLogProc;
  ALogSummary: TBuildRuntimeSummaryProc
): Boolean;

procedure ApplyBuildManagerConfigCore(
  const AConfig: TBuildConfig;
  var AState: TBuildRuntimeConfigState;
  AEnsureDir: TBuildRuntimeEnsureDirProc;
  ALogLine: TBuildRuntimeLogProc
);

function ExecuteBuildManagerRunMakeCore(
  const ASourcePath: string;
  const ATargets: array of string;
  var AParallelJobs: Integer;
  const ACPU_TARGET, AOS_TARGET, APrefix, AInstallPrefix, APP, ACrossOpt: string;
  AVerbose, ADryRun: Boolean;
  ALoggerVerbosity: Integer;
  const ALogFileName: string;
  AResolveMakeCmd: TBuildRuntimeResolveMakeCmdFunc;
  AFindExecutable: TBuildRuntimeFindExecutableFunc;
  ARunDirect: TBuildRuntimeRunDirectFunc;
  ALogLine: TBuildRuntimeLogProc;
  out ALastError: string
): Boolean;

procedure CreateBuildManagerStampCore(
  const ASandboxRoot, AVersion: string;
  ACurrentTime: TDateTime;
  AEnsureDir: TBuildRuntimeEnsureDirProc;
  AWriteStamp: TBuildRuntimeWriteStampProc;
  ALogLine: TBuildRuntimeLogProc
);

implementation

function CopyStringArray(const AValues: TStringArray): TStringArray;
begin
  Result := Copy(AValues, 0, Length(AValues));
end;

procedure AppendArg(var AArgs: TStringArray; const AValue: string);
var
  Index: Integer;
begin
  Index := Length(AArgs);
  SetLength(AArgs, Index + 1);
  AArgs[Index] := AValue;
end;

function JoinArgs(const AArgs: array of string): string;
var
  Index: Integer;
begin
  Result := '';
  for Index := Low(AArgs) to High(AArgs) do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + AArgs[Index];
  end;
end;

function ProbeToolOrMiss(const ACmd, AProbeArg: string;
  AProbeTool: TBuildRuntimeToolProbeFunc;
  out AOk: Boolean; out ALine: string): Boolean;
begin
  if Assigned(AProbeTool) then
    Exit(AProbeTool(ACmd, AProbeArg, AOk, ALine));

  AOk := False;
  ALine := '[MISS] ' + ACmd;
  Result := False;
end;

function ResolveBuildManagerHostCPUCore: string;
begin
  {$IFDEF CPUX86_64}
  Result := 'x86_64';
  {$ELSE}
  {$IFDEF CPUI386}
  Result := 'i386';
  {$ELSE}
  {$IFDEF CPUARM}
  Result := 'arm';
  {$ELSE}
  {$IFDEF CPUAARCH64}
  Result := 'aarch64';
  {$ELSE}
  Result := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

function ResolveBuildManagerHostOSCore: string;
begin
  {$IFDEF LINUX}
  Result := 'linux';
  {$ELSE}
  {$IFDEF MSWINDOWS}
  Result := 'win64';
  {$ELSE}
  {$IFDEF DARWIN}
  Result := 'darwin';
  {$ELSE}
  Result := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

function ExecuteBuildManagerToolchainCheckCore(
  AVerbosity: Integer;
  AProbeTool: TBuildRuntimeToolProbeFunc;
  ALogLine: TBuildRuntimeLogProc;
  ALogSummary: TBuildRuntimeSummaryProc
): Boolean;
var
  Issues: TStringList;
  StartTime: TDateTime;
  Ok: Boolean;
  Line: string;
  Index: Integer;
  SummaryResult: string;
begin
  StartTime := Now;
  Issues := TStringList.Create;
  try
    if Assigned(ALogLine) then
      ALogLine('== Toolchain Check START');

    ProbeToolOrMiss('fpc', '-iV', AProbeTool, Ok, Line);
    if not Ok then
      Issues.Add(Line)
    else if (AVerbosity > 0) and Assigned(ALogLine) then
      ALogLine(Line);

    ProbeToolOrMiss('lazbuild', '--version', AProbeTool, Ok, Line);
    if not Ok then
      Issues.Add(Line)
    else if (AVerbosity > 0) and Assigned(ALogLine) then
      ALogLine(Line);

    {$IFDEF MSWINDOWS}
    if not ProbeToolOrMiss('mingw32-make', '--version', AProbeTool, Ok, Line) then
      if not ProbeToolOrMiss('make', '--version', AProbeTool, Ok, Line) then
        if not ProbeToolOrMiss('gmake', '--version', AProbeTool, Ok, Line) then
          Issues.Add('[MISS] make-family');
    {$ELSE}
    if not ProbeToolOrMiss('gmake', '--version', AProbeTool, Ok, Line) then
      if not ProbeToolOrMiss('make', '--version', AProbeTool, Ok, Line) then
        Issues.Add('[MISS] make-family');
    {$ENDIF}

    ProbeToolOrMiss('git', '--version', AProbeTool, Ok, Line);
    if not Ok then
      Issues.Add(Line)
    else if (AVerbosity > 0) and Assigned(ALogLine) then
      ALogLine(Line);

    ProbeToolOrMiss('openssl', 'version', AProbeTool, Ok, Line);
    if not Ok then
      Issues.Add(Line)
    else if (AVerbosity > 0) and Assigned(ALogLine) then
      ALogLine(Line);

    ProbeToolOrMiss('ppc386', '', AProbeTool, Ok, Line);
    if (not Ok) and (AVerbosity > 0) and Assigned(ALogLine) then
      ALogLine(Line);
    ProbeToolOrMiss('ppcx64', '', AProbeTool, Ok, Line);
    if (not Ok) and (AVerbosity > 0) and Assigned(ALogLine) then
      ALogLine(Line);
    ProbeToolOrMiss('ppcarm', '', AProbeTool, Ok, Line);
    if (not Ok) and (AVerbosity > 0) and Assigned(ALogLine) then
      ALogLine(Line);

    Result := Issues.Count = 0;
    if Result then
    begin
      if Assigned(ALogLine) then
        ALogLine('== Toolchain Check END OK');
    end
    else
    begin
      if Assigned(ALogLine) then
        ALogLine('== Toolchain Check END FAIL issues=' + IntToStr(Issues.Count));
      if (AVerbosity > 0) and Assigned(ALogLine) then
        for Index := 0 to Issues.Count - 1 do
          ALogLine('issue: ' + Issues[Index]);
    end;

    if Result then
      SummaryResult := 'OK'
    else
      SummaryResult := 'FAIL';

    if Assigned(ALogSummary) then
      ALogSummary('n/a', 'toolchain', SummaryResult,
        MilliSecondsBetween(Now, StartTime));
  finally
    Issues.Free;
  end;
end;

procedure ApplyBuildManagerConfigCore(
  const AConfig: TBuildConfig;
  var AState: TBuildRuntimeConfigState;
  AEnsureDir: TBuildRuntimeEnsureDirProc;
  ALogLine: TBuildRuntimeLogProc
);
begin
  if AConfig.SourceRoot <> '' then
    AState.SourceRoot := AConfig.SourceRoot;
  if AConfig.SandboxRoot <> '' then
    AState.SandboxRoot := AConfig.SandboxRoot;
  if AConfig.LogDir <> '' then
    AState.LogDir := AConfig.LogDir;
  AState.ParallelJobs := AConfig.ParallelJobs;
  AState.Verbose := AConfig.Verbose;
  AState.AllowInstall := AConfig.AllowInstall;
  AState.DryRun := AConfig.DryRun;
  AState.StrictResults := AConfig.StrictResults;
  AState.StrictConfigPath := AConfig.StrictConfigPath;
  AState.ToolchainStrict := AConfig.ToolchainStrict;
  AState.LogVerbosity := AConfig.LogVerbosity;
  AState.MakeCmd := AConfig.MakeCmd;
  AState.CpuTarget := AConfig.CpuTarget;
  AState.OsTarget := AConfig.OsTarget;
  AState.Prefix := AConfig.Prefix;
  AState.InstallPrefix := AConfig.InstallPrefix;

  if Length(AConfig.SelectedPackages) > 0 then
    AState.SelectedPackages := CopyStringArray(AConfig.SelectedPackages);
  if Length(AConfig.SkippedPackages) > 0 then
    AState.SkippedPackages := CopyStringArray(AConfig.SkippedPackages);

  if Assigned(AEnsureDir) then
  begin
    AEnsureDir(AState.SandboxRoot);
    AEnsureDir(AState.LogDir);
  end;

  if Assigned(ALogLine) then
    ALogLine('Configuration applied from TBuildConfig');
end;

function ExecuteBuildManagerRunMakeCore(
  const ASourcePath: string;
  const ATargets: array of string;
  var AParallelJobs: Integer;
  const ACPU_TARGET, AOS_TARGET, APrefix, AInstallPrefix, APP, ACrossOpt: string;
  AVerbose, ADryRun: Boolean;
  ALoggerVerbosity: Integer;
  const ALogFileName: string;
  AResolveMakeCmd: TBuildRuntimeResolveMakeCmdFunc;
  AFindExecutable: TBuildRuntimeFindExecutableFunc;
  ARunDirect: TBuildRuntimeRunDirectFunc;
  ALogLine: TBuildRuntimeLogProc;
  out ALastError: string
): Boolean;
var
  Args: TStringArray;
  Index: Integer;
  MakeCommand: string;
  MakePath: string;
  ProbeResult: TProcessResult;
  RunResult: TProcessResult;
begin
  Result := False;
  ALastError := '';
  Args := nil;

  if not DirectoryExists(ASourcePath) then
  begin
    ALastError := 'Source path not found: ' + ASourcePath;
    Exit(False);
  end;

  if Assigned(AResolveMakeCmd) then
    MakeCommand := AResolveMakeCmd()
  else
    MakeCommand := '';
  if MakeCommand = '' then
  begin
    ALastError := 'Make command not configured';
    Exit(False);
  end;

  if Assigned(AFindExecutable) then
    MakePath := AFindExecutable(MakeCommand)
  else
    MakePath := '';
  if MakePath = '' then
    MakePath := MakeCommand;

  if AParallelJobs <= 0 then
    AParallelJobs := 1;
  if AParallelJobs > 16 then
    AParallelJobs := 16;

  AppendArg(Args, '-C');
  AppendArg(Args, ASourcePath);
  AppendArg(Args, '-j' + IntToStr(AParallelJobs));
  if ACPU_TARGET <> '' then
    AppendArg(Args, 'CPU_TARGET=' + ACPU_TARGET);
  if AOS_TARGET <> '' then
    AppendArg(Args, 'OS_TARGET=' + AOS_TARGET);
  if APrefix <> '' then
    AppendArg(Args, 'PREFIX=' + APrefix);
  if AInstallPrefix <> '' then
    AppendArg(Args, 'INSTALL_PREFIX=' + AInstallPrefix);
  if APP <> '' then
    AppendArg(Args, 'PP=' + APP);
  if ACrossOpt <> '' then
    AppendArg(Args, 'CROSSOPT=' + ACrossOpt);
  for Index := Low(ATargets) to High(ATargets) do
    AppendArg(Args, ATargets[Index]);
  if AVerbose then
  begin
    AppendArg(Args, 'VERBOSE=1');
    AppendArg(Args, 'OPT="-O2"');
  end;

  if (ALoggerVerbosity > 0) and Assigned(ALogLine) then
    ALogLine('make ' + JoinArgs(Args));

  if ADryRun then
  begin
    if Assigned(ALogLine) then
      ALogLine('dry-run: skipped make execution');
    Exit(True);
  end;

  if not Assigned(ARunDirect) then
  begin
    ALastError := 'Failed to execute make (' + MakePath + '): run-direct callback missing';
    Exit(False);
  end;

  ProbeResult := ARunDirect(MakePath, ['--version'], '');
  if not ProbeResult.Success then
  begin
    if ProbeResult.ErrorMessage <> '' then
      ALastError := 'Failed to execute make (' + MakePath + '): ' +
        ProbeResult.ErrorMessage
    else
      ALastError := 'Make not detected (' + MakePath + '), exit=' +
        IntToStr(ProbeResult.ExitCode);
    if Assigned(ALogLine) then
      ALogLine(ALastError);
    Exit(False);
  end;

  RunResult := ARunDirect(MakePath, Args, '');
  Result := RunResult.Success;
  if not Result then
  begin
    if RunResult.ErrorMessage <> '' then
      ALastError := 'Failed to execute make (' + MakePath + '): ' +
        RunResult.ErrorMessage
    else
      ALastError := 'make failed (' + MakePath + '), exit=' +
        IntToStr(RunResult.ExitCode) + ' (log: ' + ALogFileName + ')';
    if Assigned(ALogLine) then
      ALogLine(ALastError);
  end;
end;

procedure DefaultWriteStamp(const AFilePath: string; const ALines: TStringArray);
var
  Lines: TStringList;
  Index: Integer;
begin
  Lines := TStringList.Create;
  try
    for Index := 0 to High(ALines) do
      Lines.Add(ALines[Index]);
    Lines.SaveToFile(AFilePath);
  finally
    Lines.Free;
  end;
end;

procedure CreateBuildManagerStampCore(
  const ASandboxRoot, AVersion: string;
  ACurrentTime: TDateTime;
  AEnsureDir: TBuildRuntimeEnsureDirProc;
  AWriteStamp: TBuildRuntimeWriteStampProc;
  ALogLine: TBuildRuntimeLogProc
);
var
  CpuName: string;
  OsName: string;
  StampFile: string;
  Lines: TStringArray;
begin
  CpuName := ResolveBuildManagerHostCPUCore;
  OsName := ResolveBuildManagerHostOSCore;
  StampFile := IncludeTrailingPathDelimiter(ASandboxRoot) + 'build-stamp.' +
    CpuName + '-' + OsName;

  if Assigned(AEnsureDir) then
    AEnsureDir(ASandboxRoot);

  Lines := nil;
  SetLength(Lines, 4);
  Lines[0] := 'version=' + AVersion;
  Lines[1] := 'timestamp=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', ACurrentTime);
  Lines[2] := 'cpu=' + CpuName;
  Lines[3] := 'os=' + OsName;

  try
    if Assigned(AWriteStamp) then
      AWriteStamp(StampFile, Lines)
    else
      DefaultWriteStamp(StampFile, Lines);

    if Assigned(ALogLine) then
      ALogLine('Created build stamp: ' + StampFile);
  except
    on E: Exception do
      if Assigned(ALogLine) then
        ALogLine('Failed to create build stamp: ' + E.Message);
  end;
end;

end.
