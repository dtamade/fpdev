unit fpdev.cmd.repo.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TRepoHelpCommand }
  TRepoHelpCommand = class(TInterfacedObject, ICommand)
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
  fpdev.help.details.repo;

function TRepoHelpCommand.Name: string; begin Result := 'help'; end;

function TRepoHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TRepoHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;
end;

function TRepoHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := ExecuteDomainHelpCommandCore(
    AParams,
    Ctx,
    _(HELP_REPO_USAGE),
    _(HELP_REPO_SUBCOMMANDS),
    _(HELP_USE_HELP_CMD_REPO),
    @BuildRepoHelpItems,
    @WriteRepoHelpDetailsCore
  );
end;

function RepoHelpFactory: ICommand;
begin
  Result := TRepoHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['system', 'repo', 'help'], @RepoHelpFactory, []);

end.
