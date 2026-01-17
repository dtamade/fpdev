unit fpdev.cmd.fpc.update;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.fpc,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TFPCUpdateCommand }
  TFPCUpdateCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TFPCUpdateCommand.Name: string; begin Result := 'update'; end;

function TFPCUpdateCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCUpdateCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TFPCUpdateCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LMgr: TFPCManager;
  LVer: string;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_UPDATE_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_UPDATE_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_UPDATE_OPT_HELP));
    Exit(0);
  end;

  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    // If version specified, update that version's sources
    if Length(AParams) >= 1 then
    begin
      LVer := AParams[0];
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_UPDATE_VERSION, [LVer]));
      if LMgr.UpdateSources(LVer) then
        Ctx.Out.WriteLn(_(CMD_FPC_UPDATE_DONE))
      else
      begin
        Ctx.Err.WriteLn(_Fmt(CMD_FPC_UPDATE_FAILED, [LVer]));
        Exit(3);
      end;
    end
    else
    begin
      // No version specified, update index only
      Ctx.Out.WriteLn(_(CMD_FPC_UPDATE_INDEX));
      FPC_UpdateIndex;
      Ctx.Out.WriteLn(_(CMD_FPC_UPDATE_DONE));
    end;
  finally
    LMgr.Free;
  end;
end;

function FPCUpdateFactory: ICommand;
begin
  Result := TFPCUpdateCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','update'], @FPCUpdateFactory, []);

end.

