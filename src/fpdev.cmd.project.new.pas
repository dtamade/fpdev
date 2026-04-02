unit fpdev.cmd.project.new;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TProjectNewCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TProjectNewCommand.Name: string; begin Result := 'new'; end;
function TProjectNewCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectNewCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectNewFactory: ICommand;
begin
  Result := TProjectNewCommand.Create;
end;

function TProjectNewCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTemplate, LName, LTargetDir: string;
  LMgr: TProjectManager;
  UnknownOption: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_NEW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_NEW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_NEW_EXAMPLE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_NEW_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PROJECT_NEW_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) < 2 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['template, name']));
    Ctx.Err.WriteLn(_(HELP_PROJECT_NEW_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 3 then
  begin
    Ctx.Err.WriteLn(_(HELP_PROJECT_NEW_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LTemplate := GetPositionalArg(AParams, 0);
  LName := GetPositionalArg(AParams, 1);
  if CountPositionalArgs(AParams) > 2 then
    LTargetDir := GetPositionalArg(AParams, 2) + PathDelim + LName
  else
    LTargetDir := '.' + PathDelim + LName;

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.CreateProject(LTemplate, LName, LTargetDir) then
    begin
      Ctx.Out.WriteLn(_Fmt(CMD_PROJECT_NEW_DONE, [LName]));
      Exit(EXIT_OK);
    end;

    Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PROJECT_NEW_FAILED));
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','new'], @ProjectNewFactory, []);

end.
