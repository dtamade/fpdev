unit fpdev.cmd.lazarus.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TLazarusHelpCommand }
  TLazarusHelpCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses
  fpdev.help.catalog,
  fpdev.help.commandflow,
  fpdev.help.details.lazarus;

function TLazarusHelpCommand.Name: string; begin Result := 'help'; end;

function TLazarusHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TLazarusHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;
end;

function TLazarusHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteDomainHelpCommandCore(
    AParams,
    Ctx,
    _(HELP_LAZARUS_USAGE),
    _(HELP_LAZARUS_SUBCOMMANDS),
    _(HELP_USE_HELP_CMD_LAZARUS),
    @BuildLazarusHelpItems,
    @WriteLazarusHelpDetailsCore
  );
end;

function LazarusHelpFactory: ICommand;
begin
  Result := TLazarusHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus', 'help'], @LazarusHelpFactory, []);

end.
