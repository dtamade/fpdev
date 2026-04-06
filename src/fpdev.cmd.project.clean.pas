unit fpdev.cmd.project.clean;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TProjectCleanCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TProjectCleanCommand.Name: string; begin Result := 'clean'; end;
function TProjectCleanCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectCleanCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectCleanFactory: ICommand;
begin
  Result := TProjectCleanCommand.Create;
end;

function TProjectCleanCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LDir: string;
  LMgr: TProjectManager;
  UnknownOption: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_CLEAN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_CLEAN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_CLEAN_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PROJECT_CLEAN_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_PROJECT_CLEAN_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 0 then
    LDir := GetPositionalArg(AParams, 0)
  else
    LDir := '.';

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.CleanProject(Ctx.Out, Ctx.Err, LDir) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','clean'], @ProjectCleanFactory, []);

end.
