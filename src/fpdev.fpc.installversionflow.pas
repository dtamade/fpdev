unit fpdev.fpc.installversionflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TFPCInstallVerifyFunc = function(
    const AFPCExe, AExpectedVersion: string;
    out AError: string
  ): Boolean of object;
  TFPCInstallHasArtifactsFunc = function(const AVersion: string): Boolean of object;
  TFPCInstallRestoreArtifactsFunc = function(const AVersion, AInstallPath: string): Boolean of object;
  TFPCInstallSaveArtifactsFunc = function(const AVersion, AInstallPath: string): Boolean of object;
  TFPCInstallDownloadSourceFunc = function(const AVersion, ASourceDir: string): Boolean of object;
  TFPCInstallEnsureBootstrapFunc = function(const AVersion: string): Boolean of object;
  TFPCInstallBuildSourceFunc = function(const ASourceDir, AInstallPath: string): Boolean of object;
  TFPCInstallSetupEnvironmentFunc = function(const AVersion, AInstallPath: string): Boolean of object;
  TFPCInstallBinaryFunc = function(const AVersion, APrefix: string): Boolean of object;

function ResolveFPCInstallPathCore(const APrefix, ADefaultInstallPath: string): string;
function BuildFPCSourceInstallPathCore(const AInstallRoot, AVersion: string): string;
function BuildFPCInstalledExecutablePathCore(const AInstallPath: string): string;
function ShouldReuseInstalledFPCVersionCore(
  AAlreadyInstalled: Boolean;
  const APrefix: string;
  AEnsure: Boolean
): Boolean;

function ExecuteFPCInstallVersionCore(
  const AVersion, AInstallRoot, ADefaultInstallPath, APrefix: string;
  AFromSource, AEnsure, AAlreadyInstalled: Boolean;
  Outp, Errp: IOutput;
  AVerifyInstalledExecutable: TFPCInstallVerifyFunc;
  AHasCachedArtifacts: TFPCInstallHasArtifactsFunc;
  ARestoreCachedArtifacts: TFPCInstallRestoreArtifactsFunc;
  ASaveBuildArtifacts: TFPCInstallSaveArtifactsFunc;
  ADownloadSource: TFPCInstallDownloadSourceFunc;
  AEnsureBootstrap: TFPCInstallEnsureBootstrapFunc;
  ABuildFromSource: TFPCInstallBuildSourceFunc;
  ASetupEnvironment: TFPCInstallSetupEnvironmentFunc;
  AInstallBinary: TFPCInstallBinaryFunc
): Boolean;

implementation

uses
  SysUtils,
  fpdev.i18n,
  fpdev.i18n.strings;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ResolveFPCInstallPathCore(const APrefix, ADefaultInstallPath: string): string;
begin
  if APrefix <> '' then
    Result := ExpandFileName(APrefix)
  else
    Result := ADefaultInstallPath;
end;

function BuildFPCSourceInstallPathCore(const AInstallRoot, AVersion: string): string;
begin
  Result := AInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' +
    PathDelim + 'fpc-' + AVersion;
end;

function BuildFPCInstalledExecutablePathCore(const AInstallPath: string): string;
begin
  {$IFDEF MSWINDOWS}
  Result := AInstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  Result := AInstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
end;

function ShouldReuseInstalledFPCVersionCore(
  AAlreadyInstalled: Boolean;
  const APrefix: string;
  AEnsure: Boolean
): Boolean;
begin
  Result := AAlreadyInstalled and (APrefix = '') and (not AEnsure);
end;

function ExecuteFPCSourceInstallFlowCore(
  const AVersion, AInstallRoot, AInstallPath: string;
  Outp, Errp: IOutput;
  AHasCachedArtifacts: TFPCInstallHasArtifactsFunc;
  ARestoreCachedArtifacts: TFPCInstallRestoreArtifactsFunc;
  ASaveBuildArtifacts: TFPCInstallSaveArtifactsFunc;
  ADownloadSource: TFPCInstallDownloadSourceFunc;
  AEnsureBootstrap: TFPCInstallEnsureBootstrapFunc;
  ABuildFromSource: TFPCInstallBuildSourceFunc;
  ASetupEnvironment: TFPCInstallSetupEnvironmentFunc
): Boolean;
var
  CacheRestored: Boolean;
  SourceDir: string;
begin
  Result := False;
  CacheRestored := False;

  if Assigned(AHasCachedArtifacts) and AHasCachedArtifacts(AVersion) then
  begin
    WriteLine(Outp, 'Restoring from build cache...');
    if Assigned(ARestoreCachedArtifacts) and
       ARestoreCachedArtifacts(AVersion, AInstallPath) then
    begin
      WriteLine(Outp, 'Build cache restored successfully');
      CacheRestored := True;
      WriteLine(Outp, _(MSG_FPC_STEP_SETUP));
      Result := Assigned(ASetupEnvironment) and
        ASetupEnvironment(AVersion, AInstallPath);
    end
    else
      WriteLine(Outp, 'Cache restore failed, building from source...');
  end;

  if CacheRestored then
    Exit;

  SourceDir := BuildFPCSourceInstallPathCore(AInstallRoot, AVersion);

  WriteLine(Outp, _(MSG_FPC_STEP_DOWNLOAD));
  if (not Assigned(ADownloadSource)) or
     (not ADownloadSource(AVersion, SourceDir)) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _(CMD_FPC_DOWNLOAD_FAILED));
    Exit(False);
  end;

  WriteLine(Outp, _(MSG_FPC_STEP_BOOTSTRAP));
  if (not Assigned(AEnsureBootstrap)) or
     (not AEnsureBootstrap(AVersion)) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _(CMD_FPC_BOOTSTRAP_CHECK_FAILED));
    Exit(False);
  end;

  WriteLine(Outp, _(MSG_FPC_STEP_BUILD));
  if (not Assigned(ABuildFromSource)) or
     (not ABuildFromSource(SourceDir, AInstallPath)) then
  begin
    WriteLine(Errp, _(MSG_ERROR) + ': ' + _(CMD_FPC_BUILD_FROM_SOURCE_FAILED));
    Exit(False);
  end;

  WriteLine(Outp, _(MSG_FPC_STEP_SETUP));
  Result := Assigned(ASetupEnvironment) and
    ASetupEnvironment(AVersion, AInstallPath);

  if Result and Assigned(ASaveBuildArtifacts) then
  begin
    WriteLine(Outp, 'Saving build artifacts to cache...');
    if ASaveBuildArtifacts(AVersion, AInstallPath) then
      WriteLine(Outp, 'Build artifacts cached successfully')
    else
      WriteLine(Outp, 'Warning: Failed to cache build artifacts');
  end;
end;

function ExecuteFPCInstallVersionCore(
  const AVersion, AInstallRoot, ADefaultInstallPath, APrefix: string;
  AFromSource, AEnsure, AAlreadyInstalled: Boolean;
  Outp, Errp: IOutput;
  AVerifyInstalledExecutable: TFPCInstallVerifyFunc;
  AHasCachedArtifacts: TFPCInstallHasArtifactsFunc;
  ARestoreCachedArtifacts: TFPCInstallRestoreArtifactsFunc;
  ASaveBuildArtifacts: TFPCInstallSaveArtifactsFunc;
  ADownloadSource: TFPCInstallDownloadSourceFunc;
  AEnsureBootstrap: TFPCInstallEnsureBootstrapFunc;
  ABuildFromSource: TFPCInstallBuildSourceFunc;
  ASetupEnvironment: TFPCInstallSetupEnvironmentFunc;
  AInstallBinary: TFPCInstallBinaryFunc
): Boolean;
var
  InstallPath: string;
  VerifyError: string;
begin
  Result := False;

  if ShouldReuseInstalledFPCVersionCore(AAlreadyInstalled, APrefix, AEnsure) then
  begin
    WriteLine(Outp, _Fmt(ERR_ALREADY_INSTALLED, ['FPC ' + AVersion]));
    WriteLine(Outp, 'Verifying installation...');

    VerifyError := '';
    if Assigned(AVerifyInstalledExecutable) and
       AVerifyInstalledExecutable(
         BuildFPCInstalledExecutablePathCore(ADefaultInstallPath),
         AVersion,
         VerifyError
       ) then
    begin
      WriteLine(Outp, 'Installation verified successfully');
      Exit(True);
    end;

    WriteLine(Outp, 'Warning: Installation verification failed');
    WriteLine(Outp, 'Reason: ' + VerifyError);
    WriteLine(Outp, 'Proceeding with reinstallation...');
  end;

  InstallPath := ResolveFPCInstallPathCore(APrefix, ADefaultInstallPath);
  WriteLine(Outp, _Fmt(CMD_FPC_INSTALL_START, [AVersion]) + ' to: ' + InstallPath);

  if AFromSource then
    Result := ExecuteFPCSourceInstallFlowCore(
      AVersion,
      AInstallRoot,
      InstallPath,
      Outp,
      Errp,
      AHasCachedArtifacts,
      ARestoreCachedArtifacts,
      ASaveBuildArtifacts,
      ADownloadSource,
      AEnsureBootstrap,
      ABuildFromSource,
      ASetupEnvironment
    )
  else
  begin
    WriteLine(Outp, _(MSG_FPC_STEP_DOWNLOAD_BIN));
    Result := Assigned(AInstallBinary) and AInstallBinary(AVersion, APrefix);
  end;

  if Result then
    WriteLine(Outp, _Fmt(CMD_FPC_INSTALL_DONE, [AVersion]));
end;

end.
