unit fpdev.cmd.cross.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TCrossHelpCommand }
  TCrossHelpCommand = class(TInterfacedObject, ICommand)
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
  fpdev.help.details.cross;

function TCrossHelpCommand.Name: string; begin Result := 'help'; end;

function TCrossHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCrossHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;
end;

function TCrossHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteDomainHelpCommandCore(
    AParams,
    Ctx,
    _(HELP_CROSS_USAGE),
    _(HELP_CROSS_SUBCOMMANDS),
    _(HELP_USE_HELP_CMD_CROSS),
    @BuildCrossHelpItems,
    @WriteCrossHelpDetailsCore
  );
end;

function CrossHelpFactory: ICommand;
begin
  Result := TCrossHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross', 'help'], @CrossHelpFactory, []);

end.
