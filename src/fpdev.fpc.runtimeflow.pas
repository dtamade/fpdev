unit fpdev.fpc.runtimeflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.config.interfaces,
  fpdev.utils.process;

type
  TFPCSourcePlan = record
    Version: string;
    SourceDir: string;
  end;

  IFPCGitRuntime = interface
    ['{D6144850-05B4-47A9-B292-690E7B11D2E8}']
    function BackendAvailable: Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function GetLastError: string;
  end;

  TFPCPathExistsFunc = function(const APath: string): Boolean of object;
  TFPCSourceCleaner = function(const ASourceDir: string): Integer of object;
  TFPCVersionValidator = function(const AVersion: string): Boolean of object;
  TFPCVersionInstalledChecker = function(const AVersion: string): Boolean of object;
  TFPCInstallPathResolver = function(const AVersion: string): string of object;
  TFPCToolchainInfoLookup = function(const AVersion: string; out AInfo: TToolchainInfo): Boolean of object;
  TFPCVersionInfoWriter = procedure(const AOut: IOutput; const AInfo: TToolchainInfo);
  TFPCExecutableInfoRunner = function(const AExecutable: string): TProcessResult of object;

function CreateFPCSourcePlanCore(
  const AInstallRoot, ARequestedVersion: string
): TFPCSourcePlan;

function ExecuteFPCUpdatePlanCore(
  const APlan: TFPCSourcePlan;
  const Outp, Errp: IOutput;
  ADirectoryExists: TFPCPathExistsFunc;
  const AGit: IFPCGitRuntime
): Boolean;

function ExecuteFPCCleanPlanCore(
  const APlan: TFPCSourcePlan;
  const Outp, Errp: IOutput;
  ADirectoryExists: TFPCPathExistsFunc;
  ACleanSource: TFPCSourceCleaner
): Boolean;

function ExecuteFPCShowVersionInfoCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AValidateVersion: TFPCVersionValidator;
  AIsInstalled: TFPCVersionInstalledChecker;
  AGetInstallPath: TFPCInstallPathResolver;
  AGetToolchainInfo: TFPCToolchainInfoLookup
): Boolean; overload;

function ExecuteFPCShowVersionInfoCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AValidateVersion: TFPCVersionValidator;
  AIsInstalled: TFPCVersionInstalledChecker;
  AGetInstallPath: TFPCInstallPathResolver;
  AGetToolchainInfo: TFPCToolchainInfoLookup;
  AWriteToolchainInfo: TFPCVersionInfoWriter
): Boolean; overload;

function ExecuteFPCTestInstallationCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AIsInstalled: TFPCVersionInstalledChecker;
  AGetInstallPath: TFPCInstallPathResolver;
  AExecuteInfo: TFPCExecutableInfoRunner
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.fpc.installversionflow;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function CreateFPCSourcePlanCore(
  const AInstallRoot, ARequestedVersion: string
): TFPCSourcePlan;
begin
  Result := Default(TFPCSourcePlan);
  if ARequestedVersion <> '' then
    Result.Version := ARequestedVersion
  else
    Result.Version := 'main';
  Result.SourceDir := BuildFPCSourceInstallPathCore(AInstallRoot, Result.Version);
end;

function ExecuteFPCUpdatePlanCore(
  const APlan: TFPCSourcePlan;
  const Outp, Errp: IOutput;
  ADirectoryExists: TFPCPathExistsFunc;
  const AGit: IFPCGitRuntime
): Boolean;
begin
  Result := False;

  if (APlan.Version = '') or (APlan.SourceDir = '') then
    Exit;

  if not Assigned(ADirectoryExists) then
    Exit;

  if not ADirectoryExists(APlan.SourceDir) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [APlan.SourceDir]));
    Exit;
  end;

  if AGit = nil then
    Exit;

  if not AGit.BackendAvailable then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _(CMD_FPC_NO_GIT_BACKEND));
    Exit;
  end;

  if not AGit.IsRepository(APlan.SourceDir) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_NOT_GIT_REPO, [APlan.SourceDir]));
    Exit;
  end;

  if not AGit.HasRemote(APlan.SourceDir) then
  begin
    WriteLine(Outp, _(MSG_FPC_SOURCE_LOCAL_ONLY) + ' ' + APlan.SourceDir);
    Exit(True);
  end;

  if AGit.Pull(APlan.SourceDir) then
  begin
    WriteLine(Outp, _(CMD_FPC_UPDATE_DONE) + ': ' + APlan.SourceDir);
    Exit(True);
  end;

  WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_GIT_PULL_FAILED, [AGit.GetLastError]));
end;

function ExecuteFPCCleanPlanCore(
  const APlan: TFPCSourcePlan;
  const Outp, Errp: IOutput;
  ADirectoryExists: TFPCPathExistsFunc;
  ACleanSource: TFPCSourceCleaner
): Boolean;
var
  DeletedCount: Integer;
begin
  Result := False;

  if (APlan.Version = '') or (APlan.SourceDir = '') then
    Exit;

  if (not Assigned(ADirectoryExists)) or (not Assigned(ACleanSource)) then
    Exit;

  if not ADirectoryExists(APlan.SourceDir) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [APlan.SourceDir]));
    Exit;
  end;

  try
    DeletedCount := ACleanSource(APlan.SourceDir);
    WriteLine(Outp, _(CMD_FPC_CLEAN_DONE) + ' - ' + IntToStr(DeletedCount) + ' file(s): ' + APlan.SourceDir);
    Result := True;
  except
    on E: Exception do
    begin
      WriteLine(Errp, _(MSG_ERROR) + ': CleanSources failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

procedure WriteLocalizedToolchainInfo(const AOut: IOutput; const AInfo: TToolchainInfo);
begin
  WriteLine(AOut, _Fmt(MSG_FPC_INSTALL_DATE, [FormatDateTime('yyyy-mm-dd hh:nn:ss', AInfo.InstallDate)]));
  WriteLine(AOut, _Fmt(MSG_FPC_SOURCE_URL, [AInfo.SourceURL]));
end;

function ExecuteFPCShowVersionInfoCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AValidateVersion: TFPCVersionValidator;
  AIsInstalled: TFPCVersionInstalledChecker;
  AGetInstallPath: TFPCInstallPathResolver;
  AGetToolchainInfo: TFPCToolchainInfoLookup
): Boolean;
begin
  Result := ExecuteFPCShowVersionInfoCore(
    AVersion, Outp, Errp, AValidateVersion, AIsInstalled, AGetInstallPath,
    AGetToolchainInfo, @WriteLocalizedToolchainInfo
  );
end;

function ExecuteFPCShowVersionInfoCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AValidateVersion: TFPCVersionValidator;
  AIsInstalled: TFPCVersionInstalledChecker;
  AGetInstallPath: TFPCInstallPathResolver;
  AGetToolchainInfo: TFPCToolchainInfoLookup;
  AWriteToolchainInfo: TFPCVersionInfoWriter
): Boolean;
var
  ToolchainInfo: TToolchainInfo;
  InstallPath: string;
begin
  Result := False;
  ToolchainInfo := Default(TToolchainInfo);

  if (not Assigned(AIsInstalled)) or (not Assigned(AGetInstallPath)) then
    Exit;

  if Assigned(AValidateVersion) and (not AValidateVersion(AVersion)) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_UNSUPPORTED_VERSION, [AVersion]));
    Exit;
  end;

  try
    if AIsInstalled(AVersion) then
    begin
      InstallPath := AGetInstallPath(AVersion);
      if InstallPath = '' then
      begin
        WriteLine(Errp, _(MSG_ERROR) + ': Install path not found');
        Exit;
      end;

      if Assigned(AGetToolchainInfo) and AGetToolchainInfo(AVersion, ToolchainInfo) and
         Assigned(AWriteToolchainInfo) then
        AWriteToolchainInfo(Outp, ToolchainInfo);
    end
    else
      WriteLine(Errp, _Fmt(ERR_NOT_INSTALLED, ['FPC ' + AVersion]));

    Result := True;
  except
    on E: Exception do
    begin
      WriteLine(Errp, _(MSG_ERROR) + ': ShowVersionInfo failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

function ExecuteFPCTestInstallationCore(
  const AVersion: string;
  const Outp, Errp: IOutput;
  AIsInstalled: TFPCVersionInstalledChecker;
  AGetInstallPath: TFPCInstallPathResolver;
  AExecuteInfo: TFPCExecutableInfoRunner
): Boolean;
var
  LResult: TProcessResult;
  FPCExe: string;
  InstallPath: string;
begin
  Result := False;

  if (not Assigned(AIsInstalled)) or (not Assigned(AGetInstallPath)) or
     (not Assigned(AExecuteInfo)) then
    Exit;

  if not AIsInstalled(AVersion) then
  begin
    WriteLine(Errp, _Fmt(CMD_FPC_USE_NOT_FOUND, [AVersion]));
    Exit;
  end;

  try
    InstallPath := AGetInstallPath(AVersion);
    FPCExe := BuildFPCInstalledExecutablePathCore(InstallPath);

    WriteLine(Outp, _Fmt(CMD_FPC_DOCTOR_CHECKING, [AVersion]));

    LResult := AExecuteInfo(FPCExe);
    Result := LResult.Success;
    if Result then
      WriteLine(Outp, _(CMD_FPC_DOCTOR_OK))
    else if Errp <> nil then
      WriteLine(Errp, _Fmt(CMD_FPC_DOCTOR_ISSUES, [1]))
    else
      WriteLine(Outp, _Fmt(CMD_FPC_DOCTOR_ISSUES, [1]));
  except
    on E: Exception do
    begin
      WriteLine(Errp, _(MSG_ERROR) + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
