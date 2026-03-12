unit fpdev.package.lifecycle;

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.package.types,
  fpdev.package.fetch,
  fpdev.toolchain.fetcher;

type
  TPackageDeleteDirAction = function(const APath: string): Boolean;
  TPackageUninstallAction = function(const APackageName: string; Outp, Errp: IOutput): Boolean of object;
  TPackageInstallAction = function(
    const APackageName, AVersion: string;
    Outp, Errp: IOutput
  ): Boolean of object;
  TPackageNameValidator = function(const APackageName: string): Boolean of object;
  TPackageInstalledChecker = function(const APackageName: string): Boolean of object;
  TPackageInfoProvider = function(const APackageName: string): TPackageInfo of object;
  TPackageAvailableProvider = function: TPackageArray of object;
  TPackageDependencyInstallAction = function(
    const APackageInfo: TPackageInfo;
    Outp, Errp: IOutput
  ): Boolean of object;
  TPackageDownloadPlanBuilder = function(
    const APackageName, AVersion, ACacheDir: string;
    const AAvailablePackages: TPackageArray;
    out APlan: TPackageDownloadPlan
  ): Boolean of object;
  TPackageCachedDownloadAction = function(
    const AURLs: TStringArray;
    const DestFile: string;
    const Opt: TFetchOptions;
    out AErr: string
  ): Boolean of object;
  TPackageArchiveInstallAction = function(
    const APackageName, AVersion, AZipPath, ASandboxDir: string;
    AKeepArtifacts: Boolean;
    out ACleanupWarningPath: string;
    out AErr: string
  ): Boolean of object;

function UninstallPackageCore(
  const APackageName, AInstallPath: string;
  AIsInstalled: Boolean;
  ADeleteDirAction: TPackageDeleteDirAction;
  Outp, Errp: IOutput
): Boolean;

function UpdatePackageCore(
  const APackageName, AInstalledVersion: string;
  const AAvailablePackages: TPackageArray;
  AUninstallAction: TPackageUninstallAction;
  AInstallAction: TPackageInstallAction;
  Outp, Errp: IOutput
): Boolean;

function ExecutePackageDependencyInstallCore(
  const APackageInfo: TPackageInfo;
  const AAvailablePackages: TPackageArray;
  AInstallAction: TPackageInstallAction;
  Outp, Errp: IOutput
): Boolean;

function ExecutePackageManagerInstallCore(
  const APackageName, AVersion, ACacheDir, ASandboxDir: string;
  AKeepArtifacts: Boolean;
  AValidatePackage: TPackageNameValidator;
  AIsPackageInstalled: TPackageInstalledChecker;
  AGetAvailablePackages: TPackageAvailableProvider;
  ABuildDownloadPlan: TPackageDownloadPlanBuilder;
  AResolveDependencies: TPackageDependencyInstallAction;
  ADownloadCached: TPackageCachedDownloadAction;
  AInstallArchive: TPackageArchiveInstallAction;
  Outp, Errp: IOutput
): Boolean;

function ExecutePackageManagerUpdateCore(
  const APackageName: string;
  AValidatePackage: TPackageNameValidator;
  AIsPackageInstalled: TPackageInstalledChecker;
  AGetPackageInfo: TPackageInfoProvider;
  AGetAvailablePackages: TPackageAvailableProvider;
  AUninstallAction: TPackageUninstallAction;
  AInstallAction: TPackageInstallAction;
  Outp, Errp: IOutput
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.package.updateplan,
  fpdev.package.depgraph,
  fpdev.pkg.version;

const
  PACKAGE_MANAGER_UNKNOWN_VERSION = '0.0.0';

function UninstallPackageCore(
  const APackageName, AInstallPath: string;
  AIsInstalled: Boolean;
  ADeleteDirAction: TPackageDeleteDirAction;
  Outp, Errp: IOutput
): Boolean;
begin
  Result := False;

  if not AIsInstalled then
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_PKG_NOT_INSTALLED, [APackageName]));
    Exit(True);
  end;

  if Outp <> nil then
    Outp.WriteLn(_Fmt(MSG_PKG_UNINSTALLING, [APackageName]));

  if DirectoryExists(AInstallPath) then
  begin
    if Assigned(ADeleteDirAction) then
    begin
      if not ADeleteDirAction(AInstallPath) then
      begin
        if Errp <> nil then
          Errp.WriteLn(_Fmt(MSG_PKG_REMOVE_WARNING, [AInstallPath]));
      end;
    end
    else
      Exit(False);
  end;

  if Outp <> nil then
    Outp.WriteLn(_Fmt(MSG_PKG_UNINSTALL_COMPLETE, [APackageName]));
  Result := True;
end;

function UpdatePackageCore(
  const APackageName, AInstalledVersion: string;
  const AAvailablePackages: TPackageArray;
  AUninstallAction: TPackageUninstallAction;
  AInstallAction: TPackageInstallAction;
  Outp, Errp: IOutput
): Boolean;
var
  UpdatePlan: TPackageUpdatePlan;
begin
  Result := False;

  if not BuildPackageUpdatePlanCore(
    APackageName,
    AInstalledVersion,
    AAvailablePackages,
    UpdatePlan
  ) then
  begin
    if Errp <> nil then
    begin
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_IN_INDEX, [APackageName]));
      Errp.WriteLn(_(MSG_PKG_REPO_UPDATE_HINT));
    end;
    Exit(False);
  end;

  if Outp <> nil then
    Outp.WriteLn(_Fmt(MSG_PKG_LATEST_VERSION, [UpdatePlan.LatestVersion]));

  if not UpdatePlan.UpdateNeeded then
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_PKG_UP_TO_DATE, [APackageName]));
    Exit(True);
  end;

  if Outp <> nil then
  begin
    Outp.WriteLn(_Fmt(MSG_PKG_UPDATING, [
      APackageName,
      AInstalledVersion,
      UpdatePlan.LatestVersion
    ]));
    Outp.WriteLn(_(MSG_PKG_REMOVING_OLD));
  end;

  if (not Assigned(AUninstallAction)) or
     (not AUninstallAction(APackageName, nil, Errp)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_UNINSTALL_OLD_FAILED));
    Exit(False);
  end;

  if Outp <> nil then
    Outp.WriteLn(_(MSG_PKG_INSTALLING_NEW));

  if (not Assigned(AInstallAction)) or
     (not AInstallAction(APackageName, UpdatePlan.LatestVersion, nil, Errp)) then
  begin
    if Errp <> nil then
    begin
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_PKG_INSTALL_NEW_FAILED));
      Errp.WriteLn(_(MSG_PKG_REINSTALL_HINT));
    end;
    Exit(False);
  end;

  if Outp <> nil then
    Outp.WriteLn(_Fmt(MSG_PKG_UPDATE_SUCCESS, [APackageName, UpdatePlan.LatestVersion]));

  Result := True;
end;

function ExecutePackageDependencyInstallCore(
  const APackageInfo: TPackageInfo;
  const AAvailablePackages: TPackageArray;
  AInstallAction: TPackageInstallAction;
  Outp, Errp: IOutput
): Boolean;
var
  InstallPlan: TPackageInstallPlanItemArray;
  PlanStatus: TPackageInstallPlanBuildStatus;
  MissingDependency: string;
  ResolveError: string;
  I: Integer;
begin
  Result := False;

  if Length(APackageInfo.Dependencies) = 0 then
    Exit(True);

  if not Assigned(AInstallAction) then
    Exit(False);

  PlanStatus := BuildPackageDependencyInstallPlanCore(
    APackageInfo,
    AAvailablePackages,
    @ExtractPackageName,
    InstallPlan,
    MissingDependency,
    ResolveError
  );

  case PlanStatus of
    pipsMissingDependency:
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(MSG_PKG_DEP_NOT_FOUND, [MissingDependency]));
        Exit(False);
      end;
    pipsResolveError:
      begin
        if Errp <> nil then
          Errp.WriteLn(_(MSG_ERROR) + ': ' + ResolveError);
        Exit(False);
      end;
    pipsOk:
      ;
  end;

  for I := 0 to High(InstallPlan) do
  begin
    if InstallPlan[I].HasNestedDependencies and (Outp <> nil) then
      Outp.WriteLn(_Fmt(MSG_PKG_DEP_ADDING, [InstallPlan[I].Name]));
  end;

  if (Length(InstallPlan) > 0) and (Outp <> nil) then
    Outp.WriteLn(_(MSG_PKG_DEP_INSTALLING_ALL));

  for I := 0 to High(InstallPlan) do
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_PKG_DEP_INSTALLING_ONE, [InstallPlan[I].Name]));

    if not AInstallAction(InstallPlan[I].Name, InstallPlan[I].Version, Outp, Errp) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' +
          _Fmt(MSG_PKG_DEP_INSTALL_FAILED, [InstallPlan[I].Name]));
      Exit(False);
    end;
  end;

  Result := True;
end;

function ExecutePackageManagerInstallCore(
  const APackageName, AVersion, ACacheDir, ASandboxDir: string;
  AKeepArtifacts: Boolean;
  AValidatePackage: TPackageNameValidator;
  AIsPackageInstalled: TPackageInstalledChecker;
  AGetAvailablePackages: TPackageAvailableProvider;
  ABuildDownloadPlan: TPackageDownloadPlanBuilder;
  AResolveDependencies: TPackageDependencyInstallAction;
  ADownloadCached: TPackageCachedDownloadAction;
  AInstallArchive: TPackageArchiveInstallAction;
  Outp, Errp: IOutput
): Boolean;
var
  AvailablePackages: TPackageArray;
  Plan: TPackageDownloadPlan;
  CleanupWarningPath: string;
  Err: string;
begin
  Result := False;

  if (not Assigned(AValidatePackage)) or
     (not Assigned(AIsPackageInstalled)) or
     (not Assigned(AGetAvailablePackages)) or
     (not Assigned(ABuildDownloadPlan)) or
     (not Assigned(ADownloadCached)) or
     (not Assigned(AInstallArchive)) then
    Exit;

  if not AValidatePackage(APackageName) then
    Exit;

  if AIsPackageInstalled(APackageName) then
    Exit(True);

  AvailablePackages := AGetAvailablePackages();
  if not ABuildDownloadPlan(APackageName, AVersion, ACacheDir, AvailablePackages, Plan) then
    Exit;

  if Length(Plan.PackageInfo.Dependencies) > 0 then
  begin
    if Outp <> nil then
      Outp.WriteLn(_(MSG_PKG_DEP_RESOLVING));
    if (not Assigned(AResolveDependencies)) or
       (not AResolveDependencies(Plan.PackageInfo, Outp, Errp)) then
      Exit;
  end;

  if not ADownloadCached(Plan.URLs, Plan.ZipPath, Plan.FetchOptions, Err) then
    Exit;

  if not AInstallArchive(
    APackageName,
    Plan.PackageInfo.Version,
    Plan.ZipPath,
    ASandboxDir,
    AKeepArtifacts,
    CleanupWarningPath,
    Err
  ) then
    Exit;

  if (CleanupWarningPath <> '') and (Errp <> nil) then
    Errp.WriteLn(_(MSG_WARNING) + ': ' + _Fmt(MSG_PKG_CLEAN_TMP_FAILED, [CleanupWarningPath]));

  Result := True;
end;

function ExecutePackageManagerUpdateCore(
  const APackageName: string;
  AValidatePackage: TPackageNameValidator;
  AIsPackageInstalled: TPackageInstalledChecker;
  AGetPackageInfo: TPackageInfoProvider;
  AGetAvailablePackages: TPackageAvailableProvider;
  AUninstallAction: TPackageUninstallAction;
  AInstallAction: TPackageInstallAction;
  Outp, Errp: IOutput
): Boolean;
var
  InstalledInfo: TPackageInfo;
  AvailablePackages: TPackageArray;
  InstalledVersion: string;
begin
  Result := False;

  if (not Assigned(AValidatePackage)) or
     (not Assigned(AIsPackageInstalled)) or
     (not Assigned(AGetPackageInfo)) or
     (not Assigned(AGetAvailablePackages)) then
    Exit;

  if not AValidatePackage(APackageName) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_INVALID_NAME, [APackageName]));
    Exit;
  end;

  if not AIsPackageInstalled(APackageName) then
  begin
    if Errp <> nil then
    begin
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_PKG_NOT_INSTALLED, [APackageName]));
      Errp.WriteLn(_Fmt(MSG_PKG_INSTALL_HINT, [APackageName]));
    end;
    Exit;
  end;

  InstalledInfo := AGetPackageInfo(APackageName);
  InstalledVersion := InstalledInfo.Version;
  if InstalledVersion = '' then
    InstalledVersion := PACKAGE_MANAGER_UNKNOWN_VERSION;

  if Outp <> nil then
  begin
    Outp.WriteLn(_Fmt(MSG_PKG_CHECKING_UPDATES, [APackageName]));
    Outp.WriteLn(_Fmt(MSG_PKG_INSTALLED_VERSION, [InstalledVersion]));
  end;

  AvailablePackages := AGetAvailablePackages();
  Result := UpdatePackageCore(
    APackageName,
    InstalledVersion,
    AvailablePackages,
    AUninstallAction,
    AInstallAction,
    Outp,
    Errp
  );
end;

end.
