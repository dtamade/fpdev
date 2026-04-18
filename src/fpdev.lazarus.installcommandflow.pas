unit fpdev.lazarus.installcommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.config.interfaces;

type
  TLazarusInstallCommandPlan = record
    Version: string;
    FPCVersion: string;
    FromSource: Boolean;
    ConfigureAfterInstall: Boolean;
  end;

  TLazarusInstallCommandInstallFunc = function(
    const Outp, Errp: IOutput;
    const AVersion: string;
    const AFPCVersion: string;
    const AFromSource: Boolean;
    const AConfigure: Boolean
  ): Boolean of object;

function PrepareLazarusInstallCommandPlanCore(
  const AParams: array of string;
  var ASettings: TFPDevSettings;
  const AOut, AErr: IOutput;
  out APlan: TLazarusInstallCommandPlan;
  out AShouldExit: Boolean;
  out ASettingsModified: Boolean
): Integer;

function ExecuteLazarusInstallCommandPlanCore(
  const APlan: TLazarusInstallCommandPlan;
  const AOut, AErr: IOutput;
  AInstall: TLazarusInstallCommandInstallFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteInstallUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
end;

procedure WriteInstallHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_OPTIONS));
  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_SOURCE));
  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_FROM));
  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_FPC));
  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_JOBS));
  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_NOCONFIG));
  AOut.WriteLn(_(HELP_LAZARUS_INSTALL_OPT_HELP));
end;

function PrepareLazarusInstallCommandPlanCore(
  const AParams: array of string;
  var ASettings: TFPDevSettings;
  const AOut, AErr: IOutput;
  out APlan: TLazarusInstallCommandPlan;
  out AShouldExit: Boolean;
  out ASettingsModified: Boolean
): Integer;
var
  FromValue: string;
  JobsValue: string;
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TLazarusInstallCommandPlan);
  APlan.ConfigureAfterInstall := True;
  AShouldExit := False;
  ASettingsModified := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    if Length(AParams) > 1 then
    begin
      WriteInstallUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;

    WriteInstallHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(
    AParams,
    ['--from-source', '-from-source', '--no-configure', '-no-configure',
     '--from=', '--fpc=', '--jobs='],
    UnknownOption
  ) then
  begin
    AShouldExit := True;
    WriteInstallUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    WriteInstallUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 1 then
  begin
    AShouldExit := True;
    WriteInstallUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.Version := GetPositionalArg(AParams, 0);
  APlan.FromSource := HasFlag(AParams, 'from-source');
  APlan.ConfigureAfterInstall := not HasFlag(AParams, 'no-configure');

  if GetFlagValue(AParams, 'from', FromValue) then
  begin
    if SameText(FromValue, 'source') then
      APlan.FromSource := True
    else if SameText(FromValue, 'binary') then
      APlan.FromSource := False
    else
    begin
      AShouldExit := True;
      if AErr <> nil then
        AErr.WriteLn('Error: Invalid --from mode: ' + FromValue);
      WriteInstallUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
  end;

  APlan.FPCVersion := '';
  if GetFlagValue(AParams, 'fpc', APlan.FPCVersion) and (APlan.FPCVersion = '') then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn('Error: Missing --fpc value');
    WriteInstallUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if GetFlagValue(AParams, 'jobs', JobsValue) then
  begin
    if not TryStrToInt(JobsValue, ASettings.ParallelJobs) then
    begin
      AShouldExit := True;
      if AErr <> nil then
        AErr.WriteLn('Error: Invalid --jobs value: ' + JobsValue);
      WriteInstallUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;
    ASettingsModified := True;
  end;
end;

function ExecuteLazarusInstallCommandPlanCore(
  const APlan: TLazarusInstallCommandPlan;
  const AOut, AErr: IOutput;
  AInstall: TLazarusInstallCommandInstallFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if AOut <> nil then
    AOut.WriteLn(_Fmt(CMD_LAZARUS_INSTALL_START, [APlan.Version]));

  if not Assigned(AInstall) then
    Exit(EXIT_ERROR);

  if AInstall(
    AOut,
    AErr,
    APlan.Version,
    APlan.FPCVersion,
    APlan.FromSource,
    APlan.ConfigureAfterInstall
  ) then
    Exit(EXIT_OK);
end;

end.
