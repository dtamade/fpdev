unit fpdev.cmd.lazarus.run;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes, fpdev.output.intf;

type
  TBufferedOutput = class(TInterfacedObject, IOutput)
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
    procedure ReplayTo(const ADest: IOutput);
  end;

  { TLazRunCommand }
  TLazRunCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

constructor TBufferedOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TBufferedOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TBufferedOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TBufferedOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TBufferedOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TBufferedOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TBufferedOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TBufferedOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TBufferedOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TBufferedOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TBufferedOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TBufferedOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferedOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferedOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TBufferedOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TBufferedOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

procedure TBufferedOutput.ReplayTo(const ADest: IOutput);
var
  I: Integer;
begin
  if ADest = nil then
    Exit;
  for I := 0 to FBuffer.Count - 1 do
    ADest.WriteLn(FBuffer[I]);
end;

function TLazRunCommand.Name: string; begin Result := 'run'; end;
function TLazRunCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazRunCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazRunCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TLazarusManager;
  LBuffer: TBufferedOutput;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) > 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  if (Length(AParams) = 1) and (Length(AParams[0]) > 0) and (AParams[0][1] = '-') then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) >= 1 then LVer := AParams[0] else LVer := '';
  LMgr := TLazarusManager.Create(Ctx.Config);
  LBuffer := TBufferedOutput.Create;
  try
    if LMgr.LaunchIDE(LBuffer, LVer) then
    begin
      LBuffer.ReplayTo(Ctx.Out);
      Exit(EXIT_OK);
    end;
    LBuffer.ReplayTo(Ctx.Err);
    Result := EXIT_ERROR;
  finally
    LBuffer.Free;
    LMgr.Free;
  end;
end;

function LazRunFactory: ICommand;
begin
  Result := TLazRunCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','run'], @LazRunFactory, []);

end.
