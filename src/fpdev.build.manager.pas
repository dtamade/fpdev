unit fpdev.build.manager;

{$mode objfpc}{$H+}
// acq:allow-style-file
// acq:allow-hardcoded-constants-file

interface

uses
  SysUtils, Classes, fpdev.build.config, fpdev.build.logger, fpdev.build.makeflow,
  fpdev.build.toolchain, fpdev.build.cache.types, fpdev.build.interfaces,
  fpdev.build.packageselection,
  fpdev.perf.monitor;

type
  { TBuildManager }
  TBuildManager = class(TInterfacedObject, IBuildManager)
  private
    FSourceRoot: string;
    FParallelJobs: Integer;
    FVerbose: Boolean;
    FSandboxRoot: string;
    FLogDir: string;
    FAllowInstall: Boolean;
    FLastError: string;  // Last error message for IBuildManager interface
    FLogger: TBuildLogger;  // Logger service (Facade delegation)
    FToolchainChecker: TBuildToolchainChecker;  // Toolchain service (Facade delegation)
    FStrictResults: Boolean; // Strict mode for sandbox artifact validation
    FStrictConfigPath: string; // Strict mode config file path (optional)
    FDryRun: Boolean; // Dry run mode: only print commands, don't execute
    FToolchainStrict: Boolean; // Toolchain strict validation (fail blocks build)
    FCurrentStep: TBuildStep; // Current build stage
    // make and target/prefix configuration (optional)
    FMakeCmd: string;              // Custom make command (empty = auto-detect)
    FCPU_TARGET: string;           // Target CPU (optional)
    FOS_TARGET: string;            // Target OS (optional)
    FPREFIX: string;               // Install prefix (optional)
    FINSTALL_PREFIX: string;       // Install prefix (optional)
    // Cross-compilation support (M7)
    FPP: string;                       // PP= cross-compiler path (optional)
    FCROSSOPT: string;                 // CROSSOPT= cross-compile options (optional)
    // Package selection (Phase 4.3)
    FSelectedPackages: TStringArray; // Selective build package list
    FSkippedPackages: TStringArray;  // Packages to skip
    function GetSourcePath(const AVersion: string): string;
    function HasTool(const AExe: string; const AArgs: array of string): Boolean;
    function ResolveMakeCmd: string;
    function RunMake(const ASourcePath: string; const ATargets: array of string): Boolean;
    function RunMakeTargets(const ASourcePath: string; const ATargets: TBuildMakeTargetArray): Boolean;
    procedure Log(const ALine: string);
    procedure EnsureDir(const APath: string);
    function GetLogFileName: string;
    procedure LogDirSample(const ADir: string; ALimit: Integer);
    procedure LogEnvSnapshot;
    function ApplyStrictConfig(const ASandboxDest: string): Boolean;
    function CanWriteDir(const APath: string): Boolean;
    procedure LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
    procedure SetCurrentStepValue(AStep: TBuildStep);
    procedure StartPerfOperation(const AOperation, ACategory: string);
    procedure SetPerfMetadata(const AOperation, AMetadata: string);
    procedure EndPerfOperation(const AOperation: string; ASuccess: Boolean);
    function DetectMakeAvailable: Boolean;
    function RunPreflightPolicyCheck(const AVersion: string; out AStatus, AReason,
      AMin, ARecommended, ACurrentFpcVersion: string): Boolean;
    function BuildToolchainReportJSONValue: string;
    function RunVersionedPreflight(const AVersion: string): Boolean;
  public
    constructor Create(const ASourceRoot: string; AParallelJobs: Integer; AVerbose: Boolean);
    destructor Destroy; override;
    procedure SetSandboxRoot(const APath: string);
    procedure SetAllowInstall(AEnable: Boolean);
    procedure SetLogVerbosity(ALevel: Integer);
    procedure SetStrictResults(AEnable: Boolean);
    procedure SetStrictConfigPath(const APath: string);
    procedure SetDryRun(AEnable: Boolean);
    procedure SetToolchainStrict(AEnable: Boolean);
    // Optional configuration
    procedure SetMakeCmd(const ACmd: string);
    procedure SetTarget(const ACpu, AOs: string);
    procedure SetPrefix(const APrefix, AInstallPrefix: string);
    procedure SetPP(const APP: string);
    procedure SetCrossOpt(const ACrossOpt: string);
    { Apply configuration from TBuildConfig record (consolidates all SetXxx methods) }
    procedure ApplyConfig(const AConfig: TBuildConfig);
    property LogFileName: string read GetLogFileName;
    // Status queries
    function GetBuildStep: Integer;
    function IsDryRun: Boolean;
    function GetParallelJobs: Integer;
    function GetCurrentStep: TBuildStep;
    // Build methods
    { IBuildManager interface methods }
    function Preflight: Boolean; overload;  // Interface method (no version parameter)
    function GetLastError: string;
    
    { Legacy methods with version parameter }
    function BuildCompiler(const AVersion: string): Boolean;
    function BuildRTL(const AVersion: string): Boolean;
    function BuildPackages(const AVersion: string): Boolean;
    function InstallPackages(const AVersion: string): Boolean;
    function Install(const AVersion: string): Boolean;
    function Configure(const {%H-} AVersion: string): Boolean;
    function TestResults(const AVersion: string): Boolean;
    function Preflight(const AVersion: string): Boolean; overload;  // Legacy method
    function FullBuild(const AVersion: string): Boolean;
    // Cache support
    procedure CreateBuildStamp(const AVersion: string);
    // Environment preflight check (pure code implementation, no scripts)
    function CheckToolchain: Boolean;
    // Package selection (Phase 4.3)
    function ListPackages: TStringArray;
    procedure SetSelectedPackages(const APackages: TStringArray);
    function GetSelectedPackageCount: Integer;
    procedure SetSkippedPackages(const APackages: TStringArray);
    function GetSkippedPackageCount: Integer;
    function GetPackageBuildOrder: TStringArray;
  end;

implementation

uses
  Process, DateUtils, fpdev.toolchain, fpdev.build.probe,
  fpdev.build.fullbuildflow, fpdev.build.preflight, fpdev.build.preflightflow,
  fpdev.build.strict, fpdev.build.testresultsflow, fpdev.utils.process,
  fpdev.fpc.installer.config;

function BuildManagerDirectoryExists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

constructor TBuildManager.Create(const ASourceRoot: string; AParallelJobs: Integer; AVerbose: Boolean);
begin
  inherited Create;
  FSourceRoot := ASourceRoot;
  FParallelJobs := AParallelJobs;
  FVerbose := AVerbose;
  FSandboxRoot := 'sandbox';
  FLogDir := 'logs';
  FAllowInstall := False; // Default: don't install to avoid pollution
  FStrictResults := False;
  FStrictConfigPath := '';
  FDryRun := False;
  FToolchainStrict := False;
  FCurrentStep := bsIdle;
  FMakeCmd := '';
  FCPU_TARGET := '';
  FOS_TARGET := '';
  FPREFIX := '';
  FINSTALL_PREFIX := '';
  FPP := '';
  FCROSSOPT := '';
  // Initialize package selection arrays
  FSelectedPackages := nil;
  FSkippedPackages := nil;

  // Ensure directories exist
  EnsureDir(FSandboxRoot);
  EnsureDir(FLogDir);

  // Initialize logger service
  FLogger := TBuildLogger.Create(FLogDir);

  // Initialize toolchain checker service
  FToolchainChecker := TBuildToolchainChecker.Create(FVerbose);
end;

destructor TBuildManager.Destroy;
begin
  if Assigned(FToolchainChecker) then
    FToolchainChecker.Free;
  if Assigned(FLogger) then
    FLogger.Free;
  inherited Destroy;
end;

procedure TBuildManager.SetSandboxRoot(const APath: string);
begin
  if APath <> '' then FSandboxRoot := APath;
  EnsureDir(FSandboxRoot);
end;

procedure TBuildManager.SetAllowInstall(AEnable: Boolean);
begin
  FAllowInstall := AEnable;
end;

procedure TBuildManager.SetLogVerbosity(ALevel: Integer);
begin
  if ALevel < 0 then ALevel := 0;
  if ALevel > 1 then ALevel := 1;
  FLogger.Verbosity := ALevel;
  Log('LogVerbosity set to ' + IntToStr(ALevel));
end;

procedure TBuildManager.SetStrictResults(AEnable: Boolean);
begin
  FStrictResults := AEnable;
  Log('StrictResults set to ' + BoolToStr(FStrictResults, True));
end;

procedure TBuildManager.SetStrictConfigPath(const APath: string);
begin
  FStrictConfigPath := APath;
  Log('StrictConfigPath set to ' + FStrictConfigPath);
end;

procedure TBuildManager.SetDryRun(AEnable: Boolean);
begin
  FDryRun := AEnable;
  Log('DryRun set to ' + BoolToStr(FDryRun, True));
end;

procedure TBuildManager.SetToolchainStrict(AEnable: Boolean);
begin
  FToolchainStrict := AEnable;
  Log('ToolchainStrict set to ' + BoolToStr(FToolchainStrict, True));
end;

procedure TBuildManager.LogDirSample(const ADir: string; ALimit: Integer);
begin
  // Delegate to logger service
  FLogger.LogDirSample(ADir, ALimit);
end;

procedure TBuildManager.LogEnvSnapshot;
begin
  // Delegate to logger service
  FLogger.LogEnvSnapshot;
end;

function TBuildManager.ApplyStrictConfig(const ASandboxDest: string): Boolean;
var
  LIniPath: string;
begin
  LIniPath := BuildManagerResolveStrictConfigPathCore(FStrictConfigPath, ASandboxDest);
  if LIniPath = '' then
    Exit(True);

  Log('Strict config detected: ' + LIniPath);
  Result := BuildManagerApplyStrictConfigCore(
    LIniPath,
    ASandboxDest,
    FLogger.Verbosity,
    @Log,
    @LogDirSample
  );
end;

function TBuildManager.GetSourcePath(const AVersion: string): string;
var
  LVersion: string;
begin
  LVersion := AVersion;
  if LVersion = '' then LVersion := 'main';
  Result := IncludeTrailingPathDelimiter(FSourceRoot) + 'fpc-' + LVersion;
end;

function TBuildManager.CanWriteDir(const APath: string): Boolean;
var
  LTest: string;
  F: TextFile;
begin
  Result := False;
  if not DirectoryExists(APath) then Exit(False);
  LTest := IncludeTrailingPathDelimiter(APath) + '.write_test.tmp';
  try
    AssignFile(F, LTest);
    Rewrite(F);
    WriteLn(F, 'ok');
    CloseFile(F);
    Result := True;
  except
    on E: Exception do
    begin
      Log('cannot write to dir: ' + APath + ' err=' + E.Message);
      Result := False;
    end;
  end;
  if FileExists(LTest) then DeleteFile(LTest);
end;

procedure TBuildManager.LogTestSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
begin
  Log('Summary: version=' + AVersion + ' context=' + AContext + ' result=' + AResult + ' elapsed_ms=' + IntToStr(AElapsedMs));
end;

procedure TBuildManager.SetCurrentStepValue(AStep: TBuildStep);
begin
  FCurrentStep := AStep;
end;

procedure TBuildManager.StartPerfOperation(const AOperation, ACategory: string);
begin
  PerfMon.StartOperation(AOperation, ACategory);
end;

procedure TBuildManager.SetPerfMetadata(const AOperation, AMetadata: string);
begin
  PerfMon.SetMetadata(AOperation, AMetadata);
end;

procedure TBuildManager.EndPerfOperation(const AOperation: string; ASuccess: Boolean);
begin
  PerfMon.EndOperation(AOperation, ASuccess);
end;

function TBuildManager.DetectMakeAvailable: Boolean;
begin
  Result := HasTool('make', ['--version']);
end;

function TBuildManager.RunPreflightPolicyCheck(const AVersion: string;
  out AStatus, AReason, AMin, ARecommended, ACurrentFpcVersion: string): Boolean;
begin
  Result := CheckFPCVersionPolicy(AVersion, AStatus, AReason, AMin,
    ARecommended, ACurrentFpcVersion);
end;

function TBuildManager.BuildToolchainReportJSONValue: string;
begin
  Result := BuildToolchainReportJSON;
end;

function TBuildManager.CheckToolchain: Boolean;
var
  LIssues: TStringList;
  LStart: TDateTime;
  Ok: Boolean;
  Line: string;
  i: Integer;
  LRes: string;
  function Check(const ACmd, AProbeArg: string; out AOk: Boolean; out ALine: string): Boolean;
  var ExitCode: Integer;
  begin
    try
      if AProbeArg <> '' then ExitCode := ExecuteProcess(ACmd, [AProbeArg])
      else ExitCode := ExecuteProcess(ACmd, []);
      AOk := (ExitCode = 0);
    except
      AOk := False;
    end;
    if AOk then ALine := '[ OK ] ' + ACmd else ALine := '[MISS] ' + ACmd;
    Result := AOk;
  end;
begin
  LStart := Now;
  LIssues := TStringList.Create;
  try
    Log('== Toolchain Check START');
    // Try a set of common tools per platform
    Ok := False; Line := '';
    // Build tools
    Check('fpc','-iV', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogger.Verbosity>0 then Log(Line);
    Check('lazbuild','--version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogger.Verbosity>0 then Log(Line);
    // make family
    {$IFDEF MSWINDOWS}
    if not Check('mingw32-make','--version', Ok, Line) then
      if not Check('make','--version', Ok, Line) then
        if not Check('gmake','--version', Ok, Line) then LIssues.Add('[MISS] make-family');
    {$ELSE}
    if not Check('gmake','--version', Ok, Line) then
      if not Check('make','--version', Ok, Line) then LIssues.Add('[MISS] make-family');
    {$ENDIF}
    // Version control / SSL (optional)
    Check('git','--version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogger.Verbosity>0 then Log(Line);
    Check('openssl','version', Ok, Line); if not Ok then LIssues.Add(Line) else if FLogger.Verbosity>0 then Log(Line);
    // Platform-specific compiler frontends (optional)
    Check('ppc386','', Ok, Line); if not Ok then if FLogger.Verbosity>0 then Log(Line);
    Check('ppcx64','', Ok, Line); if not Ok then if FLogger.Verbosity>0 then Log(Line);
    Check('ppcarm','', Ok, Line); if not Ok then if FLogger.Verbosity>0 then Log(Line);
    Result := (LIssues.Count = 0);
    if Result then Log('== Toolchain Check END OK') else
    begin
      Log('== Toolchain Check END FAIL issues=' + IntToStr(LIssues.Count));
      if FLogger.Verbosity>0 then
      begin
        for i:=0 to LIssues.Count-1 do Log('issue: ' + LIssues[i]);
      end;
    end;
    if Result then LRes := 'OK' else LRes := 'FAIL';
    LogTestSummary('n/a','toolchain', LRes, MilliSecondsBetween(Now, LStart));
  finally
    LIssues.Free;
  end;
end;

function TBuildManager.HasTool(const AExe: string; const AArgs: array of string): Boolean;
begin
  // Delegate to toolchain checker service
  Result := FToolchainChecker.HasTool(AExe, AArgs);
end;

function TBuildManager.ResolveMakeCmd: string;
begin
  // Custom make command takes priority
  if FMakeCmd <> '' then
    Exit(FMakeCmd);

  // Windows: try mingw32-make first
  {$IFDEF MSWINDOWS}
  if FToolchainChecker.HasTool('mingw32-make', ['--version']) then
    Exit('mingw32-make');
  {$ENDIF}

  // Delegate to toolchain checker for gmake/make detection
  Result := FToolchainChecker.ResolveMakeCmd;
end;

procedure TBuildManager.SetMakeCmd(const ACmd: string);
begin
  FMakeCmd := Trim(ACmd);
end;

procedure TBuildManager.SetTarget(const ACpu, AOs: string);
begin
  FCPU_TARGET := Trim(ACpu);
  FOS_TARGET := Trim(AOs);
end;

procedure TBuildManager.SetPrefix(const APrefix, AInstallPrefix: string);
begin
  FPREFIX := Trim(APrefix);
  FINSTALL_PREFIX := Trim(AInstallPrefix);
end;

procedure TBuildManager.SetPP(const APP: string);
begin
  FPP := Trim(APP);
end;

procedure TBuildManager.SetCrossOpt(const ACrossOpt: string);
begin
  FCROSSOPT := Trim(ACrossOpt);
end;

procedure TBuildManager.ApplyConfig(const AConfig: TBuildConfig);
var
  I: Integer;
begin
  // Apply execution configuration
  if AConfig.SourceRoot <> '' then
    FSourceRoot := AConfig.SourceRoot;
  if AConfig.SandboxRoot <> '' then
    FSandboxRoot := AConfig.SandboxRoot;
  if AConfig.LogDir <> '' then
    FLogDir := AConfig.LogDir;
  FParallelJobs := AConfig.ParallelJobs;
  FVerbose := AConfig.Verbose;

  // Apply control flags
  FAllowInstall := AConfig.AllowInstall;
  FDryRun := AConfig.DryRun;

  // Apply validation configuration
  FStrictResults := AConfig.StrictResults;
  FStrictConfigPath := AConfig.StrictConfigPath;
  FToolchainStrict := AConfig.ToolchainStrict;
  FLogger.Verbosity := AConfig.LogVerbosity;

  // Apply make configuration
  FMakeCmd := AConfig.MakeCmd;
  FCPU_TARGET := AConfig.CpuTarget;
  FOS_TARGET := AConfig.OsTarget;
  FPREFIX := AConfig.Prefix;
  FINSTALL_PREFIX := AConfig.InstallPrefix;

  // Apply package selection
  if Length(AConfig.SelectedPackages) > 0 then
  begin
    SetLength(FSelectedPackages, Length(AConfig.SelectedPackages));
    for I := 0 to High(AConfig.SelectedPackages) do
      FSelectedPackages[I] := AConfig.SelectedPackages[I];
  end;

  if Length(AConfig.SkippedPackages) > 0 then
  begin
    SetLength(FSkippedPackages, Length(AConfig.SkippedPackages));
    for I := 0 to High(AConfig.SkippedPackages) do
      FSkippedPackages[I] := AConfig.SkippedPackages[I];
  end;

  // Ensure directories exist
  EnsureDir(FSandboxRoot);
  EnsureDir(FLogDir);

  Log('Configuration applied from TBuildConfig');
end;

function TBuildManager.GetBuildStep: Integer;
begin
  Result := Ord(FCurrentStep);
end;

function TBuildManager.IsDryRun: Boolean;
begin
  Result := FDryRun;
end;

function TBuildManager.GetParallelJobs: Integer;
begin
  Result := FParallelJobs;
end;

function TBuildManager.GetCurrentStep: TBuildStep;
begin
  Result := FCurrentStep;
end;

procedure TBuildManager.Log(const ALine: string);
begin
  // Delegate to logger service
  FLogger.Log(ALine);
end;

function TBuildManager.GetLogFileName: string;
begin
  // Delegate to logger service
  Result := FLogger.LogFileName;
end;

procedure TBuildManager.EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

function TBuildManager.RunMake(const ASourcePath: string; const ATargets: array of string): Boolean;
var
  LArgs: array of string;
  i, LIdx: Integer;
  LJobs: string;
  LMake: string;
  LMakePath: string;
  LMakeVersionResult: TProcessResult;
  LRunResult: TProcessResult;
begin
  Result := False;
  LArgs := nil;
  FLastError := '';
  if not DirectoryExists(ASourcePath) then
  begin
    FLastError := 'Source path not found: ' + ASourcePath;
    Exit(False);
  end;
  // Resolve make command (removed inline variables)
  LMake := ResolveMakeCmd;
  if LMake = '' then
  begin
    FLastError := 'Make command not configured';
    Exit(False);
  end;
  LMakePath := TProcessExecutor.FindExecutable(LMake);
  if LMakePath = '' then
    LMakePath := LMake;
  // Assemble arguments: -C <dir> -jN <targets>
  if FParallelJobs <= 0 then FParallelJobs := 1;
  if FParallelJobs > 16 then FParallelJobs := 16;
  LJobs := IntToStr(FParallelJobs);
  // Reserved extra variable slots: CPU_TARGET/OS_TARGET/PREFIX/INSTALL_PREFIX/PP/CROSSOPT
  SetLength(LArgs, 2 + 2 + 6 + Length(ATargets));
  LArgs[0] := '-C'; LArgs[1] := ASourcePath;
  LArgs[2] := '-j' + LJobs;
  LIdx := 3;
  if FCPU_TARGET <> '' then begin LArgs[LIdx] := 'CPU_TARGET=' + FCPU_TARGET; Inc(LIdx); end;
  if FOS_TARGET <> '' then begin LArgs[LIdx] := 'OS_TARGET=' + FOS_TARGET; Inc(LIdx); end;
  // Include PREFIX/INSTALL_PREFIX if set (Install still overrides explicitly)
  if FPREFIX <> '' then begin LArgs[LIdx] := 'PREFIX=' + FPREFIX; Inc(LIdx); end;
  if FINSTALL_PREFIX <> '' then begin LArgs[LIdx] := 'INSTALL_PREFIX=' + FINSTALL_PREFIX; Inc(LIdx); end;
  // Cross-compilation: PP (cross-compiler path) and CROSSOPT (cross-compile options)
  if FPP <> '' then begin LArgs[LIdx] := 'PP=' + FPP; Inc(LIdx); end;
  if FCROSSOPT <> '' then begin LArgs[LIdx] := 'CROSSOPT=' + FCROSSOPT; Inc(LIdx); end;
  for i := Low(ATargets) to High(ATargets) do
  begin
    LArgs[LIdx] := ATargets[i];
    Inc(LIdx);
  end;
  if FVerbose then
  begin
    SetLength(LArgs, Length(LArgs) + 2);
    LArgs[High(LArgs)-1] := 'VERBOSE=1';
    LArgs[High(LArgs)] := 'OPT="-O2"';
  end;
  if FLogger.Verbosity > 0 then Log('make ' + String.Join(' ', LArgs));
  if FDryRun then
  begin
    Log('dry-run: skipped make execution');
    Exit(True);
  end;

  // Ensure make is runnable (and avoid unhandled EOSError crashes).
  LMakeVersionResult := TProcessExecutor.RunDirect(LMakePath, ['--version'], '');
  if not LMakeVersionResult.Success then
  begin
    if LMakeVersionResult.ErrorMessage <> '' then
      FLastError := 'Failed to execute make (' + LMakePath + '): ' +
        LMakeVersionResult.ErrorMessage
    else
      FLastError := 'Make not detected (' + LMakePath + '), exit=' +
        IntToStr(LMakeVersionResult.ExitCode);
    Log(FLastError);
    Exit(False);
  end;

  LRunResult := TProcessExecutor.RunDirect(LMakePath, LArgs, '');
  Result := LRunResult.Success;
  if not Result then
  begin
    if LRunResult.ErrorMessage <> '' then
      FLastError := 'Failed to execute make (' + LMakePath + '): ' +
        LRunResult.ErrorMessage
    else
      FLastError := 'make failed (' + LMakePath + '), exit=' +
        IntToStr(LRunResult.ExitCode) + ' (log: ' + FLogger.LogFileName + ')';
    Log(FLastError);
  end;
end;

function TBuildManager.RunMakeTargets(const ASourcePath: string; const ATargets: TBuildMakeTargetArray): Boolean;
begin
  Result := RunMake(ASourcePath, ATargets);
end;

function TBuildManager.BuildCompiler(const AVersion: string): Boolean;
var
  LPlan: TBuildMakeStepPlan;
begin
  LPlan := CreateBuildCompilerStepPlanCore(AVersion, GetSourcePath(AVersion));
  Result := ExecuteBuildMakeStepCore(
    LPlan,
    FAllowInstall,
    FLogger.Verbosity,
    @SetCurrentStepValue,
    @EnsureDir,
    @RunMakeTargets,
    @Log,
    @LogEnvSnapshot,
    @StartPerfOperation,
    @SetPerfMetadata,
    @EndPerfOperation
  );
end;

function TBuildManager.BuildRTL(const AVersion: string): Boolean;
var
  LPlan: TBuildMakeStepPlan;
begin
  LPlan := CreateBuildRTLStepPlanCore(AVersion, GetSourcePath(AVersion));
  Result := ExecuteBuildMakeStepCore(
    LPlan,
    FAllowInstall,
    FLogger.Verbosity,
    @SetCurrentStepValue,
    @EnsureDir,
    @RunMakeTargets,
    @Log,
    @LogEnvSnapshot,
    @StartPerfOperation,
    @SetPerfMetadata,
    @EndPerfOperation
  );
end;

function TBuildManager.BuildPackages(const AVersion: string): Boolean;
var
  LPlan: TBuildMakeStepPlan;
begin
  LPlan := CreateBuildPackagesStepPlanCore(AVersion, GetSourcePath(AVersion));
  Result := ExecuteBuildMakeStepCore(
    LPlan,
    FAllowInstall,
    FLogger.Verbosity,
    @SetCurrentStepValue,
    @EnsureDir,
    @RunMakeTargets,
    @Log,
    @LogEnvSnapshot,
    @StartPerfOperation,
    @SetPerfMetadata,
    @EndPerfOperation
  );
end;

function TBuildManager.InstallPackages(const AVersion: string): Boolean;
var
  LPlan: TBuildMakeStepPlan;
  LDest: string;
begin
  LDest := IncludeTrailingPathDelimiter(FSandboxRoot) + 'fpc-' + AVersion;
  LPlan := CreateBuildInstallPackagesStepPlanCore(
    AVersion,
    GetSourcePath(AVersion),
    LDest
  );
  Result := ExecuteBuildMakeStepCore(
    LPlan,
    FAllowInstall,
    FLogger.Verbosity,
    @SetCurrentStepValue,
    @EnsureDir,
    @RunMakeTargets,
    @Log,
    @LogEnvSnapshot,
    @StartPerfOperation,
    @SetPerfMetadata,
    @EndPerfOperation
  );
end;

function TBuildManager.Install(const AVersion: string): Boolean;
var
  LPlan: TBuildMakeStepPlan;
  LDest: string;
begin
  LDest := IncludeTrailingPathDelimiter(FSandboxRoot) + 'fpc-' + AVersion;
  LPlan := CreateBuildInstallStepPlanCore(
    AVersion,
    GetSourcePath(AVersion),
    LDest
  );
  Result := ExecuteBuildMakeStepCore(
    LPlan,
    FAllowInstall,
    FLogger.Verbosity,
    @SetCurrentStepValue,
    @EnsureDir,
    @RunMakeTargets,
    @Log,
    @LogEnvSnapshot,
    @StartPerfOperation,
    @SetPerfMetadata,
    @EndPerfOperation
  );
end;

function TBuildManager.Configure(const AVersion: string): Boolean;
var
  LDest: string;
begin
  if not FAllowInstall then
    Exit(True);

  if Trim(AVersion) = '' then
  begin
    Log('Configure: missing version for install-mode configuration');
    Exit(False);
  end;

  LDest := IncludeTrailingPathDelimiter(FSandboxRoot) + 'fpc-' + AVersion;
  Result := EnsureManagedFPCInstallLayout(LDest, AVersion, nil);
  if Result then
    Log('Configure: managed layout ready at ' + LDest)
  else
    Log('Configure: managed layout incomplete at ' + LDest);
end;

function TBuildManager.TestResults(const AVersion: string): Boolean;
begin
  Result := ExecuteBuildTestResultsCore(
    AVersion,
    FSandboxRoot,
    FAllowInstall,
    FStrictResults,
    FLogger.Verbosity,
    @GetSourcePath,
    @ApplyStrictConfig,
    @BuildManagerDirectoryExists,
    @BuildManagerDirHasAnyFile,
    @BuildManagerDirHasAnyEntry,
    @Log,
    @LogDirSample,
    @LogTestSummary
  );
end;

function TBuildManager.Preflight(const AVersion: string): Boolean;
var
  LStart: TDateTime;
  LIssues: TStringArray;
  LFailureLines: TStringArray;
  LInputs: TBuildPreflightInputs;
  I: Integer;
begin
  FCurrentStep := bsPreflight;
  PerfMon.StartOperation('Preflight', 'Build');
  PerfMon.SetMetadata('Preflight', 'version=' + AVersion);
  LStart := Now;
  Log('== Preflight START version=' + AVersion + ' srcRoot=' + FSourceRoot + ' sandbox=' + FSandboxRoot + ' logDir=' + FLogDir);
  if FLogger.Verbosity > 0 then
    LogEnvSnapshot;

  LInputs := BuildBuildPreflightInputsCore(
    AVersion,
    GetSourcePath(AVersion),
    FSandboxRoot,
    FLogDir,
    FToolchainStrict,
    FAllowInstall,
    @RunPreflightPolicyCheck,
    @BuildToolchainReportJSONValue,
    @DetectMakeAvailable,
    @CanWriteDir
  );

  if LInputs.PolicyCheckPassed and (LInputs.PolicyStatus <> 'OK') and
     (FLogger.Verbosity > 0) then
    Log(Format('fpc policy %s: current=%s min=%s rec=%s', [
      LInputs.PolicyStatus,
      LInputs.CurrentFpcVersion,
      LInputs.PolicyMin,
      LInputs.PolicyRecommended
    ]));

  LIssues := CollectBuildPreflightIssuesCore(LInputs);
  Result := Length(LIssues) = 0;
  PerfMon.EndOperation('Preflight', Result);

  LFailureLines := FormatBuildPreflightLogLinesCore(LIssues, FLogger.Verbosity);
  for I := 0 to High(LFailureLines) do
    Log(LFailureLines[I]);

  if Result then
    LogTestSummary(AVersion, 'preflight', 'OK', MilliSecondsBetween(Now, LStart))
  else
    LogTestSummary(AVersion, 'preflight', 'FAIL', MilliSecondsBetween(Now, LStart));
end;

function TBuildManager.FullBuild(const AVersion: string): Boolean;
begin
  Result := RunFullBuildCore(
    AVersion,
    @RunVersionedPreflight,
    @BuildCompiler,
    @BuildRTL,
    @BuildPackages,
    @InstallPackages,
    @Install,
    @TestResults,
    @SetCurrentStepValue,
    @Log,
    @LogTestSummary
  );
end;

function TBuildManager.RunVersionedPreflight(const AVersion: string): Boolean;
begin
  // Keep FullBuild off the overloaded @Preflight method pointer for FPC 3.2.2.
  Result := Preflight(AVersion);
end;

procedure TBuildManager.CreateBuildStamp(const AVersion: string);
var
  StampFile: string;
  F: TextFile;
  LCpu, LOs: string;
begin
  {$IFDEF CPUX86_64}
  LCpu := 'x86_64';
  {$ELSE}
  {$IFDEF CPUI386}
  LCpu := 'i386';
  {$ELSE}
  {$IFDEF CPUARM}
  LCpu := 'arm';
  {$ELSE}
  {$IFDEF CPUAARCH64}
  LCpu := 'aarch64';
  {$ELSE}
  LCpu := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}

  {$IFDEF LINUX}
  LOs := 'linux';
  {$ELSE}
  {$IFDEF MSWINDOWS}
  LOs := 'win64';
  {$ELSE}
  {$IFDEF DARWIN}
  LOs := 'darwin';
  {$ELSE}
  LOs := 'unknown';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}

  StampFile := IncludeTrailingPathDelimiter(FSandboxRoot) + 'build-stamp.' + LCpu + '-' + LOs;
  EnsureDir(FSandboxRoot);

  AssignFile(F, StampFile);
  try
    Rewrite(F);
    WriteLn(F, 'version=', AVersion);
    WriteLn(F, 'timestamp=', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn(F, 'cpu=', LCpu);
    WriteLn(F, 'os=', LOs);
    CloseFile(F);
    Log('Created build stamp: ' + StampFile);
  except
    on E: Exception do
      Log('Failed to create build stamp: ' + E.Message);
  end;
end;

{ Package Selection Methods (Phase 4.3) }

function TBuildManager.ListPackages: TStringArray;
begin
  Result := BuildDefaultPackageListCore;
end;

procedure TBuildManager.SetSelectedPackages(const APackages: TStringArray);
begin
  FSelectedPackages := CopyBuildPackageSelectionCore(APackages);
end;

function TBuildManager.GetSelectedPackageCount: Integer;
begin
  Result := Length(FSelectedPackages);
end;

procedure TBuildManager.SetSkippedPackages(const APackages: TStringArray);
begin
  FSkippedPackages := CopyBuildPackageSelectionCore(APackages);
end;

function TBuildManager.GetSkippedPackageCount: Integer;
begin
  Result := Length(FSkippedPackages);
end;

function TBuildManager.GetPackageBuildOrder: TStringArray;
begin
  Result := ResolveBuildPackageOrderCore(FSelectedPackages, ListPackages);
end;

{ IBuildManager interface implementation }

function TBuildManager.Preflight: Boolean;
begin
  // Interface method without version parameter
  // Use empty string as default version
  Result := Preflight('');
end;

function TBuildManager.GetLastError: string;
begin
  Result := FLastError;
end;

end.
