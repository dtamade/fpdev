unit fpdev.cross.engine;

{
  TCrossBuildEngine - Cross-compilation build engine

  Orchestrates the FPC cross-compiler build process using TBuildManager:

    Step 1: compiler_cycle   (native compiler builds cross-compiler)
    Step 2: compiler_install (install cross-compiler to sandbox)
    Step 3: rtl_all          (cross-compiler builds RTL for target)
    Step 4: rtl_install      (install cross-compiled RTL)
    Step 5: packages_all     (cross-compiler builds packages for target)
    Step 6: packages_install (install cross-compiled packages)
    Step 7: verify           (check output artifacts)

  Key make variables:
    CPU_TARGET=<cpu>   — target CPU architecture
    OS_TARGET=<os>     — target OS
    PP=<path>          — compiler to use (native for step 1-2, cross for 3-6)
    CROSSOPT=<opts>    — cross-compilation options (-Ca, -Cf, -Cp, -Fl)
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.cross.engine.intf,
  fpdev.cross.opts,
  fpdev.cross.compiler,
  fpdev.build.manager;

type
  { TCrossBuildEngine - Implements ICrossBuildEngine using TBuildManager }
  TCrossBuildEngine = class(TInterfacedObject, ICrossBuildEngine)
  private
    FBuildManager: TBuildManager;
    FOwnsManager: Boolean;
    FCurrentStage: TCrossBuildStage;
    FLastError: string;
    FCrossCompilerPath: string;
    FDryRun: Boolean;
    FCommandLog: TStringArray;
    FCommandLogCount: Integer;
    procedure SetStage(AStage: TCrossBuildStage);
    procedure LogCommand(const AStep, ADescription: string);
    procedure AddToLog(const ALine: string);
    function BuildCrossOpt(const ATarget: TCrossTarget): string;
    function ResolveCrossCompilerPath(const ATarget: TCrossTarget;
      const ASourceRoot, {%H-}AVersion: string): string;
  public
    constructor Create(ABuildManager: TBuildManager; AOwnsManager: Boolean = False);
    destructor Destroy; override;

    // ICrossBuildEngine implementation
    function BuildCrossCompiler(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;

    function Preflight(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot: string): Boolean;
    function CompilerCycle(const ATarget: TCrossTarget;
      const ASourceRoot, AVersion: string): Boolean;
    function InstallCompiler(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
    function BuildRTL(const ATarget: TCrossTarget;
      const ASourceRoot, AVersion: string): Boolean;
    function InstallRTL(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
    function BuildPackages(const ATarget: TCrossTarget;
      const ASourceRoot, AVersion: string): Boolean;
    function InstallPackages(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
    function Verify(const ATarget: TCrossTarget;
      const ASandboxRoot, AVersion: string): Boolean;

    function GetCurrentStage: TCrossBuildStage;
    function GetLastError: string;

    // Extended API
    procedure SetDryRun(AEnable: Boolean);
    function GetCommandLog: TStringArray;
    function GetCommandLogCount: Integer;
  end;

implementation

constructor TCrossBuildEngine.Create(ABuildManager: TBuildManager; AOwnsManager: Boolean);
begin
  inherited Create;
  FBuildManager := ABuildManager;
  FOwnsManager := AOwnsManager;
  FCurrentStage := cbsIdle;
  FLastError := '';
  FCrossCompilerPath := '';
  FDryRun := False;
  FCommandLog := nil;
  SetLength(FCommandLog, 64);
  FCommandLogCount := 0;
end;

destructor TCrossBuildEngine.Destroy;
begin
  if FOwnsManager and Assigned(FBuildManager) then
    FBuildManager.Free;
  inherited Destroy;
end;

procedure TCrossBuildEngine.SetStage(AStage: TCrossBuildStage);
begin
  FCurrentStage := AStage;
end;

procedure TCrossBuildEngine.AddToLog(const ALine: string);
begin
  if FCommandLogCount >= Length(FCommandLog) then
    SetLength(FCommandLog, Length(FCommandLog) * 2);
  FCommandLog[FCommandLogCount] := ALine;
  Inc(FCommandLogCount);
end;

procedure TCrossBuildEngine.LogCommand(const AStep, ADescription: string);
begin
  AddToLog('[' + AStep + '] ' + ADescription);
end;

function TCrossBuildEngine.BuildCrossOpt(const ATarget: TCrossTarget): string;
begin
  Result := TCrossOptBuilder.Build(ATarget);
end;

function TCrossBuildEngine.ResolveCrossCompilerPath(const ATarget: TCrossTarget;
  const ASourceRoot, {%H-}AVersion: string): string;
var
  PPName, CompilerDir: string;
begin
  Result := '';
  PPName := TCrossCompilerResolver.GetPPCrossName(ATarget.CPU);
  if PPName = '' then
  begin
    FLastError := 'Unknown CPU target: ' + ATarget.CPU;
    Exit;
  end;

  // After compiler_cycle + compiler_install, the cross-compiler should be in
  // the sandbox or build output directory
  CompilerDir := ASourceRoot + PathDelim + 'compiler';
  {$IFDEF MSWINDOWS}
  PPName := PPName + '.exe';
  {$ENDIF}

  // Search order: compiler output dir, then system paths
  if FileExists(CompilerDir + PathDelim + PPName) then
    Result := CompilerDir + PathDelim + PPName
  else
    Result := TCrossCompilerResolver.FindCrossCompiler(ATarget.CPU, ASourceRoot);

  // In dry-run mode, return a placeholder path if not found
  if (Result = '') and FDryRun then
    Result := '<' + PPName + '>';
end;

function TCrossBuildEngine.GetCurrentStage: TCrossBuildStage;
begin
  Result := FCurrentStage;
end;

function TCrossBuildEngine.GetLastError: string;
begin
  Result := FLastError;
end;

procedure TCrossBuildEngine.SetDryRun(AEnable: Boolean);
begin
  FDryRun := AEnable;
  if Assigned(FBuildManager) then
    FBuildManager.SetDryRun(AEnable);
end;

function TCrossBuildEngine.GetCommandLog: TStringArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, FCommandLogCount);
  for I := 0 to FCommandLogCount - 1 do
    Result[I] := FCommandLog[I];
end;

function TCrossBuildEngine.GetCommandLogCount: Integer;
begin
  Result := FCommandLogCount;
end;

{ ICrossBuildEngine implementation }

function TCrossBuildEngine.Preflight(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot: string): Boolean;
begin
  SetStage(cbsPreflight);
  FLastError := '';

  // Validate target
  if ATarget.CPU = '' then
  begin
    FLastError := 'Target CPU not specified';
    SetStage(cbsFailed);
    Exit(False);
  end;
  if ATarget.OS = '' then
  begin
    FLastError := 'Target OS not specified';
    SetStage(cbsFailed);
    Exit(False);
  end;

  // Check source root exists
  if not DirectoryExists(ASourceRoot) then
  begin
    if not FDryRun then
    begin
      FLastError := 'Source root not found: ' + ASourceRoot;
      SetStage(cbsFailed);
      Exit(False);
    end;
  end;

  // Verify cross-compiler name is known
  if TCrossCompilerResolver.GetPPCrossName(ATarget.CPU) = '' then
  begin
    FLastError := 'Unsupported CPU target: ' + ATarget.CPU;
    SetStage(cbsFailed);
    Exit(False);
  end;

  LogCommand('preflight', 'Target: ' + ATarget.CPU + '-' + ATarget.OS +
    ', Source: ' + ASourceRoot + ', Sandbox: ' + ASandboxRoot);

  Result := True;
end;

function TCrossBuildEngine.CompilerCycle(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
begin
  SetStage(cbsCompilerCycle);
  FLastError := '';

  // Step 1: Build cross-compiler using NATIVE compiler
  // No PP= needed (use system default), but we need CPU_TARGET and OS_TARGET
  FBuildManager.SetTarget(ATarget.CPU, ATarget.OS);
  // Clear PP and CROSSOPT for compiler build (use native compiler)
  FBuildManager.SetPP('');
  FBuildManager.SetCrossOpt('');

  LogCommand('step1:compiler_cycle',
    'make -C ' + ASourceRoot + ' CPU_TARGET=' + ATarget.CPU +
    ' OS_TARGET=' + ATarget.OS + ' compiler_cycle');

  Result := FBuildManager.BuildCompiler(AVersion);
  if not Result then
  begin
    FLastError := 'Compiler cycle failed for ' + ATarget.CPU + '-' + ATarget.OS;
    SetStage(cbsFailed);
  end;
end;

function TCrossBuildEngine.InstallCompiler(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
begin
  SetStage(cbsCompilerInstall);
  FLastError := '';

  // Step 2: Install the cross-compiler to sandbox
  FBuildManager.SetTarget(ATarget.CPU, ATarget.OS);
  FBuildManager.SetPP('');
  FBuildManager.SetCrossOpt('');
  FBuildManager.SetSandboxRoot(ASandboxRoot);
  FBuildManager.SetAllowInstall(True);

  LogCommand('step2:compiler_install',
    'make -C ' + ASourceRoot + ' CPU_TARGET=' + ATarget.CPU +
    ' OS_TARGET=' + ATarget.OS + ' compiler_install');

  Result := FBuildManager.Install(AVersion);
  if not Result then
  begin
    FLastError := 'Compiler install failed for ' + ATarget.CPU + '-' + ATarget.OS;
    SetStage(cbsFailed);
  end;

  // Resolve cross-compiler path for subsequent steps
  if Result then
    FCrossCompilerPath := ResolveCrossCompilerPath(ATarget, ASourceRoot, AVersion);
end;

function TCrossBuildEngine.BuildRTL(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
var
  CrossOpt: string;
begin
  SetStage(cbsRTLBuild);
  FLastError := '';

  // Step 3: Build RTL using the NEW cross-compiler (PP=ppcross*)
  CrossOpt := BuildCrossOpt(ATarget);
  FBuildManager.SetTarget(ATarget.CPU, ATarget.OS);
  FBuildManager.SetPP(FCrossCompilerPath);
  FBuildManager.SetCrossOpt(CrossOpt);

  LogCommand('step3:rtl_build',
    'make -C ' + ASourceRoot + ' CPU_TARGET=' + ATarget.CPU +
    ' OS_TARGET=' + ATarget.OS +
    ' PP=' + FCrossCompilerPath +
    ' CROSSOPT="' + CrossOpt + '" rtl');

  Result := FBuildManager.BuildRTL(AVersion);
  if not Result then
  begin
    FLastError := 'RTL build failed for ' + ATarget.CPU + '-' + ATarget.OS;
    SetStage(cbsFailed);
  end;
end;

function TCrossBuildEngine.InstallRTL(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
var
  CrossOpt: string;
begin
  SetStage(cbsRTLInstall);
  FLastError := '';

  // Step 4: Install RTL using cross-compiler
  CrossOpt := BuildCrossOpt(ATarget);
  FBuildManager.SetTarget(ATarget.CPU, ATarget.OS);
  FBuildManager.SetPP(FCrossCompilerPath);
  FBuildManager.SetCrossOpt(CrossOpt);
  FBuildManager.SetSandboxRoot(ASandboxRoot);
  FBuildManager.SetAllowInstall(True);

  LogCommand('step4:rtl_install',
    'make -C ' + ASourceRoot + ' CPU_TARGET=' + ATarget.CPU +
    ' OS_TARGET=' + ATarget.OS +
    ' PP=' + FCrossCompilerPath + ' rtl_install');

  Result := FBuildManager.Install(AVersion);
  if not Result then
  begin
    FLastError := 'RTL install failed for ' + ATarget.CPU + '-' + ATarget.OS;
    SetStage(cbsFailed);
  end;
end;

function TCrossBuildEngine.BuildPackages(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
var
  CrossOpt: string;
begin
  SetStage(cbsPackagesBuild);
  FLastError := '';

  // Step 5: Build packages using cross-compiler
  CrossOpt := BuildCrossOpt(ATarget);
  FBuildManager.SetTarget(ATarget.CPU, ATarget.OS);
  FBuildManager.SetPP(FCrossCompilerPath);
  FBuildManager.SetCrossOpt(CrossOpt);

  LogCommand('step5:packages_build',
    'make -C ' + ASourceRoot + ' CPU_TARGET=' + ATarget.CPU +
    ' OS_TARGET=' + ATarget.OS +
    ' PP=' + FCrossCompilerPath +
    ' CROSSOPT="' + CrossOpt + '" packages');

  Result := FBuildManager.BuildPackages(AVersion);
  if not Result then
  begin
    FLastError := 'Packages build failed for ' + ATarget.CPU + '-' + ATarget.OS;
    SetStage(cbsFailed);
  end;
end;

function TCrossBuildEngine.InstallPackages(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
var
  CrossOpt: string;
begin
  SetStage(cbsPackagesInstall);
  FLastError := '';

  // Step 6: Install packages
  CrossOpt := BuildCrossOpt(ATarget);
  FBuildManager.SetTarget(ATarget.CPU, ATarget.OS);
  FBuildManager.SetPP(FCrossCompilerPath);
  FBuildManager.SetCrossOpt(CrossOpt);
  FBuildManager.SetSandboxRoot(ASandboxRoot);
  FBuildManager.SetAllowInstall(True);

  LogCommand('step6:packages_install',
    'make -C ' + ASourceRoot + ' CPU_TARGET=' + ATarget.CPU +
    ' OS_TARGET=' + ATarget.OS +
    ' PP=' + FCrossCompilerPath + ' packages_install');

  Result := FBuildManager.Install(AVersion);
  if not Result then
  begin
    FLastError := 'Packages install failed for ' + ATarget.CPU + '-' + ATarget.OS;
    SetStage(cbsFailed);
  end;
end;

function TCrossBuildEngine.Verify(const ATarget: TCrossTarget;
  const ASandboxRoot, AVersion: string): Boolean;
var
  PPName, ExpectedPath: string;
begin
  SetStage(cbsVerify);
  FLastError := '';

  // Step 7: Verify the cross-compiler was built correctly
  PPName := TCrossCompilerResolver.GetPPCrossName(ATarget.CPU);
  {$IFDEF MSWINDOWS}
  PPName := PPName + '.exe';
  {$ENDIF}

  ExpectedPath := ASandboxRoot + PathDelim + 'fpc-' + AVersion +
    PathDelim + 'bin' + PathDelim + PPName;

  LogCommand('step7:verify', 'Checking: ' + ExpectedPath);

  if FDryRun then
  begin
    // In dry-run mode, always succeed verification
    SetStage(cbsComplete);
    Result := True;
    Exit;
  end;

  Result := FileExists(ExpectedPath);
  if Result then
    SetStage(cbsComplete)
  else
  begin
    FLastError := 'Cross-compiler not found at: ' + ExpectedPath;
    SetStage(cbsFailed);
  end;
end;

function TCrossBuildEngine.BuildCrossCompiler(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
begin
  Result := False;
  FCommandLogCount := 0;

  LogCommand('start', 'Cross-compile ' + ATarget.CPU + '-' + ATarget.OS +
    ' version=' + AVersion);

  // Step 0: Preflight
  if not Preflight(ATarget, ASourceRoot, ASandboxRoot) then Exit;

  // Step 1: Compiler cycle (native compiler builds cross-compiler)
  if not CompilerCycle(ATarget, ASourceRoot, AVersion) then Exit;

  // Step 2: Install compiler
  if not InstallCompiler(ATarget, ASourceRoot, ASandboxRoot, AVersion) then Exit;

  // Step 3: Build RTL (using new cross-compiler)
  if not BuildRTL(ATarget, ASourceRoot, AVersion) then Exit;

  // Step 4: Install RTL
  if not InstallRTL(ATarget, ASourceRoot, ASandboxRoot, AVersion) then Exit;

  // Step 5: Build packages (using cross-compiler)
  if not BuildPackages(ATarget, ASourceRoot, AVersion) then Exit;

  // Step 6: Install packages
  if not InstallPackages(ATarget, ASourceRoot, ASandboxRoot, AVersion) then Exit;

  // Step 7: Verify
  if not Verify(ATarget, ASandboxRoot, AVersion) then Exit;

  Result := True;
end;

end.
