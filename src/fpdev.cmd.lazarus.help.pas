unit fpdev.cmd.lazarus.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TLazarusHelpCommand }
  TLazarusHelpCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowLazarusHelp(const Ctx: IContext);
    procedure ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TLazarusHelpCommand.Name: string; begin Result := 'help'; end;

function TLazarusHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TLazarusHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TLazarusHelpCommand.ShowLazarusHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_LAZARUS_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_LAZARUS_SUBCOMMANDS));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_AVAILABLE_COMMANDS));
  Ctx.Out.WriteLn('  install            ' + _(HELP_LAZARUS_INSTALL_DESC));
  Ctx.Out.WriteLn('  uninstall          ' + _(HELP_LAZARUS_UNINSTALL_DESC));
  Ctx.Out.WriteLn('  list               ' + _(HELP_LAZARUS_LIST_DESC));
  Ctx.Out.WriteLn('  use, default       ' + _(HELP_LAZARUS_USE_DESC));
  Ctx.Out.WriteLn('  current            ' + _(HELP_LAZARUS_CURRENT_DESC));
  Ctx.Out.WriteLn('  show               ' + _(HELP_LAZARUS_SHOW_DESC));
  Ctx.Out.WriteLn('  run                ' + _(HELP_LAZARUS_RUN_DESC));
  Ctx.Out.WriteLn('  test               ' + _(HELP_LAZARUS_TEST_DESC));
  Ctx.Out.WriteLn('  doctor             ' + _(HELP_LAZARUS_DOCTOR_DESC));
  Ctx.Out.WriteLn('  update             ' + _(HELP_LAZARUS_UPDATE_DESC));
  Ctx.Out.WriteLn('  configure, config  ' + _(HELP_LAZARUS_CONFIGURE_DESC));
  Ctx.Out.WriteLn('  help               ' + _(HELP_SHOW_HELP));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_USE_HELP_CMD_LAZARUS));
end;

procedure TLazarusHelpCommand.ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
var
  LSubcmd: string;
begin
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
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_HELP));
  end
  else if (LSubcmd = 'use') or (LSubcmd = 'default') then
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
  else if (LSubcmd = 'configure') or (LSubcmd = 'config') then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_OPT_HELP));
  end
  else
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_UNKNOWN_COMMAND, [ASubcmd]));
    Ctx.Out.WriteLn('');
    ShowLazarusHelp(Ctx);
  end;
end;

function TLazarusHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := 0;

  if Length(AParams) = 0 then
    ShowLazarusHelp(Ctx)
  else
    ShowSubcommandHelp(AParams[0], Ctx);
end;

function LazarusHelpFactory: ICommand;
begin
  Result := TLazarusHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','help'], @LazarusHelpFactory, []);

end.
