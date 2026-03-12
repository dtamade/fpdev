unit fpdev.help.details.fpc;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.command.intf;

function WriteFPCHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function WriteFPCHelpDetailsCore(const ASubcmd: string; const Ctx: IContext): Boolean;
var
  LSubcmd: string;
begin
  Result := True;
  LSubcmd := LowerCase(ASubcmd);

  if LSubcmd = 'install' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_EXAMPLE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_SOURCE));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_BINARY));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_FROM));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_JOBS));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_PREFIX));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_HELP));
  end
  else if LSubcmd = 'list' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPT_HELP));
  end
  else if LSubcmd = 'use' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_USE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_USE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_USE_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_USE_OPT_ENSURE));
    Ctx.Out.WriteLn(_(HELP_FPC_USE_OPT_HELP));
  end
  else if LSubcmd = 'current' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_CURRENT_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_CURRENT_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_CURRENT_OPT_HELP));
  end
  else if LSubcmd = 'show' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_SHOW_OPT_HELP));
  end
  else if LSubcmd = 'doctor' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_DOCTOR_OPT_HELP));
  end
  else if LSubcmd = 'test' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_TEST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_TEST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_TEST_OPT_HELP));
  end
  else if LSubcmd = 'verify' then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc verify <version>');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Example: fpdev fpc verify 3.2.2');
  end
  else if LSubcmd = 'auto-install' then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc auto-install');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Read .fpdev.toml and install configured FPC/toolchain dependencies.');
  end
  else if LSubcmd = 'update-manifest' then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc update-manifest [options]');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Download and cache the latest FPC manifest from remote repository.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Options:');
    Ctx.Out.WriteLn('  --force       Force refresh even if cache is valid');
    Ctx.Out.WriteLn('  -h, --help    Show this help message');
  end
  else if LSubcmd = 'cache' then
  begin
    Ctx.Out.WriteLn('Usage: fpdev fpc cache <subcommand>');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Manage local FPC artifact cache.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Subcommands:');
    Ctx.Out.WriteLn('  list          List cached FPC versions');
    Ctx.Out.WriteLn('  stats         Show cache statistics');
    Ctx.Out.WriteLn('  clean         Clean cached versions');
    Ctx.Out.WriteLn('  path          Show cache directory path');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Use "fpdev fpc cache <subcommand> --help" for details.');
  end
  else if LSubcmd = 'update' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_UPDATE_OPT_HELP));
  end
  else if LSubcmd = 'uninstall' then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_UNINSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_UNINSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_UNINSTALL_OPT_HELP));
  end
  else
    Result := False;
end;

end.
