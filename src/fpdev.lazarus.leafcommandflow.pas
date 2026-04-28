unit fpdev.lazarus.leafcommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TLazarusCurrentCommandPlan = record
    JsonOutput: Boolean;
  end;

  TLazarusVersionLeafPlan = record
    Version: string;
  end;

  TLazarusUpdateCommandPlan = record
    Version: string;
  end;

  TLazarusCurrentVersionFunc = function: string of object;
  TLazarusVersionActionFunc = function(
    const Outp, Errp: IOutput;
    const AVersion: string
  ): Boolean of object;
  TLazarusShowActionFunc = function(
    const Outp: IOutput;
    const AVersion: string
  ): Boolean of object;
  TLazarusVersionValidFunc = function(const AVersion: string): Boolean of object;

function PrepareLazarusCurrentCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusCurrentCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteLazarusCurrentCommandPlanCore(
  const APlan: TLazarusCurrentCommandPlan;
  const AOut: IOutput;
  AGetCurrentVersion: TLazarusCurrentVersionFunc
): Integer;

function PrepareLazarusUseCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteLazarusUseCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  ASetDefaultVersion: TLazarusVersionActionFunc
): Integer;

function PrepareLazarusShowCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteLazarusShowCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  AIsValidVersion: TLazarusVersionValidFunc;
  AShowVersionInfo: TLazarusShowActionFunc
): Integer;

function PrepareLazarusConfigureCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteLazarusConfigureCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  AConfigureIDE: TLazarusVersionActionFunc
): Integer;

function PrepareLazarusUninstallCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteLazarusUninstallCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  AUninstallVersion: TLazarusVersionActionFunc
): Integer;

function PrepareLazarusUpdateCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusUpdateCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteLazarusUpdateCommandPlanCore(
  const APlan: TLazarusUpdateCommandPlan;
  const AOut, AErr: IOutput;
  AUpdateSources: TLazarusVersionActionFunc
): Integer;

function PrepareLazarusTestCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteLazarusTestCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  ATestInstallation: TLazarusVersionActionFunc
): Integer;

implementation

uses
  SysUtils, fpjson,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

type
  TLazarusLeafKind = (
    llkCurrent,
    llkUse,
    llkShow,
    llkConfigure,
    llkUninstall,
    llkUpdate,
    llkTest
  );

procedure WriteLeafUsage(const AOut: IOutput; const AKind: TLazarusLeafKind);
begin
  if AOut = nil then
    Exit;

  case AKind of
    llkCurrent:
      AOut.WriteLn(_(HELP_LAZARUS_CURRENT_USAGE));
    llkUse:
      AOut.WriteLn(_(HELP_LAZARUS_USE_USAGE));
    llkShow:
      AOut.WriteLn(_(HELP_LAZARUS_SHOW_USAGE));
    llkConfigure:
      AOut.WriteLn(_(HELP_LAZARUS_CONFIGURE_USAGE));
    llkUninstall:
      AOut.WriteLn(_(HELP_LAZARUS_UNINSTALL_USAGE));
    llkUpdate:
      AOut.WriteLn(_(HELP_LAZARUS_UPDATE_USAGE));
    llkTest:
      AOut.WriteLn(_(HELP_LAZARUS_TEST_USAGE));
  end;
end;

procedure WriteLeafHelp(const AOut: IOutput; const AKind: TLazarusLeafKind);
begin
  if AOut = nil then
    Exit;

  case AKind of
    llkCurrent:
      begin
        AOut.WriteLn(_(HELP_LAZARUS_CURRENT_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_CURRENT_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_CURRENT_OPT_JSON));
        AOut.WriteLn(_(HELP_LAZARUS_CURRENT_OPT_HELP));
      end;
    llkUse:
      begin
        AOut.WriteLn(_(HELP_LAZARUS_USE_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_USE_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_USE_OPT_HELP));
      end;
    llkShow:
      begin
        AOut.WriteLn(_(HELP_LAZARUS_SHOW_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_SHOW_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_SHOW_OPT_HELP));
      end;
    llkConfigure:
      begin
        AOut.WriteLn(_(HELP_LAZARUS_CONFIGURE_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_CONFIGURE_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_CONFIGURE_OPT_HELP));
      end;
    llkUninstall:
      begin
        AOut.WriteLn(_(HELP_LAZARUS_UNINSTALL_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_UNINSTALL_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_UNINSTALL_OPT_HELP));
      end;
    llkUpdate:
      begin
        AOut.WriteLn(_(HELP_LAZARUS_UPDATE_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_UPDATE_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_UPDATE_OPT_HELP));
      end;
    llkTest:
      begin
        AOut.WriteLn(_(HELP_LAZARUS_TEST_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_TEST_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_LAZARUS_TEST_OPT_HELP));
      end;
  end;
end;

function PrepareRequiredVersionLeafPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  const AKind: TLazarusLeafKind;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TLazarusVersionLeafPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    if Length(AParams) > 1 then
    begin
      WriteLeafUsage(AErr, AKind);
      Exit(EXIT_USAGE_ERROR);
    end;

    WriteLeafHelp(AOut, AKind);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteLeafUsage(AErr, AKind);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['version']));
    WriteLeafUsage(AErr, AKind);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 1 then
  begin
    AShouldExit := True;
    WriteLeafUsage(AErr, AKind);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.Version := GetPositionalArg(AParams, 0);
end;

function ExecuteBooleanVersionLeafCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  const AStartBanner: string;
  const AAppendFailedOnError: Boolean;
  AAction: TLazarusVersionActionFunc
): Integer;
begin
  Result := EXIT_ERROR;
  if not Assigned(AAction) then
    Exit(EXIT_ERROR);

  if (AStartBanner <> '') and (AOut <> nil) then
    AOut.WriteLn(AStartBanner);

  if AAction(AOut, AErr, APlan.Version) then
    Exit(EXIT_OK);

  if AAppendFailedOnError and (AErr <> nil) then
    AErr.WriteLn(_(MSG_FAILED));
end;

function PrepareLazarusCurrentCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusCurrentCommandPlan;
  out AShouldExit: Boolean
): Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TLazarusCurrentCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    if Length(AParams) > 1 then
    begin
      WriteLeafUsage(AErr, llkCurrent);
      Exit(EXIT_USAGE_ERROR);
    end;

    WriteLeafHelp(AOut, llkCurrent);
    Exit(EXIT_OK);
  end;

  if Length(AParams) > 1 then
  begin
    AShouldExit := True;
    WriteLeafUsage(AErr, llkCurrent);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.JsonOutput := HasFlag(AParams, 'json');
  if (Length(AParams) = 1) and (not APlan.JsonOutput) then
  begin
    AShouldExit := True;
    WriteLeafUsage(AErr, llkCurrent);
    Exit(EXIT_USAGE_ERROR);
  end;
end;

function ExecuteLazarusCurrentCommandPlanCore(
  const APlan: TLazarusCurrentCommandPlan;
  const AOut: IOutput;
  AGetCurrentVersion: TLazarusCurrentVersionFunc
): Integer;
var
  LVersion: string;
  LJson: TJSONObject;
begin
  Result := EXIT_ERROR;
  if not Assigned(AGetCurrentVersion) then
    Exit(EXIT_ERROR);

  LVersion := AGetCurrentVersion();
  if APlan.JsonOutput then
  begin
    LJson := TJSONObject.Create;
    try
      if LVersion <> '' then
      begin
        LJson.Add('version', LVersion);
        LJson.Add('has_default', True);
      end
      else
      begin
        LJson.Add('version', TJSONNull.Create);
        LJson.Add('has_default', False);
      end;
      if AOut <> nil then
        AOut.WriteLn(LJson.FormatJSON);
    finally
      LJson.Free;
    end;
  end
  else if AOut <> nil then
  begin
    if LVersion <> '' then
      AOut.WriteLn(_Fmt(CMD_LAZARUS_CURRENT_VERSION, [LVersion]))
    else
      AOut.WriteLn(_(CMD_LAZARUS_CURRENT_NONE));
  end;

  Result := EXIT_OK;
end;

function PrepareLazarusUseCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;
begin
  Result := PrepareRequiredVersionLeafPlanCore(
    AParams,
    AOut,
    AErr,
    llkUse,
    APlan,
    AShouldExit
  );
end;

function ExecuteLazarusUseCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  ASetDefaultVersion: TLazarusVersionActionFunc
): Integer;
begin
  Result := ExecuteBooleanVersionLeafCore(
    APlan,
    AOut,
    AErr,
    '',
    False,
    ASetDefaultVersion
  );
end;

function PrepareLazarusShowCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;
begin
  Result := PrepareRequiredVersionLeafPlanCore(
    AParams,
    AOut,
    AErr,
    llkShow,
    APlan,
    AShouldExit
  );
end;

function ExecuteLazarusShowCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  AIsValidVersion: TLazarusVersionValidFunc;
  AShowVersionInfo: TLazarusShowActionFunc
): Integer;
begin
  Result := EXIT_ERROR;
  if (not Assigned(AIsValidVersion)) or (not Assigned(AShowVersionInfo)) then
    Exit(EXIT_ERROR);

  if not AIsValidVersion(APlan.Version) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_Fmt(CMD_LAZARUS_UNSUPPORTED_VERSION, [APlan.Version]));
    Exit(EXIT_NOT_FOUND);
  end;

  if AShowVersionInfo(AOut, APlan.Version) then
    Exit(EXIT_OK);
end;

function PrepareLazarusConfigureCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;
begin
  Result := PrepareRequiredVersionLeafPlanCore(
    AParams,
    AOut,
    AErr,
    llkConfigure,
    APlan,
    AShouldExit
  );
end;

function ExecuteLazarusConfigureCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  AConfigureIDE: TLazarusVersionActionFunc
): Integer;
begin
  Result := ExecuteBooleanVersionLeafCore(
    APlan,
    AOut,
    AErr,
    _Fmt(CMD_LAZARUS_CONFIG_START, [APlan.Version]),
    False,
    AConfigureIDE
  );
end;

function PrepareLazarusUninstallCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;
begin
  Result := PrepareRequiredVersionLeafPlanCore(
    AParams,
    AOut,
    AErr,
    llkUninstall,
    APlan,
    AShouldExit
  );
end;

function ExecuteLazarusUninstallCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  AUninstallVersion: TLazarusVersionActionFunc
): Integer;
begin
  Result := ExecuteBooleanVersionLeafCore(
    APlan,
    AOut,
    AErr,
    '',
    True,
    AUninstallVersion
  );
end;

function PrepareLazarusUpdateCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusUpdateCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TLazarusUpdateCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    if Length(AParams) > 1 then
    begin
      WriteLeafUsage(AErr, llkUpdate);
      Exit(EXIT_USAGE_ERROR);
    end;

    WriteLeafHelp(AOut, llkUpdate);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteLeafUsage(AErr, llkUpdate);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount > 1 then
  begin
    AShouldExit := True;
    WriteLeafUsage(AErr, llkUpdate);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount >= 1 then
    APlan.Version := GetPositionalArg(AParams, 0)
  else
    APlan.Version := '';
end;

function ExecuteLazarusUpdateCommandPlanCore(
  const APlan: TLazarusUpdateCommandPlan;
  const AOut, AErr: IOutput;
  AUpdateSources: TLazarusVersionActionFunc
): Integer;
begin
  Result := EXIT_ERROR;
  if not Assigned(AUpdateSources) then
    Exit(EXIT_ERROR);

  if AUpdateSources(AOut, AErr, APlan.Version) then
    Exit(EXIT_OK);
end;

function PrepareLazarusTestCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TLazarusVersionLeafPlan;
  out AShouldExit: Boolean
): Integer;
begin
  Result := PrepareRequiredVersionLeafPlanCore(
    AParams,
    AOut,
    AErr,
    llkTest,
    APlan,
    AShouldExit
  );
end;

function ExecuteLazarusTestCommandPlanCore(
  const APlan: TLazarusVersionLeafPlan;
  const AOut, AErr: IOutput;
  ATestInstallation: TLazarusVersionActionFunc
): Integer;
begin
  Result := ExecuteBooleanVersionLeafCore(
    APlan,
    AOut,
    AErr,
    '',
    False,
    ATestInstallation
  );
end;

end.
