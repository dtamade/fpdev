unit fpdev.cmd.fpc.test;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.fpc.manager,
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

uses
  fpdev.command.utils,
  fpdev.utils.process;

function TryTestSystemFPC(const Ctx: IContext): Boolean;
var
  LFPCExe: string;
  LResult: TProcessResult;
begin
  Result := False;

  LFPCExe := TProcessExecutor.FindExecutable('fpc');
  if LFPCExe = '' then
  begin
    Ctx.Err.WriteLn('Error: system FPC not found in PATH');
    Exit(False);
  end;

  Ctx.Out.WriteLn('Testing system FPC...');
  LResult := TProcessExecutor.Execute(LFPCExe, ['-i'], '');
  Result := LResult.Success;
  if Result then
    Ctx.Out.WriteLn('OK: system FPC is functional')
  else if LResult.ErrorMessage <> '' then
    Ctx.Err.WriteLn('Error: system FPC failed - ' + LResult.ErrorMessage)
  else
    Ctx.Err.WriteLn('Error: system FPC failed');
end;

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
  Result := EXIT_OK;

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
      // No default toolchain set: fall back to checking the system FPC in PATH.
      if TryTestSystemFPC(Ctx) then
        Exit(EXIT_OK);
      Ctx.Err.WriteLn(_(CMD_FPC_CURRENT_NONE));
      Exit(EXIT_CONFIG_ERROR);
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

