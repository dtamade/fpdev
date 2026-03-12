unit fpdev.cmd.lazarus.run;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TLazRunCommand }
  TLazRunCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TLazRunCommand.Name: string; begin Result := 'run'; end;
function TLazRunCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazRunCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazRunCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
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
      Ctx.Err.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_RUN_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) > 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  if (Length(AParams) = 1) and (Length(AParams[0]) > 0) and (AParams[0][1] = '-') then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_RUN_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) >= 1 then LVer := AParams[0] else LVer := '';
  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.LaunchIDE(Ctx.Out, LVer) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

function LazRunFactory: ICommand;
begin
  Result := TLazRunCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','run'], @LazRunFactory, []);

end.
