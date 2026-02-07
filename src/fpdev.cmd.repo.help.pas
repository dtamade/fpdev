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
  private
    procedure ShowRepoHelp(const Ctx: IContext);
    procedure ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TRepoHelpCommand.Name: string; begin Result := 'help'; end;

function TRepoHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TRepoHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TRepoHelpCommand.ShowRepoHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_REPO_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_REPO_SUBCOMMANDS));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_AVAILABLE_COMMANDS));
  Ctx.Out.WriteLn('  add              ' + _(HELP_REPO_ADD_DESC));
  Ctx.Out.WriteLn('  remove, rm       ' + _(HELP_REPO_REMOVE_DESC));
  Ctx.Out.WriteLn('  list             ' + _(HELP_REPO_LIST_DESC));
  Ctx.Out.WriteLn('  show             ' + _(HELP_REPO_SHOW_DESC));
  Ctx.Out.WriteLn('  versions         ' + _(HELP_REPO_VERSIONS_DESC));
  Ctx.Out.WriteLn('  default          ' + _(HELP_REPO_DEFAULT_DESC));
  Ctx.Out.WriteLn('  help             ' + _(HELP_SHOW_HELP));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_USE_HELP_CMD_REPO));
end;

procedure TRepoHelpCommand.ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
var
  LSubcmd: string;
begin
  LSubcmd := LowerCase(ASubcmd);

  if LSubcmd = 'add' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_ADD_OPT_HELP));
  end
  else if (LSubcmd = 'remove') or (LSubcmd = 'rm') then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_REMOVE_OPT_HELP));
  end
  else if LSubcmd = 'list' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_LIST_OPT_HELP));
  end
  else if LSubcmd = 'show' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_SHOW_OPT_HELP));
  end
  else if LSubcmd = 'versions' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_REPO));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_OS));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_ARCH));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_OFFLINE));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_REFRESH));
    Ctx.Out.WriteLn(_(HELP_REPO_VERSIONS_OPT_HELP));
  end
  else if LSubcmd = 'default' then
  begin
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_REPO_DEFAULT_OPT_HELP));
  end
  else
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_UNKNOWN_COMMAND, [ASubcmd]));
    Ctx.Out.WriteLn('');
    ShowRepoHelp(Ctx);
  end;
end;

function TRepoHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := 0;

  if Length(AParams) = 0 then
    ShowRepoHelp(Ctx)
  else
    ShowSubcommandHelp(AParams[0], Ctx);
end;

function RepoHelpFactory: ICommand;
begin
  Result := TRepoHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['repo','help'], @RepoHelpFactory, []);

end.
