unit fpdev.cmd.fpc.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCHelpCommand }
  TFPCHelpCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowFPCHelp(const Ctx: IContext);
    procedure ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TFPCHelpCommand.Name: string; begin Result := 'help'; end;

function TFPCHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TFPCHelpCommand.ShowFPCHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_FPC_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_FPC_SUBCOMMANDS));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_AVAILABLE_COMMANDS));
  Ctx.Out.WriteLn('  install          ' + _(HELP_FPC_INSTALL_DESC));
  Ctx.Out.WriteLn('  uninstall        ' + _(HELP_FPC_UNINSTALL_DESC));
  Ctx.Out.WriteLn('  list             ' + _(HELP_FPC_LIST_DESC));
  Ctx.Out.WriteLn('  use, default     ' + _(HELP_FPC_USE_DESC));
  Ctx.Out.WriteLn('  current          ' + _(HELP_FPC_CURRENT_DESC));
  Ctx.Out.WriteLn('  show             ' + _(HELP_FPC_SHOW_DESC));
  Ctx.Out.WriteLn('  doctor           ' + _(HELP_FPC_DOCTOR_DESC));
  Ctx.Out.WriteLn('  test             ' + _(HELP_FPC_TEST_DESC));
  Ctx.Out.WriteLn('  update           ' + _(HELP_FPC_UPDATE_DESC));
  Ctx.Out.WriteLn('  help             ' + _(HELP_SHOW_HELP));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_USE_HELP_CMD_FPC));
end;

procedure TFPCHelpCommand.ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
var
  LSubcmd: string;
begin
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
  else if (LSubcmd = 'use') or (LSubcmd = 'default') then
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
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_UNKNOWN_COMMAND, [ASubcmd]));
    Ctx.Out.WriteLn('');
    ShowFPCHelp(Ctx);
  end;
end;

function TFPCHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) = 0 then
    ShowFPCHelp(Ctx)
  else
    ShowSubcommandHelp(AParams[0], Ctx);
end;

function FPCHelpFactory: ICommand;
begin
  Result := TFPCHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','help'], @FPCHelpFactory, []);

end.
