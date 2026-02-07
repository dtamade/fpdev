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
  private
    procedure ShowPackageHelp(const Ctx: IContext);
    procedure ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TPackageHelpCommand.Name: string; begin Result := 'help'; end;

function TPackageHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TPackageHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TPackageHelpCommand.ShowPackageHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_PACKAGE_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_PACKAGE_SUBCOMMANDS));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_AVAILABLE_COMMANDS));
  Ctx.Out.WriteLn('  install          ' + _(HELP_PACKAGE_INSTALL_DESC));
  Ctx.Out.WriteLn('  uninstall        ' + _(HELP_PACKAGE_UNINSTALL_DESC));
  Ctx.Out.WriteLn('  update           ' + _(HELP_PACKAGE_UPDATE_DESC));
  Ctx.Out.WriteLn('  list             ' + _(HELP_PACKAGE_LIST_DESC));
  Ctx.Out.WriteLn('  search           ' + _(HELP_PACKAGE_SEARCH_DESC));
  Ctx.Out.WriteLn('  info             ' + _(HELP_PACKAGE_INFO_DESC));
  Ctx.Out.WriteLn('  create           ' + _(HELP_PACKAGE_CREATE_DESC));
  Ctx.Out.WriteLn('  publish          ' + _(HELP_PACKAGE_PUBLISH_DESC));
  Ctx.Out.WriteLn('  clean            ' + _(HELP_PACKAGE_CLEAN_DESC));
  Ctx.Out.WriteLn('  install-local    ' + _(HELP_PACKAGE_INSTALL_LOCAL_DESC));
  Ctx.Out.WriteLn('  repo             ' + _(HELP_PACKAGE_REPO_DESC));
  Ctx.Out.WriteLn('  help             ' + _(HELP_SHOW_HELP));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_USE_HELP_CMD_PACKAGE));
end;

procedure TPackageHelpCommand.ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
var
  LSubcmd: string;
begin
  LSubcmd := LowerCase(ASubcmd);

  if LSubcmd = 'install' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_VERSION));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_KEEP));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_HELP));
  end
  else if LSubcmd = 'uninstall' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UNINSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UNINSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UNINSTALL_OPT_HELP));
  end
  else if LSubcmd = 'update' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_UPDATE_OPT_HELP));
  end
  else if LSubcmd = 'list' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_LIST_OPT_HELP));
  end
  else if LSubcmd = 'search' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_EXAMPLE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_SEARCH_OPT_HELP));
  end
  else if LSubcmd = 'info' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INFO_OPT_HELP));
  end
  else if LSubcmd = 'create' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CREATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CREATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CREATE_OPT_HELP));
  end
  else if LSubcmd = 'publish' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_PUBLISH_OPT_HELP));
  end
  else if LSubcmd = 'clean' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_DRYRUN));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_YES));
    Ctx.Out.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_HELP));
  end
  else if (LSubcmd = 'install-local') or (LSubcmd = 'install_local') then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_OPT_HELP));
  end
  else if LSubcmd = 'repo' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_REPO_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(MSG_AVAILABLE_COMMANDS));
    Ctx.Out.WriteLn('  list             ' + _(HELP_PACKAGE_REPO_LIST_DESC));
    Ctx.Out.WriteLn('  add              ' + _(HELP_PACKAGE_REPO_ADD_DESC));
    Ctx.Out.WriteLn('  remove           ' + _(HELP_PACKAGE_REPO_REMOVE_DESC));
    Ctx.Out.WriteLn('  update           ' + _(HELP_PACKAGE_REPO_UPDATE_DESC));
  end
  else
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_UNKNOWN_COMMAND, [ASubcmd]));
    Ctx.Out.WriteLn('');
    ShowPackageHelp(Ctx);
  end;
end;

function TPackageHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := 0;

  if Length(AParams) = 0 then
    ShowPackageHelp(Ctx)
  else
    ShowSubcommandHelp(AParams[0], Ctx);
end;

function PackageHelpFactory: ICommand;
begin
  Result := TPackageHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['package','help'], @PackageHelpFactory, []);

end.
