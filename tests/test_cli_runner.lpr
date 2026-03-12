program test_cli_runner;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.config.interfaces,
  fpdev.logger.intf,
  fpdev.cli.runner;

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

  TStubContext = class(TInterfacedObject, IContext)
  public
    function Out: IOutput;
    function Err: IOutput;
    function Config: IConfigManager;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

  TOutputCaptureCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GStdOut: TStringOutput;
  GStdErr: TStringOutput;
  GCallLog: TStringList;
  GNormalizedPrimary: string;
  GNormalizedParams: TStringArray;
  GDispatchExitCode: Integer;
  GDispatchArgs: TStringArray;
  GRootHelpCalls: Integer = 0;
  GNormalizeCalls: Integer = 0;
  GBuildArgsCalls: Integer = 0;
  GCreateContextCalls: Integer = 0;
  GDispatchCalls: Integer = 0;

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
  if AColor = ccDefault then;
  Write(S);
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  if AColor = ccDefault then;
  WriteLn(S);
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  if AColor = ccDefault then;
  if AStyle = csNone then;
  Write(S);
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  if AColor = ccDefault then;
  if AStyle = csNone then;
  WriteLn(S);
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

function TStubContext.Out: IOutput;
begin
  Result := GStdOut as IOutput;
end;

function TStubContext.Err: IOutput;
begin
  Result := GStdErr as IOutput;
end;

function TStubContext.Config: IConfigManager;
begin
  Result := nil;
end;

function TStubContext.Logger: ILogger;
begin
  Result := nil;
end;

procedure TStubContext.SaveIfModified;
begin
end;

function TOutputCaptureCommand.Name: string;
begin
  Result := 'zz-output-capture';
end;

function TOutputCaptureCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TOutputCaptureCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TOutputCaptureCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  if Length(AParams) = -1 then;
  Ctx.Out.WriteLn('captured-out');
  Ctx.Err.WriteLn('captured-err');
  Result := 23;
end;

procedure Check(const ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', AName);
  end;
end;

function MakeArgs(const AValues: array of string): TStringArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
    Result[I] := AValues[I];
end;

procedure ResetState;
begin
  GCallLog.Clear;
  GStdOut := TStringOutput.Create;
  GStdErr := TStringOutput.Create;
  GNormalizedPrimary := '';
  GNormalizedParams := nil;
  GDispatchExitCode := 0;
  GDispatchArgs := nil;
  GRootHelpCalls := 0;
  GNormalizeCalls := 0;
  GBuildArgsCalls := 0;
  GCreateContextCalls := 0;
  GDispatchCalls := 0;
end;

procedure LogCall(const AName: string);
begin
  GCallLog.Add(AName);
end;

procedure StubRootHelp(const AParams: TStringArray; const AOut: IOutput);
begin
  Inc(GRootHelpCalls);
  LogCall('help');
  if Length(AParams) = 0 then;
  if AOut <> nil then
    AOut.WriteLn('root-help');
end;

procedure StubNormalize(const ARawArgs: TStringArray; out APrimary: string; out AParams: TStringArray);
begin
  Inc(GNormalizeCalls);
  LogCall('normalize');
  if Length(ARawArgs) = -1 then;
  APrimary := GNormalizedPrimary;
  AParams := Copy(GNormalizedParams);
end;

function StubBuildDispatchArgs(const APrimary: string; const AParams: TStringArray): TStringArray;
begin
  Inc(GBuildArgsCalls);
  LogCall('build-args');
  if APrimary = '' then;
  Result := Copy(AParams);
  SetLength(Result, Length(Result) + 1);
  Move(Result[0], Result[1], (Length(Result) - 1) * SizeOf(string));
  Result[0] := APrimary;
end;

function StubCreateContext(const AOut, AErr: IOutput): IContext;
begin
  Inc(GCreateContextCalls);
  LogCall('create-context');
  if AOut = nil then;
  if AErr = nil then;
  Result := TStubContext.Create;
end;

function StubDispatch(const AArgs: TStringArray; const Ctx: IContext): Integer;
begin
  Inc(GDispatchCalls);
  LogCall('dispatch');
  if Ctx = nil then;
  GDispatchArgs := Copy(AArgs);
  Result := GDispatchExitCode;
end;

function OutputCaptureFactory: ICommand;
begin
  Result := TOutputCaptureCommand.Create;
end;

procedure TestNoArgsInvokesRootHelp;
var
  ExitCode: Integer;
begin
  ResetState;
  ExitCode := RunCLIRootFlowCore(
    nil,
    GStdOut as IOutput,
    GStdErr as IOutput,
    @StubRootHelp,
    @StubNormalize,
    @StubBuildDispatchArgs,
    @StubCreateContext,
    @StubDispatch
  );
  Check(ExitCode = 0, 'no args exit ok');
  Check(GRootHelpCalls = 1, 'no args calls root help');
  Check(GNormalizeCalls = 0, 'no args skips normalize');
  Check(GDispatchCalls = 0, 'no args skips dispatch');
end;

procedure TestEmptyPrimaryAfterNormalizeInvokesRootHelp;
var
  ExitCode: Integer;
begin
  ResetState;
  GNormalizedPrimary := '';
  ExitCode := RunCLIRootFlowCore(
    MakeArgs(['--portable']),
    GStdOut as IOutput,
    GStdErr as IOutput,
    @StubRootHelp,
    @StubNormalize,
    @StubBuildDispatchArgs,
    @StubCreateContext,
    @StubDispatch
  );
  Check(ExitCode = 0, 'empty normalized primary exits ok');
  Check(GNormalizeCalls = 1, 'empty normalized primary still normalizes args');
  Check(GRootHelpCalls = 1, 'empty normalized primary calls root help');
  Check(GDispatchCalls = 0, 'empty normalized primary skips dispatch');
end;

procedure TestRegistryDispatchUsesBuiltArgsAndContext;
var
  ExitCode: Integer;
begin
  ResetState;
  GNormalizedPrimary := 'system';
  GNormalizedParams := MakeArgs(['doctor']);
  GDispatchExitCode := 11;
  ExitCode := RunCLIRootFlowCore(
    MakeArgs(['system', 'doctor']),
    GStdOut as IOutput,
    GStdErr as IOutput,
    @StubRootHelp,
    @StubNormalize,
    @StubBuildDispatchArgs,
    @StubCreateContext,
    @StubDispatch
  );
  Check(ExitCode = 11, 'dispatch returns registry exit code');
  Check(GBuildArgsCalls = 1, 'dispatch builds args');
  Check(GCreateContextCalls = 1, 'dispatch creates context');
  Check(GDispatchCalls = 1, 'dispatch reaches registry');
  Check((Length(GDispatchArgs) = 2) and (GDispatchArgs[0] = 'system') and (GDispatchArgs[1] = 'doctor'),
    'dispatch receives normalized args');
end;

procedure TestRunCLIInjectsProvidedOutputsIntoContext;
var
  StdOutBuffer: TStringOutput;
  StdErrBuffer: TStringOutput;
  StdOutSink: IOutput;
  StdErrSink: IOutput;
  ExitCode: Integer;
begin
  StdOutBuffer := TStringOutput.Create;
  StdErrBuffer := TStringOutput.Create;
  StdOutSink := StdOutBuffer as IOutput;
  StdErrSink := StdErrBuffer as IOutput;

  GlobalCommandRegistry.RegisterPath(['zz-output-capture'], @OutputCaptureFactory, []);

  ExitCode := RunCLI(MakeArgs(['zz-output-capture']), StdOutSink, StdErrSink);

  Check(ExitCode = 23, 'runcli returns dispatched command exit code');
  Check(Pos('captured-out', StdOutBuffer.Text) > 0, 'runcli injects provided stdout into context');
  Check(Pos('captured-err', StdErrBuffer.Text) > 0, 'runcli injects provided stderr into context');
end;

begin
  GCallLog := TStringList.Create;
  try
    WriteLn('=== CLI Runner Tests ===');
    WriteLn;
    TestNoArgsInvokesRootHelp;
    TestEmptyPrimaryAfterNormalizeInvokesRootHelp;
    TestRegistryDispatchUsesBuiltArgsAndContext;
    TestRunCLIInjectsProvidedOutputsIntoContext;
    WriteLn;
    WriteLn('Passed: ', TestsPassed);
    WriteLn('Failed: ', TestsFailed);
    if TestsFailed > 0 then
      Halt(1);
  finally
    GCallLog.Free;
  end;
end.
