unit fpdev.fpc.maintenanceflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf,
  fpdev.fpc.runtimeflow;

type
  TFPCMaintenanceCurrentVersionFunc = function: string of object;
  TFPCMaintenanceGetInstallPathFunc = function(const AVersion: string): string of object;
  TFPCMaintenanceIsVersionInstalledFunc = function(const AVersion: string): Boolean of object;
  TFPCMaintenanceDeleteDirProc = procedure(const APath: string) of object;
  TFPCMaintenanceRemoveToolchainProc = procedure(const AName: string) of object;
  TFPCMaintenanceGitRuntimeFactory = function: IFPCGitRuntime of object;

function ExecuteManagedFPCUninstallCore(
  const AVersion: string;
  AIsVersionInstalled: TFPCMaintenanceIsVersionInstalledFunc;
  AGetInstallPath: TFPCMaintenanceGetInstallPathFunc;
  ADeleteDir: TFPCMaintenanceDeleteDirProc;
  ARemoveToolchain: TFPCMaintenanceRemoveToolchainProc
): Boolean;

function ExecuteManagedFPCUpdateSourcesCore(
  const AVersion, AInstallRoot: string;
  const Outp, Errp: IOutput;
  AGetCurrentVersion: TFPCMaintenanceCurrentVersionFunc;
  ADirectoryExists: TFPCPathExistsFunc;
  ACreateGitRuntime: TFPCMaintenanceGitRuntimeFactory
): Boolean;

function ExecuteManagedFPCCleanSourcesCore(
  const AVersion, AInstallRoot: string;
  const Outp, Errp: IOutput;
  AGetCurrentVersion: TFPCMaintenanceCurrentVersionFunc;
  ADirectoryExists: TFPCPathExistsFunc;
  ACleanSource: TFPCSourceCleaner
): Boolean;

implementation

uses
  SysUtils;

function ResolveManagedFPCMaintenanceVersionCore(
  const ARequestedVersion: string;
  AGetCurrentVersion: TFPCMaintenanceCurrentVersionFunc
): string;
begin
  Result := ARequestedVersion;
  if (Result = '') and Assigned(AGetCurrentVersion) then
    Result := AGetCurrentVersion();
end;

function ExecuteManagedFPCUninstallCore(
  const AVersion: string;
  AIsVersionInstalled: TFPCMaintenanceIsVersionInstalledFunc;
  AGetInstallPath: TFPCMaintenanceGetInstallPathFunc;
  ADeleteDir: TFPCMaintenanceDeleteDirProc;
  ARemoveToolchain: TFPCMaintenanceRemoveToolchainProc
): Boolean;
var
  InstallPath: string;
begin
  if Assigned(AIsVersionInstalled) and (not AIsVersionInstalled(AVersion)) then
    Exit(True);

  InstallPath := '';
  if Assigned(AGetInstallPath) then
    InstallPath := AGetInstallPath(AVersion);

  if (InstallPath <> '') and DirectoryExists(InstallPath) and Assigned(ADeleteDir) then
    ADeleteDir(InstallPath);

  if Assigned(ARemoveToolchain) then
    ARemoveToolchain('fpc-' + AVersion);

  Result := True;
end;

function ExecuteManagedFPCUpdateSourcesCore(
  const AVersion, AInstallRoot: string;
  const Outp, Errp: IOutput;
  AGetCurrentVersion: TFPCMaintenanceCurrentVersionFunc;
  ADirectoryExists: TFPCPathExistsFunc;
  ACreateGitRuntime: TFPCMaintenanceGitRuntimeFactory
): Boolean;
var
  Plan: TFPCSourcePlan;
  GitRuntime: IFPCGitRuntime;
begin
  Plan := CreateFPCSourcePlanCore(
    AInstallRoot,
    ResolveManagedFPCMaintenanceVersionCore(AVersion, AGetCurrentVersion)
  );

  GitRuntime := nil;
  if Assigned(ACreateGitRuntime) then
    GitRuntime := ACreateGitRuntime();

  Result := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, ADirectoryExists, GitRuntime);
end;

function ExecuteManagedFPCCleanSourcesCore(
  const AVersion, AInstallRoot: string;
  const Outp, Errp: IOutput;
  AGetCurrentVersion: TFPCMaintenanceCurrentVersionFunc;
  ADirectoryExists: TFPCPathExistsFunc;
  ACleanSource: TFPCSourceCleaner
): Boolean;
var
  Plan: TFPCSourcePlan;
begin
  Plan := CreateFPCSourcePlanCore(
    AInstallRoot,
    ResolveManagedFPCMaintenanceVersionCore(AVersion, AGetCurrentVersion)
  );

  Result := ExecuteFPCCleanPlanCore(Plan, Outp, Errp, ADirectoryExists, ACleanSource);
end;

end.
