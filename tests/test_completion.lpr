program test_completion;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.logger.intf,
  fpdev.cmd.completion,
  fpdev.command.imports;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

type
  TStringBuffer = class(TInterfacedObject, IOutput)
  private
    FBuf: string;
  public
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
  end;

{ PLACEHOLDER_IMPL }

procedure TStringBuffer.Write(const S: string); begin FBuf := FBuf + S; end;
procedure TStringBuffer.WriteLn; begin FBuf := FBuf + LineEnding; end;
procedure TStringBuffer.WriteLn(const S: string); begin FBuf := FBuf + S + LineEnding; end;
procedure TStringBuffer.WriteFmt(const Fmt: string; const Args: array of const); begin FBuf := FBuf + Format(Fmt, Args); end;
procedure TStringBuffer.WriteLnFmt(const Fmt: string; const Args: array of const); begin FBuf := FBuf + Format(Fmt, Args) + LineEnding; end;
procedure TStringBuffer.WriteColored(const S: string; const AColor: TConsoleColor); begin if AColor = ccDefault then; FBuf := FBuf + S; end;
procedure TStringBuffer.WriteLnColored(const S: string; const AColor: TConsoleColor); begin if AColor = ccDefault then; FBuf := FBuf + S + LineEnding; end;
procedure TStringBuffer.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle); begin if AColor = ccDefault then; if AStyle = csNone then; FBuf := FBuf + S; end;
procedure TStringBuffer.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle); begin if AColor = ccDefault then; if AStyle = csNone then; FBuf := FBuf + S + LineEnding; end;
procedure TStringBuffer.WriteSuccess(const S: string); begin FBuf := FBuf + S + LineEnding; end;
procedure TStringBuffer.WriteError(const S: string); begin FBuf := FBuf + S + LineEnding; end;
procedure TStringBuffer.WriteWarning(const S: string); begin FBuf := FBuf + S + LineEnding; end;
procedure TStringBuffer.WriteInfo(const S: string); begin FBuf := FBuf + S + LineEnding; end;
function TStringBuffer.SupportsColor: Boolean; begin Result := False; end;
function TStringBuffer.GetBuffer: string; begin Result := FBuf; end;

type
  TTestContext = class(TInterfacedObject, IContext)
  private
    FOut, FErr: IOutput;
  public
    constructor Create(AOut, AErr: IOutput);
    function Config: IConfigManager;
    function Out: IOutput;
    function Err: IOutput;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

constructor TTestContext.Create(AOut, AErr: IOutput);
begin
  inherited Create;
  FOut := AOut;
  FErr := AErr;
end;
function TTestContext.Config: IConfigManager; begin Result := nil; end;
function TTestContext.Out: IOutput; begin Result := FOut; end;
function TTestContext.Err: IOutput; begin Result := FErr; end;
function TTestContext.Logger: ILogger; begin Result := nil; end;
procedure TTestContext.SaveIfModified; begin end;

procedure TestCompletionBashOutput;
var
  OutBuf: TStringBuffer;
  ErrBuf: TStringBuffer;
  Ctx: IContext;
  Ret: Integer;
begin
  OutBuf := TStringBuffer.Create;
  ErrBuf := TStringBuffer.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Ret := GlobalCommandRegistry.DispatchPath(['completion', 'bash'], Ctx);
  Check('completion bash returns 0', Ret = 0, IntToStr(Ret));
  Check('completion bash contains function', Pos('_fpdev_completions', OutBuf.GetBuffer) > 0);
  Check('completion bash contains complete command', Pos('complete -F', OutBuf.GetBuffer) > 0);
  Check('completion bash contains --list call', Pos('--list', OutBuf.GetBuffer) > 0);
end;

procedure TestCompletionZshOutput;
var
  OutBuf: TStringBuffer;
  ErrBuf: TStringBuffer;
  Ctx: IContext;
  Ret: Integer;
begin
  OutBuf := TStringBuffer.Create;
  ErrBuf := TStringBuffer.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Ret := GlobalCommandRegistry.DispatchPath(['completion', 'zsh'], Ctx);
  Check('completion zsh returns 0', Ret = 0, IntToStr(Ret));
  Check('completion zsh contains compdef', Pos('#compdef fpdev', OutBuf.GetBuffer) > 0);
  Check('completion zsh contains compadd', Pos('compadd', OutBuf.GetBuffer) > 0);
end;

procedure TestCompletionFishOutput;
var
  OutBuf: TStringBuffer;
  ErrBuf: TStringBuffer;
  Ctx: IContext;
  Ret: Integer;
begin
  OutBuf := TStringBuffer.Create;
  ErrBuf := TStringBuffer.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Ret := GlobalCommandRegistry.DispatchPath(['completion', 'fish'], Ctx);
  Check('completion fish returns 0', Ret = 0, IntToStr(Ret));
  Check('completion fish contains complete -c fpdev', Pos('complete -c fpdev', OutBuf.GetBuffer) > 0);
  Check('completion fish contains __fpdev_complete', Pos('__fpdev_complete', OutBuf.GetBuffer) > 0);
end;

procedure TestCompletionListRoot;
var
  OutBuf: TStringBuffer;
  ErrBuf: TStringBuffer;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringBuffer.Create;
  ErrBuf := TStringBuffer.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Ret := GlobalCommandRegistry.DispatchPath(['completion', '--list'], Ctx);
  Output := OutBuf.GetBuffer;
  Check('completion --list returns 0', Ret = 0, IntToStr(Ret));
  Check('completion --list contains package', Pos('package', Output) > 0, Output);
  Check('completion --list contains fpc', Pos('fpc', Output) > 0, Output);
  Check('completion --list contains system', Pos('system', Output) > 0, Output);
end;

procedure TestCompletionListSubpath;
var
  OutBuf: TStringBuffer;
  ErrBuf: TStringBuffer;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringBuffer.Create;
  ErrBuf := TStringBuffer.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Ret := GlobalCommandRegistry.DispatchPath(['completion', '--list', 'package'], Ctx);
  Output := OutBuf.GetBuffer;
  Check('completion --list package returns 0', Ret = 0, IntToStr(Ret));
  Check('completion --list package contains install', Pos('install', Output) > 0, Output);
  Check('completion --list package contains info', Pos('info', Output) > 0, Output);
  Check('completion --list package contains lock', Pos('lock', Output) > 0, Output);
end;

procedure TestCompletionNoShellReturnsError;
var
  OutBuf: TStringBuffer;
  ErrBuf: TStringBuffer;
  Ctx: IContext;
  Ret: Integer;
begin
  OutBuf := TStringBuffer.Create;
  ErrBuf := TStringBuffer.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Ret := GlobalCommandRegistry.DispatchPath(['completion'], Ctx);
  Check('completion no-arg returns error', Ret <> 0, IntToStr(Ret));
  Check('completion no-arg prints usage to stderr', Pos('bash|zsh|fish', ErrBuf.GetBuffer) > 0);
end;

procedure TestHookBashContainsDeactivation;
var
  OutBuf: TStringBuffer;
  ErrBuf: TStringBuffer;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringBuffer.Create;
  ErrBuf := TStringBuffer.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'env', 'hook', 'bash'], Ctx);
  Output := OutBuf.GetBuffer;
  Check('hook bash returns 0', Ret = 0, IntToStr(Ret));
  Check('hook bash contains _FPDEV_SAVED_PATH save', Pos('_FPDEV_SAVED_PATH', Output) > 0);
  Check('hook bash contains Deactivated message', Pos('Deactivated', Output) > 0);
  Check('hook bash contains unset FPCDIR', Pos('unset FPCDIR', Output) > 0);
end;

procedure TestHookFishContainsDeactivation;
var
  OutBuf: TStringBuffer;
  ErrBuf: TStringBuffer;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringBuffer.Create;
  ErrBuf := TStringBuffer.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'env', 'hook', 'fish'], Ctx);
  Output := OutBuf.GetBuffer;
  Check('hook fish returns 0', Ret = 0, IntToStr(Ret));
  Check('hook fish contains _FPDEV_SAVED_PATH', Pos('_FPDEV_SAVED_PATH', Output) > 0);
  Check('hook fish contains Deactivated message', Pos('Deactivated', Output) > 0);
  Check('hook fish contains set -e FPCDIR', Pos('set -e FPCDIR', Output) > 0);
end;

begin
  WriteLn('========================================');
  WriteLn('  Completion + Hook Tests');
  WriteLn('========================================');
  WriteLn;

  EnsureCommandImports;

  TestCompletionBashOutput;
  TestCompletionZshOutput;
  TestCompletionFishOutput;
  TestCompletionListRoot;
  TestCompletionListSubpath;
  TestCompletionNoShellReturnsError;
  TestHookBashContainsDeactivation;
  TestHookFishContainsDeactivation;

  WriteLn;
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);

  if GFailCount > 0 then
    Halt(1);
end.