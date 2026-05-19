unit fpdev.package.cleancommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TPackageCleanCommandPlan = record
    Scope: string;
    DryRun: Boolean;
    Yes: Boolean;
  end;

  TPackageCleanCommandCleanFunc = function(
    const Scope: string;
    Outp: IOutput;
    Errp: IOutput
  ): Boolean of object;

function PreparePackageCleanCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageCleanCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageCleanCommandPlanCore(
  const APlan: TPackageCleanCommandPlan;
  const AOut, AErr: IOutput;
  const ASandboxDir, APackageCacheDir: string;
  ACleanPackages: TPackageCleanCommandCleanFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteCleanHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_CLEAN_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_CLEAN_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_CLEAN_OPTIONS));
  AOut.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_DRYRUN));
  AOut.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_YES));
  AOut.WriteLn(_(HELP_PACKAGE_CLEAN_OPT_HELP));
end;

procedure WriteCleanShortUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(CMD_PKG_CLEAN_USAGE));
end;

procedure WriteCleanHelpUsage(const AOut: IOutput);
begin
  if AOut <> nil then
    AOut.WriteLn(_(HELP_PACKAGE_CLEAN_USAGE));
end;

function PreparePackageCleanCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageCleanCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  I: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageCleanCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteCleanHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, ['--dry-run', '--yes'], UnknownOption) then
  begin
    AShouldExit := True;
    WriteCleanShortUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if Length(AParams) < 1 then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['scope']));
    WriteCleanHelpUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.Scope := LowerCase(Trim(AParams[0]));
  if (APlan.Scope <> 'sandbox') and
     (APlan.Scope <> 'cache') and
     (APlan.Scope <> 'all') then
  begin
    AShouldExit := True;
    WriteCleanShortUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  for I := 1 to High(AParams) do
    if (AParams[I] <> '') and (AParams[I][1] <> '-') then
    begin
      AShouldExit := True;
      WriteCleanShortUsage(AErr);
      Exit(EXIT_USAGE_ERROR);
    end;

  APlan.DryRun := HasFlag(AParams, 'dry-run');
  APlan.Yes := HasFlag(AParams, 'yes');
end;

function ExecutePackageCleanCommandPlanCore(
  const APlan: TPackageCleanCommandPlan;
  const AOut, AErr: IOutput;
  const ASandboxDir, APackageCacheDir: string;
  ACleanPackages: TPackageCleanCommandCleanFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if APlan.DryRun then
  begin
    if (APlan.Scope = 'sandbox') or (APlan.Scope = 'all') then
      if AOut <> nil then
        AOut.WriteLn(_Fmt(CMD_PKG_CLEAN_DRY_RUN, [ASandboxDir]));
    if (APlan.Scope = 'cache') or (APlan.Scope = 'all') then
      if AOut <> nil then
        AOut.WriteLn(_Fmt(CMD_PKG_CLEAN_DRY_RUN, [APackageCacheDir]));
    Exit(EXIT_OK);
  end;

  if not APlan.Yes then
  begin
    if AOut <> nil then
    begin
      if (APlan.Scope = 'sandbox') or (APlan.Scope = 'all') then
        AOut.WriteLn('Will clean: ' + ASandboxDir);
      if (APlan.Scope = 'cache') or (APlan.Scope = 'all') then
        AOut.WriteLn('Will clean: ' + APackageCacheDir);
      AOut.WriteLn('');
      AOut.WriteLn('Add --yes to confirm, or --dry-run to preview.');
    end;
    Exit(EXIT_USAGE_ERROR);
  end;

  if not Assigned(ACleanPackages) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(CMD_PKG_CLEAN_ERRORS));
    Exit(EXIT_ERROR);
  end;

  if ACleanPackages(APlan.Scope, AOut, AErr) then
  begin
    if AOut <> nil then
      AOut.WriteLn(_(CMD_PKG_CLEAN_COMPLETE));
    Exit(EXIT_OK);
  end;

  if AErr <> nil then
    AErr.WriteLn(_(CMD_PKG_CLEAN_ERRORS));
end;

end.
