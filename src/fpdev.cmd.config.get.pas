unit fpdev.cmd.config.get;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry;

type
  TConfigGetCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateConfigGetCommand: ICommand;

implementation

uses
  fpdev.config.commandflow, fpdev.exitcodes;

function CreateConfigGetCommand: ICommand;
begin
  Result := TConfigGetCommand.Create;
end;

function TConfigGetCommand.Name: string;
begin
  Result := 'get';
end;

function TConfigGetCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TConfigGetCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TConfigGetCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  if Length(AParams) <> 1 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system config get <key>');
    Exit(EXIT_USAGE_ERROR);
  end;
  Result := RunConfigGet(AParams[0], Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'config', 'get'], @CreateConfigGetCommand, []);

end.
