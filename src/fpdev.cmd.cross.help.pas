unit fpdev.cmd.cross.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TCrossHelpCommand }
  TCrossHelpCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowCrossHelp(const Ctx: IContext);
    procedure ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TCrossHelpCommand.Name: string; begin Result := 'help'; end;

function TCrossHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TCrossHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TCrossHelpCommand.ShowCrossHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_CROSS_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_CROSS_SUBCOMMANDS));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_AVAILABLE_COMMANDS));
  Ctx.Out.WriteLn('  list             ' + _(HELP_CROSS_LIST_DESC));
  Ctx.Out.WriteLn('  install          ' + _(HELP_CROSS_INSTALL_DESC));
  Ctx.Out.WriteLn('  uninstall        ' + _(HELP_CROSS_UNINSTALL_DESC));
  Ctx.Out.WriteLn('  enable           ' + _(HELP_CROSS_ENABLE_DESC));
  Ctx.Out.WriteLn('  disable          ' + _(HELP_CROSS_DISABLE_DESC));
  Ctx.Out.WriteLn('  show             ' + _(HELP_CROSS_SHOW_DESC));
  Ctx.Out.WriteLn('  test             ' + _(HELP_CROSS_TEST_DESC));
  Ctx.Out.WriteLn('  configure        ' + _(HELP_CROSS_CONFIGURE_DESC));
  Ctx.Out.WriteLn('  doctor           ' + _(HELP_CROSS_DOCTOR_DESC));
  Ctx.Out.WriteLn('  help             ' + _(HELP_SHOW_HELP));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_USE_HELP_CMD_CROSS));
end;

procedure TCrossHelpCommand.ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
var
  LSubcmd: string;
begin
  LSubcmd := LowerCase(ASubcmd);

  if LSubcmd = 'list' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_CROSS_LIST_OPT_ALL));
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
  else if LSubcmd = 'doctor' then
  begin
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_CROSS_DOCTOR_OPT_HELP));
  end
  else
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_UNKNOWN_COMMAND, [ASubcmd]));
    Ctx.Out.WriteLn('');
    ShowCrossHelp(Ctx);
  end;
end;

function TCrossHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := 0;

  if Length(AParams) = 0 then
    ShowCrossHelp(Ctx)
  else
    ShowSubcommandHelp(AParams[0], Ctx);
end;

function CrossHelpFactory: ICommand;
begin
  Result := TCrossHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['cross','help'], @CrossHelpFactory, []);

end.
