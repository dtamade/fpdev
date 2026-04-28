unit fpdev.cross.managerflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.config.interfaces,
  fpdev.output.intf,
  fpdev.cross.query;

type
  TCrossTargetArrayProvider = function: TCrossTargetQueryArray of object;
  TCrossTargetInfoProvider = function(const ATarget: string): TCrossTargetQueryInfo of object;
  TCrossTargetCheckFunc = function(const ATarget: string): Boolean of object;
  TCrossTargetInstallPathFunc = function(const ATarget: string): string of object;
  TCrossTargetConfigGetter = function(const ATarget: string; out AInfo: TCrossTarget): Boolean of object;
  TCrossTargetConfigSaver = function(const ATarget: string; const AInfo: TCrossTarget): Boolean of object;
  TCrossTargetConfigRemover = function(const ATarget: string): Boolean of object;
  TCrossTargetDownloadFunc = function(
    const ATarget: string;
    const ATargetInfo: TCrossTargetQueryInfo;
    Outp: IOutput
  ): Boolean of object;
  TCrossTargetSetupFunc = function(
    const ATarget: string;
    const ATargetInfo: TCrossTargetQueryInfo
  ): Boolean of object;
  TCrossSystemCompilerDetectFunc = function(
    const ATarget: string;
    out ABinutilsPath: string
  ): Boolean of object;
  TCrossPackageInstructionsFunc = function(const ATarget: string): string of object;

  TCrossCleanPaths = record
    InstallPath: string;
    BinutilsPath: string;
    LibrariesPath: string;
  end;

function ExecuteCrossListTargetsCore(
  AShowAll: Boolean;
  AGetAvailableTargets: TCrossTargetArrayProvider;
  AGetInstalledTargets: TCrossTargetArrayProvider;
  Outp: IOutput
): Boolean;

function ExecuteCrossShowTargetInfoCore(
  const ATarget: string;
  AValidateTarget: TCrossTargetCheckFunc;
  AGetTargetInfo: TCrossTargetInfoProvider;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  Outp, Errp: IOutput
): Boolean;

function ExecuteCrossUpdateTargetCore(
  const ATarget: string;
  AValidateTarget: TCrossTargetCheckFunc;
  AIsTargetInstalled: TCrossTargetCheckFunc;
  AGetTargetInfo: TCrossTargetInfoProvider;
  ADownloadBinutils: TCrossTargetDownloadFunc;
  ADownloadLibraries: TCrossTargetDownloadFunc;
  Outp, Errp: IOutput
): Boolean;

function ExecuteCrossInstallTargetCore(
  const ATarget: string;
  AValidateTarget: TCrossTargetCheckFunc;
  AIsTargetInstalled: TCrossTargetCheckFunc;
  AGetTargetInfo: TCrossTargetInfoProvider;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  ADetectSystemCompiler: TCrossSystemCompilerDetectFunc;
  ASaveCrossTargetConfig: TCrossTargetConfigSaver;
  ADownloadBinutils: TCrossTargetDownloadFunc;
  ADownloadLibraries: TCrossTargetDownloadFunc;
  ASetupCrossEnvironment: TCrossTargetSetupFunc;
  AGetPackageManagerInstructions: TCrossPackageInstructionsFunc;
  Outp, Errp: IOutput
): Boolean;

function ResolveCrossCleanPathsCore(
  const ATarget: string;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  AGetCrossTargetConfig: TCrossTargetConfigGetter
): TCrossCleanPaths;

function ExecuteCrossCleanTargetCore(
  const ATarget: string;
  AValidateTarget: TCrossTargetCheckFunc;
  AIsTargetInstalled: TCrossTargetCheckFunc;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  AGetCrossTargetConfig: TCrossTargetConfigGetter;
  Outp, Errp: IOutput
): Boolean;

function ExecuteCrossUninstallTargetCore(
  const ATarget: string;
  AIsTargetInstalled: TCrossTargetCheckFunc;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  ARemoveCrossTargetConfig: TCrossTargetConfigRemover;
  Outp, Errp: IOutput
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.utils.fs;

function ExecuteCrossListTargetsCore(
  AShowAll: Boolean;
  AGetAvailableTargets: TCrossTargetArrayProvider;
  AGetInstalledTargets: TCrossTargetArrayProvider;
  Outp: IOutput
): Boolean;
var
  Targets: TCrossTargetQueryArray;
  Index: Integer;
  Line: string;
begin
  Result := False;
  if not Assigned(Outp) then
    Exit;

  Targets := nil;

  try
    if AShowAll then
    begin
      if not Assigned(AGetAvailableTargets) then
        Exit;
      Targets := AGetAvailableTargets();
      Outp.WriteLn(_(MSG_CROSS_LIST_AVAILABLE));
    end
    else
    begin
      if not Assigned(AGetInstalledTargets) then
        Exit;
      Targets := AGetInstalledTargets();
      Outp.WriteLn(_(MSG_CROSS_LIST_INSTALLED));
    end;

    Outp.WriteLn('');

    if Length(Targets) = 0 then
    begin
      if AShowAll then
        Outp.WriteLn(_(MSG_CROSS_LIST_NO_AVAILABLE))
      else
        Outp.WriteLn(_(MSG_CROSS_LIST_NO_INSTALLED));
      Outp.WriteLn('');
      Outp.WriteLn(_(MSG_CROSS_LIST_USE_ALL));
      Exit(True);
    end;

    Outp.WriteLn(_(MSG_CROSS_LIST_TABLE_HEADER));
    Outp.WriteLn(_(MSG_CROSS_LIST_TABLE_LINE));

    for Index := 0 to High(Targets) do
    begin
      Line := Format('%-10s  ', [Targets[Index].Name]);
      if Targets[Index].Installed then
        Line := Line + _(MSG_CROSS_STATUS_INSTALLED)
      else
        Line := Line + _(MSG_CROSS_STATUS_AVAILABLE);
      Line := Line + Format('%-20s  ', [Targets[Index].DisplayName]);
      Line := Line + Format('%-8s  ', [Targets[Index].CPU]);
      Line := Line + Targets[Index].OS;
      Outp.WriteLn(Line);
    end;

    Outp.WriteLn('');
    Outp.WriteLn(_Fmt(MSG_CROSS_LIST_TOTAL, [Length(Targets)]));
    Result := True;
  except
    on E: Exception do
    begin
      Outp.WriteLn(_Fmt(MSG_CROSS_LIST_ERROR, [E.Message]));
      Result := False;
    end;
  end;
end;

function ExecuteCrossShowTargetInfoCore(
  const ATarget: string;
  AValidateTarget: TCrossTargetCheckFunc;
  AGetTargetInfo: TCrossTargetInfoProvider;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  Outp, Errp: IOutput
): Boolean;
var
  TargetInfo: TCrossTargetQueryInfo;
  InstallPath: string;
begin
  Result := False;

  if (not Assigned(AValidateTarget)) or (not AValidateTarget(ATarget)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  if (not Assigned(AGetTargetInfo)) or (Outp = nil) then
    Exit;

  try
    TargetInfo := AGetTargetInfo(ATarget);
    Outp.WriteLn(_Fmt(MSG_CROSS_SHOW_DISPLAY_NAME, [TargetInfo.DisplayName]));
    Outp.WriteLn(_Fmt(MSG_CROSS_SHOW_CPU, [TargetInfo.CPU]));
    Outp.WriteLn(_Fmt(MSG_CROSS_SHOW_OS, [TargetInfo.OS]));
    Outp.WriteLn(_Fmt(MSG_CROSS_SHOW_BINUTILS_PREFIX, [TargetInfo.BinutilsPrefix]));

    if TargetInfo.Installed and Assigned(AGetTargetInstallPath) then
    begin
      InstallPath := AGetTargetInstallPath(ATarget);
      if InstallPath <> '' then
        Outp.WriteLn('Install Path: ' + InstallPath);
    end;

    Result := True;
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['displaying target info', E.Message]));
      Result := False;
    end;
  end;
end;

function ExecuteCrossUpdateTargetCore(
  const ATarget: string;
  AValidateTarget: TCrossTargetCheckFunc;
  AIsTargetInstalled: TCrossTargetCheckFunc;
  AGetTargetInfo: TCrossTargetInfoProvider;
  ADownloadBinutils: TCrossTargetDownloadFunc;
  ADownloadLibraries: TCrossTargetDownloadFunc;
  Outp, Errp: IOutput
): Boolean;
var
  TargetInfo: TCrossTargetQueryInfo;
begin
  Result := False;
  if ATarget = '' then
    Exit;

  if (not Assigned(AValidateTarget)) or (not AValidateTarget(ATarget)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  if (not Assigned(AIsTargetInstalled)) or (not AIsTargetInstalled(ATarget)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_INSTALLED, [ATarget]));
    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_USE_INSTALL_FIRST, [ATarget]));
    Exit;
  end;

  if (Outp = nil) or (not Assigned(AGetTargetInfo)) then
    Exit;

  TargetInfo := AGetTargetInfo(ATarget);

  Outp.WriteLn(_Fmt(MSG_CROSS_UPDATING, [ATarget]));
  Outp.WriteLn(_(MSG_CROSS_UPDATE_STEP1));
  if (not Assigned(ADownloadBinutils)) or
     (not ADownloadBinutils(ATarget, TargetInfo, Outp)) then
    Outp.WriteLn(_Fmt(MSG_CROSS_UPDATE_BINUTILS_WARN, [ATarget]));

  Outp.WriteLn(_(MSG_CROSS_UPDATE_STEP2));
  if (not Assigned(ADownloadLibraries)) or
     (not ADownloadLibraries(ATarget, TargetInfo, Outp)) then
    Outp.WriteLn(_Fmt(MSG_CROSS_UPDATE_LIBS_WARN, [ATarget]));

  Outp.WriteLn(_Fmt(MSG_CROSS_UPDATE_DONE, [ATarget]));
  Result := True;
end;

function ExecuteCrossInstallTargetCore(
  const ATarget: string;
  AValidateTarget: TCrossTargetCheckFunc;
  AIsTargetInstalled: TCrossTargetCheckFunc;
  AGetTargetInfo: TCrossTargetInfoProvider;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  ADetectSystemCompiler: TCrossSystemCompilerDetectFunc;
  ASaveCrossTargetConfig: TCrossTargetConfigSaver;
  ADownloadBinutils: TCrossTargetDownloadFunc;
  ADownloadLibraries: TCrossTargetDownloadFunc;
  ASetupCrossEnvironment: TCrossTargetSetupFunc;
  AGetPackageManagerInstructions: TCrossPackageInstructionsFunc;
  Outp, Errp: IOutput
): Boolean;
var
  TargetInfo: TCrossTargetQueryInfo;
  InstallPath: string;
  SystemBinutilsPath: string;
  CrossTarget: TCrossTarget;
  Instructions: string;
begin
  Result := False;

  if (not Assigned(AValidateTarget)) or (not AValidateTarget(ATarget)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  if (not Assigned(AIsTargetInstalled)) or (not Assigned(AGetTargetInfo)) or
     (not Assigned(AGetTargetInstallPath)) or (Outp = nil) then
    Exit;

  if AIsTargetInstalled(ATarget) then
  begin
    Outp.WriteLn(_Fmt(MSG_CROSS_ALREADY_INSTALLED, [ATarget]));
    Exit(True);
  end;

  try
    TargetInfo := AGetTargetInfo(ATarget);
    InstallPath := AGetTargetInstallPath(ATarget);

    Outp.WriteLn(_Fmt(MSG_CROSS_INSTALLING, [ATarget]));
    Outp.WriteLn('');

    Outp.WriteLn(_(MSG_CROSS_INSTALL_STEP1));
    if Assigned(ADetectSystemCompiler) and ADetectSystemCompiler(ATarget, SystemBinutilsPath) then
    begin
      Outp.WriteLn(_Fmt(MSG_CROSS_SYSTEM_FOUND, [SystemBinutilsPath]));
      Outp.WriteLn('');
      Outp.WriteLn(_(MSG_CROSS_SKIP_DOWNLOAD));
      Outp.WriteLn(_(MSG_CROSS_INSTALL_STEP3));

      CrossTarget := Default(TCrossTarget);
      CrossTarget.Enabled := True;
      CrossTarget.BinutilsPath := SystemBinutilsPath;
      CrossTarget.LibrariesPath := '';

      Result := Assigned(ASaveCrossTargetConfig) and
        ASaveCrossTargetConfig(ATarget, CrossTarget);
      if Result then
      begin
        Outp.WriteLn('');
        Outp.WriteLn(_Fmt(MSG_CROSS_INSTALL_SUCCESS, [ATarget]));
        Outp.WriteLn(_Fmt(MSG_CROSS_USING_SYSTEM, [SystemBinutilsPath]));
      end
      else if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_CONFIGURE_FAILED, [ATarget]));
      Exit;
    end;

    Outp.WriteLn(_(MSG_CROSS_SYSTEM_NOT_FOUND));
    Outp.WriteLn('');

    if (InstallPath <> '') and (not DirectoryExists(InstallPath)) then
      EnsureDir(InstallPath);

    Outp.WriteLn(_(MSG_CROSS_INSTALL_STEP2));
    if (not Assigned(ADownloadBinutils)) or
       (not ADownloadBinutils(ATarget, TargetInfo, Outp)) then
    begin
      Outp.WriteLn('');
      Outp.WriteLn(_(MSG_CROSS_DOWNLOAD_UNAVAIL));
      Outp.WriteLn('');
      Instructions := '';
      if Assigned(AGetPackageManagerInstructions) then
        Instructions := AGetPackageManagerInstructions(ATarget);
      if Instructions <> '' then
        Outp.WriteLn(Instructions);
      Outp.WriteLn('');
      Outp.WriteLn(_(MSG_CROSS_AFTER_INSTALL_HINT));
      Outp.WriteLn(_Fmt(MSG_CROSS_INSTALL_HINT, [ATarget]));
      Outp.WriteLn(_(MSG_CROSS_MANUAL_CONFIG_HINT));
      Outp.WriteLn(_Fmt(MSG_CROSS_CONFIGURE_HINT, [ATarget]));
      Exit(False);
    end;

    if (not Assigned(ADownloadLibraries)) or
       (not ADownloadLibraries(ATarget, TargetInfo, Outp)) then
      Outp.WriteLn(_(MSG_CROSS_LIBS_SKIP_NOTE));

    Outp.WriteLn(_(MSG_CROSS_INSTALL_STEP3));
    Result := Assigned(ASetupCrossEnvironment) and
      ASetupCrossEnvironment(ATarget, TargetInfo);

    if Result then
    begin
      Outp.WriteLn('');
      Outp.WriteLn(_Fmt(MSG_CROSS_INSTALL_SUCCESS, [ATarget]));
    end
    else if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_CROSS_SETUP_FAILED));
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['installation', E.Message]));
      Result := False;
    end;
  end;
end;

function ResolveCrossCleanPathsCore(
  const ATarget: string;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  AGetCrossTargetConfig: TCrossTargetConfigGetter
): TCrossCleanPaths;
var
  CrossTarget: TCrossTarget;
begin
  Result := Default(TCrossCleanPaths);
  if not Assigned(AGetTargetInstallPath) then
    Exit;

  Result.InstallPath := AGetTargetInstallPath(ATarget);
  Result.BinutilsPath := Result.InstallPath + PathDelim + 'bin';
  Result.LibrariesPath := Result.InstallPath + PathDelim + 'lib';

  CrossTarget := Default(TCrossTarget);
  if Assigned(AGetCrossTargetConfig) and AGetCrossTargetConfig(ATarget, CrossTarget) then
  begin
    if (CrossTarget.BinutilsPath <> '') and (CrossTarget.BinutilsPath <> Result.BinutilsPath) then
      Result.BinutilsPath := CrossTarget.BinutilsPath;
    if (CrossTarget.LibrariesPath <> '') and (CrossTarget.LibrariesPath <> Result.LibrariesPath) then
      Result.LibrariesPath := CrossTarget.LibrariesPath;
  end;
end;

procedure DeleteCrossCleanArtifactsCore(const AInstallPath: string);
const
  CLEAN_FILES: array[0..6] of string = (
    'binutils.tar.xz',
    'binutils.zip',
    'libraries.tar.xz',
    'libraries.zip',
    'cross_test.pas',
    'cross_test',
    'cross_test.exe'
  );
var
  Index: Integer;
  ArtifactPath: string;
begin
  if AInstallPath = '' then
    Exit;

  for Index := 0 to High(CLEAN_FILES) do
  begin
    ArtifactPath := IncludeTrailingPathDelimiter(AInstallPath) + CLEAN_FILES[Index];
    if FileExists(ArtifactPath) then
      DeleteFile(ArtifactPath);
  end;
end;

function ExecuteCrossCleanTargetCore(
  const ATarget: string;
  AValidateTarget: TCrossTargetCheckFunc;
  AIsTargetInstalled: TCrossTargetCheckFunc;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  AGetCrossTargetConfig: TCrossTargetConfigGetter;
  Outp, Errp: IOutput
): Boolean;
var
  Paths: TCrossCleanPaths;
begin
  Result := False;
  if ATarget = '' then
    Exit;

  if (not Assigned(AValidateTarget)) or (not AValidateTarget(ATarget)) then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  if (not Assigned(AIsTargetInstalled)) or (not AIsTargetInstalled(ATarget)) then
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_NOT_INSTALLED_NOTHING, [ATarget]));
    Exit(True);
  end;

  if Outp = nil then
    Exit;

  Outp.WriteLn(_Fmt(MSG_CROSS_CLEANING, [ATarget]));
  Paths := ResolveCrossCleanPathsCore(ATarget, AGetTargetInstallPath, AGetCrossTargetConfig);

  if DirectoryExists(Paths.BinutilsPath) then
  begin
    Outp.WriteLn(_Fmt(MSG_CROSS_CLEANING_BINUTILS, [Paths.BinutilsPath]));
    DeleteDirRecursive(Paths.BinutilsPath);
  end;

  if DirectoryExists(Paths.LibrariesPath) then
  begin
    Outp.WriteLn(_Fmt(MSG_CROSS_CLEANING_LIBS, [Paths.LibrariesPath]));
    DeleteDirRecursive(Paths.LibrariesPath);
  end;

  DeleteCrossCleanArtifactsCore(Paths.InstallPath);

  Outp.WriteLn(_Fmt(MSG_CROSS_CLEAN_DONE, [ATarget]));
  Outp.WriteLn(_Fmt(MSG_CROSS_CLEAN_NOTE, [ATarget]));
  Result := True;
end;

function ExecuteCrossUninstallTargetCore(
  const ATarget: string;
  AIsTargetInstalled: TCrossTargetCheckFunc;
  AGetTargetInstallPath: TCrossTargetInstallPathFunc;
  ARemoveCrossTargetConfig: TCrossTargetConfigRemover;
  Outp, Errp: IOutput
): Boolean;
var
  InstallPath: string;
begin
  Result := False;

  if (not Assigned(AIsTargetInstalled)) or (not AIsTargetInstalled(ATarget)) then
  begin
    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_TARGET_NOT_INSTALLED_MSG, [ATarget]));
    Exit(True);
  end;

  if not Assigned(AGetTargetInstallPath) then
    Exit;

  try
    InstallPath := AGetTargetInstallPath(ATarget);

    if (InstallPath <> '') and DirectoryExists(InstallPath) then
      DeleteDirRecursive(InstallPath);

    if Assigned(ARemoveCrossTargetConfig) then
      ARemoveCrossTargetConfig(ATarget);

    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_UNINSTALLED, [ATarget]));
    Result := True;
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['uninstallation', E.Message]));
      Result := False;
    end;
  end;
end;

end.
