unit fpdev.cmd.fpc.show;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.fpc.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes, fpdev.version.registry;

type
  { TFPCShowCommand }
  TFPCShowCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.utils;

function TFPCShowCommand.Name: string; begin Result := 'show'; end;

function TFPCShowCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCShowCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TFPCShowCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TFPCManager;
  LUnknownOption: string;
  LPositionalCount: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_FPC_SHOW_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_FPC_SHOW_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_SHOW_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_SHOW_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], LUnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_FPC_SHOW_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LPositionalCount := CountPositionalArgs(AParams);
  if LPositionalCount < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_FPC_SHOW_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if LPositionalCount > 1 then
  begin
    Ctx.Err.WriteLn(_(HELP_FPC_SHOW_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  LVer := GetPositionalArg(AParams, 0);
  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    if not TVersionRegistry.Instance.IsFPCVersionValid(LVer) then
    begin
      Ctx.Err.WriteLn(_Fmt(CMD_FPC_UNSUPPORTED_VERSION, [LVer]));
      Exit(EXIT_NOT_FOUND);
    end;

    if LMgr.ShowVersionInfo(Ctx.Out, LVer) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

function FPCShowFactory: ICommand;
begin
  Result := TFPCShowCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','show'], @FPCShowFactory, []);

end.

