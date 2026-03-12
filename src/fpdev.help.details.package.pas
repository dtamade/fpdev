unit fpdev.help.details.package;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

function WritePackageHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function WritePackageHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;
var
  LSubcmd: string;
begin
  Result := True;
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
  else if LSubcmd = 'deps' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_DEPS_HINT));
  end
  else if LSubcmd = 'why' then
  begin
    Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PACKAGE_WHY_HINT));
  end
  else
    Result := False;
end;

end.
