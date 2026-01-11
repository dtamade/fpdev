unit fpdev.cmd.lazarus.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TLazShowCommand }
  TLazShowCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TLazShowCommand.Name: string; begin Result := 'show'; end;
function TLazShowCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazShowCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazShowCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TLazarusManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_SHOW_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_LAZARUS_SHOW_USAGE));
    Exit(2);
  end;

  LVer := AParams[0];
  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.ShowVersionInfo(Ctx.Out, LVer) then
      Exit(0);
    // ShowVersionInfo returns False for unknown or uninstalled versions
    Ctx.Err.WriteLn(_Fmt(CMD_LAZARUS_UNSUPPORTED_VERSION, [LVer]));
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

function LazShowFactory: ICommand;
begin
  Result := TLazShowCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','show'], @LazShowFactory, []);

end.
