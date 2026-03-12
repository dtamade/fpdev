unit fpdev.cmd.project.template.update;

{$mode objfpc}{$H+}

{ B246: CLI command for updating project templates from remote repository }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.exitcodes;

type
  TProjectTemplateUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TProjectTemplateUpdateCommand.Name: string; begin Result := 'update'; end;
function TProjectTemplateUpdateCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTemplateUpdateCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ProjectTemplateUpdateFactory: ICommand;
begin
  Result := TProjectTemplateUpdateCommand.Create;
end;

function TProjectTemplateUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TProjectManager;
begin
  Result := 0;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev project template update');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Update project templates from the remote resource repository.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('  --help, -h    Show this help message');
    Exit(EXIT_OK);
  end;

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.UpdateTemplates(Ctx.Out, Ctx.Err) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','template','update'], @ProjectTemplateUpdateFactory, []);

end.
