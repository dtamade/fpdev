unit fpdev.help.details.lazarus;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

function WriteLazarusHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function WriteLazarusHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;
var
  LSubcmd: string;
begin
  Result := True;
  LSubcmd := LowerCase(ASubcmd);

  if LSubcmd = 'install' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_SOURCE));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_FROM));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_FPC));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_JOBS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_HELP));
  end
  else if LSubcmd = 'uninstall' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UNINSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UNINSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UNINSTALL_OPT_HELP));
  end
  else if LSubcmd = 'list' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_HELP));
  end
  else if LSubcmd = 'use' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_USE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_USE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_USE_OPT_HELP));
  end
  else if LSubcmd = 'current' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CURRENT_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CURRENT_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CURRENT_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CURRENT_OPT_HELP));
  end
  else if LSubcmd = 'show' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_SHOW_OPT_HELP));
  end
  else if LSubcmd = 'run' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_OPT_HELP));
  end
  else if LSubcmd = 'test' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_TEST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_TEST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_TEST_OPT_HELP));
  end
  else if LSubcmd = 'doctor' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_DOCTOR_OPT_HELP));
  end
  else if LSubcmd = 'update' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UPDATE_OPT_HELP));
  end
  else if LSubcmd = 'configure' then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_OPT_HELP));
  end
  else
    Result := False;
end;

end.
