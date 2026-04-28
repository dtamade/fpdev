unit fpdev.fpc.validator;

{
================================================================================
  fpdev.fpc.validator - FPC Installation Validation Service
================================================================================

  Provides FPC installation validation and diagnostics:
  - Install path / executable path resolution
  - Executable existence checks
  - Installation health diagnostics and info views

  Executable-level version verification and smoke testing are delegated to
  fpdev.fpc.verify.TFPCVerifier so the runtime verification logic stays in one place.

  This service is extracted from TFPCManager as part of the Facade pattern
  refactoring to reduce god class complexity.

  Usage:
    Validator := TFPCValidator.Create(ConfigManager);
    try
      if Validator.VerifyInstallation('3.2.2', VerifResult) then
        WriteLn('Installation verified: ', VerifResult.DetectedVersion);
    finally
      Validator.Free;
    end;

  Author: fafafaStudio
  Email: dtamade@gmail.com
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.types,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.process,
  fpdev.fpc.runtimeflow, fpdev.paths, fpdev.constants, fpdev.fpc.types,
  fpdev.fpc.utils;

type
  { TFPCValidator - FPC installation validation service }
  TFPCValidator = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;

    procedure InitializeVerificationResult(out VerifResult: TVerificationResult);
    function VerifyExecutable(const AFPCExe, AVersion: string;
      out VerifResult: TVerificationResult): Boolean;

    { Gets the installation path for a given FPC version. }
    function GetVersionInstallPath(const AVersion: string): string;

    { Gets the FPC executable path for a given version. }
    function GetFPCExecutablePath(const AVersion: string): string;
    function TryGetConfiguredInstallPath(const AVersion: string; out AInstallPath: string): Boolean;
    function LookupToolchainInfo(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
    function ExecuteInstalledFPCInfo(const AExecutable: string): TProcessResult;

  public
    constructor Create(AConfigManager: IConfigManager);

    { Verifies FPC installation completeness.
      Checks executable exists, version matches, and runs smoke test.
      AVersion: FPC version to verify
      VerifResult: Output record with verification details
      Returns: True if all verification checks pass }
    function VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;

    { Tests if FPC installation is functional.
      AVersion: FPC version to test
      Outp: Optional output stream for messages
      Errp: Optional error stream for messages
      Returns: True if installation is functional }
    function TestInstallation(const AVersion: string; Outp: IOutput = nil; Errp: IOutput = nil): Boolean;

    { Shows detailed version information.
      AVersion: FPC version to show info for
      Outp: Optional output stream for messages
      Returns: True if version info was displayed }
    function ShowVersionInfo(const AVersion: string; Outp: IOutput = nil): Boolean;

    { Checks if a version is installed (executable exists). }
    function IsVersionInstalled(const AVersion: string): Boolean;
  end;

implementation

uses
  fpdev.i18n.strings, fpdev.fpc.installversionflow, fpdev.fpc.verify;

procedure WritePlainToolchainInfo(const AOut: IOutput; const AInfo: TToolchainInfo);
begin
  if AOut <> nil then
  begin
    AOut.WriteLn('Install Date: ' + FormatToolchainInstallDate(AInfo.InstallDate));
    AOut.WriteLn('Source URL: ' + AInfo.SourceURL);
  end;
end;


{ TFPCValidator }

constructor TFPCValidator.Create(AConfigManager: IConfigManager);
var
  Settings: TFPDevSettings;
begin
  inherited Create;
  FConfigManager := AConfigManager;

  Settings := FConfigManager.GetSettingsManager.GetSettings;
  FInstallRoot := Settings.InstallRoot;

  if FInstallRoot = '' then
    FInstallRoot := GetDataRoot;
end;

function TFPCValidator.GetVersionInstallPath(const AVersion: string): string;
var
  Scope: TInstallScope;
  ProjectRoot: string;
begin
  // Resolve based on current scope.
  Scope := fpdev.fpc.utils.DetectInstallScope(GetCurrentDir);
  if Scope = isProject then
  begin
    ProjectRoot := fpdev.fpc.utils.FindProjectRoot(GetCurrentDir);
    if ProjectRoot <> '' then
    begin
      Result := ProjectRoot + PathDelim + FPDEV_CONFIG_DIR + PathDelim +
        'toolchains' + PathDelim + 'fpc' + PathDelim + AVersion;
      Exit;
    end;
  end;

  if TryGetConfiguredInstallPath(AVersion, Result) then
    Exit;

  // User scope: toolchains under InstallRoot.
  Result := BuildFPCInstallDirFromInstallRoot(FInstallRoot, AVersion);
end;

function TFPCValidator.TryGetConfiguredInstallPath(const AVersion: string;
  out AInstallPath: string): Boolean;
var
  Info: TToolchainInfo;
begin
  AInstallPath := '';
  Result := False;
  if not LookupToolchainInfo(AVersion, Info) then
    Exit;
  AInstallPath := Trim(Info.InstallPath);
  Result := AInstallPath <> '';
end;

function TFPCValidator.GetFPCExecutablePath(const AVersion: string): string;
var
  InstallPath: string;
begin
  InstallPath := ResolveInstalledFPCInstallPathCore(
    GetVersionInstallPath(AVersion),
    AVersion
  );
  Result := BuildFPCInstalledExecutablePathCore(InstallPath);
end;

function TFPCValidator.IsVersionInstalled(const AVersion: string): Boolean;
var
  FPCExe: string;
begin
  FPCExe := GetFPCExecutablePath(AVersion);
  Result := FileExists(FPCExe);
end;

function TFPCValidator.LookupToolchainInfo(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
begin
  Result := FConfigManager.GetToolchainManager.GetToolchain('fpc-' + AVersion, AInfo);
end;

function TFPCValidator.ExecuteInstalledFPCInfo(const AExecutable: string): TProcessResult;
begin
  Result := TProcessExecutor.Execute(AExecutable, ['-i'], '');
end;

procedure TFPCValidator.InitializeVerificationResult(out VerifResult: TVerificationResult);
begin
  VerifResult := Default(TVerificationResult);
  VerifResult.Verified := False;
  VerifResult.ExecutableExists := False;
  VerifResult.DetectedVersion := '';
  VerifResult.SmokeTestPassed := False;
  VerifResult.ErrorMessage := '';
end;

function TFPCValidator.VerifyExecutable(const AFPCExe, AVersion: string;
  out VerifResult: TVerificationResult): Boolean;
var
  Verifier: fpdev.fpc.verify.TFPCVerifier;
begin
  Result := False;
  InitializeVerificationResult(VerifResult);
  VerifResult.ExecutableExists := True;

  Verifier := fpdev.fpc.verify.TFPCVerifier.Create;
  try
    try
      if not Verifier.VerifyVersion(AFPCExe, AVersion) then
      begin
        VerifResult.ErrorMessage := Verifier.GetLastError;
        Exit(False);
      end;

      VerifResult.DetectedVersion := AVersion;
      if not Verifier.CompileHelloWorld(AFPCExe) then
      begin
        VerifResult.ErrorMessage := Verifier.GetLastError;
        Exit(False);
      end;

      VerifResult.SmokeTestPassed := True;
      VerifResult.Verified := True;
      Result := True;
    except
      on E: Exception do
      begin
        VerifResult.ErrorMessage := 'Exception during verification: ' + E.Message;
        Result := False;
      end;
    end;
  finally
    Verifier.Free;
  end;
end;

function TFPCValidator.VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
var
  FPCExe: string;
begin
  InitializeVerificationResult(VerifResult);

  FPCExe := GetFPCExecutablePath(AVersion);
  if not FileExists(FPCExe) then
  begin
    VerifResult.ErrorMessage := 'FPC executable not found: ' + FPCExe;
    Exit(False);
  end;

  Result := VerifyExecutable(FPCExe, AVersion, VerifResult);
end;

function TFPCValidator.TestInstallation(const AVersion: string; Outp: IOutput; Errp: IOutput): Boolean;
begin
  Result := ExecuteFPCTestInstallationCore(
    AVersion, Outp, Errp, @IsVersionInstalled, @GetVersionInstallPath, @ExecuteInstalledFPCInfo
  );
end;

function TFPCValidator.ShowVersionInfo(const AVersion: string; Outp: IOutput): Boolean;
begin
  Result := ExecuteFPCShowVersionInfoCore(
    AVersion, Outp, Outp, nil, @IsVersionInstalled, @GetVersionInstallPath,
    @LookupToolchainInfo, @WritePlainToolchainInfo
  );
end;

end.
