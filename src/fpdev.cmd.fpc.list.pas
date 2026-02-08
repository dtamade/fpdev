unit fpdev.cmd.fpc.list;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.cmd.fpc,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCListCommand }
  TFPCListCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TFPCListCommand.Name: string; begin Result := 'list'; end;

function TFPCListCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCListCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCListFactory: ICommand;
begin
  Result := TFPCListCommand.Create;
end;


function TFPCListCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LShowAll: Boolean;
  LMgr: TFPCManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPT_ALL));
    Ctx.Out.WriteLn(_(HELP_FPC_LIST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LShowAll := HasFlag(AParams, 'all') or HasFlag(AParams, 'remote');
  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    if LMgr.ListVersions(Ctx.Out, LShowAll) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;


initialization
  GlobalCommandRegistry.RegisterPath(['fpc','list'], @FPCListFactory, []);

end.

