program test_cmd_env;

{$mode objfpc}{$H+}

{
================================================================================
  test_cmd_env - Tests for fpdev.cmd.env
================================================================================

  Tests the environment information command:
  - Command name and aliases
  - Help output
  - Overview subcommand
  - Vars subcommand
  - Path subcommand
  - Export subcommand
  - GlobalCommandRegistry registration

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.logger.intf,
  fpdev.cmd.env;

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

{ Test output capture }
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

function TStringOutput.GetBuffer: string;
begin
  Result := FBuffer.Text;
end;

procedure TStringOutput.Clear;
begin
  FBuffer.Clear;
end;

{ Test context }
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
  Result := nil;
end;

function TTestContext.Logger: ILogger;
begin
  Result := nil;
end;

procedure TTestContext.SaveIfModified;
begin
end;

{ Tests }

procedure TestCommandName;
var
  Cmd: ICommand;
begin
  Cmd := CreateEnvCommand;
  Test('Command name is "env"', Cmd.Name = 'env');
end;

procedure TestAliasesIsNil;
var
  Cmd: ICommand;
begin
  Cmd := CreateEnvCommand;
  Test('Aliases returns nil', Cmd.Aliases = nil);
end;

procedure TestFindSubReturnsNil;
var
  Cmd: ICommand;
begin
  Cmd := CreateEnvCommand;
  Test('FindSub returns nil', Cmd.FindSub('test') = nil);
end;

procedure TestHelpOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['help'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Help returns exit code 0', Ret = 0);
  Test('Help contains Usage', Pos('Usage:', Output) > 0);
  Test('Help contains vars', Pos('vars', Output) > 0);
  Test('Help contains path', Pos('path', Output) > 0);
  Test('Help contains export', Pos('export', Output) > 0);
  Test('Help contains Examples', Pos('Examples:', Output) > 0);
end;

procedure TestOverviewOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute([], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Overview returns exit code 0', Ret = 0);
  Test('Overview shows Environment Overview', Pos('Environment Overview', Output) > 0);
  Test('Overview shows Platform', Pos('Platform:', Output) > 0);
  Test('Overview shows FPDev Paths', Pos('FPDev Paths:', Output) > 0);
  Test('Overview shows Data Root', Pos('Data Root:', Output) > 0);
  Test('Overview shows Key Environment Variables', Pos('Key Environment Variables', Output) > 0);
end;

procedure TestVarsOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['vars'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Vars returns exit code 0', Ret = 0);
  Test('Vars shows FPC/Lazarus Environment Variables', Pos('FPC/Lazarus Environment Variables', Output) > 0);
  Test('Vars shows FPC Variables', Pos('FPC Variables:', Output) > 0);
  Test('Vars shows FPCDIR', Pos('FPCDIR:', Output) > 0);
  Test('Vars shows Lazarus Variables', Pos('Lazarus Variables:', Output) > 0);
  Test('Vars shows Cross-Compilation Variables', Pos('Cross-Compilation Variables:', Output) > 0);
end;

procedure TestPathOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['path'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Path returns exit code 0', Ret = 0);
  Test('Path shows PATH Configuration', Pos('PATH Configuration', Output) > 0);
  Test('Path shows Total entries', Pos('Total entries:', Output) > 0);
end;

procedure TestExportBashOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['export', '--shell', 'bash'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Export bash returns exit code 0', Ret = 0);
  Test('Export bash shows header', Pos('FPDev Environment Export', Output) > 0);
  Test('Export bash shows export', Pos('export FPDEV_ROOT=', Output) > 0);
  Test('Export bash shows FPDEV_TOOLCHAINS', Pos('FPDEV_TOOLCHAINS', Output) > 0);
end;

procedure TestExportCmdOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['export', '--shell', 'cmd'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Export cmd returns exit code 0', Ret = 0);
  Test('Export cmd shows set', Pos('set FPDEV_ROOT=', Output) > 0);
end;

procedure TestExportPsOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['export', '--shell', 'ps'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Export ps returns exit code 0', Ret = 0);
  Test('Export ps shows $env:', Pos('$env:FPDEV_ROOT=', Output) > 0);
end;

procedure TestUnknownSubcommand;
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
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['invalid'], Ctx);
  ErrOutput := ErrBuf.GetBuffer;

  Test('Unknown subcommand returns non-zero', Ret <> 0);
  Test('Error mentions unknown', Pos('Unknown', ErrOutput) > 0);
end;

procedure TestRegisteredInGlobalRegistry;
var
  Ctx: IContext;
  Args: TStringArray;
  Ret: Integer;
begin
  Ctx := TDefaultCommandContext.Create;
  SetLength(Args, 2);
  Args[0] := 'env';
  Args[1] := 'help';

  Ret := GlobalCommandRegistry.Dispatch(Args, Ctx);
  Test('env command registered in GlobalCommandRegistry', Ret = 0);
end;

begin
  WriteLn('=== fpdev.cmd.env Tests ===');
  WriteLn;

  TestCommandName;
  TestAliasesIsNil;
  TestFindSubReturnsNil;
  TestHelpOutput;
  TestOverviewOutput;
  TestVarsOutput;
  TestPathOutput;
  TestExportBashOutput;
  TestExportCmdOutput;
  TestExportPsOutput;
  TestUnknownSubcommand;
  TestRegisteredInGlobalRegistry;

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
