program test_config_list;

{$mode objfpc}{$H+}

{
================================================================================
  test_config_list - Tests for fpdev.cmd.config.list
================================================================================

  Tests the config list command functionality:
  - Command name and aliases
  - Help output
  - Option parsing (--fpc, --lazarus, --active)
  - Output formatting

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, test_config_isolation,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.logger.intf,
  fpdev.cmd.config.list;

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
  Cmd := CreateConfigListCommand;
  Test('Command name is "list"', Cmd.Name = 'list');
end;

procedure TestAliases;
var
  Cmd: ICommand;
  Aliases: TStringArray;
begin
  Cmd := CreateConfigListCommand;
  Aliases := Cmd.Aliases;
  Test('Has no aliases', Aliases = nil);
end;

procedure TestFindSubReturnsNil;
var
  Cmd: ICommand;
begin
  Cmd := CreateConfigListCommand;
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
  Cmd := CreateConfigListCommand;

  Ret := Cmd.Execute(['--help'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Help returns exit code 0', Ret = 0);
  Test('Help contains Usage', Pos('Usage:', Output) > 0);
  Test('Help contains --fpc', Pos('--fpc', Output) > 0);
  Test('Help contains --lazarus', Pos('--lazarus', Output) > 0);
  Test('Help contains --active', Pos('--active', Output) > 0);
  Test('Help contains Examples', Pos('Examples:', Output) > 0);
end;

procedure TestListWithEmptyConfig;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateConfigListCommand;

  // Execute without options - should list both FPC and Lazarus
  Ret := Cmd.Execute([], Ctx);
  Output := OutBuf.GetBuffer;

  Test('List returns exit code 0', Ret = 0);
  Test('Output contains FPC section', Pos('FPC', Output) > 0);
  Test('Output contains Lazarus section', Pos('Lazarus', Output) > 0);
end;

procedure TestRegisteredInGlobalRegistry;
var
  Ctx: IContext;
  Args: TStringArray;
  Ret: Integer;
begin
  Ctx := TDefaultCommandContext.Create;
  SetLength(Args, 4);
  Args[0] := 'system';
  Args[1] := 'config';
  Args[2] := 'list';
  Args[3] := '--help';

  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Test('system config list command registered in GlobalCommandRegistry', Ret = 0);
end;

procedure TestAliasRegistration;
var
  Ctx: IContext;
  Args: TStringArray;
  Ret: Integer;
begin
  Ctx := TDefaultCommandContext.Create;
  SetLength(Args, 4);
  Args[0] := 'system';
  Args[1] := 'config';
  Args[2] := 'ls';
  Args[3] := '--help';

  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Test('system config ls alias removed', Ret <> 0);
end;

begin
  WriteLn('=== fpdev.cmd.config.list Tests ===');
  WriteLn;

  TestCommandName;
  TestAliases;
  TestFindSubReturnsNil;
  TestHelpOutput;
  TestListWithEmptyConfig;
  TestRegisteredInGlobalRegistry;
  TestAliasRegistration;

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
