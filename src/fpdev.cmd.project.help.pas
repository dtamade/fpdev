unit fpdev.cmd.project.help;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TProjectHelpCommand }
  TProjectHelpCommand = class(TInterfacedObject, ICommand)
  private
    procedure ShowProjectHelp(const Ctx: IContext);
    procedure ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

function TProjectHelpCommand.Name: string; begin Result := 'help'; end;

function TProjectHelpCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TProjectHelpCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

procedure TProjectHelpCommand.ShowProjectHelp(const Ctx: IContext);
begin
  Ctx.Out.WriteLn(_(HELP_PROJECT_USAGE));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_PROJECT_SUBCOMMANDS));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(MSG_AVAILABLE_COMMANDS));
  Ctx.Out.WriteLn('  new              ' + _(HELP_PROJECT_NEW_DESC));
  Ctx.Out.WriteLn('  list             ' + _(HELP_PROJECT_LIST_DESC));
  Ctx.Out.WriteLn('  info             ' + _(HELP_PROJECT_INFO_DESC));
  Ctx.Out.WriteLn('  build            ' + _(HELP_PROJECT_BUILD_DESC));
  Ctx.Out.WriteLn('  run              ' + _(HELP_PROJECT_RUN_DESC));
  Ctx.Out.WriteLn('  test             ' + _(HELP_PROJECT_TEST_DESC));
  Ctx.Out.WriteLn('  clean            ' + _(HELP_PROJECT_CLEAN_DESC));
  Ctx.Out.WriteLn('  help             ' + _(HELP_SHOW_HELP));
  Ctx.Out.WriteLn('');
  Ctx.Out.WriteLn(_(HELP_USE_HELP_CMD_PROJECT));
end;

procedure TProjectHelpCommand.ShowSubcommandHelp(const ASubcmd: string; const Ctx: IContext);
var
  LSubcmd: string;
begin
  LSubcmd := LowerCase(ASubcmd);

  if LSubcmd = 'new' then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_NEW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_NEW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_NEW_EXAMPLE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_NEW_OPT_HELP));
  end
  else if LSubcmd = 'list' then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_OPT_HELP));
  end
  else if LSubcmd = 'info' then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_INFO_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_INFO_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_INFO_OPT_HELP));
  end
  else if LSubcmd = 'build' then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_BUILD_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_BUILD_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_BUILD_OPT_HELP));
  end
  else if LSubcmd = 'run' then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_RUN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_RUN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_RUN_OPT_HELP));
  end
  else if LSubcmd = 'test' then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_TEST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_TEST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_TEST_OPT_HELP));
  end
  else if LSubcmd = 'clean' then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_CLEAN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_CLEAN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_CLEAN_OPT_HELP));
  end
  else
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_UNKNOWN_COMMAND, [ASubcmd]));
    Ctx.Out.WriteLn('');
    ShowProjectHelp(Ctx);
  end;
end;

function TProjectHelpCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
begin
  Result := EXIT_OK;

  if Length(AParams) = 0 then
    ShowProjectHelp(Ctx)
  else
    ShowSubcommandHelp(AParams[0], Ctx);
end;

function ProjectHelpFactory: ICommand;
begin
  Result := TProjectHelpCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','help'], @ProjectHelpFactory, []);

end.
