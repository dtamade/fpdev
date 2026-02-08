unit fpdev.cmd.help.root;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.registry, fpdev.command.intf, fpdev.cmd.help;

type
  { THelpCommand }
  THelpCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const {%H-} AName: string): ICommand;
    function Execute(const AParams: array of string; const AContext: IContext): Integer;
  end;

function HelpFactory: ICommand;

implementation

{ THelpCommand }

function THelpCommand.Name: string;
begin
  Result := 'help';
end;

function THelpCommand.Aliases: TStringArray;
begin
  Result := nil; // Aliases registered via GlobalCommandRegistry
end;

function THelpCommand.FindSub(const {%H-} AName: string): ICommand;
begin
  // AName parameter not used - help command has no subcommands
  if AName <> '' then;
  Result := nil; // help命令没有子命令
end;

function THelpCommand.Execute(const AParams: array of string; const AContext: IContext): Integer;
begin
  fpdev.cmd.help.execute(AParams, AContext.Out);
  Result := 0;
end;

function HelpFactory: ICommand;
begin
  Result := THelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['help'], @HelpFactory, ['h', '?']);

end.
