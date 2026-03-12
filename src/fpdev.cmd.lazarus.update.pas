unit fpdev.cmd.lazarus.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TLazUpdateCommand }
  TLazUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TLazUpdateCommand.Name: string; begin Result := 'update'; end;
function TLazUpdateCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazUpdateCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
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
      Ctx.Err.WriteLn(_(HELP_LAZARUS_UPDATE_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_UPDATE_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) > 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_UPDATE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  if (Length(AParams) = 1) and (Length(AParams[0]) > 0) and (AParams[0][1] = '-') then
  begin
    Ctx.Err.WriteLn(_(HELP_LAZARUS_UPDATE_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  // Version is optional - if not provided, update current version
  if Length(AParams) >= 1 then
    LVer := AParams[0]
  else
    LVer := '';

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.UpdateSources(LVer) then
    begin
      Ctx.Out.WriteLn('Lazarus sources updated successfully.');
      Exit(EXIT_OK);
    end;
    Ctx.Err.WriteLn(_(MSG_FAILED));
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

function LazUpdateFactory: ICommand;
begin
  Result := TLazUpdateCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','update'], @LazUpdateFactory, []);

end.
