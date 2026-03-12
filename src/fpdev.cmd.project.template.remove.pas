unit fpdev.cmd.project.template.remove;

{$mode objfpc}{$H+}

{ B245: CLI command for removing a custom project template }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.exitcodes;

type
  TProjectTemplateRemoveCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TProjectTemplateRemoveCommand.Name: string; begin Result := 'remove'; end;
function TProjectTemplateRemoveCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTemplateRemoveCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ProjectTemplateRemoveFactory: ICommand;
begin
  Result := TProjectTemplateRemoveCommand.Create;
end;

function TProjectTemplateRemoveCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LName: string;
  LMgr: TProjectManager;
begin
  Result := 0;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev project template remove <name>');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Remove a custom project template.');
    Ctx.Out.WriteLn('Built-in templates (console, gui, library, etc.) cannot be removed.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Arguments:');
    Ctx.Out.WriteLn('  <name>        Name of the template to remove');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('  --help, -h    Show this help message');
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
    Exit(MissingArgError(Ctx, 'name', 'Usage: fpdev project template remove <name>'));

  LName := AParams[0];
  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.RemoveTemplate(Ctx.Out, Ctx.Err, LName) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','template','remove'], @ProjectTemplateRemoveFactory, []);

end.
