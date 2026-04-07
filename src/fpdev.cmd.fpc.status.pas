unit fpdev.cmd.fpc.status;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.fpc.manager,
  fpdev.i18n, fpdev.i18n.strings, fpdev.exitcodes;

type
  TFPCStatusCommand = class(TInterfacedObject, ICommand)
  public
    function Name: string;
    function Aliases: TStringArray;
    function FindSub(const AName: string): ICommand;
    function Execute(const AParams: array of string; const Ctx: IContext): Integer;
  end;

function CreateFPCStatusCommand: ICommand;

implementation

uses
  fpjson, fpdev.command.utils, fpdev.fpc.types;

function CreateFPCStatusCommand: ICommand;
begin
  Result := TFPCStatusCommand.Create;
end;

function TFPCStatusCommand.Name: string;
begin
  Result := 'status';
end;

function TFPCStatusCommand.Aliases: TStringArray;
begin
  Result := nil;
end;

function TFPCStatusCommand.FindSub(const AName: string): ICommand;
begin
  if AName <> '' then;
  Result := nil;
end;

function ValueOrNone(const AValue: string): string;
begin
  if Trim(AValue) = '' then
    Result := 'none'
  else
    Result := AValue;
end;

function TFPCStatusCommand.Execute(const AParams: array of string; const Ctx: IContext): Integer;
var
  Manager: TFPCManager;
  StatusInfo: TFPCStatusInfo;
  ErrMsg: string;
  JsonOutput: Boolean;
  UnknownOption: string;
  StatusJson: TJSONObject;
  SourceMode: string;
begin
  Result := EXIT_ERROR;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    if Length(AParams) > 1 then
    begin
      Ctx.Err.WriteLn(_(HELP_FPC_STATUS_USAGE));
      Exit(EXIT_USAGE_ERROR);
    end;
    Ctx.Out.WriteLn(_(HELP_FPC_STATUS_USAGE));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_STATUS_DESC));
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_(HELP_FPC_STATUS_OPTIONS));
    Ctx.Out.WriteLn(_(HELP_FPC_STATUS_OPT_JSON));
    Ctx.Out.WriteLn(_(HELP_FPC_STATUS_OPT_HELP));
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, ['--json'], UnknownOption) then
  begin
    Ctx.Err.WriteLn(_(HELP_FPC_STATUS_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 0 then
  begin
    Ctx.Err.WriteLn(_(HELP_FPC_STATUS_USAGE));
    Exit(EXIT_USAGE_ERROR);
  end;

  JsonOutput := HasFlag(AParams, 'json');
  Manager := TFPCManager.Create(Ctx.Config, Ctx.Out, Ctx.Err);
  try
    if not Manager.GetStatus(StatusInfo, ErrMsg) then
    begin
      Ctx.Err.WriteLn(ErrMsg);
      Exit(EXIT_NOT_FOUND);
    end;

    if StatusInfo.HasSourceMode then
      SourceMode := FPCSourceModeToString(StatusInfo.SourceMode)
    else
      SourceMode := 'unknown';

    if JsonOutput then
    begin
      StatusJson := TJSONObject.Create;
      try
        StatusJson.Add('effective_version', ValueOrNone(StatusInfo.EffectiveVersion));
        StatusJson.Add('configured_default', ValueOrNone(StatusInfo.ConfiguredDefault));
        StatusJson.Add('active_scope', FPCStatusScopeToString(StatusInfo.ActiveScope));
        StatusJson.Add('managed_prefix', ValueOrNone(StatusInfo.ManagedPrefix));
        StatusJson.Add('source_mode', SourceMode);
        StatusJson.Add('verify_status', FPCVerifyStatusToString(StatusInfo.VerifyStatus));
        Ctx.Out.WriteLn(StatusJson.FormatJSON);
      finally
        StatusJson.Free;
      end;
      Exit(EXIT_OK);
    end;

    Ctx.Out.WriteLn('Effective version: ' + ValueOrNone(StatusInfo.EffectiveVersion));
    Ctx.Out.WriteLn('Configured default: ' + ValueOrNone(StatusInfo.ConfiguredDefault));
    Ctx.Out.WriteLn('Active scope: ' + FPCStatusScopeToString(StatusInfo.ActiveScope));
    Ctx.Out.WriteLn('Managed prefix: ' + ValueOrNone(StatusInfo.ManagedPrefix));
    Ctx.Out.WriteLn('Source mode: ' + SourceMode);
    Ctx.Out.WriteLn('Verify status: ' + FPCVerifyStatusToString(StatusInfo.VerifyStatus));
    Result := EXIT_OK;
  finally
    Manager.Free;
  end;
end;

initialization
  GlobalCommandRegistry.RegisterPath(['fpc', 'status'], @CreateFPCStatusCommand, []);

end.
