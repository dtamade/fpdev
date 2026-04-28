unit fpdev.package.lifecyclecommandflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.package.types;

type
  TPackageUpdateCommandPlan = record
    PackageName: string;
  end;

  TPackageUninstallCommandPlan = record
    PackageName: string;
  end;

  TPackageInstallLocalCommandPlan = record
    PackagePath: string;
  end;

  TPackageLifecycleCommandGetPackagesFunc = function: TPackageArray of object;
  TPackageLifecycleCommandPackageFunc = function(
    const APackageName: string;
    Outp: IOutput;
    Errp: IOutput
  ): Boolean of object;
  TPackageLifecycleCommandInstallLocalFunc = function(
    const APackagePath: string;
    Outp: IOutput;
    Errp: IOutput
  ): Boolean of object;

function PreparePackageUpdateCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageUpdateCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageUpdateCommandPlanCore(
  const APlan: TPackageUpdateCommandPlan;
  const AOut, AErr: IOutput;
  AGetInstalledPackages: TPackageLifecycleCommandGetPackagesFunc;
  AGetAvailablePackages: TPackageLifecycleCommandGetPackagesFunc;
  AUpdatePackage: TPackageLifecycleCommandPackageFunc
): Integer;

function PreparePackageUninstallCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageUninstallCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageUninstallCommandPlanCore(
  const APlan: TPackageUninstallCommandPlan;
  const AOut, AErr: IOutput;
  AGetInstalledPackages: TPackageLifecycleCommandGetPackagesFunc;
  AUninstallPackage: TPackageLifecycleCommandPackageFunc
): Integer;

function PreparePackageInstallLocalCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageInstallLocalCommandPlan;
  out AShouldExit: Boolean
): Integer;

function ExecutePackageInstallLocalCommandPlanCore(
  const APlan: TPackageInstallLocalCommandPlan;
  const AOut, AErr: IOutput;
  AInstallFromLocal: TPackageLifecycleCommandInstallLocalFunc
): Integer;

implementation

uses
  SysUtils,
  fpdev.command.utils,
  fpdev.exitcodes,
  fpdev.i18n,
  fpdev.i18n.strings;

type
  TPackageLifecycleCommandKind = (
    plckUpdate,
    plckUninstall,
    plckInstallLocal
  );

procedure WriteLifecycleUsage(
  const AOut: IOutput;
  const AKind: TPackageLifecycleCommandKind
);
begin
  if AOut = nil then
    Exit;

  case AKind of
    plckUpdate:
      AOut.WriteLn(_(HELP_PACKAGE_UPDATE_USAGE));
    plckUninstall:
      AOut.WriteLn(_(HELP_PACKAGE_UNINSTALL_USAGE));
    plckInstallLocal:
      AOut.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_USAGE));
  end;
end;

procedure WriteLifecycleHelp(
  const AOut: IOutput;
  const AKind: TPackageLifecycleCommandKind
);
begin
  if AOut = nil then
    Exit;

  case AKind of
    plckUpdate:
      begin
        AOut.WriteLn(_(HELP_PACKAGE_UPDATE_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PACKAGE_UPDATE_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PACKAGE_UPDATE_OPT_HELP));
      end;
    plckUninstall:
      begin
        AOut.WriteLn(_(HELP_PACKAGE_UNINSTALL_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PACKAGE_UNINSTALL_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PACKAGE_UNINSTALL_OPT_HELP));
      end;
    plckInstallLocal:
      begin
        AOut.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_USAGE));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_DESC));
        AOut.WriteLn('');
        AOut.WriteLn(_(HELP_PACKAGE_INSTALL_LOCAL_OPT_HELP));
      end;
  end;
end;

function PrepareSingleTargetPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  const AKind: TPackageLifecycleCommandKind;
  const AArgumentName: string;
  out ATarget: string;
  out AShouldExit: Boolean
): Integer;
var
  UnknownOption: string;
begin
  Result := EXIT_OK;
  ATarget := '';
  AShouldExit := False;

  if HasFlag(AParams, 'help') or HasFlag(AParams, 'h') then
  begin
    AShouldExit := True;
    WriteLifecycleHelp(AOut, AKind);
    Exit(EXIT_OK);
  end;

  if FindUnknownOption(AParams, [], UnknownOption) then
  begin
    AShouldExit := True;
    WriteLifecycleUsage(AErr, AKind);
    Exit(EXIT_USAGE_ERROR);
  end;

  if CountPositionalArgs(AParams) > 1 then
  begin
    AShouldExit := True;
    WriteLifecycleUsage(AErr, AKind);
    Exit(EXIT_USAGE_ERROR);
  end;

  ATarget := Trim(GetPositionalArg(AParams, 0));
  if ATarget = '' then
  begin
    AShouldExit := True;
    if AErr <> nil then
      AErr.WriteLn(_Fmt(ERR_MISSING_ARGUMENT, [AArgumentName]));
    WriteLifecycleUsage(AErr, AKind);
    Exit(EXIT_USAGE_ERROR);
  end;
end;

function PackageExists(
  const APackages: TPackageArray;
  const APackageName: string
): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(APackages) do
    if SameText(APackages[I].Name, APackageName) then
      Exit(True);
end;

function PreparePackageUpdateCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageUpdateCommandPlan;
  out AShouldExit: Boolean
): Integer;
begin
  APlan := Default(TPackageUpdateCommandPlan);
  Result := PrepareSingleTargetPlanCore(
    AParams,
    AOut,
    AErr,
    plckUpdate,
    'package',
    APlan.PackageName,
    AShouldExit
  );
end;

function ExecutePackageUpdateCommandPlanCore(
  const APlan: TPackageUpdateCommandPlan;
  const AOut, AErr: IOutput;
  AGetInstalledPackages: TPackageLifecycleCommandGetPackagesFunc;
  AGetAvailablePackages: TPackageLifecycleCommandGetPackagesFunc;
  AUpdatePackage: TPackageLifecycleCommandPackageFunc
): Integer;
var
  InstalledPackages: TPackageArray;
  AvailablePackages: TPackageArray;
begin
  Result := EXIT_ERROR;

  if (not Assigned(AGetInstalledPackages)) or
     (not Assigned(AGetAvailablePackages)) or
     (not Assigned(AUpdatePackage)) then
    Exit(EXIT_ERROR);

  InstalledPackages := AGetInstalledPackages();
  if not PackageExists(InstalledPackages, APlan.PackageName) then
  begin
    if AErr <> nil then
    begin
      AErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_INSTALLED, [APlan.PackageName]));
      AErr.WriteLn(_Fmt(MSG_PKG_INSTALL_HINT, [APlan.PackageName]));
    end;
    Exit(EXIT_NOT_FOUND);
  end;

  AvailablePackages := AGetAvailablePackages();
  if not PackageExists(AvailablePackages, APlan.PackageName) then
  begin
    if AErr <> nil then
    begin
      AErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_IN_INDEX, [APlan.PackageName]));
      AErr.WriteLn(_(MSG_PKG_REPO_UPDATE_HINT));
    end;
    Exit(EXIT_NOT_FOUND);
  end;

  if AUpdatePackage(APlan.PackageName, AOut, AErr) then
    Exit(EXIT_OK);
end;

function PreparePackageUninstallCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageUninstallCommandPlan;
  out AShouldExit: Boolean
): Integer;
begin
  APlan := Default(TPackageUninstallCommandPlan);
  Result := PrepareSingleTargetPlanCore(
    AParams,
    AOut,
    AErr,
    plckUninstall,
    'package',
    APlan.PackageName,
    AShouldExit
  );
end;

function ExecutePackageUninstallCommandPlanCore(
  const APlan: TPackageUninstallCommandPlan;
  const AOut, AErr: IOutput;
  AGetInstalledPackages: TPackageLifecycleCommandGetPackagesFunc;
  AUninstallPackage: TPackageLifecycleCommandPackageFunc
): Integer;
var
  InstalledPackages: TPackageArray;
begin
  Result := EXIT_ERROR;

  if (not Assigned(AGetInstalledPackages)) or
     (not Assigned(AUninstallPackage)) then
    Exit(EXIT_ERROR);

  InstalledPackages := AGetInstalledPackages();
  if not PackageExists(InstalledPackages, APlan.PackageName) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_INSTALLED, [APlan.PackageName]));
    Exit(EXIT_NOT_FOUND);
  end;

  if AUninstallPackage(APlan.PackageName, AOut, AErr) then
    Exit(EXIT_OK);
end;

function PreparePackageInstallLocalCommandPlanCore(
  const AParams: array of string;
  const AOut, AErr: IOutput;
  out APlan: TPackageInstallLocalCommandPlan;
  out AShouldExit: Boolean
): Integer;
begin
  APlan := Default(TPackageInstallLocalCommandPlan);
  Result := PrepareSingleTargetPlanCore(
    AParams,
    AOut,
    AErr,
    plckInstallLocal,
    'path',
    APlan.PackagePath,
    AShouldExit
  );
end;

function ExecutePackageInstallLocalCommandPlanCore(
  const APlan: TPackageInstallLocalCommandPlan;
  const AOut, AErr: IOutput;
  AInstallFromLocal: TPackageLifecycleCommandInstallLocalFunc
): Integer;
begin
  Result := EXIT_ERROR;

  if not DirectoryExists(APlan.PackagePath) then
  begin
    if AErr <> nil then
      AErr.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_PATH_NOT_FOUND, [APlan.PackagePath]));
    Exit(EXIT_NOT_FOUND);
  end;

  if not Assigned(AInstallFromLocal) then
    Exit(EXIT_ERROR);

  if AInstallFromLocal(APlan.PackagePath, AOut, AErr) then
    Exit(EXIT_OK);
end;

end.
