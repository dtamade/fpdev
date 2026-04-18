unit fpdev.fpc.usecommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.command.intf,
  fpdev.fpc.types,
  fpdev.output.intf;

type
  TFPCUseCommandPlan = record
    Version: string;
    AutoInstall: Boolean;
    Ensure: Boolean;
    AnnounceSource: Boolean;
    SourceLabel: string;
  end;

  TFPCUseInstallFunc = function(
    const AVersion: string;
    const AFromSource: Boolean;
    const APrefix: string;
    const AEnsure: Boolean;
    const ANoCache: Boolean;
    const AOfflineMode: Boolean
  ): Boolean of object;

  TFPCUseActivateFunc = function(const AVersion: string): TActivationResult of object;

function PrepareFPCUseCommandPlanCore(
  const AParams: array of string;
  const AGlobalFPC: string;
  const AOut, AErr: IOutput;
  out APlan: TFPCUseCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecuteFPCUseCommandPlanCore(
  const APlan: TFPCUseCommandPlan;
  const Ctx: IContext;
  const AIsInstalled: Boolean;
  AInstallVersion: TFPCUseInstallFunc;
  AActivateVersion: TFPCUseActivateFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.config.project,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteUseUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_FPC_USE_USAGE));
end;

procedure WriteUseHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_FPC_USE_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_FPC_USE_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_FPC_USE_OPTIONS));
  AOut.WriteLn(_(HELP_FPC_USE_OPT_ENSURE));
  AOut.WriteLn(_(HELP_FPC_USE_OPT_HELP));
  AOut.WriteLn('');
  AOut.WriteLn('Version aliases:');
  AOut.WriteLn('  stable    Latest stable version');
  AOut.WriteLn('  lts       Long-term support version');
  AOut.WriteLn('  trunk     Development version (main branch)');
end;

function PrepareFPCUseCommandPlanCore(
  const AParams: array of string;
  const AGlobalFPC: string;
  const AOut, AErr: IOutput;
  out APlan: TFPCUseCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  Resolver: TProjectConfigResolver;
  Resolved: TResolvedConfig;
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TFPCUseCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    if Length(AParams) > 1 then
    begin
      WriteUseUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;

    WriteUseHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, ['--ensure'], UnknownOption) then
  begin
    AShouldExit := True;
    WriteUseUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  PositionalCount := CountPositionalArgs(AParams);
  if PositionalCount > 1 then
  begin
    AShouldExit := True;
    WriteUseUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  Resolver := TProjectConfigResolver.Create(AGlobalFPC, '');
  try
    if PositionalCount < 1 then
    begin
      Resolved := Resolver.ResolveConfig(GetCurrentDir);
      APlan.Version := Resolved.FPCVersion;
      if APlan.Version = '' then
      begin
        AShouldExit := True;
        if AErr <> nil then
        begin
          AErr.WriteLn('Error: No version specified and no default configured.');
          AErr.WriteLn('');
          AErr.WriteLn('Usage: fpdev fpc use <version>');
          AErr.WriteLn('');
          AErr.WriteLn('Or set a global fallback with: fpdev fpc use <version>');
          AErr.WriteLn('Or create a .fpdevrc file in your project.');
        end;
        Exit(EXIT_USAGE_ERROR);
      end;

      APlan.AnnounceSource := True;
      APlan.SourceLabel := ConfigSourceToString(Resolved.FPCSource);
      APlan.AutoInstall := Resolved.AutoInstall;
    end
    else
    begin
      APlan.Version := Resolver.ResolveVersionAlias(GetPositionalArg(AParams, 0));
      Resolved := Resolver.ResolveConfig(GetCurrentDir);
      APlan.AutoInstall := Resolved.AutoInstall;
    end;
  finally
    Resolver.Free;
  end;

  APlan.Ensure := HasFlag(AParams, 'ensure');
end;

function ExecuteFPCUseCommandPlanCore(
  const APlan: TFPCUseCommandPlan;
  const Ctx: IContext;
  const AIsInstalled: Boolean;
  AInstallVersion: TFPCUseInstallFunc;
  AActivateVersion: TFPCUseActivateFunc
): Integer;
var
  ActivationResult: TActivationResult;
begin
  Result := EXIT_ERROR;
  if Ctx = nil then
    Exit(EXIT_ERROR);

  if APlan.AnnounceSource then
  begin
    Ctx.Out.WriteLn('Using version from ' + APlan.SourceLabel + ': ' + APlan.Version);
  end;

  if not AIsInstalled then
  begin
    if APlan.Ensure or APlan.AutoInstall then
    begin
      if not Assigned(AInstallVersion) then
        Exit(EXIT_ERROR);

      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn('FPC ' + APlan.Version + ' is not installed. Installing...');
      Ctx.Out.WriteLn('');
      if not AInstallVersion(APlan.Version, True, '', True, False, False) then
      begin
        Ctx.Err.WriteLn('Error: Failed to install FPC ' + APlan.Version);
        Exit(EXIT_ERROR);
      end;
    end
    else
    begin
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Error: FPC ' + APlan.Version + ' is not installed.');
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('To install it, run:');
      Ctx.Err.WriteLn('  fpdev fpc install ' + APlan.Version);
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Or use --ensure to auto-install:');
      Ctx.Err.WriteLn('  fpdev fpc use ' + APlan.Version + ' --ensure');
      Ctx.Err.WriteLn('');
      Ctx.Err.WriteLn('Or enable auto_install in your .fpdevrc:');
      Ctx.Err.WriteLn('  [settings]');
      Ctx.Err.WriteLn('  auto_install = true');
      Exit(EXIT_ERROR);
    end;
  end;

  if not Assigned(AActivateVersion) then
    Exit(EXIT_ERROR);

  ActivationResult := AActivateVersion(APlan.Version);
  if ActivationResult.Success then
  begin
    Ctx.Out.WriteLn('');
    Ctx.Out.WriteLn(_Fmt(CMD_FPC_USE_ACTIVATED, [APlan.Version]));
    Ctx.Out.WriteLn('');
    if ActivationResult.ActivationScript <> '' then
    begin
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_USE_SCRIPT_CREATED, [ActivationResult.ActivationScript]));
      Ctx.Out.WriteLn('');
      Ctx.Out.WriteLn(_(CMD_FPC_USE_SCRIPT_RUN));
      Ctx.Out.WriteLn('  ' + ActivationResult.ShellCommand);
    end;
    if ActivationResult.VSCodeSettings <> '' then
      Ctx.Out.WriteLn(_Fmt(CMD_FPC_USE_VSCODE_UPDATED, [ActivationResult.VSCodeSettings]));
    Exit(EXIT_OK);
  end;

  Ctx.Err.WriteLn(_(MSG_ERROR) + ': ' + ActivationResult.ErrorMessage);
end;

end.
