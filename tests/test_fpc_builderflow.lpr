program test_fpc_builderflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.process,
  fpdev.fpc.builder, fpdev.fpc.builderflow, fpdev.fpc.builder.bootstrapresolveflow;

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Text: string;
  end;

  TBuilderFlowHarness = class
  public
    RequiredVersion: string;
    CurrentVersion: string;
    InstalledBootstrapVersion: string;
    InstalledBootstrapCompiler: string;
    BootstrapAvailable: Boolean;
    BootstrapPath: string;
    EnsureRepoResult: Boolean;
    HasRepoBootstrapResult: Boolean;
    BestRepoBootstrapVersion: string;
    InstallBootstrapResult: Boolean;
    SourceExistsResult: Boolean;
    PrepareCalls: Integer;
    EnsureDirCalls: Integer;
    ResolvePlanCalls: Integer;
    ExecutePlanCalls: Integer;
    EnsureRepoCalls: Integer;
    HasRepoBootstrapCalls: Integer;
    FindBestCalls: Integer;
    InstallBootstrapCalls: Integer;
    LastResolvedInstallDir: string;
    LastResolvedBootstrap: string;
    LastResolvedJobs: Integer;
    LastExecuteSourceDir: string;
    LastInstallVersion: string;
    LastInstallPlatform: string;
    LastInstallDestDir: string;
    BuildPlan: TFPCBuilderBuildPlan;
    BuildResult: TProcessResult;
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;
    function GetCurrentCompilerVersion: string;
    function TryResolveInstalledBootstrapCompiler(
      const ATargetVersion, ARequiredVersion: string;
      out AResolvedVersion, AResolvedCompiler: string
    ): Boolean;
    function IsBootstrapAvailable(const AVersion: string): Boolean;
    function GetBootstrapCompilerPath(const AVersion: string): string;
    function EnsureResourceRepository: Boolean;
    function HasResourceRepositoryBootstrapCompiler(
      const AVersion, APlatform: string
    ): Boolean;
    function FindBestResourceRepositoryBootstrapVersion(
      const AFPCVersion, APlatform: string
    ): string;
    function InstallBootstrapFromResourceRepository(
      const AVersion, APlatform, ADestDir: string
    ): Boolean;
    function SourceDirectoryExists(const APath: string): Boolean;
    procedure PrepareSourceTree(const ASourceDir: string);
    procedure EnsureInstallDirectory(const APath: string);
    function ResolveBuildPlan(
      const AInstallDir, ABootstrapFPC: string;
      const AParallelJobs: Integer
    ): TFPCBuilderBuildPlan;
    function ExecuteBuildPlan(
      const ABuildPlan: TFPCBuilderBuildPlan;
      const ASourceDir: string
    ): TProcessResult;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TStringOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TBuilderFlowHarness.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  if ATargetVersion <> '' then;
  Result := RequiredVersion;
end;

function TBuilderFlowHarness.GetCurrentCompilerVersion: string;
begin
  Result := CurrentVersion;
end;

function TBuilderFlowHarness.TryResolveInstalledBootstrapCompiler(
  const ATargetVersion, ARequiredVersion: string;
  out AResolvedVersion, AResolvedCompiler: string
): Boolean;
begin
  if ATargetVersion <> '' then;
  if ARequiredVersion <> '' then;
  AResolvedVersion := InstalledBootstrapVersion;
  AResolvedCompiler := InstalledBootstrapCompiler;
  Result := (InstalledBootstrapVersion <> '') and (InstalledBootstrapCompiler <> '');
end;

function TBuilderFlowHarness.IsBootstrapAvailable(const AVersion: string): Boolean;
begin
  if AVersion <> '' then;
  Result := BootstrapAvailable;
end;

function TBuilderFlowHarness.GetBootstrapCompilerPath(const AVersion: string): string;
begin
  if AVersion <> '' then;
  Result := BootstrapPath;
end;

function TBuilderFlowHarness.EnsureResourceRepository: Boolean;
begin
  Inc(EnsureRepoCalls);
  Result := EnsureRepoResult;
end;

function TBuilderFlowHarness.HasResourceRepositoryBootstrapCompiler(
  const AVersion, APlatform: string
): Boolean;
begin
  Inc(HasRepoBootstrapCalls);
  if AVersion <> '' then;
  if APlatform <> '' then;
  Result := HasRepoBootstrapResult;
end;

function TBuilderFlowHarness.FindBestResourceRepositoryBootstrapVersion(
  const AFPCVersion, APlatform: string
): string;
begin
  Inc(FindBestCalls);
  if AFPCVersion <> '' then;
  if APlatform <> '' then;
  Result := BestRepoBootstrapVersion;
end;

function TBuilderFlowHarness.InstallBootstrapFromResourceRepository(
  const AVersion, APlatform, ADestDir: string
): Boolean;
begin
  Inc(InstallBootstrapCalls);
  LastInstallVersion := AVersion;
  LastInstallPlatform := APlatform;
  LastInstallDestDir := ADestDir;
  Result := InstallBootstrapResult;
end;

function TBuilderFlowHarness.SourceDirectoryExists(const APath: string): Boolean;
begin
  if APath <> '' then;
  Result := SourceExistsResult;
end;

procedure TBuilderFlowHarness.PrepareSourceTree(const ASourceDir: string);
begin
  Inc(PrepareCalls);
  if ASourceDir <> '' then;
end;

procedure TBuilderFlowHarness.EnsureInstallDirectory(const APath: string);
begin
  Inc(EnsureDirCalls);
  LastResolvedInstallDir := APath;
end;

function TBuilderFlowHarness.ResolveBuildPlan(
  const AInstallDir, ABootstrapFPC: string;
  const AParallelJobs: Integer
): TFPCBuilderBuildPlan;
begin
  Inc(ResolvePlanCalls);
  LastResolvedInstallDir := AInstallDir;
  LastResolvedBootstrap := ABootstrapFPC;
  LastResolvedJobs := AParallelJobs;
  Result := BuildPlan;
end;

function TBuilderFlowHarness.ExecuteBuildPlan(
  const ABuildPlan: TFPCBuilderBuildPlan;
  const ASourceDir: string
): TProcessResult;
begin
  Inc(ExecutePlanCalls);
  LastExecuteSourceDir := ASourceDir;
  if ABuildPlan.MakeCommand <> '' then;
  Result := BuildResult;
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; const ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TestEnsureBootstrapUsesSystemCompiler;
var
  Harness: TBuilderFlowHarness;
  Outp, Errp: TStringOutput;
  Callbacks: TFPCBuilderBootstrapCallbacks;
  State: TFPCBuilderBootstrapState;
begin
  Harness := TBuilderFlowHarness.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    State := Default(TFPCBuilderBootstrapState);
    Callbacks := Default(TFPCBuilderBootstrapCallbacks);
    Harness.RequiredVersion := '3.2.0';
    Harness.CurrentVersion := '3.2.2';

    State.TargetVersion := '3.2.2';
    State.Platform := 'linux';
    Callbacks.GetRequiredBootstrapVersion := @Harness.GetRequiredBootstrapVersion;
    Callbacks.GetCurrentCompilerVersion := @Harness.GetCurrentCompilerVersion;
    Callbacks.CanUseSystemCompiler := @FPCBuilderCanUseSystemCompilerAsBootstrapCore;
    Callbacks.TryResolveInstalledBootstrapCompiler := @Harness.TryResolveInstalledBootstrapCompiler;
    Callbacks.IsBootstrapAvailable := @Harness.IsBootstrapAvailable;
    Callbacks.GetBootstrapCompilerPath := @Harness.GetBootstrapCompilerPath;
    Callbacks.EnsureResourceRepository := @Harness.EnsureResourceRepository;
    Callbacks.HasResourceRepositoryBootstrapCompiler := @Harness.HasResourceRepositoryBootstrapCompiler;
    Callbacks.FindBestResourceRepositoryBootstrapVersion := @Harness.FindBestResourceRepositoryBootstrapVersion;
    Callbacks.InstallBootstrapFromResourceRepository := @Harness.InstallBootstrapFromResourceRepository;

    Check(
      'ensure bootstrap uses compatible system compiler',
      ExecuteFPCBuilderEnsureBootstrapCore(State, Outp, Errp, Callbacks),
      Errp.Text
    );
    Check(
      'ensure bootstrap skips repository when system compiler works',
      Harness.EnsureRepoCalls = 0,
      IntToStr(Harness.EnsureRepoCalls)
    );
    Check(
      'ensure bootstrap reports compatibility',
      Pos('bootstrap-compatible', Outp.Text) > 0,
      Outp.Text
    );
  finally
    Errp.Free;
    Outp.Free;
    Harness.Free;
  end;
end;

procedure TestEnsureBootstrapUsesRepositoryAlternative;
var
  Harness: TBuilderFlowHarness;
  Outp, Errp: TStringOutput;
  Callbacks: TFPCBuilderBootstrapCallbacks;
  State: TFPCBuilderBootstrapState;
begin
  Harness := TBuilderFlowHarness.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    State := Default(TFPCBuilderBootstrapState);
    Callbacks := Default(TFPCBuilderBootstrapCallbacks);
    Harness.RequiredVersion := '3.2.0';
    Harness.CurrentVersion := '3.1.1';
    Harness.EnsureRepoResult := True;
    Harness.BestRepoBootstrapVersion := '3.2.2';
    Harness.BootstrapPath := '/tmp/bootstrap/fpc';
    Harness.InstallBootstrapResult := True;

    State.TargetVersion := 'main';
    State.Platform := 'linux';
    Callbacks.GetRequiredBootstrapVersion := @Harness.GetRequiredBootstrapVersion;
    Callbacks.GetCurrentCompilerVersion := @Harness.GetCurrentCompilerVersion;
    Callbacks.CanUseSystemCompiler := @FPCBuilderCanUseSystemCompilerAsBootstrapCore;
    Callbacks.TryResolveInstalledBootstrapCompiler := @Harness.TryResolveInstalledBootstrapCompiler;
    Callbacks.IsBootstrapAvailable := @Harness.IsBootstrapAvailable;
    Callbacks.GetBootstrapCompilerPath := @Harness.GetBootstrapCompilerPath;
    Callbacks.EnsureResourceRepository := @Harness.EnsureResourceRepository;
    Callbacks.HasResourceRepositoryBootstrapCompiler := @Harness.HasResourceRepositoryBootstrapCompiler;
    Callbacks.FindBestResourceRepositoryBootstrapVersion := @Harness.FindBestResourceRepositoryBootstrapVersion;
    Callbacks.InstallBootstrapFromResourceRepository := @Harness.InstallBootstrapFromResourceRepository;

    Check(
      'ensure bootstrap installs repository alternative',
      ExecuteFPCBuilderEnsureBootstrapCore(State, Outp, Errp, Callbacks),
      Errp.Text
    );
    Check(
      'ensure bootstrap asks repository for best version',
      Harness.FindBestCalls = 1,
      IntToStr(Harness.FindBestCalls)
    );
    Check(
      'ensure bootstrap installs best repository version',
      (Harness.InstallBootstrapCalls = 1) and
      (Harness.LastInstallVersion = '3.2.2'),
      Harness.LastInstallVersion
    );
  finally
    Errp.Free;
    Outp.Free;
    Harness.Free;
  end;
end;

procedure TestBuildFromSourceBuildsWithResolvedPlan;
var
  Harness: TBuilderFlowHarness;
  Outp, Errp: TStringOutput;
  Callbacks: TFPCBuilderBuildCallbacks;
  State: TFPCBuilderBuildState;
begin
  Harness := TBuilderFlowHarness.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    State := Default(TFPCBuilderBuildState);
    Callbacks := Default(TFPCBuilderBuildCallbacks);
    Harness.SourceExistsResult := True;
    Harness.CurrentVersion := '3.2.2';
    Harness.RequiredVersion := '3.2.0';
    Harness.BuildPlan.MakeCommand := 'gmake';
    SetLength(Harness.BuildPlan.Params, 2);
    Harness.BuildPlan.Params[0] := 'all';
    Harness.BuildPlan.Params[1] := 'install';
    Harness.BuildResult.Success := True;
    Harness.BuildResult.ExitCode := 0;

    State.SourceDir := '/tmp/src';
    State.InstallDir := '/tmp/install';
    State.TargetVersion := '3.2.2';
    State.ParallelJobs := 4;
    Callbacks.SourceDirectoryExists := @Harness.SourceDirectoryExists;
    Callbacks.PrepareSourceTree := @Harness.PrepareSourceTree;
    Callbacks.EnsureInstallDirectory := @Harness.EnsureInstallDirectory;
    Callbacks.GetRequiredBootstrapVersion := @Harness.GetRequiredBootstrapVersion;
    Callbacks.GetCurrentCompilerVersion := @Harness.GetCurrentCompilerVersion;
    Callbacks.CanUseSystemCompiler := @FPCBuilderCanUseSystemCompilerAsBootstrapCore;
    Callbacks.TryResolveInstalledBootstrapCompiler := @Harness.TryResolveInstalledBootstrapCompiler;
    Callbacks.ResolveBuildPlan := @Harness.ResolveBuildPlan;
    Callbacks.ExecuteBuildPlan := @Harness.ExecuteBuildPlan;

    Check(
      'build from source executes resolved build plan',
      ExecuteFPCBuilderBuildFromSourceCore(State, Outp, Errp, Callbacks),
      Errp.Text
    );
    Check(
      'build from source prepares source tree once',
      Harness.PrepareCalls = 1,
      IntToStr(Harness.PrepareCalls)
    );
    Check(
      'build from source resolves plan once',
      Harness.ResolvePlanCalls = 1,
      IntToStr(Harness.ResolvePlanCalls)
    );
    Check(
      'build from source executes plan once',
      Harness.ExecutePlanCalls = 1,
      IntToStr(Harness.ExecutePlanCalls)
    );
    Check(
      'build from source uses system compiler bootstrap',
      Harness.LastResolvedBootstrap = 'fpc',
      Harness.LastResolvedBootstrap
    );
    Check(
      'build from source prints command line',
      Pos('Executing: gmake all install', Outp.Text) > 0,
      Outp.Text
    );
  finally
    Errp.Free;
    Outp.Free;
    Harness.Free;
  end;
end;

procedure TestBuildFromSourceMissingSourceShortCircuits;
var
  Harness: TBuilderFlowHarness;
  Outp, Errp: TStringOutput;
  Callbacks: TFPCBuilderBuildCallbacks;
  State: TFPCBuilderBuildState;
begin
  Harness := TBuilderFlowHarness.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    State := Default(TFPCBuilderBuildState);
    Callbacks := Default(TFPCBuilderBuildCallbacks);
    Harness.SourceExistsResult := False;
    State.SourceDir := '/missing/src';
    State.InstallDir := '/tmp/install';
    State.TargetVersion := '3.2.2';
    State.ParallelJobs := 2;
    Callbacks.SourceDirectoryExists := @Harness.SourceDirectoryExists;
    Callbacks.PrepareSourceTree := @Harness.PrepareSourceTree;
    Callbacks.EnsureInstallDirectory := @Harness.EnsureInstallDirectory;
    Callbacks.GetRequiredBootstrapVersion := @Harness.GetRequiredBootstrapVersion;
    Callbacks.GetCurrentCompilerVersion := @Harness.GetCurrentCompilerVersion;
    Callbacks.CanUseSystemCompiler := @FPCBuilderCanUseSystemCompilerAsBootstrapCore;
    Callbacks.TryResolveInstalledBootstrapCompiler := @Harness.TryResolveInstalledBootstrapCompiler;
    Callbacks.ResolveBuildPlan := @Harness.ResolveBuildPlan;
    Callbacks.ExecuteBuildPlan := @Harness.ExecuteBuildPlan;

    Check(
      'build from source rejects missing source directory',
      not ExecuteFPCBuilderBuildFromSourceCore(State, Outp, Errp, Callbacks),
      'expected failure'
    );
    Check(
      'build from source failure avoids plan resolution',
      (Harness.ResolvePlanCalls = 0) and (Harness.ExecutePlanCalls = 0),
      IntToStr(Harness.ResolvePlanCalls) + '/' + IntToStr(Harness.ExecutePlanCalls)
    );
    Check(
      'build from source failure reports missing source',
      Pos('Source directory', Errp.Text) > 0,
      Errp.Text
    );
  finally
    Errp.Free;
    Outp.Free;
    Harness.Free;
  end;
end;

begin
  TestEnsureBootstrapUsesSystemCompiler;
  TestEnsureBootstrapUsesRepositoryAlternative;
  TestBuildFromSourceBuildsWithResolvedPlan;
  TestBuildFromSourceMissingSourceShortCircuits;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
