unit fpdev.cmd.fpc.uninstall;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.fpc.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCUninstallCommand }
  TFPCUninstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TFPCUninstallCommand.Name: string; begin Result := 'uninstall'; end;
function TFPCUninstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TFPCUninstallCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TFPCUninstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TFPCManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_UNINSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_UNINSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_UNINSTALL_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_FPC_UNINSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LVer := AParams[0];

  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    if LMgr.UninstallVersion(LVer) then
    begin
      Ctx.Out.WriteLn(_Fmt(MSG_UNINSTALL_SUCCESS, ['FPC', LVer]));
      Exit(EXIT_OK);
    end;
    Ctx.Err.WriteLn(_(MSG_FAILED));
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

function FPCUninstallFactory: ICommand;
begin
  Result := TFPCUninstallCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','uninstall'], @FPCUninstallFactory, []);

end.
