unit fpdev.cmd.fpc.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.config.interfaces, fpdev.cmd.fpc, fpdev.types,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TFPCInstallCommand }
  TFPCInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.command.registry, fpdev.cmd.utils;

function TFPCInstallCommand.Name: string; begin Result := 'install'; end;

function TFPCInstallCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCInstallCommand.FindSub(const AName: string): ICommand;
begin
  Result := nil;
  if AName <> '' then;  // Unused parameter
end;

function FPCInstallFactory: ICommand;
begin
  Result := TFPCInstallCommand.Create;
end;



function TFPCInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer, LJobs, LFrom, LPrefix: string;
  LMode: TInstallMode;
  LFromSource: Boolean;
  LSettings: TFPDevSettings;
  LOk: Boolean;
  LMgr: TFPCManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_SOURCE));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_BINARY));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_FROM));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_JOBS));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_PREFIX));
    Ctx.Out.WriteLn(_(HELP_FPC_INSTALL_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_FPC_INSTALL_USAGE));
    Exit(2);
  end;
  LVer := AParams[0];

  // Parse install mode using type-safe enum
  LMode := imAuto;  // Default mode
  if GetFlagValue(AParams, 'from', LFrom) then
  begin
    if not TryStringToInstallMode(LFrom, LMode) then
    begin
      Ctx.Err.WriteLn(_Fmt(ERR_INVALID_INSTALL_MODE, [LFrom]));
      Ctx.Err.WriteLn(_(ERR_VALID_INSTALL_MODES));
      Exit(2);
    end;
  end
  else if HasFlag(AParams, 'from-source') then
    LMode := imSource
  else if HasFlag(AParams, 'from-binary') then
    LMode := imBinary;

  // Convert mode to legacy boolean (until TFPCManager is refactored)
  LFromSource := (LMode = imSource);

  // Parse other flags
  if GetFlagValue(AParams, 'jobs', LJobs) then
  begin
    LSettings := Ctx.Config.GetSettingsManager.GetSettings;
    if TryStrToInt(LJobs, LSettings.ParallelJobs) then
      Ctx.Config.GetSettingsManager.SetSettings(LSettings);
  end;
  if not GetFlagValue(AParams, 'prefix', LPrefix) then LPrefix := '';

  // Show installation mode
  Ctx.Out.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [LVer]) + ' (mode: ' + InstallModeToString(LMode) + ')');

  LMgr := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    LOk := LMgr.InstallVersion(LVer, LFromSource, LPrefix, False);
    if LOk then
    begin
      Exit(0);
    end
    else
    begin
      Ctx.Err.WriteLn(_Fmt(CMD_FPC_INSTALL_FAILED, [LVer]));
      Exit(3);
    end;
  finally
    LMgr.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc','install'], @FPCInstallFactory, []);

end.

