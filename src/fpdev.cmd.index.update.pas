unit fpdev.cmd.index.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry;

type
  TIndexUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateIndexUpdateCommand: ICommand;

implementation

uses
  fpdev.index.commandflow, fpdev.exitcodes;

function CreateIndexUpdateCommand: ICommand;
begin
  Result := TIndexUpdateCommand.Create;
end;

function TIndexUpdateCommand.Name: string;
begin
  Result := 'update';
end;

function TIndexUpdateCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TIndexUpdateCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TIndexUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  if Length(AParams) > 0 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system index update');
    Exit(EXIT_USAGE_ERROR);
  end;
  Result := RunIndexUpdate(Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'index', 'update'], @CreateIndexUpdateCommand, []);

end.
