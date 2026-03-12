unit fpdev.cmd.project.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TProjectHelpCommand }
  TProjectHelpCommand = class(TInterfacedObject, ICommand)
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
  fpdev.help.details.project;

function TProjectHelpCommand.Name: string; begin Result := 'help'; end;

function TProjectHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TProjectHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;
end;

function TProjectHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteDomainHelpCommandCore(
    AParams,
    Ctx,
    _(HELP_PROJECT_USAGE),
    _(HELP_PROJECT_SUBCOMMANDS),
    _(HELP_USE_HELP_CMD_PROJECT),
    @BuildProjectHelpItems,
    @WriteProjectHelpDetailsCore
  );
end;

function ProjectHelpFactory: ICommand;
begin
  Result := TProjectHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project', 'help'], @ProjectHelpFactory, []);

end.
