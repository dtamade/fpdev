unit fpdev.cmd.lazarus.configure;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TLazConfigureCommand }
  TLazConfigureCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TLazConfigureCommand.Name: string; begin Result := 'configure'; end;
function TLazConfigureCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazConfigureCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazConfigureCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TLazarusManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_CONFIGURE_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_LAZARUS_CONFIGURE_USAGE));
    Exit(2);
  end;

  LVer := AParams[0];
  Ctx.Out.WriteLn(_Fmt(CMD_LAZARUS_CONFIG_START, [LVer]));

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.ConfigureIDE(Ctx.Out, Ctx.Err, LVer) then
      Exit(0);
    Ctx.Err.WriteLn(_(CMD_LAZARUS_CONFIG_FAILED));
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

function LazConfigureFactory: ICommand;
begin
  Result := TLazConfigureCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','configure'], @LazConfigureFactory, ['config']);

end.
