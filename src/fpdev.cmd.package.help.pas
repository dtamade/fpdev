unit fpdev.cmd.package.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TPackageHelpCommand }
  TPackageHelpCommand = class(TInterfacedObject, ICommand)
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
  fpdev.help.details.package;

function TPackageHelpCommand.Name: string; begin Result := 'help'; end;

function TPackageHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPackageHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;
end;

function TPackageHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteDomainHelpCommandCore(
    AParams,
    Ctx,
    _(HELP_PACKAGE_USAGE),
    _(HELP_PACKAGE_SUBCOMMANDS),
    _(HELP_USE_HELP_CMD_PACKAGE),
    @BuildPackageHelpItems,
    @WritePackageHelpDetailsCore
  );
end;

function PackageHelpFactory: ICommand;
begin
  Result := TPackageHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package', 'help'], @PackageHelpFactory, []);

end.
