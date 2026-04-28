unit fpdev.build.manager;

{$mode objfpc}{$H+}
// acq:allow-style-file
// acq:allow-hardcoded-constants-file

interface

uses
  SysUtils, Classes, fpdev.build.config, fpdev.build.logger, fpdev.build.makeflow,
  fpdev.build.toolchain, fpdev.build.cache.types, fpdev.build.interfaces,
  fpdev.build.packageselection, fpdev.utils.process,
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
    function ProbeToolchainCommand(const ACmd, AProbeArg: string;
      out AOk: Boolean; out ALine: string): Boolean;
    function ExecuteDirectProcess(const AExecutable: string;
      const AParams: array of string; const AWorkDir: string): TProcessResult;
    function LocateExecutable(const AName: string): string;
    procedure WriteStampFile(const AFilePath: string;
      const ALines: TStringArray);
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
  fpdev.build.fullbuildflow, fpdev.build.managerflow, fpdev.build.runtimeflow,
  fpdev.build.strict,
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

function TBuildManager.ProbeToolchainCommand(const ACmd, AProbeArg: string;
  out AOk: Boolean; out ALine: string): Boolean;
var
  ExitCode: Integer;
begin
  try
    if AProbeArg <> '' then
      ExitCode := ExecuteProcess(ACmd, [AProbeArg])
    else
      ExitCode := ExecuteProcess(ACmd, []);
    AOk := ExitCode = 0;
  except
    AOk := False;
  end;

  if AOk then
    ALine := '[ OK ] ' + ACmd
  else
    ALine := '[MISS] ' + ACmd;
  Result := AOk;
end;

function TBuildManager.ExecuteDirectProcess(const AExecutable: string;
  const AParams: array of string; const AWorkDir: string): TProcessResult;
begin
  Result := TProcessExecutor.RunDirect(AExecutable, AParams, AWorkDir);
end;

function TBuildManager.LocateExecutable(const AName: string): string;
begin
  Result := TProcessExecutor.FindExecutable(AName);
end;

procedure TBuildManager.WriteStampFile(const AFilePath: string;
  const ALines: TStringArray);
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

function TBuildManager.CheckToolchain: Boolean;
begin
  Result := ExecuteBuildManagerToolchainCheckCore(
    FLogger.Verbosity,
    @ProbeToolchainCommand,
    @Log,
    @LogTestSummary
  );
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
  State: TBuildRuntimeConfigState;
begin
  State := Default(TBuildRuntimeConfigState);
  State.SourceRoot := FSourceRoot;
  State.SandboxRoot := FSandboxRoot;
  State.LogDir := FLogDir;
  State.ParallelJobs := FParallelJobs;
  State.Verbose := FVerbose;
  State.AllowInstall := FAllowInstall;
  State.DryRun := FDryRun;
  State.StrictResults := FStrictResults;
  State.StrictConfigPath := FStrictConfigPath;
  State.ToolchainStrict := FToolchainStrict;
  State.LogVerbosity := FLogger.Verbosity;
  State.MakeCmd := FMakeCmd;
  State.CpuTarget := FCPU_TARGET;
  State.OsTarget := FOS_TARGET;
  State.Prefix := FPREFIX;
  State.InstallPrefix := FINSTALL_PREFIX;
  State.SelectedPackages := Copy(FSelectedPackages, 0, Length(FSelectedPackages));
  State.SkippedPackages := Copy(FSkippedPackages, 0, Length(FSkippedPackages));

  ApplyBuildManagerConfigCore(AConfig, State, @EnsureDir, @Log);

  FSourceRoot := State.SourceRoot;
  FSandboxRoot := State.SandboxRoot;
  FLogDir := State.LogDir;
  FParallelJobs := State.ParallelJobs;
  FVerbose := State.Verbose;
  FAllowInstall := State.AllowInstall;
  FDryRun := State.DryRun;
  FStrictResults := State.StrictResults;
  FStrictConfigPath := State.StrictConfigPath;
  FToolchainStrict := State.ToolchainStrict;
  FLogger.Verbosity := State.LogVerbosity;
  FMakeCmd := State.MakeCmd;
  FCPU_TARGET := State.CpuTarget;
  FOS_TARGET := State.OsTarget;
  FPREFIX := State.Prefix;
  FINSTALL_PREFIX := State.InstallPrefix;
  FSelectedPackages := Copy(State.SelectedPackages, 0, Length(State.SelectedPackages));
  FSkippedPackages := Copy(State.SkippedPackages, 0, Length(State.SkippedPackages));
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
begin
  Result := ExecuteBuildManagerRunMakeCore(
    ASourcePath,
    ATargets,
    FParallelJobs,
    FCPU_TARGET,
    FOS_TARGET,
    FPREFIX,
    FINSTALL_PREFIX,
    FPP,
    FCROSSOPT,
    FVerbose,
    FDryRun,
    FLogger.Verbosity,
    FLogger.LogFileName,
    @ResolveMakeCmd,
    @LocateExecutable,
    @ExecuteDirectProcess,
    @Log,
    FLastError
  );
end;

function TBuildManager.RunMakeTargets(const ASourcePath: string; const ATargets: TBuildMakeTargetArray): Boolean;
begin
  Result := RunMake(ASourcePath, ATargets);
end;

function TBuildManager.BuildCompiler(const AVersion: string): Boolean;
begin
  Result := ExecuteBuildManagerMakeOperationCore(
    bmmBuildCompiler,
    AVersion,
    GetSourcePath(AVersion),
    FSandboxRoot,
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
begin
  Result := ExecuteBuildManagerMakeOperationCore(
    bmmBuildRTL,
    AVersion,
    GetSourcePath(AVersion),
    FSandboxRoot,
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
begin
  Result := ExecuteBuildManagerMakeOperationCore(
    bmmBuildPackages,
    AVersion,
    GetSourcePath(AVersion),
    FSandboxRoot,
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
begin
  Result := ExecuteBuildManagerMakeOperationCore(
    bmmInstallPackages,
    AVersion,
    GetSourcePath(AVersion),
    FSandboxRoot,
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
begin
  Result := ExecuteBuildManagerMakeOperationCore(
    bmmInstall,
    AVersion,
    GetSourcePath(AVersion),
    FSandboxRoot,
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
  Result := ExecuteBuildManagerTestResultsCore(
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
begin
  Result := ExecuteBuildManagerPreflightCore(
    AVersion,
    FSourceRoot,
    GetSourcePath(AVersion),
    FSandboxRoot,
    FLogDir,
    FLogger.Verbosity,
    FToolchainStrict,
    FAllowInstall,
    @RunPreflightPolicyCheck,
    @BuildToolchainReportJSONValue,
    @DetectMakeAvailable,
    @CanWriteDir,
    @SetCurrentStepValue,
    @Log,
    @LogEnvSnapshot,
    @StartPerfOperation,
    @SetPerfMetadata,
    @EndPerfOperation,
    @LogTestSummary
  );
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
begin
  CreateBuildManagerStampCore(
    FSandboxRoot,
    AVersion,
    Now,
    @EnsureDir,
    @WriteStampFile,
    @Log
  );
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
