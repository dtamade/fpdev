program test_cross_buildcommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.exitcodes,
  fpdev.cross.buildcommandflow,
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
    function Text: string;
  end;

  TCrossBuildProbe = class
  public
    BuildResult: Boolean;
    LastError: string;
    CurrentStage: string;
    SetDryRunCalls: Integer;
    BuildCalls: Integer;
    LastDryRunValue: Boolean;
    LastCPU: string;
    LastOS: string;
    LastSourceRoot: string;
    LastSandboxRoot: string;
    LastVersion: string;
    procedure SetDryRun(const AValue: Boolean);
    function BuildCrossCompiler(
      const ACPU, AOS, ASourceRoot, ASandboxRoot, AVersion: string
    ): Boolean;
    function GetLastError: string;
    function GetCurrentStage: string;
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

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
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

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

procedure TCrossBuildProbe.SetDryRun(const AValue: Boolean);
begin
  Inc(SetDryRunCalls);
  LastDryRunValue := AValue;
end;

function TCrossBuildProbe.BuildCrossCompiler(
  const ACPU, AOS, ASourceRoot, ASandboxRoot, AVersion: string
): Boolean;
begin
  Inc(BuildCalls);
  LastCPU := ACPU;
  LastOS := AOS;
  LastSourceRoot := ASourceRoot;
  LastSandboxRoot := ASandboxRoot;
  LastVersion := AVersion;
  Result := BuildResult;
end;

function TCrossBuildProbe.GetLastError: string;
begin
  Result := LastError;
end;

function TCrossBuildProbe.GetCurrentStage: string;
begin
  Result := CurrentStage;
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

procedure WriteTextFile(const APath, AContent: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

procedure TestPrepareHelpReturnsUsage;
var
  Plan: TCrossBuildCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareCrossBuildCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help shows dry-run option', Outp.Contains('--dry-run'), Outp.Text);
    Check('prepare help keeps stderr empty', Trim(Errp.Text) = '', Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareParsesTargetAndOptions;
var
  Plan: TCrossBuildCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareCrossBuildCommandPlanCore(
      ['x86_64-win64', '--dry-run', '--source=/tmp/src', '--sandbox=/tmp/sb', '--version=3.2.2'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare green path keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare green path keeps cpu', Plan.CPU = 'x86_64', Plan.CPU);
    Check('prepare green path keeps os', Plan.OS = 'win64', Plan.OS);
    Check('prepare green path keeps target label', Plan.TargetLabel = 'x86_64-win64', Plan.TargetLabel);
    Check('prepare green path keeps dry-run', Plan.DryRun, 'flag missing');
    Check('prepare green path keeps source root', Plan.SourceRoot = '/tmp/src', Plan.SourceRoot);
    Check('prepare green path keeps sandbox root', Plan.SandboxRoot = '/tmp/sb', Plan.SandboxRoot);
    Check('prepare green path keeps version', Plan.Version = '3.2.2', Plan.Version);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareRejectsInvalidTargetFormat;
var
  Plan: TCrossBuildCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareCrossBuildCommandPlanCore(['invalid'], Outp, Errp, Plan, ShouldExit);
    Check('prepare invalid target returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare invalid target requests exit', ShouldExit, 'should exit');
    Check('prepare invalid target reports format', Errp.Contains('invalid target format'), Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestExecuteDryRunShowsPlanAndSkipsBuild;
var
  Plan: TCrossBuildCommandPlan;
  Probe: TCrossBuildProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan.TargetLabel := 'x86_64-win64';
  Plan.CPU := 'x86_64';
  Plan.OS := 'win64';
  Plan.DryRun := True;
  Plan.SourceRoot := 'sources/fpc';
  Plan.SandboxRoot := 'sandbox';
  Plan.Version := 'main';

  Probe := TCrossBuildProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := ExecuteCrossBuildCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.SetDryRun,
      @Probe.BuildCrossCompiler,
      @Probe.GetLastError,
      @Probe.GetCurrentStage
    );
    Check('execute dry-run returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute dry-run sets dry-run mode', Probe.SetDryRunCalls = 1, IntToStr(Probe.SetDryRunCalls));
    Check('execute dry-run keeps dry-run value true', Probe.LastDryRunValue, 'expected true');
    Check('execute dry-run skips build call', Probe.BuildCalls = 0, IntToStr(Probe.BuildCalls));
    Check('execute dry-run shows plan header', Outp.Contains('Build Plan:'), Outp.Text);
    Check('execute dry-run shows skip notice', Outp.Contains('Dry-run: build execution skipped.'), Outp.Text);
    Check('execute dry-run keeps stderr empty', Trim(Errp.Text) = '', Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestExecuteMissingMakefileIsHelpful;
var
  TempDir: string;
  Plan: TCrossBuildCommandPlan;
  Probe: TCrossBuildProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  TempDir := CreateUniqueTempDir('fpdev_cross_build_missing_makefile');
  ForceDirectories(TempDir + PathDelim + 'fpc-main');

  Plan.TargetLabel := 'x86_64-win64';
  Plan.CPU := 'x86_64';
  Plan.OS := 'win64';
  Plan.DryRun := False;
  Plan.SourceRoot := TempDir;
  Plan.SandboxRoot := TempDir + PathDelim + 'sandbox';
  Plan.Version := 'main';

  Probe := TCrossBuildProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := ExecuteCrossBuildCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.SetDryRun,
      @Probe.BuildCrossCompiler,
      @Probe.GetLastError,
      @Probe.GetCurrentStage
    );
    Check('execute missing Makefile returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('execute missing Makefile skips build call', Probe.BuildCalls = 0, IntToStr(Probe.BuildCalls));
    Check('execute missing Makefile mentions Makefile', Errp.Contains('Makefile'), Errp.Text);
    Check('execute missing Makefile mentions versioned path',
      Errp.Contains(TempDir + PathDelim + 'fpc-main'),
      Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
    CleanupTempDir(TempDir);
  end;
end;

procedure TestExecuteBuildFailureReportsStage;
var
  TempDir: string;
  Plan: TCrossBuildCommandPlan;
  Probe: TCrossBuildProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  TempDir := CreateUniqueTempDir('fpdev_cross_build_failure');
  WriteTextFile(TempDir + PathDelim + 'fpc-main' + PathDelim + 'Makefile', 'all:' + LineEnding + #9 + 'echo ok');

  Plan.TargetLabel := 'arm-linux';
  Plan.CPU := 'arm';
  Plan.OS := 'linux';
  Plan.DryRun := False;
  Plan.SourceRoot := TempDir;
  Plan.SandboxRoot := TempDir + PathDelim + 'sandbox';
  Plan.Version := 'main';

  Probe := TCrossBuildProbe.Create;
  Probe.BuildResult := False;
  Probe.LastError := 'toolchain missing';
  Probe.CurrentStage := 'packages_build';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := ExecuteCrossBuildCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.SetDryRun,
      @Probe.BuildCrossCompiler,
      @Probe.GetLastError,
      @Probe.GetCurrentStage
    );
    Check('execute failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute failure calls build once', Probe.BuildCalls = 1, IntToStr(Probe.BuildCalls));
    Check('execute failure reports last error', Errp.Contains('toolchain missing'), Errp.Text);
    Check('execute failure reports stage', Errp.Contains('packages_build'), Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
    CleanupTempDir(TempDir);
  end;
end;

procedure TestExecuteSuccessReportsCompletion;
var
  TempDir: string;
  Plan: TCrossBuildCommandPlan;
  Probe: TCrossBuildProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  TempDir := CreateUniqueTempDir('fpdev_cross_build_success');
  WriteTextFile(TempDir + PathDelim + 'fpc-main' + PathDelim + 'Makefile', 'all:' + LineEnding + #9 + 'echo ok');

  Plan.TargetLabel := 'aarch64-linux';
  Plan.CPU := 'aarch64';
  Plan.OS := 'linux';
  Plan.DryRun := False;
  Plan.SourceRoot := TempDir;
  Plan.SandboxRoot := TempDir + PathDelim + 'sandbox';
  Plan.Version := 'main';

  Probe := TCrossBuildProbe.Create;
  Probe.BuildResult := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := ExecuteCrossBuildCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.SetDryRun,
      @Probe.BuildCrossCompiler,
      @Probe.GetLastError,
      @Probe.GetCurrentStage
    );
    Check('execute success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute success calls build once', Probe.BuildCalls = 1, IntToStr(Probe.BuildCalls));
    Check('execute success keeps cpu', Probe.LastCPU = 'aarch64', Probe.LastCPU);
    Check('execute success keeps os', Probe.LastOS = 'linux', Probe.LastOS);
    Check('execute success prints completion',
      Outp.Contains('Cross-compilation completed successfully.'),
      Outp.Text);
    Check('execute success keeps stderr empty', Trim(Errp.Text) = '', Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
    CleanupTempDir(TempDir);
  end;
end;

begin
  TestPrepareHelpReturnsUsage;
  TestPrepareParsesTargetAndOptions;
  TestPrepareRejectsInvalidTargetFormat;
  TestExecuteDryRunShowsPlanAndSkipsBuild;
  TestExecuteMissingMakefileIsHelpful;
  TestExecuteBuildFailureReportsStage;
  TestExecuteSuccessReportsCompletion;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  WriteLn('Total: ', PassCount + FailCount);

  if FailCount > 0 then
    Halt(1);
end.
