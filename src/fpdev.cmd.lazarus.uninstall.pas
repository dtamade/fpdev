unit fpdev.cmd.lazarus.uninstall;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.lazarus.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TLazUninstallCommand }
  TLazUninstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TLazUninstallCommand.Name: string; begin Result := 'uninstall'; end;
function TLazUninstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazUninstallCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazUninstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TLazarusManager;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_LAZARUS_UNINSTALL_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UNINSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UNINSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UNINSTALL_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_LAZARUS_UNINSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  if Length(AParams) > 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_UNINSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  if (Length(AParams[0]) > 0) and (AParams[0][1] = '-') then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_UNINSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LVer := AParams[0];

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.UninstallVersion(Ctx.Out, Ctx.Err, LVer) then
      Exit(EXIT_OK);
    Ctx.Err.WriteLn(_(MSG_FAILED));
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

function LazUninstallFactory: ICommand;
begin
  Result := TLazUninstallCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','uninstall'], @LazUninstallFactory, []);

end.
