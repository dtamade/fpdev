unit fpdev.cmd.lazarus.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config.interfaces, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings;

type
  { TLazInstallCommand }
  TLazInstallCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

implementation

uses fpdev.cmd.utils;

function TLazInstallCommand.Name: string; begin Result := 'install'; end;
function TLazInstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazInstallCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer, LFPCVer, LJobs, LFrom: string;
  LFromSource: Boolean;
  LSettings: TFPDevSettings;
  LMgr: TLazarusManager;
begin
  Result := 0;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_SOURCE));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_FROM));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_FPC));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_JOBS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_HELP));
    Exit(0);
  end;

  if Length(AParams) < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
    Exit(2);
  end;
  LVer := AParams[0];

  LFromSource := HasFlag(AParams, 'from-source');
  if GetFlagValue(AParams, 'from', LFrom) then
    LFromSource := LFromSource or SameText(LFrom, 'source');

  LFPCVer := '';
  GetFlagValue(AParams, 'fpc', LFPCVer);

  if GetFlagValue(AParams, 'jobs', LJobs) then
  begin
    LSettings := Ctx.Config.GetSettingsManager.GetSettings;
    if TryStrToInt(LJobs, LSettings.ParallelJobs) then
      Ctx.Config.GetSettingsManager.SetSettings(LSettings);
  end;

  Ctx.Out.WriteLn(_Fmt(CMD_LAZARUS_INSTALL_START, [LVer]));

  LMgr := TLazarusManager.Create(Ctx.Config);
  try
    if LMgr.InstallVersion(Ctx.Out, Ctx.Err, LVer, LFPCVer, LFromSource) then
      Exit(0);
    Ctx.Err.WriteLn(_(CMD_LAZARUS_INSTALL_FAILED));
    Result := 3;
  finally
    LMgr.Free;
  end;
end;

function LazInstallFactory: ICommand;
begin
  Result := TLazInstallCommand.Create;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['lazarus','install'], @LazInstallFactory, []);

end.
