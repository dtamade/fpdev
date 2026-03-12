unit fpdev.cmd.config.setvalue;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf, fpdev.command.registry;

type
  TConfigSetCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateConfigSetCommand: ICommand;

implementation

uses
  fpdev.config.commandflow, fpdev.exitcodes;

function CreateConfigSetCommand: ICommand;
begin
  Result := TConfigSetCommand.Create;
end;

function TConfigSetCommand.Name: string;
begin
  Result := 'set';
end;

function TConfigSetCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TConfigSetCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function TConfigSetCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  if Length(AParams) <> 2 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev system config set <key> <value>');
    Exit(EXIT_USAGE_ERROR);
  end;
  Result := RunConfigSet(AParams[0], AParams[1], Ctx);
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'config', 'set'], @CreateConfigSetCommand, []);

end.
