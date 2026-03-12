unit fpdev.cross.targetflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf,
  fpdev.config.interfaces,
  fpdev.cross.tester,
  fpdev.cross.query,
  fpdev.utils.process;

type
  TCrossGetTargetConfigFunc = function(const ATarget: string; out AInfo: TCrossTarget): Boolean of object;
  TCrossSaveTargetConfigFunc = function(const ATarget: string; const AInfo: TCrossTarget): Boolean of object;
  TCrossProcessExecFunc = function(
    const AExecutable: string;
    const AParams: SysUtils.TStringArray;
    const AWorkDir: string
  ): TProcessResult of object;
  TCrossBuildTesterFunc = function(
    const ATarget, ACPU, AOS, ABinutilsPath, ALibrariesPath, ASourceFile: string
  ): TCrossBuildTestResult of object;

function CreateCrossTargetConfigCore(
  AEnabled: Boolean;
  const ABinutilsPath, ALibrariesPath: string
): TCrossTarget;

function SetCrossTargetEnabledCore(
  const ATarget: string;
  AEnabled: Boolean;
  AGetCrossTarget: TCrossGetTargetConfigFunc;
  ASaveCrossTarget: TCrossSaveTargetConfigFunc;
  Outp, Errp: IOutput
): Boolean;

function ConfigureCrossTargetCore(
  const ATarget, ABinutilsPath, ALibrariesPath: string;
  ATargetValid: Boolean;
  ASaveCrossTarget: TCrossSaveTargetConfigFunc;
  Outp, Errp: IOutput
): Boolean;

function TestCrossTargetCore(
  const ATarget: string;
  AIsInstalled: Boolean;
  const ATargetInfo: TCrossTargetQueryInfo;
  AGetCrossTarget: TCrossGetTargetConfigFunc;
  ARunProcess: TCrossProcessExecFunc;
  Outp, Errp: IOutput
): Boolean;

function BuildCrossTargetTestCore(
  const ATarget, ASourceFile: string;
  AIsInstalled: Boolean;
  const ATargetInfo: TCrossTargetQueryInfo;
  AGetCrossTarget: TCrossGetTargetConfigFunc;
  AExecuteBuildTest: TCrossBuildTesterFunc;
  Outp, Errp: IOutput
): Boolean;

implementation

uses
  fpdev.i18n,
  fpdev.i18n.strings;

function CreateCrossTargetConfigCore(
  AEnabled: Boolean;
  const ABinutilsPath, ALibrariesPath: string
): TCrossTarget;
begin
  Result := Default(TCrossTarget);
  Result.Enabled := AEnabled;
  Result.BinutilsPath := ABinutilsPath;
  Result.LibrariesPath := ALibrariesPath;
end;

function SetCrossTargetEnabledCore(
  const ATarget: string;
  AEnabled: Boolean;
  AGetCrossTarget: TCrossGetTargetConfigFunc;
  ASaveCrossTarget: TCrossSaveTargetConfigFunc;
  Outp, Errp: IOutput
): Boolean;
var
  CrossTarget: TCrossTarget;
  SuccessMessage: string;
  FailureMessage: string;
  ExceptionAction: string;
begin
  Result := False;
  CrossTarget := Default(TCrossTarget);

  if AEnabled then
  begin
    SuccessMessage := _Fmt(MSG_CROSS_ENABLED, [ATarget]);
    FailureMessage := _Fmt(CMD_CROSS_ENABLE_FAILED, [ATarget]);
    ExceptionAction := 'enabling target';
  end
  else
  begin
    SuccessMessage := _Fmt(MSG_CROSS_DISABLED, [ATarget]);
    FailureMessage := _Fmt(CMD_CROSS_DISABLE_FAILED, [ATarget]);
    ExceptionAction := 'disabling target';
  end;

  try
    if Assigned(AGetCrossTarget) and AGetCrossTarget(ATarget, CrossTarget) then
    begin
      CrossTarget.Enabled := AEnabled;
      Result := Assigned(ASaveCrossTarget) and ASaveCrossTarget(ATarget, CrossTarget);
      if Result then
      begin
        if Outp <> nil then
          Outp.WriteLn(SuccessMessage);
      end
      else if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + FailureMessage);
    end
    else if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_CONFIGURED, [ATarget]));
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, [ExceptionAction, E.Message]));
      Result := False;
    end;
  end;
end;

function ConfigureCrossTargetCore(
  const ATarget, ABinutilsPath, ALibrariesPath: string;
  ATargetValid: Boolean;
  ASaveCrossTarget: TCrossSaveTargetConfigFunc;
  Outp, Errp: IOutput
): Boolean;
var
  CrossTarget: TCrossTarget;
begin
  Result := False;

  if not ATargetValid then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_UNSUPPORTED, [ATarget]));
    Exit;
  end;

  try
    if not DirectoryExists(ABinutilsPath) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_BINUTILS_PATH_NOT_FOUND, [ABinutilsPath]));
      Exit;
    end;

    if not DirectoryExists(ALibrariesPath) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_LIBS_PATH_NOT_FOUND, [ALibrariesPath]));
      Exit;
    end;

    CrossTarget := CreateCrossTargetConfigCore(True, ABinutilsPath, ALibrariesPath);
    Result := Assigned(ASaveCrossTarget) and ASaveCrossTarget(ATarget, CrossTarget);
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn('Cross-compilation target ' + ATarget + ' configured successfully');
    end
    else if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_CONFIGURE_FAILED, [ATarget]));
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['configuring target', E.Message]));
      Result := False;
    end;
  end;
end;

function BuildCrossCompilerExecutableCore(
  const ABinutilsPath, ABinutilsPrefix: string
): string;
begin
  Result := IncludeTrailingPathDelimiter(ABinutilsPath) + ABinutilsPrefix + 'gcc';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function TestCrossTargetCore(
  const ATarget: string;
  AIsInstalled: Boolean;
  const ATargetInfo: TCrossTargetQueryInfo;
  AGetCrossTarget: TCrossGetTargetConfigFunc;
  ARunProcess: TCrossProcessExecFunc;
  Outp, Errp: IOutput
): Boolean;
var
  CrossTarget: TCrossTarget;
  LResult: TProcessResult;
  GCCExe: string;
  Params: SysUtils.TStringArray;
begin
  Result := False;
  CrossTarget := Default(TCrossTarget);

  if not AIsInstalled then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_INSTALLED, [ATarget]));
    Exit;
  end;

  try
    if (not Assigned(AGetCrossTarget)) or (not AGetCrossTarget(ATarget, CrossTarget)) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_CROSS_CONFIG_GET_FAILED));
      Exit;
    end;

    if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_TEST_TESTING, [ATarget]));

    GCCExe := BuildCrossCompilerExecutableCore(CrossTarget.BinutilsPath, ATargetInfo.BinutilsPrefix);
    if not FileExists(GCCExe) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_COMPILER_NOT_FOUND, [GCCExe]));
      Exit;
    end;

    Params := Default(SysUtils.TStringArray);
    SetLength(Params, 1);
    Params[0] := '--version';
    if not Assigned(ARunProcess) then
      Exit(False);
    LResult := ARunProcess(GCCExe, Params, '');
    Result := LResult.Success;
    if Result then
    begin
      if Outp <> nil then
        Outp.WriteLn(_Fmt(MSG_CROSS_TEST_PASSED, [ATarget]));
    end
    else if Errp <> nil then
      Errp.WriteLn(_Fmt(MSG_CROSS_TEST_FAILED_MSG, [ATarget]))
    else if Outp <> nil then
      Outp.WriteLn(_Fmt(MSG_CROSS_TEST_FAILED_MSG, [ATarget]));
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['testing target', E.Message]));
      Result := False;
    end;
  end;
end;

function BuildCrossTargetTestCore(
  const ATarget, ASourceFile: string;
  AIsInstalled: Boolean;
  const ATargetInfo: TCrossTargetQueryInfo;
  AGetCrossTarget: TCrossGetTargetConfigFunc;
  AExecuteBuildTest: TCrossBuildTesterFunc;
  Outp, Errp: IOutput
): Boolean;
var
  CrossTarget: TCrossTarget;
  TestResult: TCrossBuildTestResult;
begin
  Result := False;
  CrossTarget := Default(TCrossTarget);

  if ATarget = '' then
    Exit;

  if not AIsInstalled then
  begin
    if Errp <> nil then
      Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_TARGET_NOT_INSTALLED, [ATarget]));
    Exit;
  end;

  try
    if (not Assigned(AGetCrossTarget)) or (not AGetCrossTarget(ATarget, CrossTarget)) then
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _(CMD_CROSS_CONFIG_GET_FAILED));
      Exit;
    end;

    if Outp <> nil then
    begin
      Outp.WriteLn(_Fmt(MSG_CROSS_BUILDING_TEST, [ATarget]));
      Outp.WriteLn(_Fmt(MSG_CROSS_BUILD_TARGET_CPU, [ATargetInfo.CPU]));
      Outp.WriteLn(_Fmt(MSG_CROSS_BUILD_TARGET_OS, [ATargetInfo.OS]));
    end;

    if not Assigned(AExecuteBuildTest) then
      Exit(False);
    TestResult := AExecuteBuildTest(
      ATarget,
      ATargetInfo.CPU,
      ATargetInfo.OS,
      CrossTarget.BinutilsPath,
      CrossTarget.LibrariesPath,
      ASourceFile
    );

    if TestResult.Success then
    begin
      if Outp <> nil then
      begin
        Outp.WriteLn(_Fmt(MSG_CROSS_BUILD_PASSED, [ATarget]));
        Outp.WriteLn(_Fmt(MSG_CROSS_OUTPUT_FILE, [TestResult.OutputFile]));
      end;
      Result := True;
    end
    else
    begin
      if Errp <> nil then
        Errp.WriteLn(_Fmt(MSG_CROSS_BUILD_FAILED, [TestResult.ErrorMessage]));
      Result := False;
    end;
  except
    on E: Exception do
    begin
      if Errp <> nil then
        Errp.WriteLn(_(MSG_ERROR) + ': ' + _Fmt(CMD_CROSS_EXCEPTION, ['building test', E.Message]));
      Result := False;
    end;
  end;
end;

end.
