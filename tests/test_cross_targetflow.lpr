program test_cross_targetflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.config.interfaces,
  fpdev.cross.tester,
  fpdev.cross.query,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.utils.process,
  fpdev.cross.targetflow,
  test_temp_paths;

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
    function Contains(const S: string): Boolean;
  end;

  TCrossFlowProbe = class
  public
    GetResult: Boolean;
    SaveResult: Boolean;
    RunSuccess: Boolean;
    RunExitCode: Integer;
    BuildSuccess: Boolean;
    BuildOutputFile: string;
    BuildErrorMessage: string;
    GetCalls: Integer;
    SaveCalls: Integer;
    RunCalls: Integer;
    BuildCalls: Integer;
    LastTarget: string;
    LastSavedTarget: string;
    StoredTarget: TCrossTarget;
    LastExecutable: string;
    LastWorkDir: string;
    LastParams: TStringArray;
    LastBuildCPU: string;
    LastBuildOS: string;
    LastBuildBinutils: string;
    LastBuildLibraries: string;
    LastBuildSource: string;
    function GetTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function SaveTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function RunProcess(const AExecutable: string; const AParams: TStringArray;
      const AWorkDir: string): TProcessResult;
    function ExecuteBuild(const ATarget, ACPU, AOS, ABinutilsPath,
      ALibrariesPath, ASourceFile: string): TCrossBuildTestResult;
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

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TCrossFlowProbe.GetTarget(const ATarget: string; out AInfo: TCrossTarget): Boolean;
begin
  Inc(GetCalls);
  LastTarget := ATarget;
  AInfo := StoredTarget;
  Result := GetResult;
end;

function TCrossFlowProbe.SaveTarget(const ATarget: string; const AInfo: TCrossTarget): Boolean;
begin
  Inc(SaveCalls);
  LastSavedTarget := ATarget;
  StoredTarget := AInfo;
  Result := SaveResult;
end;

function TCrossFlowProbe.RunProcess(const AExecutable: string; const AParams: TStringArray;
  const AWorkDir: string): TProcessResult;
var
  Index: Integer;
begin
  Inc(RunCalls);
  LastExecutable := AExecutable;
  LastWorkDir := AWorkDir;
  SetLength(LastParams, Length(AParams));
  for Index := 0 to High(AParams) do
    LastParams[Index] := AParams[Index];

  Result.Success := RunSuccess;
  Result.ExitCode := RunExitCode;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.ErrorMessage := '';
end;

function TCrossFlowProbe.ExecuteBuild(const ATarget, ACPU, AOS, ABinutilsPath,
  ALibrariesPath, ASourceFile: string): TCrossBuildTestResult;
begin
  Inc(BuildCalls);
  LastTarget := ATarget;
  LastBuildCPU := ACPU;
  LastBuildOS := AOS;
  LastBuildBinutils := ABinutilsPath;
  LastBuildLibraries := ALibrariesPath;
  LastBuildSource := ASourceFile;
  Result.Success := BuildSuccess;
  Result.OutputFile := BuildOutputFile;
  Result.ErrorMessage := BuildErrorMessage;
  Result.ExitCode := Ord(not BuildSuccess);
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

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure EnsureDirPath(const APath: string);
begin
  if not DirectoryExists(APath) then
    ForceDirectories(APath);
end;

procedure TestCreateCrossTargetConfigCoreMapsFields;
var
  CrossTarget: TCrossTarget;
begin
  CrossTarget := CreateCrossTargetConfigCore(True, '/opt/bin', '/opt/lib');
  Check('create config enabled', CrossTarget.Enabled, 'expected enabled');
  Check('create config binutils path', CrossTarget.BinutilsPath = '/opt/bin',
    'got=' + CrossTarget.BinutilsPath);
  Check('create config libraries path', CrossTarget.LibrariesPath = '/opt/lib',
    'got=' + CrossTarget.LibrariesPath);
end;

procedure TestSetCrossTargetEnabledCorePersistsEnabledState;
var
  Probe: TCrossFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.GetResult := True;
    Probe.SaveResult := True;
    Probe.StoredTarget := Default(TCrossTarget);
    Probe.StoredTarget.Enabled := False;
    Probe.StoredTarget.BinutilsPath := '/tool/bin';

    OK := SetCrossTargetEnabledCore('win64', True, @Probe.GetTarget, @Probe.SaveTarget, OutRef, ErrRef);

    Check('enable target returns true', OK, 'expected success');
    Check('enable target saves once', Probe.SaveCalls = 1, 'save calls=' + IntToStr(Probe.SaveCalls));
    Check('enable target flips state', Probe.StoredTarget.Enabled, 'target not enabled');
    Check('enable target writes success', OutBuf.Contains(_Fmt(MSG_CROSS_ENABLED, ['win64'])),
      'missing success message');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestSetCrossTargetEnabledCoreReportsMissingConfig;
var
  Probe: TCrossFlowProbe;
  ErrBuf: TStringOutput;
  ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossFlowProbe.Create;
  ErrBuf := TStringOutput.Create;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.GetResult := False;

    OK := SetCrossTargetEnabledCore('linux64', False, @Probe.GetTarget, @Probe.SaveTarget, nil, ErrRef);

    Check('disable missing target returns false', not OK, 'expected failure');
    Check('disable missing target writes not-configured',
      ErrBuf.Contains(_Fmt(CMD_CROSS_TARGET_NOT_CONFIGURED, ['linux64'])),
      'missing not-configured error');
  finally
    ErrRef := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestConfigureCrossTargetCoreRejectsMissingBinutilsDir;
var
  Probe: TCrossFlowProbe;
  ErrBuf: TStringOutput;
  ErrRef: IOutput;
  TempRoot, MissingBinDir: string;
  OK: Boolean;
begin
  Probe := TCrossFlowProbe.Create;
  ErrBuf := TStringOutput.Create;
  ErrRef := ErrBuf as IOutput;
  TempRoot := CreateUniqueTempDir('fpdev-cross-targetflow-missing-lib');
  MissingBinDir := TempRoot + PathDelim + 'not-found-bin';
  try
    Probe.SaveResult := True;

    OK := ConfigureCrossTargetCore('win64', MissingBinDir, TempRoot,
      True, @Probe.SaveTarget, nil, ErrRef);

    Check('configure missing binutils returns false', not OK, 'expected failure');
    Check('configure missing binutils writes error',
      ErrBuf.Contains(_Fmt(CMD_CROSS_BINUTILS_PATH_NOT_FOUND, [MissingBinDir])),
      'missing binutils error');
  finally
    CleanupTempDir(TempRoot);
    ErrRef := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestConfigureCrossTargetCoreSavesConfiguredTarget;
var
  Probe: TCrossFlowProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
  TempRoot, BinDir, LibDir: string;
  OK: Boolean;
begin
  Probe := TCrossFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  TempRoot := CreateUniqueTempDir('fpdev-cross-targetflow-configured');
  BinDir := TempRoot + PathDelim + 'bin';
  LibDir := TempRoot + PathDelim + 'lib';
  EnsureDirPath(BinDir);
  EnsureDirPath(LibDir);
  try
    Probe.SaveResult := True;

    OK := ConfigureCrossTargetCore('win64', BinDir, LibDir, True, @Probe.SaveTarget, OutRef, nil);

    Check('configure target returns true', OK, 'expected success');
    Check('configure target saves once', Probe.SaveCalls = 1, 'save calls=' + IntToStr(Probe.SaveCalls));
    Check('configure target stored enabled', Probe.StoredTarget.Enabled, 'expected enabled');
    Check('configure target stored binutils', Probe.StoredTarget.BinutilsPath = BinDir,
      'got=' + Probe.StoredTarget.BinutilsPath);
    Check('configure target writes success',
      OutBuf.Contains('Cross-compilation target win64 configured successfully'),
      'missing configure success');
  finally
    CleanupTempDir(TempRoot);
    OutRef := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestTestCrossTargetCoreRunsCompilerVersionCheck;
var
  Probe: TCrossFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  TargetInfo: TCrossTargetQueryInfo;
  TempRoot, BinDir, GCCPath: string;
  OK: Boolean;
begin
  Probe := TCrossFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  TempRoot := CreateUniqueTempDir('fpdev-cross-targetflow-gcc');
  BinDir := TempRoot + PathDelim + 'bin';
  EnsureDirPath(BinDir);
  GCCPath := BinDir + PathDelim + 'x86_64-w64-mingw32-gcc';
  with TFileStream.Create(GCCPath, fmCreate) do Free;
  try
    Probe.GetResult := True;
    Probe.StoredTarget := CreateCrossTargetConfigCore(True, BinDir, '/tool/lib');
    Probe.RunSuccess := True;
    Probe.RunExitCode := 0;
    TargetInfo := Default(TCrossTargetQueryInfo);
    TargetInfo.BinutilsPrefix := 'x86_64-w64-mingw32-';

    OK := TestCrossTargetCore('win64', True, TargetInfo, @Probe.GetTarget, @Probe.RunProcess, OutRef, ErrRef);

    Check('test target returns true', OK, 'expected success');
    Check('test target executes gcc --version',
      (Probe.LastExecutable = GCCPath) and (Length(Probe.LastParams) = 1) and (Probe.LastParams[0] = '--version'),
      'unexpected process invocation');
    Check('test target writes success', OutBuf.Contains(_Fmt(MSG_CROSS_TEST_PASSED, ['win64'])),
      'missing success message');
  finally
    DeleteFile(GCCPath);
    CleanupTempDir(TempRoot);
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestTestCrossTargetCoreReportsMissingCompiler;
var
  Probe: TCrossFlowProbe;
  ErrBuf: TStringOutput;
  ErrRef: IOutput;
  TargetInfo: TCrossTargetQueryInfo;
  OK: Boolean;
begin
  Probe := TCrossFlowProbe.Create;
  ErrBuf := TStringOutput.Create;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.GetResult := True;
    Probe.StoredTarget := CreateCrossTargetConfigCore(True, '/missing/bin', '/tool/lib');
    TargetInfo := Default(TCrossTargetQueryInfo);
    TargetInfo.BinutilsPrefix := 'arm-linux-gnueabihf-';

    OK := TestCrossTargetCore('arm-linux', True, TargetInfo, @Probe.GetTarget, @Probe.RunProcess, nil, ErrRef);

    Check('missing compiler returns false', not OK, 'expected failure');
    Check('missing compiler writes path error',
      ErrBuf.Contains(_Fmt(CMD_CROSS_COMPILER_NOT_FOUND, ['/missing/bin' + PathDelim + 'arm-linux-gnueabihf-gcc'])),
      'missing compiler error');
  finally
    ErrRef := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestBuildCrossTargetTestCoreReportsSuccess;
var
  Probe: TCrossFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  TargetInfo: TCrossTargetQueryInfo;
  OK: Boolean;
begin
  Probe := TCrossFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.GetResult := True;
    Probe.StoredTarget := CreateCrossTargetConfigCore(True, '/cross/bin', '/cross/lib');
    Probe.BuildSuccess := True;
    Probe.BuildOutputFile := '/tmp/cross-test.exe';
    TargetInfo := Default(TCrossTargetQueryInfo);
    TargetInfo.CPU := 'x86_64';
    TargetInfo.OS := 'win64';

    OK := BuildCrossTargetTestCore('win64', 'hello.pas', True, TargetInfo,
      @Probe.GetTarget, @Probe.ExecuteBuild, OutRef, ErrRef);

    Check('build test returns true', OK, 'expected success');
    Check('build test forwards cpu/os',
      (Probe.LastBuildCPU = 'x86_64') and (Probe.LastBuildOS = 'win64'),
      'cpu/os mismatch');
    Check('build test forwards tool paths',
      (Probe.LastBuildBinutils = '/cross/bin') and (Probe.LastBuildLibraries = '/cross/lib'),
      'tool path mismatch');
    Check('build test writes output file',
      OutBuf.Contains(_Fmt(MSG_CROSS_OUTPUT_FILE, ['/tmp/cross-test.exe'])),
      'missing output file line');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

begin
  TestCreateCrossTargetConfigCoreMapsFields;
  TestSetCrossTargetEnabledCorePersistsEnabledState;
  TestSetCrossTargetEnabledCoreReportsMissingConfig;
  TestConfigureCrossTargetCoreRejectsMissingBinutilsDir;
  TestConfigureCrossTargetCoreSavesConfiguredTarget;
  TestTestCrossTargetCoreRunsCompilerVersionCheck;
  TestTestCrossTargetCoreReportsMissingCompiler;
  TestBuildCrossTargetTestCoreReportsSuccess;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
