unit fpdev.help.routing;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

function TryDispatchLeafHelp(const PathParts: array of string; const Outp: IOutput): Boolean;
procedure ListChildrenDynamicCore(const PathParts: array of string; const Outp: IOutput);

implementation

uses
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.config.interfaces,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.logger.intf;

type
  THelpContext = class(TInterfacedObject, IContext)
  private
    FOut: IOutput;
    FErr: IOutput;
  public
    constructor Create(const AOut, AErr: IOutput);
    function Config: IConfigManager;
    function Out: IOutput;
    function Err: IOutput;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

constructor THelpContext.Create(const AOut, AErr: IOutput);
begin
  inherited Create;
  FOut := AOut;
  FErr := AErr;
end;

function THelpContext.Config: IConfigManager;
begin
  Result := nil;
end;

function THelpContext.Out: IOutput;
begin
  Result := FOut;
end;

function THelpContext.Err: IOutput;
begin
  Result := FErr;
end;

function THelpContext.Logger: ILogger;
begin
  Result := nil;
end;

procedure THelpContext.SaveIfModified;
begin
end;

function TryDispatchLeafHelp(const PathParts: array of string; const Outp: IOutput): Boolean;
var
  Args: TStringArray;
  I: Integer;
  Code: Integer;
  Ctx: IContext;
begin
  Result := False;
  if Length(PathParts) = 0 then
    Exit(False);

  Args := nil;
  SetLength(Args, Length(PathParts) + 1);
  for I := 0 to High(PathParts) do
    Args[I] := PathParts[I];
  Args[High(Args)] := '--help';

  Ctx := THelpContext.Create(Outp, Outp);
  Code := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Result := Code = EXIT_OK;
end;

procedure ListChildrenDynamicCore(const PathParts: array of string; const Outp: IOutput);
var
  Children: TStringArray;
  I: Integer;
begin
  Children := GlobalCommandRegistry.ListChildren(PathParts);
  if Length(Children) = 0 then
  begin
    if TryDispatchLeafHelp(PathParts, Outp) then
      Exit;
    Outp.WriteLn(_(HELP_NO_COMMAND_FOUND));
    Exit;
  end;

  Outp.WriteLn(_(HELP_AVAILABLE_SUBCOMMANDS));
  for I := 0 to High(Children) do
    Outp.WriteLn('  ' + Children[I]);
end;

end.
