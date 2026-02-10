program test_cmd_perf;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.output.console,
  fpdev.config.interfaces, fpdev.logger.intf,
  fpdev.perf.monitor,
  fpdev.cmd.perf;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

{ Test output capture - full IOutput implementation }
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
    function GetBuffer: string;
    procedure Clear;
  end;

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
  if AColor = ccDefault then; // suppress hint
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then; // suppress hint
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then; // suppress hint
  if AStyle = csNone then; // suppress hint
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then; // suppress hint
  if AStyle = csNone then; // suppress hint
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

function TStringOutput.GetBuffer: string;
begin
  Result := FBuffer.Text;
end;

procedure TStringOutput.Clear;
begin
  FBuffer.Clear;
end;

{ Test context with custom output }
type
  TTestContext = class(TInterfacedObject, IContext)
  private
    FOut: IOutput;
    FErr: IOutput;
  public
    constructor Create(AOut, AErr: IOutput);
    function Out: IOutput;
    function Err: IOutput;
    function Config: IConfigManager;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

constructor TTestContext.Create(AOut, AErr: IOutput);
begin
  inherited Create;
  FOut := AOut;
  FErr := AErr;
end;

function TTestContext.Out: IOutput;
begin
  Result := FOut;
end;

function TTestContext.Err: IOutput;
begin
  Result := FErr;
end;

function TTestContext.Config: IConfigManager;
begin
  Result := nil; // Not needed for perf tests
end;

function TTestContext.Logger: ILogger;
begin
  Result := nil; // Not needed for perf tests
end;

procedure TTestContext.SaveIfModified;
begin
  // No-op for tests
end;

{ Tests }

procedure TestPerfCommandName;
var
  Cmd: ICommand;
begin
  Cmd := CreatePerfCommand;
  Test('PerfCommand.Name = perf', Cmd.Name = 'perf');
end;

procedure TestPerfReportCommandName;
var
  Cmd: ICommand;
begin
  Cmd := CreatePerfReportCommand;
  Test('PerfReportCommand.Name = report', Cmd.Name = 'report');
end;

procedure TestPerfSummaryCommandName;
var
  Cmd: ICommand;
begin
  Cmd := CreatePerfSummaryCommand;
  Test('PerfSummaryCommand.Name = summary', Cmd.Name = 'summary');
end;

procedure TestPerfClearCommandName;
var
  Cmd: ICommand;
begin
  Cmd := CreatePerfClearCommand;
  Test('PerfClearCommand.Name = clear', Cmd.Name = 'clear');
end;

procedure TestPerfSaveCommandName;
var
  Cmd: ICommand;
begin
  Cmd := CreatePerfSaveCommand;
  Test('PerfSaveCommand.Name = save', Cmd.Name = 'save');
end;

procedure TestPerfCommandHelp;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreatePerfCommand;

  Ret := Cmd.Execute([], Ctx);
  Output := OutBuf.GetBuffer;

  Test('PerfCommand.Execute returns 0', Ret = 0);
  Test('PerfCommand help contains Usage', Pos('Usage:', Output) > 0);
  Test('PerfCommand help contains report', Pos('report', Output) > 0);
  Test('PerfCommand help contains summary', Pos('summary', Output) > 0);
  Test('PerfCommand help contains clear', Pos('clear', Output) > 0);
  Test('PerfCommand help contains save', Pos('save', Output) > 0);
end;

procedure TestPerfReportEmpty;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  PerfMon.Clear; // Ensure clean state
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreatePerfReportCommand;

  Ret := Cmd.Execute([], Ctx);
  Output := OutBuf.GetBuffer;

  Test('PerfReportCommand returns 0', Ret = 0);
  Test('PerfReportCommand shows no data message',
       (Pos('No performance data', Output) > 0) or (Pos('[]', Output) > 0));
end;

procedure TestPerfSummaryEmpty;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  PerfMon.Clear;
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreatePerfSummaryCommand;

  Ret := Cmd.Execute([], Ctx);
  Output := OutBuf.GetBuffer;

  Test('PerfSummaryCommand returns 0', Ret = 0);
  // Summary always shows header, but may show no data message
  Test('PerfSummaryCommand produces output', Length(Output) > 0);
end;

procedure TestPerfClear;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreatePerfClearCommand;

  Ret := Cmd.Execute([], Ctx);
  Output := OutBuf.GetBuffer;

  Test('PerfClearCommand returns 0', Ret = 0);
  Test('PerfClearCommand confirms clear', Pos('cleared', Output) > 0);
end;

procedure TestPerfSaveNoFilename;
var
  Cmd: ICommand;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ErrOutput: string;
begin
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := CreatePerfSaveCommand;

  Ret := Cmd.Execute([], Ctx);
  ErrOutput := ErrBuf.GetBuffer;

  Test('PerfSaveCommand without filename returns 1', Ret = 1);
  Test('PerfSaveCommand shows error for missing filename',
       Pos('filename', LowerCase(ErrOutput)) > 0);
end;

procedure TestPerfSaveWithFilename;
var
  Cmd: ICommand;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  TempFile: string;
begin
  TempFile := GetTempDir + 'test_perf_save_' + IntToStr(Random(100000)) + '.json';
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := CreatePerfSaveCommand;

  try
    Ret := Cmd.Execute([TempFile], Ctx);
    Output := OutBuf.GetBuffer;

    Test('PerfSaveCommand with filename returns 0', Ret = 0);
    Test('PerfSaveCommand confirms save', Pos('saved', LowerCase(Output)) > 0);
    Test('PerfSaveCommand creates file', FileExists(TempFile));
  finally
    if FileExists(TempFile) then
      DeleteFile(TempFile);
  end;
end;

procedure TestCommandsRegisteredInRegistry;
var
  Ctx: IContext;
  Args: TStringArray;
begin
  // Test that commands are registered via initialization
  Ctx := TDefaultCommandContext.Create;

  // Test perf command is accessible
  SetLength(Args, 1);
  Args[0] := 'perf';
  Test('perf command registered in GlobalCommandRegistry',
       GlobalCommandRegistry.Dispatch(Args, Ctx) = 0);
end;

procedure TestAliasesAreNil;
var
  Cmd: ICommand;
begin
  Cmd := CreatePerfCommand;
  Test('PerfCommand.Aliases returns nil', Cmd.Aliases = nil);

  Cmd := CreatePerfReportCommand;
  Test('PerfReportCommand.Aliases returns nil', Cmd.Aliases = nil);

  Cmd := CreatePerfClearCommand;
  Test('PerfClearCommand.Aliases returns nil', Cmd.Aliases = nil);
end;

procedure TestFindSubReturnsNil;
var
  Cmd: ICommand;
begin
  Cmd := CreatePerfCommand;
  Test('PerfCommand.FindSub returns nil', Cmd.FindSub('report') = nil);

  Cmd := CreatePerfReportCommand;
  Test('PerfReportCommand.FindSub returns nil', Cmd.FindSub('test') = nil);
end;

begin
  WriteLn('=== fpdev.cmd.perf Tests ===');
  WriteLn;

  Randomize;

  TestPerfCommandName;
  TestPerfReportCommandName;
  TestPerfSummaryCommandName;
  TestPerfClearCommandName;
  TestPerfSaveCommandName;
  TestPerfCommandHelp;
  TestPerfReportEmpty;
  TestPerfSummaryEmpty;
  TestPerfClear;
  TestPerfSaveNoFilename;
  TestPerfSaveWithFilename;
  TestCommandsRegisteredInRegistry;
  TestAliasesAreNil;
  TestFindSubReturnsNil;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Total:  ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);

  if GFailCount > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
