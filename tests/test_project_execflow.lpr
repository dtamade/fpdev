program test_project_execflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  test_temp_paths,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.utils.process,
  fpdev.project.execflow;

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

  TExecProbe = class
  public
    NextSuccess: Boolean;
    NextExitCode: Integer;
    CallCount: Integer;
    LastExecutable: string;
    LastWorkDir: string;
    LastParams: TStringArray;
    function Run(const AExecutable: string; const AParams: TStringArray;
      const AWorkDir: string): TProcessResult;
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

function TExecProbe.Run(const AExecutable: string; const AParams: TStringArray;
  const AWorkDir: string): TProcessResult;
var
  Index: Integer;
begin
  Inc(CallCount);
  LastExecutable := AExecutable;
  LastWorkDir := AWorkDir;
  SetLength(LastParams, Length(AParams));
  for Index := 0 to High(AParams) do
    LastParams[Index] := AParams[Index];

  Result.Success := NextSuccess;
  Result.ExitCode := NextExitCode;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.ErrorMessage := '';
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

procedure WriteFile(const APath, AContent: string);
var
  F: TextFile;
begin
  AssignFile(F, APath);
  Rewrite(F);
  try
    if AContent <> '' then
      Write(F, AContent);
  finally
    CloseFile(F);
  end;
end;

procedure TestFindProjectExecutableCoreResolvesExecutableFromLPR;
var
  Dir, ExePath: string;
begin
  Dir := CreateUniqueTempDir('project-exec-find-run');
  try
    WriteFile(Dir + PathDelim + 'demo.lpr', 'program demo; begin end.');
    ExePath := Dir + PathDelim + 'demo';
    WriteFile(ExePath, '');

    Check('find executable resolves matching binary',
      FindProjectExecutableCore(Dir) = ExePath,
      'got=' + FindProjectExecutableCore(Dir));
  finally
    CleanupTempDir(Dir);
  end;
end;

procedure TestFindProjectTestExecutableCoreResolvesMatchingBinary;
var
  Dir, ExePath: string;
begin
  Dir := CreateUniqueTempDir('project-exec-find-test');
  try
    WriteFile(Dir + PathDelim + 'test_demo.lpr', 'program test_demo; begin end.');
    ExePath := Dir + PathDelim + 'test_demo';
    WriteFile(ExePath, '');

    Check('find test executable resolves matching binary',
      FindProjectTestExecutableCore(Dir) = ExePath,
      'got=' + FindProjectTestExecutableCore(Dir));
  finally
    CleanupTempDir(Dir);
  end;
end;

procedure TestParseProjectRunArgsCoreSplitsWhitespace;
var
  Params: TStringArray;
begin
  Params := ParseProjectRunArgsCore('alpha beta gamma');
  Check('parse args count', Length(Params) = 3, 'count=' + IntToStr(Length(Params)));
  Check('parse args first', Params[0] = 'alpha', 'got=' + Params[0]);
  Check('parse args third', Params[2] = 'gamma', 'got=' + Params[2]);
end;

procedure TestExecuteProjectBuildCoreUsesLazbuildForLPI;
var
  Dir: string;
  Probe: TExecProbe;
  OK: Boolean;
begin
  Dir := CreateUniqueTempDir('project-exec-build-lpi');
  Probe := TExecProbe.Create;
  try
    WriteFile(Dir + PathDelim + 'sample.lpi', '<CONFIG/>');
    Probe.NextSuccess := True;
    Probe.NextExitCode := 0;

    OK := ExecuteProjectBuildCore(Dir, 'x86_64', @Probe.Run);

    Check('build lpi returns success', OK, 'expected success');
    Check('build lpi uses lazbuild', Probe.LastExecutable = 'lazbuild',
      'exe=' + Probe.LastExecutable);
    Check('build lpi param count', Length(Probe.LastParams) = 2,
      'count=' + IntToStr(Length(Probe.LastParams)));
    Check('build lpi passes project file',
      Probe.LastParams[0] = Dir + PathDelim + 'sample.lpi',
      'param0=' + Probe.LastParams[0]);
    Check('build lpi passes cpu target', Probe.LastParams[1] = '--cpu=x86_64',
      'param1=' + Probe.LastParams[1]);
  finally
    Probe.Free;
    CleanupTempDir(Dir);
  end;
end;

procedure TestExecuteProjectBuildCoreFallsBackToFPC;
var
  Dir: string;
  Probe: TExecProbe;
  OK: Boolean;
begin
  Dir := CreateUniqueTempDir('project-exec-build-fpc');
  Probe := TExecProbe.Create;
  try
    WriteFile(Dir + PathDelim + 'sample.lpr', 'program sample; begin end.');
    Probe.NextSuccess := True;
    Probe.NextExitCode := 0;

    OK := ExecuteProjectBuildCore(Dir, '', @Probe.Run);

    Check('build lpr returns success', OK, 'expected success');
    Check('build lpr uses fpc', Probe.LastExecutable = 'fpc',
      'exe=' + Probe.LastExecutable);
    Check('build lpr passes basename only',
      (Length(Probe.LastParams) = 1) and (Probe.LastParams[0] = 'sample.lpr'),
      'param=' + Probe.LastParams[0]);
  finally
    Probe.Free;
    CleanupTempDir(Dir);
  end;
end;

procedure TestExecuteProjectTestCoreReportsSuccess;
var
  Dir: string;
  Probe: TExecProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Dir := CreateUniqueTempDir('project-exec-test-run');
  Probe := TExecProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    WriteFile(Dir + PathDelim + 'test_suite', '');
    Probe.NextSuccess := True;
    Probe.NextExitCode := 0;

    OK := ExecuteProjectTestCore(Dir, OutRef, ErrRef, @Probe.Run);

    Check('test flow returns success', OK, 'expected success');
    Check('test flow uses absolute executable path',
      Probe.LastExecutable = ExpandFileName(Dir + PathDelim + 'test_suite'),
      'exe=' + Probe.LastExecutable);
    Check('test flow emits running message',
      OutBuf.Contains(_Fmt(CMD_PROJECT_RUNNING_TESTS, ['test_suite'])),
      'missing running message');
    Check('test flow emits success message',
      OutBuf.Contains(_(CMD_PROJECT_TEST_PASSED)), 'missing success message');
    Check('test flow keeps stderr clean', not ErrBuf.Contains(_(MSG_ERROR)),
      'unexpected stderr');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
    CleanupTempDir(Dir);
  end;
end;

procedure TestExecuteProjectTestCoreWritesMissingTestHint;
var
  Dir: string;
  Probe: TExecProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Dir := CreateUniqueTempDir('project-exec-test-missing');
  Probe := TExecProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.NextSuccess := True;

    OK := ExecuteProjectTestCore(Dir, OutRef, ErrRef, @Probe.Run);

    Check('missing test flow returns false', not OK, 'expected failure');
    Check('missing test flow does not run process', Probe.CallCount = 0,
      'calls=' + IntToStr(Probe.CallCount));
    Check('missing test flow writes not-found message',
      ErrBuf.Contains(_Fmt(CMD_PROJECT_NO_TEST_FOUND, [Dir])),
      'missing no-test message');
    Check('missing test flow writes note',
      ErrBuf.Contains(_(CMD_PROJECT_TEST_NOTE)), 'missing note');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
    CleanupTempDir(Dir);
  end;
end;

procedure TestExecuteProjectRunCoreParsesArgsAndWarnsOnFailure;
var
  Dir: string;
  Probe: TExecProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Dir := CreateUniqueTempDir('project-exec-run');
  Probe := TExecProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    WriteFile(Dir + PathDelim + 'sample.lpr', 'program sample; begin end.');
    WriteFile(Dir + PathDelim + 'sample', '');
    Probe.NextSuccess := False;
    Probe.NextExitCode := 3;

    OK := ExecuteProjectRunCore(Dir, 'alpha beta', OutRef, ErrRef, @Probe.Run);

    Check('run flow returns false on exit code', not OK, 'expected failure');
    Check('run flow uses executable path',
      Probe.LastExecutable = ExpandFileName(Dir + PathDelim + 'sample'),
      'exe=' + Probe.LastExecutable);
    Check('run flow passes parsed args',
      (Length(Probe.LastParams) = 2) and
      (Probe.LastParams[0] = 'alpha') and
      (Probe.LastParams[1] = 'beta'),
      'params mismatch');
    Check('run flow writes warning exit code',
      ErrBuf.Contains(_(MSG_WARNING) + ': ' + _Fmt(CMD_PROJECT_EXIT_CODE, ['3'])),
      'missing exit-code warning');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
    CleanupTempDir(Dir);
  end;
end;

begin
  TestFindProjectExecutableCoreResolvesExecutableFromLPR;
  TestFindProjectTestExecutableCoreResolvesMatchingBinary;
  TestParseProjectRunArgsCoreSplitsWhitespace;
  TestExecuteProjectBuildCoreUsesLazbuildForLPI;
  TestExecuteProjectBuildCoreFallsBackToFPC;
  TestExecuteProjectTestCoreReportsSuccess;
  TestExecuteProjectTestCoreWritesMissingTestHint;
  TestExecuteProjectRunCoreParsesArgsAndWarnsOnFailure;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
