unit fpdev.fpc.installcommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.types,
  fpdev.config.interfaces;

type
  TFPCInstallCommandPlan = record
    Version: string;
    Mode: TInstallMode;
    Prefix: string;
    OfflineMode: Boolean;
    NoCache: Boolean;
  end;

  TFPCInstallCommandInstallFunc = function(
    const AVersion: string;
    const AFromSource: Boolean;
    const APrefix: string;
    const AEnsure: Boolean;
    const ANoCache: Boolean;
    const AOfflineMode: Boolean
  ): Boolean of object;

function PrepareFPCInstallCommandPlanCore(
  const AParams: array of string;
  var ASettings: TFPDevSettings;
  const AOut, AErr: IOutput;
  out APlan: TFPCInstallCommandPlan;
  out AShouldExit: Boolean;
  out ASettingsModified: Boolean
): Integer;

function ExecuteFPCInstallCommandPlanCore(
  const APlan: TFPCInstallCommandPlan;
  const AOut, AErr: IOutput;
  const ANetworkDisabled: Boolean;
  AInstall: TFPCInstallCommandInstallFunc
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
    AOut.WriteLn(_(HELP_FPC_INSTALL_USAGE));
end;

procedure WriteInstallHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_FPC_INSTALL_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_FPC_INSTALL_OPTIONS));
  AOut.WriteLn(_(HELP_FPC_INSTALL_OPT_SOURCE));
  AOut.WriteLn(_(HELP_FPC_INSTALL_OPT_BINARY));
  AOut.WriteLn(_(HELP_FPC_INSTALL_OPT_FROM));
  AOut.WriteLn(_(HELP_FPC_INSTALL_OPT_JOBS));
  AOut.WriteLn(_(HELP_FPC_INSTALL_OPT_PREFIX));
  AOut.WriteLn('  --offline         Force offline mode (use cache only)');
  AOut.WriteLn('  --no-cache        Ignore cache, force re-download');
  AOut.WriteLn(_(HELP_FPC_INSTALL_OPT_HELP));
end;

procedure WriteStartBanner(const APlan: TFPCInstallCommandPlan; const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  if APlan.OfflineMode then
    AOut.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [APlan.Version]) +
      ' (mode: ' + InstallModeToString(APlan.Mode) + ', offline)')
  else if APlan.NoCache then
    AOut.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [APlan.Version]) +
      ' (mode: ' + InstallModeToString(APlan.Mode) + ', no-cache)')
  else
    AOut.WriteLn(_Fmt(CMD_FPC_INSTALL_START, [APlan.Version]) +
      ' (mode: ' + InstallModeToString(APlan.Mode) + ')');
end;

function PrepareFPCInstallCommandPlanCore(
  const AParams: array of string;
  var ASettings: TFPDevSettings;
  const AOut, AErr: IOutput;
  out APlan: TFPCInstallCommandPlan;
  out AShouldExit: Boolean;
  out ASettingsModified: Boolean
): Integer;
var
  JobsValue: string;
  FromValue: string;
  PrefixValue: string;
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TFPCInstallCommandPlan);
  APlan.Mode := imAuto;
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
    ['--from-source', '--from-binary', '--from=', '--jobs=', '--prefix=',
     '--offline', '--no-cache'],
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
  APlan.OfflineMode := HasFlag(AParams, 'offline');
  APlan.NoCache := HasFlag(AParams, 'no-cache');

  if GetFlagValue(AParams, 'from', FromValue) then
  begin
    if not TryStringToInstallMode(FromValue, APlan.Mode) then
    begin
      AShouldExit := True;
      if AErr <> nil then
      begin
        AErr.WriteLn(_Fmt(ERR_INVALID_INSTALL_MODE, [FromValue]));
        AErr.WriteLn(_(ERR_VALID_INSTALL_MODES));
      end;
      Exit(EXIT_USAGE_ERROR);
    end;
  end
  else if HasFlag(AParams, 'from-source') then
    APlan.Mode := imSource
  else if HasFlag(AParams, 'from-binary') then
    APlan.Mode := imBinary;

  if GetFlagValue(AParams, 'jobs', JobsValue) then
  begin
    if not TryStrToInt(JobsValue, ASettings.ParallelJobs) then
    begin
      AShouldExit := True;
      if AErr <> nil then
      begin
        AErr.WriteLn('Error: Invalid --jobs value: ' + JobsValue);
        AErr.WriteLn(_(HELP_FPC_INSTALL_USAGE));
      end;
      Exit(EXIT_USAGE_ERROR);
    end;
    ASettingsModified := True;
  end;

  if GetFlagValue(AParams, 'prefix', PrefixValue) then
  begin
    if PrefixValue = '' then
    begin
      AShouldExit := True;
      if AErr <> nil then
      begin
        AErr.WriteLn('Error: Missing --prefix value');
        AErr.WriteLn(_(HELP_FPC_INSTALL_USAGE));
      end;
      Exit(EXIT_USAGE_ERROR);
    end;
    APlan.Prefix := PrefixValue;
  end
  else
    APlan.Prefix := '';
end;

function ExecuteFPCInstallCommandPlanCore(
  const APlan: TFPCInstallCommandPlan;
  const AOut, AErr: IOutput;
  const ANetworkDisabled: Boolean;
  AInstall: TFPCInstallCommandInstallFunc
): Integer;
var
  Ok: Boolean;
begin
  Result := EXIT_ERROR;
  WriteStartBanner(APlan, AOut);

  if ANetworkDisabled and (not APlan.OfflineMode) then
  begin
    if AErr <> nil then
    begin
      AErr.WriteLn('[FAIL] Network operations disabled (FPDEV_SKIP_NETWORK_TESTS=1)');
      AErr.WriteLn('[HINT] Re-run without FPDEV_SKIP_NETWORK_TESTS=1 to perform real installation');
    end;
    Exit(EXIT_IO_ERROR);
  end;

  if not Assigned(AInstall) then
    Exit(EXIT_ERROR);

  if APlan.Mode = imAuto then
  begin
    if AOut <> nil then
      AOut.WriteLn('Attempting binary installation first...');

    Ok := AInstall(
      APlan.Version,
      False,
      APlan.Prefix,
      False,
      APlan.NoCache,
      APlan.OfflineMode
    );

    if (not Ok) and (not APlan.OfflineMode) then
    begin
      if AOut <> nil then
      begin
        AOut.WriteLn('');
        AOut.WriteLn('Binary installation failed, falling back to source installation...');
        AOut.WriteLn('Note: Source installation requires a bootstrap compiler and may take longer');
        AOut.WriteLn('');
      end;

      Ok := AInstall(
        APlan.Version,
        True,
        APlan.Prefix,
        False,
        APlan.NoCache,
        False
      );

      if not Ok then
      begin
        if AErr <> nil then
        begin
          AErr.WriteLn('');
          AErr.WriteLn('Both binary and source installation failed');
          AErr.WriteLn('Troubleshooting:');
          AErr.WriteLn('  1. Check network connectivity');
          AErr.WriteLn('  2. Verify version exists: fpdev fpc list --all');
          AErr.WriteLn('  3. For source builds, ensure bootstrap compiler is available');
        end;
        Exit(EXIT_ERROR);
      end;
    end;
  end
  else
    Ok := AInstall(
      APlan.Version,
      APlan.Mode = imSource,
      APlan.Prefix,
      False,
      APlan.NoCache,
      APlan.OfflineMode
    );

  if Ok then
    Exit(EXIT_OK);

  if APlan.OfflineMode then
    Exit(EXIT_IO_ERROR);

  Exit(EXIT_ERROR);
end;

end.
