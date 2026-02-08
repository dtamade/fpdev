unit fpdev.cmd.project.test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TProjectTestCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TProjectTestCommand.Name: string; begin Result := 'test'; end;
function TProjectTestCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectTestCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectTestFactory: ICommand;
begin
  Result := TProjectTestCommand.Create;
end;

function TProjectTestCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LDir: string;
  LMgr: TProjectManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_TEST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_TEST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_TEST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) > 0 then
    LDir := AParams[0]
  else
    LDir := '.';

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.TestProject(Ctx.Out, Ctx.Err, LDir) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','test'], @ProjectTestFactory, []);

end.
