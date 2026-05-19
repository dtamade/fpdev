unit fpdev.cross.engine.pipelineflow;

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
  { TCrossBuildPipelineStep - Callback signature for a single pipeline step }
  TCrossBuildPipelineStep = function(const ATarget: TCrossTarget;
    const ASourceRoot, ASandboxRoot, AVersion: string): Boolean of object;

  { TCrossBuildPipeline - Orchestrates the 7-step cross-compilation pipeline }
  TCrossBuildPipeline = class
  private
    FBuildManager: TBuildManager;
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
      const ASourceRoot, AVersion: string): string;
  public
    constructor Create(ABuildManager: TBuildManager);

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

    function BuildCrossCompiler(const ATarget: TCrossTarget;
      const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;

    procedure SetDryRun(AEnable: Boolean);
    function GetCommandLog: TStringArray;
    function GetCommandLogCount: Integer;

    property CurrentStage: TCrossBuildStage read FCurrentStage;
    property LastError: string read FLastError;
    property CrossCompilerPath: string read FCrossCompilerPath;
  end;

implementation

{ TCrossBuildPipeline }

constructor TCrossBuildPipeline.Create(ABuildManager: TBuildManager);
begin
  inherited Create;
  FBuildManager := ABuildManager;
  FCurrentStage := cbsIdle;
  FLastError := '';
  FCrossCompilerPath := '';
  FDryRun := False;
  FCommandLog := nil;
  SetLength(FCommandLog, 64);
  FCommandLogCount := 0;
end;

procedure TCrossBuildPipeline.SetStage(AStage: TCrossBuildStage);
begin
  FCurrentStage := AStage;
end;

procedure TCrossBuildPipeline.AddToLog(const ALine: string);
begin
  if FCommandLogCount >= Length(FCommandLog) then
    SetLength(FCommandLog, Length(FCommandLog) * 2);
  FCommandLog[FCommandLogCount] := ALine;
  Inc(FCommandLogCount);
end;

procedure TCrossBuildPipeline.LogCommand(const AStep, ADescription: string);
begin
  AddToLog('[' + AStep + '] ' + ADescription);
end;

function TCrossBuildPipeline.BuildCrossOpt(const ATarget: TCrossTarget): string;
begin
  Result := TCrossOptBuilder.Build(ATarget);
end;

function TCrossBuildPipeline.ResolveCrossCompilerPath(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): string;
var
  PPName, CompilerDir: string;
begin
  Result := '';
  if AVersion <> '' then;
  PPName := TCrossCompilerResolver.GetPPCrossName(ATarget.CPU);
  if PPName = '' then
  begin
    FLastError := 'Unknown CPU target: ' + ATarget.CPU;
    Exit;
  end;

  CompilerDir := ASourceRoot + PathDelim + 'compiler';
  {$IFDEF MSWINDOWS}
  PPName := PPName + '.exe';
  {$ENDIF}

  if FileExists(CompilerDir + PathDelim + PPName) then
    Result := CompilerDir + PathDelim + PPName
  else
    Result := TCrossCompilerResolver.FindCrossCompiler(ATarget.CPU, ASourceRoot);

  if (Result = '') and FDryRun then
    Result := CompilerDir + PathDelim + PPName;
end;

procedure TCrossBuildPipeline.SetDryRun(AEnable: Boolean);
begin
  FDryRun := AEnable;
  if Assigned(FBuildManager) then
    FBuildManager.SetDryRun(AEnable);
end;

function TCrossBuildPipeline.GetCommandLog: TStringArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, FCommandLogCount);
  for I := 0 to FCommandLogCount - 1 do
    Result[I] := FCommandLog[I];
end;

function TCrossBuildPipeline.GetCommandLogCount: Integer;
begin
  Result := FCommandLogCount;
end;

function TCrossBuildPipeline.Preflight(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot: string): Boolean;
begin
  SetStage(cbsPreflight);
  FLastError := '';

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

  if not DirectoryExists(ASourceRoot) then
  begin
    if not FDryRun then
    begin
      FLastError := 'Source root not found: ' + ASourceRoot;
      SetStage(cbsFailed);
      Exit(False);
    end;
  end;

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

function TCrossBuildPipeline.CompilerCycle(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
begin
  SetStage(cbsCompilerCycle);
  FLastError := '';

  FBuildManager.SetTarget(ATarget.CPU, ATarget.OS);
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

function TCrossBuildPipeline.InstallCompiler(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
begin
  SetStage(cbsCompilerInstall);
  FLastError := '';

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

  if Result then
    FCrossCompilerPath := ResolveCrossCompilerPath(ATarget, ASourceRoot, AVersion);
end;

function TCrossBuildPipeline.BuildRTL(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
var
  CrossOpt: string;
begin
  SetStage(cbsRTLBuild);
  FLastError := '';

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

function TCrossBuildPipeline.InstallRTL(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
var
  CrossOpt: string;
begin
  SetStage(cbsRTLInstall);
  FLastError := '';

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

function TCrossBuildPipeline.BuildPackages(const ATarget: TCrossTarget;
  const ASourceRoot, AVersion: string): Boolean;
var
  CrossOpt: string;
begin
  SetStage(cbsPackagesBuild);
  FLastError := '';

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

function TCrossBuildPipeline.InstallPackages(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
var
  CrossOpt: string;
begin
  SetStage(cbsPackagesInstall);
  FLastError := '';

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

function TCrossBuildPipeline.Verify(const ATarget: TCrossTarget;
  const ASandboxRoot, AVersion: string): Boolean;
var
  PPName, ExpectedPath: string;
begin
  SetStage(cbsVerify);
  FLastError := '';

  PPName := TCrossCompilerResolver.GetPPCrossName(ATarget.CPU);
  {$IFDEF MSWINDOWS}
  PPName := PPName + '.exe';
  {$ENDIF}

  ExpectedPath := ASandboxRoot + PathDelim + 'fpc-' + AVersion +
    PathDelim + 'bin' + PathDelim + PPName;

  LogCommand('step7:verify', 'Checking: ' + ExpectedPath);

  if FDryRun then
  begin
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

function TCrossBuildPipeline.BuildCrossCompiler(const ATarget: TCrossTarget;
  const ASourceRoot, ASandboxRoot, AVersion: string): Boolean;
begin
  Result := False;
  FCommandLogCount := 0;

  LogCommand('start', 'Cross-compile ' + ATarget.CPU + '-' + ATarget.OS +
    ' version=' + AVersion);

  if not Preflight(ATarget, ASourceRoot, ASandboxRoot) then Exit;
  if not CompilerCycle(ATarget, ASourceRoot, AVersion) then Exit;
  if not InstallCompiler(ATarget, ASourceRoot, ASandboxRoot, AVersion) then Exit;
  if not BuildRTL(ATarget, ASourceRoot, AVersion) then Exit;
  if not InstallRTL(ATarget, ASourceRoot, ASandboxRoot, AVersion) then Exit;
  if not BuildPackages(ATarget, ASourceRoot, AVersion) then Exit;
  if not InstallPackages(ATarget, ASourceRoot, ASandboxRoot, AVersion) then Exit;
  if not Verify(ATarget, ASandboxRoot, AVersion) then Exit;

  Result := True;
end;

end.
