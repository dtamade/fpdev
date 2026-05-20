unit fpdev.package.installcommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.package.types;

type
  TPackageInstallCommandPlan = record
    PackageName: string;
    Version: string;
    KeepBuildArtifacts: Boolean;
    NoDeps: Boolean;
    DryRun: Boolean;
    OfflineMode: Boolean;
  end;

  TPackageInstallCommandSetKeepArtifactsProc = procedure(const AValue: Boolean) of object;
  TPackageInstallCommandSetOfflineModeProc = procedure(const AValue: Boolean) of object;
  TPackageInstallCommandGetAvailablePackagesFunc = function: TPackageArray of object;
  TPackageInstallCommandInstallFunc = function(
    const APackageName: string;
    const AVersion: string;
    Outp: IOutput;
    Errp: IOutput
  ): Boolean of object;

function PreparePackageInstallCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageInstallCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageInstallCommandPlanCore(
  const APlan: TPackageInstallCommandPlan;
  const AOut, AErr: IOutput;
  ASetKeepArtifacts: TPackageInstallCommandSetKeepArtifactsProc;
  ASetOfflineMode: TPackageInstallCommandSetOfflineModeProc;
  AGetAvailablePackages: TPackageInstallCommandGetAvailablePackagesFunc;
  AInstallPackage: TPackageInstallCommandInstallFunc
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
    AOut.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
end;

procedure WriteInstallHelp(const AOut: IOutput);
begin
  if AOut = nil then
    Exit;

  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_USAGE));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_DESC));
  AOut.WriteLn('');
  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_OPTIONS));
  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_VERSION));
  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_KEEP));
  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_NODEPS));
  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_DRYRUN));
  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_OFFLINE));
  AOut.WriteLn(_(HELP_PACKAGE_INSTALL_OPT_HELP));
end;

function PreparePackageInstallCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageInstallCommandPlan;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
  PositionalCount: Integer;
begin
  Result := EXIT_OK;
  APlan := Default(TPackageInstallCommandPlan);
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteInstallHelp(AOut);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(
    AParams,
    ['--keep-build-artifacts', '--no-deps', '--dry-run', '--offline'],
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
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    WriteInstallUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount > 2 then
  begin
    AShouldExit := True;
    WriteInstallUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  APlan.PackageName := GetPositionalArg(AParams, 0);
  if Trim(APlan.PackageName) = '' then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, ['package']));
    WriteInstallUsage(AErr);
    Exit(EXIT_USAGE_ERROR);
  end;

  if PositionalCount >= 2 then
    APlan.Version := GetPositionalArg(AParams, 1)
  else
    APlan.Version := '';

  APlan.KeepBuildArtifacts := HasFlag(AParams, 'keep-build-artifacts');
  APlan.NoDeps := HasFlag(AParams, 'no-deps');
  APlan.DryRun := HasFlag(AParams, 'dry-run');
  APlan.OfflineMode := HasFlag(AParams, 'offline');
end;

function ExecutePackageInstallCommandPlanCore(
  const APlan: TPackageInstallCommandPlan;
  const AOut, AErr: IOutput;
  ASetKeepArtifacts: TPackageInstallCommandSetKeepArtifactsProc;
  ASetOfflineMode: TPackageInstallCommandSetOfflineModeProc;
  AGetAvailablePackages: TPackageInstallCommandGetAvailablePackagesFunc;
  AInstallPackage: TPackageInstallCommandInstallFunc
): Integer;
var
  AvailablePackages: TPackageArray;
  I: Integer;
  HasPackage: Boolean;
  HasVersion: Boolean;
begin
  Result := EXIT_ERROR;

  if APlan.KeepBuildArtifacts and Assigned(ASetKeepArtifacts) then
    ASetKeepArtifacts(True);

  if APlan.OfflineMode and Assigned(ASetOfflineMode) then
    ASetOfflineMode(True);

  if APlan.DryRun then
  begin
    if AOut <> nil then
    begin
      AOut.WriteLn('');
      AOut.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_HEADER));
      AOut.WriteLn('');
      AOut.WriteLn(_Fmt(CMD_PKG_INSTALL_DRYRUN_PACKAGE, [APlan.PackageName]));
      if APlan.Version <> '' then
        AOut.WriteLn(_Fmt(CMD_PKG_INSTALL_DRYRUN_VERSION, [APlan.Version]))
      else
        AOut.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_VERSION_LATEST));

      if APlan.NoDeps then
        AOut.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_DEPS_SKIPPED))
      else
        AOut.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_DEPS_RESOLVED));

      AOut.WriteLn('');
      AOut.WriteLn(_(CMD_PKG_INSTALL_DRYRUN_NO_CHANGES));
    end;
    Exit(EXIT_OK);
  end;

  if APlan.NoDeps and (AOut <> nil) then
  begin
    AOut.WriteLn('');
    AOut.WriteLn(_(CMD_PKG_INSTALL_NODEPS_WARN1));
    AOut.WriteLn(_(CMD_PKG_INSTALL_NODEPS_WARN2));
    AOut.WriteLn(_(CMD_PKG_INSTALL_NODEPS_WARN3));
    AOut.WriteLn('');
  end;

  if (not Assigned(AGetAvailablePackages)) or (not Assigned(AInstallPackage)) then
    Exit(EXIT_ERROR);

  AvailablePackages := AGetAvailablePackages();
  HasPackage := False;
  HasVersion := False;
  for I := 0 to High(AvailablePackages) do
  begin
    if SameText(AvailablePackages[I].Name, APlan.PackageName) then
    begin
      HasPackage := True;
      if (APlan.Version = '') or SameText(AvailablePackages[I].Version, APlan.Version) then
      begin
        HasVersion := True;
        Break;
      end;
    end;
  end;

  if (not HasPackage) or ((APlan.Version <> '') and (not HasVersion)) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_IN_INDEX, [APlan.PackageName]));
    Exit(EXIT_NOT_FOUND);
  end;

  if AInstallPackage(APlan.PackageName, APlan.Version, AOut, AErr) then
    Exit(EXIT_OK);
end;

end.
