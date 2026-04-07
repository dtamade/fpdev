unit fpdev.cmd.project.info;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TProjectInfoCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TProjectInfoCommand.Name: string; begin Result := 'info'; end;
function TProjectInfoCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectInfoCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectInfoFactory: ICommand;
begin
  Result := TProjectInfoCommand.Create;
end;

function TProjectInfoCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LTemplate: string;
  LMgr: TProjectManager;
  UnknownOption: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_INFO_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_INFO_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_INFO_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PROJECT_INFO_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['template']));
    Ctx.Err.WriteLn(_(HELP_PROJECT_INFO_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_PROJECT_INFO_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LTemplate := AParams[0];
  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.ShowTemplateInfo(Ctx.Out, Ctx.Err, LTemplate) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','info'], @ProjectInfoFactory, []);

end.
