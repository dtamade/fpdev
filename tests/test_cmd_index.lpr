program test_cmd_index;

{$mode objfpc}{$H+}

{
================================================================================
  test_cmd_index - Tests for fpdev.cmd.index
================================================================================

  Tests the index management command:
  - Command name and aliases
  - Help output
  - Status subcommand output
  - Command registration in GlobalCommandRegistry

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, test_config_isolation,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.logger.intf,
  fpdev.cmd.index, fpdev.cmd.index.status, fpdev.cmd.index.show, fpdev.cmd.index.update;

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
  Cmd := CreateIndexCommand;
  Test('Command name is "index"', Cmd.Name = 'index');
end;

procedure TestAliasesIsNil;
var
  Cmd: ICommand;
begin
  Cmd := CreateIndexCommand;
  Test('Aliases returns nil', Cmd.Aliases = nil);
end;

procedure TestFindSubReturnsNil;
var
  Cmd: ICommand;
begin
  Cmd := CreateIndexCommand;
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
  Cmd := CreateIndexCommand;

  Ret := Cmd.Execute(['help'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Help returns exit code 0', Ret = 0);
  Test('Help contains Usage', Pos('Usage:', Output) > 0);
  Test('Help contains status', Pos('status', Output) > 0);
  Test('Help contains show', Pos('show', Output) > 0);
  Test('Help contains update', Pos('update', Output) > 0);
  Test('Help contains Examples', Pos('Examples:', Output) > 0);
end;

procedure TestStatusOutput;
var
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  Args: TStringArray;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  SetLength(Args, 3);
  Args[0] := 'system';
  Args[1] := 'index';
  Args[2] := 'status';
  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Output := OutBuf.GetBuffer;

  Test('Status returns exit code 0', Ret = 0);
  Test('Status shows Index Status header', Pos('Index Status', Output) > 0);
  Test('Status shows Platform', Pos('Platform:', Output) > 0);
  Test('Status shows Cache Directory', Pos('Cache Directory:', Output) > 0);
  Test('Status shows Index File', Pos('Index File:', Output) > 0);
end;

procedure TestNoArgsShowsHelp;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateIndexCommand;

  Ret := Cmd.Execute([], Ctx);
  Output := OutBuf.GetBuffer;

  Test('No args returns exit code 0', Ret = 0);
  Test('No args shows help (contains Usage)', Pos('Usage:', Output) > 0);
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
  Cmd := CreateIndexCommand;

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
  Children: TStringArray;
  I: Integer;
  HasStatus, HasShow, HasUpdate: Boolean;
begin
  Ctx := TDefaultCommandContext.Create;
  SetLength(Args, 3);
  Args[0] := 'system';
  Args[1] := 'index';
  Args[2] := 'help';

  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Test('system index command registered in GlobalCommandRegistry', Ret = 0);

  Children := GlobalCommandRegistry.ListChildren(['system', 'index']);
  HasStatus := False;
  HasShow := False;
  HasUpdate := False;
  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'status' then HasStatus := True;
    if Children[I] = 'show' then HasShow := True;
    if Children[I] = 'update' then HasUpdate := True;
  end;
  Test('system index status subcommand registered', HasStatus);
  Test('system index show subcommand registered', HasShow);
  Test('system index update subcommand registered', HasUpdate);
end;

begin
  WriteLn('=== fpdev.cmd.index Tests ===');
  WriteLn;

  TestCommandName;
  TestAliasesIsNil;
  TestFindSubReturnsNil;
  TestHelpOutput;
  TestStatusOutput;
  TestNoArgsShowsHelp;
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
