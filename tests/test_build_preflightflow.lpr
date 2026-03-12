program test_build_preflightflow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.preflight,
  fpdev.build.preflightflow,
  fpdev.utils.fs;

type
  TPreflightProbe = class
  public
    PolicyCalls: Integer;
    JSONCalls: Integer;
    HasMakeCalls: Integer;
    CanWriteCalls: Integer;
    function PolicyCheck(const AVersion: string;
      out AStatus, AReason, AMin, ARecommended, ACurrentFpcVersion: string): Boolean;
    function BuildJSON: string;
    function HasMake: Boolean;
    function CanWriteDir(const APath: string): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

function TPreflightProbe.PolicyCheck(const AVersion: string;
  out AStatus, AReason, AMin, ARecommended, ACurrentFpcVersion: string): Boolean;
begin
  Inc(PolicyCalls);
  AStatus := 'WARN';
  AReason := 'policy warning';
  AMin := '3.2.0';
  ARecommended := '3.2.2';
  ACurrentFpcVersion := '3.2.2';
  Result := AVersion <> '';
end;

function TPreflightProbe.BuildJSON: string;
begin
  Inc(JSONCalls);
  Result := '{"toolchain":"ok"}';
end;

function TPreflightProbe.HasMake: Boolean;
begin
  Inc(HasMakeCalls);
  Result := True;
end;

function TPreflightProbe.CanWriteDir(const APath: string): Boolean;
begin
  Inc(CanWriteCalls);
  Result := Pos('readonly', APath) = 0;
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

function MakeTempDir(const APrefix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    APrefix + '-' + IntToStr(GetTickCount64);
  ForceDirectories(Result);
end;

procedure TestStrictPreflightBuildsPolicyAwareInputs;
var
  Probe: TPreflightProbe;
  RootDir, SourcePath, SandboxRoot, LogDir: string;
  Inputs: TBuildPreflightInputs;
begin
  Probe := TPreflightProbe.Create;
  RootDir := MakeTempDir('build-preflight-strict');
  try
    SourcePath := RootDir + PathDelim + 'src' + PathDelim + 'fpc-3.2.2';
    SandboxRoot := RootDir + PathDelim + 'sandbox';
    LogDir := RootDir + PathDelim + 'logs';
    ForceDirectories(SourcePath);

    Inputs := BuildBuildPreflightInputsCore(
      '3.2.2',
      SourcePath,
      SandboxRoot,
      LogDir,
      True,
      True,
      @Probe.PolicyCheck,
      @Probe.BuildJSON,
      @Probe.HasMake,
      @Probe.CanWriteDir
    );

    Check('strict preflight calls policy once', Probe.PolicyCalls = 1,
      'policy calls=' + IntToStr(Probe.PolicyCalls));
    Check('strict preflight calls json once', Probe.JSONCalls = 1,
      'json calls=' + IntToStr(Probe.JSONCalls));
    Check('strict preflight skips make probe', Probe.HasMakeCalls = 0,
      'make calls=' + IntToStr(Probe.HasMakeCalls));
    Check('strict preflight probes writable dirs thrice', Probe.CanWriteCalls = 3,
      'canwrite calls=' + IntToStr(Probe.CanWriteCalls));
    Check('strict preflight keeps source path', Inputs.SourcePath = SourcePath,
      'source=' + Inputs.SourcePath);
    Check('strict preflight marks source exists', Inputs.SourceExists,
      'source should exist');
    Check('strict preflight builds sandbox dest root',
      Inputs.SandboxDestRoot = SandboxRoot + PathDelim + 'fpc-3.2.2',
      'dest=' + Inputs.SandboxDestRoot);
    Check('strict preflight creates sandbox dir', DirectoryExists(SandboxRoot),
      'sandbox missing');
    Check('strict preflight creates log dir', DirectoryExists(LogDir),
      'log missing');
    Check('strict preflight creates install dest', DirectoryExists(Inputs.SandboxDestRoot),
      'dest missing');
    Check('strict preflight forwards policy status', Inputs.PolicyStatus = 'WARN',
      'status=' + Inputs.PolicyStatus);
    Check('strict preflight forwards report json', Inputs.ToolchainReportJSON = '{"toolchain":"ok"}',
      'json=' + Inputs.ToolchainReportJSON);
  finally
    DeleteDirRecursive(RootDir);
    Probe.Free;
  end;
end;

procedure TestNonStrictPreflightUsesMakeProbeAndSkipsPolicy;
var
  Probe: TPreflightProbe;
  RootDir, SourcePath, SandboxRoot, LogDir: string;
  Inputs: TBuildPreflightInputs;
begin
  Probe := TPreflightProbe.Create;
  RootDir := MakeTempDir('build-preflight-nonstrict');
  try
    SourcePath := RootDir + PathDelim + 'readonly-src' + PathDelim + 'fpc-3.2.0';
    SandboxRoot := RootDir + PathDelim + 'readonly-sandbox';
    LogDir := RootDir + PathDelim + 'readonly-logs';
    ForceDirectories(SourcePath);
    ForceDirectories(SandboxRoot);
    ForceDirectories(LogDir);

    Inputs := BuildBuildPreflightInputsCore(
      '3.2.0',
      SourcePath,
      SandboxRoot,
      LogDir,
      False,
      False,
      @Probe.PolicyCheck,
      @Probe.BuildJSON,
      @Probe.HasMake,
      @Probe.CanWriteDir
    );

    Check('non-strict preflight skips policy', Probe.PolicyCalls = 0,
      'policy calls=' + IntToStr(Probe.PolicyCalls));
    Check('non-strict preflight skips json', Probe.JSONCalls = 0,
      'json calls=' + IntToStr(Probe.JSONCalls));
    Check('non-strict preflight probes make once', Probe.HasMakeCalls = 1,
      'make calls=' + IntToStr(Probe.HasMakeCalls));
    Check('non-strict preflight probes writable dirs twice', Probe.CanWriteCalls = 2,
      'canwrite calls=' + IntToStr(Probe.CanWriteCalls));
    Check('non-strict preflight defaults policy passed', Inputs.PolicyCheckPassed,
      'policy should pass');
    Check('non-strict preflight records make availability', Inputs.HasMake,
      'make should be available');
    Check('non-strict preflight marks sandbox non-writable', not Inputs.SandboxWritable,
      'sandbox writable should be false');
    Check('non-strict preflight marks log non-writable', not Inputs.LogWritable,
      'log writable should be false');
    Check('non-strict preflight does not create install dest', not Inputs.SandboxDestExists,
      'dest exists should be false');
  finally
    DeleteDirRecursive(RootDir);
    Probe.Free;
  end;
end;

begin
  TestStrictPreflightBuildsPolicyAwareInputs;
  TestNonStrictPreflightUsesMakeProbeAndSkipsPolicy;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
