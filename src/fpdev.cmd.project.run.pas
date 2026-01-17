unit fpdev.cmd.project.run;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.project,
  fpdev.i18n, fpdev.i18n.strings;

type
  TProjectRunCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function JoinParams(const Params: array of string; const StartIndex: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := StartIndex to High(Params) do
  begin
    if Result <> '' then Result := Result + ' ';
    Result := Result + Params[i];
  end;
end;

function TProjectRunCommand.Name: string; begin Result := 'run'; end;
function TProjectRunCommand.Aliases: TStringArray; begin Result := nil; end;
function TProjectRunCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function ProjectRunFactory: ICommand;
begin
  Result := TProjectRunCommand.Create;
end;

function TProjectRunCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LDir, LArgs: string;
  LMgr: TProjectManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_PROJECT_RUN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_RUN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_PROJECT_RUN_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) > 0 then
    LDir := AParams[0]
  else
    LDir := '.';

  if Length(AParams) > 1 then
    LArgs := JoinParams(AParams, 1)
  else
    LArgs := '';

  LMgr := TProjectManager.Create(Ctx.Config);
  try
    if LMgr.RunProject(Ctx.Out, Ctx.Err, LDir, LArgs) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['project','run'], @ProjectRunFactory, []);

end.
