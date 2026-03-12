unit fpdev.cmd.lazarus.install;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config.interfaces, fpdev.cmd.lazarus,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

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

uses fpdev.command.utils;

function TLazInstallCommand.Name: string; begin Result := 'install'; end;
function TLazInstallCommand.Aliases: TStringArray; begin Result := nil; end;
function TLazInstallCommand.FindSub(const AName: string): ICommand; begin if AName <> '' then; Result := nil; end;

function TLazInstallCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  LVer, LFPCVer, LJobs, LFrom: string;
  LFromSource: Boolean;
  LNoConfigure: Boolean;
  LSettings: TFPDevSettings;
  LMgr: TLazarusManager;
  I: Integer;
  LParam: string;
  LPositionalCount: Integer;
begin
  Result := EXIT_OK;

  // Handle --help flag
  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_SOURCE));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_FROM));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_FPC));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_JOBS));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_NOCONFIG));
    Ctx.Out.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_HELP));
    Exit(EXIT_OK);
  end;

  LPositionalCount := 0;
  for I := Low(AParams) to High(AParams) do
  begin
    LParam := AParams[I];
    if (Length(LParam) > 0) and (LParam[1] = '-') then
    begin
      if SameText(LParam, '--from-source') or SameText(LParam, '-from-source') or
         SameText(LParam, '--no-configure') or SameText(LParam, '-no-configure') or
         (Pos('--from=', LowerCase(LParam)) = 1) or
         (Pos('--fpc=', LowerCase(LParam)) = 1) or
         (Pos('--jobs=', LowerCase(LParam)) = 1) then
        Continue;
      Ctx.Err.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;

    Inc(LPositionalCount);
    if LPositionalCount > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
  end;

  if LPositionalCount < 1 then
  begin
    Ctx.Err.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    Ctx.Err.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;
  LVer := GetPositionalArg(AParams, 0);

  LFromSource := HasFlag(AParams, 'from-source');
  if GetFlagValue(AParams, 'from', LFrom) then
    LFromSource := LFromSource or SameText(LFrom, 'source');

  LNoConfigure := HasFlag(AParams, 'no-configure');

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
    if LMgr.InstallVersion(Ctx.Out, Ctx.Err, LVer, LFPCVer, LFromSource, not LNoConfigure) then
      Exit(EXIT_OK);
    Ctx.Err.WriteLn(_(CMD_LAZARUS_INSTALL_FAILED));
    Result := EXIT_ERROR;
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
