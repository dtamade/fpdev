unit fpdev.cmd.project.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.i18n, fpdev.i18n.strings;

type
  TProjectListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TProjectListCommand.Name: string; begin Result := 'list'; end;
function TProjectListCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectListFactory: ICommand;
begin
  Result := TProjectListCommand.Create;
end;

function TProjectListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TProjectManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_LIST_OPT_HELP));
    Exit(0);
  end;

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.ListTemplates(Ctx.Out) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','list'], @ProjectListFactory, []);

end.
