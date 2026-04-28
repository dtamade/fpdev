unit fpdev.lazarus.maintenanceflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.config.interfaces,
  fpdev.lazarus.commandflow;

type
  TLazarusMaintenanceCurrentVersionFunc = function: string of object;
  TLazarusMaintenanceInstallPathFunc = function(const AVersion: string): string of object;
  TLazarusMaintenanceInstalledFunc = function(const AVersion: string): Boolean of object;
  TLazarusMaintenanceConfiguredLookupFunc = function(
    const AVersion: string;
    out ALazarusInfo: TLazarusInfo
  ): Boolean of object;
  TLazarusMaintenanceDeleteDirProc = procedure(const APath: string) of object;
  TLazarusMaintenanceRemoveVersionProc = procedure(const AVersion: string) of object;
  TLazarusMaintenanceSourceValidator = function(const ASourceDir: string): Boolean of object;
  TLazarusMaintenanceGitFactory = function(const ACliOnly: Boolean): ILazarusGitRuntime of object;

function ExecuteManagedLazarusUninstallCore(
  const AVersion: string;
  AIsVersionInstalled: TLazarusMaintenanceInstalledFunc;
  AGetResolvedInstallPath: TLazarusMaintenanceInstallPathFunc;
  ALookupConfiguredLazarusInfo: TLazarusMaintenanceConfiguredLookupFunc;
  ADeleteDir: TLazarusMaintenanceDeleteDirProc;
  ARemoveConfiguredVersion: TLazarusMaintenanceRemoveVersionProc
): Boolean;

function ExecuteManagedLazarusUpdateSourcesCore(
  const AVersion, AInstallRoot: string;
  const Outp, Errp: IOutput;
  AGetCurrentVersion: TLazarusMaintenanceCurrentVersionFunc;
  AIsValidSourceDirectory: TLazarusMaintenanceSourceValidator;
  ACreateGitRuntime: TLazarusMaintenanceGitFactory
): Boolean;

function ExecuteManagedLazarusCleanSourcesCore(
  const AVersion, AInstallRoot: string;
  const Outp: IOutput;
  AGetCurrentVersion: TLazarusMaintenanceCurrentVersionFunc;
  AIsValidSourceDirectory: TLazarusMaintenanceSourceValidator;
  ACleanSource: TLazarusSourceCleaner
): Boolean;

implementation

uses
  SysUtils,
  fpdev.i18n,
  fpdev.i18n.strings;

function ResolveManagedLazarusMaintenanceVersionCore(
  const ARequestedVersion: string;
  AGetCurrentVersion: TLazarusMaintenanceCurrentVersionFunc
): string;
begin
  Result := ARequestedVersion;
  if (Result = '') and Assigned(AGetCurrentVersion) then
    Result := AGetCurrentVersion();
end;

function ExecuteManagedLazarusUninstallCore(
  const AVersion: string;
  AIsVersionInstalled: TLazarusMaintenanceInstalledFunc;
  AGetResolvedInstallPath: TLazarusMaintenanceInstallPathFunc;
  ALookupConfiguredLazarusInfo: TLazarusMaintenanceConfiguredLookupFunc;
  ADeleteDir: TLazarusMaintenanceDeleteDirProc;
  ARemoveConfiguredVersion: TLazarusMaintenanceRemoveVersionProc
): Boolean;
var
  InstallPath: string;
  LazarusInfo: TLazarusInfo;
  HasMetadata: Boolean;
begin
  InstallPath := '';
  if Assigned(AGetResolvedInstallPath) then
    InstallPath := AGetResolvedInstallPath(AVersion);

  LazarusInfo := Default(TLazarusInfo);
  HasMetadata := Assigned(ALookupConfiguredLazarusInfo) and
    ALookupConfiguredLazarusInfo(AVersion, LazarusInfo);

  if (Assigned(AIsVersionInstalled) and (not AIsVersionInstalled(AVersion))) and
     (not DirectoryExists(InstallPath)) and
     (not HasMetadata) then
    Exit(True);

  if (InstallPath <> '') and DirectoryExists(InstallPath) and Assigned(ADeleteDir) then
    ADeleteDir(InstallPath);

  if Assigned(ARemoveConfiguredVersion) then
    ARemoveConfiguredVersion(AVersion);

  Result := True;
end;

function ExecuteManagedLazarusUpdateSourcesCore(
  const AVersion, AInstallRoot: string;
  const Outp, Errp: IOutput;
  AGetCurrentVersion: TLazarusMaintenanceCurrentVersionFunc;
  AIsValidSourceDirectory: TLazarusMaintenanceSourceValidator;
  ACreateGitRuntime: TLazarusMaintenanceGitFactory
): Boolean;
var
  SourcePlan: TLazarusSourcePlan;
  Git: ILazarusGitRuntime;
begin
  Result := False;
  SourcePlan := CreateLazarusSourcePlanCore(
    AInstallRoot,
    AVersion,
    ResolveManagedLazarusMaintenanceVersionCore(AVersion, AGetCurrentVersion)
  );

  if (SourcePlan.Version = '') or (not DirectoryExists(SourcePlan.SourceDir)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_SOURCE_DIR_NOT_FOUND, [SourcePlan.SourceDir]));
    Exit;
  end;

  if Assigned(AIsValidSourceDirectory) and (not AIsValidSourceDirectory(SourcePlan.SourceDir)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_LAZARUS_INVALID_SOURCE_DIR, [SourcePlan.SourceDir]));
    Exit;
  end;

  Git := nil;
  if Assigned(ACreateGitRuntime) then
    Git := ACreateGitRuntime(False);

  Result := ExecuteLazarusUpdatePlanCore(SourcePlan, Outp, Errp, Git);
end;

function ExecuteManagedLazarusCleanSourcesCore(
  const AVersion, AInstallRoot: string;
  const Outp: IOutput;
  AGetCurrentVersion: TLazarusMaintenanceCurrentVersionFunc;
  AIsValidSourceDirectory: TLazarusMaintenanceSourceValidator;
  ACleanSource: TLazarusSourceCleaner
): Boolean;
var
  SourcePlan: TLazarusSourcePlan;
begin
  SourcePlan := CreateLazarusSourcePlanCore(
    AInstallRoot,
    AVersion,
    ResolveManagedLazarusMaintenanceVersionCore(AVersion, AGetCurrentVersion)
  );

  if (SourcePlan.Version = '') or (not DirectoryExists(SourcePlan.SourceDir)) then
    Exit(False);
  if Assigned(AIsValidSourceDirectory) and (not AIsValidSourceDirectory(SourcePlan.SourceDir)) then
    Exit(False);

  Result := ExecuteLazarusCleanPlanCore(SourcePlan, Outp, ACleanSource);
end;

end.
