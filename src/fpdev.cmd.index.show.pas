unit fpdev.cmd.index.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry;

type
  TIndexShowCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateIndexShowCommand: ICommand;

implementation

uses
  fpdev.index.commandflow, fpdev.exitcodes;

function CreateIndexShowCommand: ICommand;
begin
  Result := TIndexShowCommand.Create;
end;

function TIndexShowCommand.Name: string;
begin
  Result := 'show';
end;

function TIndexShowCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TIndexShowCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TIndexShowCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system index show');
    Exit(EXIT_USAGE_ERROR);
  end;
  Result := RunIndexShow(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'index', 'show'], @CreateIndexShowCommand, []);

end.
