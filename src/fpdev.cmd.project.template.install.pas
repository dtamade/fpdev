unit fpdev.cmd.project.template.install;

{$mode objfpc}{$H+}

{ B244: CLI command for installing a custom project template }

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.exitcodes;

type
  TProjectTemplateInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TProjectTemplateInstallCommand.Name: string; begin Result := 'install'; end;
function TProjectTemplateInstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTemplateInstallCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ProjectTemplateInstallFactory: ICommand;
begin
  Result := TProjectTemplateInstallCommand.Create;
end;

function TProjectTemplateInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LPath: string;
  LMgr: TProjectManager;
  UnknownOption: string;
begin
  Result := 0;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn('Usage: fpdev project template install <path>');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Install a custom project template from a directory.');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('Arguments:');
    Ctx.Out.WriteLn('  <path>        Path to the template directory');
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn('  --help, -h    Show this help message');
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    Ctx.Err.WriteLn('Usage: fpdev project template install <path>');
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) < 1 then
    Exit(MissingArgError(Ctx, 'path', 'Usage: fpdev project template install <path>'));

  if CountPositionalArgs(AParams) > 1 then
  begin
    Ctx.Err.WriteLn('Usage: fpdev project template install <path>');
    Exit(EXIT_USAGE_ERROR);
  end;

  LPath := GetPositionalArg(AParams, 0);
  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.InstallTemplate(Ctx.Out, Ctx.Err, LPath) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','template','install'], @ProjectTemplateInstallFactory, []);

end.
