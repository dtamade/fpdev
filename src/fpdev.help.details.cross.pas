unit fpdev.help.details.cross;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

function WriteCrossHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function WriteCrossHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;
var
  LSubcmd: string;
begin
  Result := True;
  LSubcmd := LowerCase(ASubcmd);

  if LSubcmd = 'list' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPT_HELP));
  end
  else if LSubcmd = 'install' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_INSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_INSTALL_EXAMPLE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_INSTALL_OPT_HELP));
  end
  else if LSubcmd = 'uninstall' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_UNINSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_UNINSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_UNINSTALL_OPT_HELP));
  end
  else if LSubcmd = 'enable' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_ENABLE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_ENABLE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_ENABLE_OPT_HELP));
  end
  else if LSubcmd = 'disable' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DISABLE_OPT_HELP));
  end
  else if LSubcmd = 'show' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_SHOW_OPT_HELP));
  end
  else if LSubcmd = 'test' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_TEST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_TEST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_TEST_OPT_HELP));
  end
  else if LSubcmd = 'configure' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_BINUTILS));
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_LIBRARIES));
    Ctx.Out.WriteLn(_(HELP_CROSS_CONFIGURE_OPT_HELP));
  end
  else if LSubcmd = 'update' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_UPDATE_OPT_HELP));
  end
  else if LSubcmd = 'clean' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_CLEAN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CLEAN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_CLEAN_OPT_HELP));
  end
  else if LSubcmd = 'doctor' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_OPT_HELP));
  end
  else if LSubcmd = 'build' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_BUILD_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_BUILD_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_BUILD_OPT_DRYRUN));
    Ctx.Out.WriteLn(_(HELP_CROSS_BUILD_OPT_HELP));
  end
  else
    Result := False;
end;

end.
