unit fpdev.cmd.project.build;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.project.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TProjectBuildCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TProjectBuildCommand.Name: string; begin Result := 'build'; end;
function TProjectBuildCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectBuildCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectBuildFactory: ICommand;
begin
  Result := TProjectBuildCommand.Create;
end;

function TProjectBuildCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LDir, LTarget: string;
  LMgr: TProjectManager;
  UnknownOption: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_BUILD_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_BUILD_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_BUILD_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_PROJECT_BUILD_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 2 then
  begin
    Ctx.Err.WriteLn(_(HELP_PROJECT_BUILD_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 0 then
    LDir := GetPositionalArg(AParams, 0)
  else
    LDir := '.';

  if CountPositionalArgs(AParams) > 1 then
    LTarget := GetPositionalArg(AParams, 1)
  else
    LTarget := '';

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.BuildProject(LDir, LTarget) then
    begin
      Ctx.Out.WriteLn(_(CMD_PROJECT_BUILD_DONE));
      Exit(EXIT_OK);
    end;

    Ctx.Err.WriteLn(_(CMD_PROJECT_BUILD_FAILED));
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','build'], @ProjectBuildFactory, []);

end.
