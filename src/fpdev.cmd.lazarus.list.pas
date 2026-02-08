unit fpdev.cmd.lazarus.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TLazListCommand }
  TLazListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TLazListCommand.Name: string; begin Result := 'list'; end;
function TLazListCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazListCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LAll: Boolean;
  LMgr: TLazarusManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_LIST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LAll := HasFlag(AParams, 'all');
  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.ListVersions(Ctx.Out, LAll) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

function LazListFactory: ICommand;
begin
  Result := TLazListCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','list'], @LazListFactory, []);

end.

