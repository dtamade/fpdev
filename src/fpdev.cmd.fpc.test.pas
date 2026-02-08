unit fpdev.cmd.fpc.test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.cmd.fpc,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  { TFPCCTestCommand }
  TFPCCTestCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TFPCCTestCommand.Name: string; begin Result := 'test'; end;

function TFPCCTestCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCCTestCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function TFPCCTestCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer: string;
  LMgr: TFPCManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_TEST_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_TEST_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_TEST_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if Length(AParams) < 1 then
  begin
    // Use current default version if not specified
    LVer := Ctx.Config.GetToolchainManager.GetDefaultToolchain;
    if LVer <> '' then
      LVer := StringReplace(LVer, 'fpc-', '', [rfReplaceAll]);
    if LVer = '' then
    begin
      Ctx.Err.WriteLn(_(CMD_FPC_CURRENT_NONE));
      Exit(EXIT_USAGE_ERROR);
    end;
  end
  else
    LVer := AParams[0];
  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    if LMgr.TestInstallation(Ctx.Out, Ctx.Err, LVer) then
      Exit(EXIT_OK);
    Result := EXIT_ERROR;
  finally
    LMgr.Free;
  end;
end;

function FPCTestFactory: ICommand;
begin
  Result := TFPCCTestCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','test'], @FPCTestFactory, []);

end.

