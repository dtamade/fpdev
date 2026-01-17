unit fpdev.cmd.lazarus.test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TLazTestCommand }
  TLazTestCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TLazTestCommand.Name: string; begin Result := 'test'; end;
function TLazTestCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazTestCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazTestCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TLazarusManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_TEST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_TEST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_TEST_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_LAZARUS_TEST_USAGE));
    Exit(2);
  end;

  LVer := AParams[0];
  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.TestInstallation(Ctx.Out, Ctx.Err, LVer) then
      Exit(0);
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

function LazTestFactory: ICommand;
begin
  Result := TLazTestCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','test'], @LazTestFactory, []);

end.
