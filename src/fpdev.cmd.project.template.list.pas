unit fpdev.cmd.project.template.list;

{$mode objfpc}{$H+}

{ B243: CLI command for listing available project templates }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.exitcodes;

type
  TProjectTemplateListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TProjectTemplateListCommand.Name: string; begin Result := 'list'; end;
function TProjectTemplateListCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTemplateListCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ProjectTemplateListFactory: ICommand;
begin
  Result := TProjectTemplateListCommand.Create;
end;

function TProjectTemplateListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TProjectManager;
  UnknownOption: string;
begin
  Result := 0;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev project template list');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('List all available project templates (built-in and custom).');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('  --help, -h    Show this help message');
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) or (CountPositionalArgs(AParams) > 0) then
  begin
    Ctx.Err.WriteLn('Usage: fpdev project template list');
    Exit(EXIT_USAGE_ERROR);
  end;

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.ListTemplates(Ctx.Out) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','template','list'], @ProjectTemplateListFactory, []);

end.
