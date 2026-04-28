unit fpdev.fpc.sourceinstallflow;

{$mode objfpc}{$H+}

interface

type
  TFPCSourceInstallSetStepProc = procedure(AStep: Integer) of object;
  TFPCSourceInstallReportStepFunc = function(AStep: Integer; const AMessage: string): Boolean of object;
  TFPCSourceInstallVersionFunc = function(const AVersion: string): Boolean of object;

  TFPCSourceInstallState = record
    Version: string;
    PreviousVersion: string;
    UseCache: Boolean;
  end;

  TFPCSourceInstallCallbacks = record
    SetCurrentStep: TFPCSourceInstallSetStepProc;
    ReportStep: TFPCSourceInstallReportStepFunc;
    InitializeInstall: TFPCSourceInstallVersionFunc;
    EnsureBootstrap: TFPCSourceInstallVersionFunc;
    CloneSource: TFPCSourceInstallVersionFunc;
    IsCacheAvailable: TFPCSourceInstallVersionFunc;
    UseCachedBuild: TFPCSourceInstallVersionFunc;
    BuildCompiler: TFPCSourceInstallVersionFunc;
    BuildRTL: TFPCSourceInstallVersionFunc;
    BuildPackages: TFPCSourceInstallVersionFunc;
    InstallBinaries: TFPCSourceInstallVersionFunc;
    ConfigureEnvironment: TFPCSourceInstallVersionFunc;
    TestBuildResults: TFPCSourceInstallVersionFunc;
    WriteCacheMarker: TFPCSourceInstallVersionFunc;
  end;

function ExecuteFPCSourceInstallFlowCore(
  const AState: TFPCSourceInstallState;
  var ACurrentVersion: string;
  const ACallbacks: TFPCSourceInstallCallbacks
): Boolean;

implementation

const
  FPC_SOURCE_STEP_INIT = 0;
  FPC_SOURCE_STEP_BOOTSTRAP = 1;
  FPC_SOURCE_STEP_CLONE = 2;
  FPC_SOURCE_STEP_COMPILER = 3;
  FPC_SOURCE_STEP_RTL = 4;
  FPC_SOURCE_STEP_PACKAGES = 5;
  FPC_SOURCE_STEP_INSTALL = 6;
  FPC_SOURCE_STEP_CONFIG = 7;
  FPC_SOURCE_STEP_FINISHED = 8;

procedure SetStep(const ACallbacks: TFPCSourceInstallCallbacks; AStep: Integer);
begin
  if Assigned(ACallbacks.SetCurrentStep) then
    ACallbacks.SetCurrentStep(AStep);
end;

function ReportStep(
  const ACallbacks: TFPCSourceInstallCallbacks;
  AStep: Integer;
  const AMessage: string
): Boolean;
begin
  if Assigned(ACallbacks.ReportStep) then
    Exit(ACallbacks.ReportStep(AStep, AMessage));
  Result := True;
end;

function RunVersionStep(
  const ACallback: TFPCSourceInstallVersionFunc;
  const AVersion: string
): Boolean;
begin
  if Assigned(ACallback) then
    Exit(ACallback(AVersion));
  Result := True;
end;

function ExecuteFPCSourceInstallFlowCore(
  const AState: TFPCSourceInstallState;
  var ACurrentVersion: string;
  const ACallbacks: TFPCSourceInstallCallbacks
): Boolean;
var
  Version: string;

  function Rollback: Boolean;
  begin
    ACurrentVersion := AState.PreviousVersion;
    Result := False;
  end;

  function CompleteInstallAndValidation: Boolean;
  begin
    SetStep(ACallbacks, FPC_SOURCE_STEP_INSTALL);
    if not ReportStep(ACallbacks, FPC_SOURCE_STEP_INSTALL, 'Install FPC binaries') then
      Exit(False);
    if not RunVersionStep(ACallbacks.InstallBinaries, Version) then
      Exit(False);

    SetStep(ACallbacks, FPC_SOURCE_STEP_CONFIG);
    if not ReportStep(ACallbacks, FPC_SOURCE_STEP_CONFIG, 'Configure FPC environment') then
      Exit(False);
    if not RunVersionStep(ACallbacks.ConfigureEnvironment, Version) then
      Exit(False);

    if not ReportStep(ACallbacks, FPC_SOURCE_STEP_CONFIG, 'Test build results') then
      Exit(False);
    Result := RunVersionStep(ACallbacks.TestBuildResults, Version);
  end;

begin
  Result := False;
  Version := AState.Version;
  if Version = '' then
    Version := ACurrentVersion;
  if Version = '' then
    Version := 'main';

  SetStep(ACallbacks, FPC_SOURCE_STEP_INIT);
  if not ReportStep(ACallbacks, FPC_SOURCE_STEP_INIT, 'Initialize build environment') then
    Exit(False);
  if not RunVersionStep(ACallbacks.InitializeInstall, Version) then
    Exit(Rollback);

  SetStep(ACallbacks, FPC_SOURCE_STEP_BOOTSTRAP);
  if not ReportStep(ACallbacks, FPC_SOURCE_STEP_BOOTSTRAP, 'Check Bootstrap Compiler') then
    Exit(False);
  if not RunVersionStep(ACallbacks.EnsureBootstrap, Version) then
    Exit(Rollback);

  SetStep(ACallbacks, FPC_SOURCE_STEP_CLONE);
  if not ReportStep(ACallbacks, FPC_SOURCE_STEP_CLONE, 'Clone FPC sources') then
    Exit(False);
  if not RunVersionStep(ACallbacks.CloneSource, Version) then
    Exit(Rollback);
  ACurrentVersion := Version;

  if AState.UseCache and RunVersionStep(ACallbacks.IsCacheAvailable, Version) then
  begin
    if RunVersionStep(ACallbacks.UseCachedBuild, Version) then
    begin
      if not CompleteInstallAndValidation then
        Exit(Rollback);

      SetStep(ACallbacks, FPC_SOURCE_STEP_FINISHED);
      ReportStep(ACallbacks, FPC_SOURCE_STEP_FINISHED, 'FPC build/test completed');
      Exit(True);
    end;
  end;

  SetStep(ACallbacks, FPC_SOURCE_STEP_COMPILER);
  if not ReportStep(ACallbacks, FPC_SOURCE_STEP_COMPILER, 'Build FPC Compiler') then
    Exit(False);
  if not RunVersionStep(ACallbacks.BuildCompiler, Version) then
    Exit(Rollback);

  SetStep(ACallbacks, FPC_SOURCE_STEP_RTL);
  if not ReportStep(ACallbacks, FPC_SOURCE_STEP_RTL, 'Build FPC RTL') then
    Exit(False);
  if not RunVersionStep(ACallbacks.BuildRTL, Version) then
    Exit(Rollback);

  SetStep(ACallbacks, FPC_SOURCE_STEP_PACKAGES);
  if not ReportStep(ACallbacks, FPC_SOURCE_STEP_PACKAGES, 'Build FPC packages') then
    Exit(False);
  if not RunVersionStep(ACallbacks.BuildPackages, Version) then
    Exit(Rollback);

  if not CompleteInstallAndValidation then
    Exit(Rollback);

  if not RunVersionStep(ACallbacks.WriteCacheMarker, Version) then
    Exit(Rollback);

  SetStep(ACallbacks, FPC_SOURCE_STEP_FINISHED);
  ReportStep(ACallbacks, FPC_SOURCE_STEP_FINISHED, 'FPC build/test completed');
  ACurrentVersion := Version;
  Result := True;
end;

end.
