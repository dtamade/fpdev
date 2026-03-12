unit fpdev.fpc.validator;

{
================================================================================
  fpdev.fpc.validator - FPC Installation Validation Service
================================================================================

  Provides FPC installation verification and testing capabilities:
  - Executable existence check
  - Version detection and matching
  - Smoke test (compile and run hello world)
  - Installation health diagnostics

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
  SysUtils, Classes,
  fpdev.types,
  fpdev.config.interfaces, fpdev.output.intf, fpdev.utils.fs, fpdev.utils.process,
  fpdev.fpc.runtimeflow, fpdev.paths, fpdev.constants, fpdev.fpc.utils;

type
  { TVerificationResult - Result of installation verification }
  TVerificationResult = record
    Verified: Boolean;
    ExecutableExists: Boolean;
    DetectedVersion: string;
    SmokeTestPassed: Boolean;
    ErrorMessage: string;
  end;

  { TFPCValidator - FPC installation validation service }
  TFPCValidator = class
  private
    FConfigManager: IConfigManager;
    FInstallRoot: string;

    { Runs smoke test: compiles and executes hello world program.
      Updates VerifResult.SmokeTestPassed and ErrorMessage. }
    function RunSmokeTest(const AFPCExe: string; var VerifResult: TVerificationResult): Boolean;

    { Gets the installation path for a given FPC version. }
    function GetVersionInstallPath(const AVersion: string): string;

    { Gets the FPC executable path for a given version. }
    function GetFPCExecutablePath(const AVersion: string): string;
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
  fpdev.i18n.strings;

procedure WritePlainToolchainInfo(const AOut: IOutput; const AInfo: TToolchainInfo);
begin
  if AOut <> nil then
  begin
    AOut.WriteLn('Install Date: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', AInfo.InstallDate));
    AOut.WriteLn('Source URL: ' + AInfo.SourceURL);
  end;
end;

{$IFDEF MSWINDOWS}
const
  WINDOWS_CMD_SWITCH = '/c';
{$ENDIF}

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
  begin
    {$IFDEF MSWINDOWS}
    FInstallRoot := GetEnvironmentVariable('USERPROFILE') + PathDelim + '.fpdev';
    {$ELSE}
    FInstallRoot := GetEnvironmentVariable('HOME') + PathDelim + '.fpdev';
    {$ENDIF}
  end;
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

  // User scope: toolchains under InstallRoot.
  Result := BuildFPCInstallDirFromInstallRoot(FInstallRoot, AVersion);
end;

function TFPCValidator.GetFPCExecutablePath(const AVersion: string): string;
var
  InstallPath: string;
  RootDir: string;
  LegacyInstallPath: string;
  LegacyExe: string;
begin
  InstallPath := GetVersionInstallPath(AVersion);
  {$IFDEF MSWINDOWS}
  Result := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  Result := InstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}

  if FileExists(Result) then
    Exit;

  // Legacy fallback: <root>/fpc/<version>/bin/fpc(.exe)
  RootDir := ExtractFileDir(ExtractFileDir(ExtractFileDir(InstallPath)));
  if RootDir <> '' then
  begin
    LegacyInstallPath := RootDir + PathDelim + 'fpc' + PathDelim + AVersion;
    {$IFDEF MSWINDOWS}
    LegacyExe := LegacyInstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
    {$ELSE}
    LegacyExe := LegacyInstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
    {$ENDIF}
    if FileExists(LegacyExe) then
      Result := LegacyExe;
  end;
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

function TFPCValidator.VerifyInstallation(const AVersion: string; out VerifResult: TVerificationResult): Boolean;
var
  LResult: TProcessResult;
  FPCExe: string;
  DetectedVer: string;
  Lines: TStringList;
begin
  // Initialize result record
  Initialize(VerifResult);
  VerifResult.Verified := False;
  VerifResult.ExecutableExists := False;
  VerifResult.DetectedVersion := '';
  VerifResult.SmokeTestPassed := False;
  VerifResult.ErrorMessage := '';

  // Get FPC executable path
  FPCExe := GetFPCExecutablePath(AVersion);

  // Check if executable exists
  if not FileExists(FPCExe) then
  begin
    VerifResult.ErrorMessage := 'FPC executable not found: ' + FPCExe;
    Exit(False);
  end;

  VerifResult.ExecutableExists := True;

  try
    // Run fpc -iV to get version
    LResult := TProcessExecutor.Execute(FPCExe, ['-iV'], '');

    if LResult.Success then
    begin
      // Parse first line of output
      Lines := TStringList.Create;
      try
        Lines.Text := LResult.StdOut;
        if Lines.Count > 0 then
        begin
          DetectedVer := Trim(Lines[0]);
          VerifResult.DetectedVersion := DetectedVer;

          // Verify version matches
          if not SameText(DetectedVer, AVersion) then
          begin
            VerifResult.ErrorMessage := 'Version mismatch: expected ' + AVersion + ', detected ' + DetectedVer;
            Exit(False);
          end;
        end else begin
          VerifResult.ErrorMessage := 'No version output from fpc -iV';
          Exit(False);
        end;
      finally
        Lines.Free;
      end;
    end else begin
      VerifResult.ErrorMessage := 'fpc -iV failed with exit code: ' + IntToStr(LResult.ExitCode);
      Exit(False);
    end;

    // Run smoke test: compile and execute hello world
    if not RunSmokeTest(FPCExe, VerifResult) then
    begin
      VerifResult.Verified := False;
      Exit(False);
    end;

    // Verification successful
    VerifResult.Verified := True;
    Exit(True);

  except
    on E: Exception do
    begin
      VerifResult.ErrorMessage := 'Exception during verification: ' + E.Message;
      Exit(False);
    end;
  end;
end;

function TFPCValidator.RunSmokeTest(const AFPCExe: string; var VerifResult: TVerificationResult): Boolean;
var
  TempDir, HelloPas, HelloExe: string;
  HelloFile: TextFile;
  LResult: TProcessResult;
  Lines: TStringList;
  Output: string;
begin
  Result := False;
  VerifResult.SmokeTestPassed := False;

  try
    // Create temporary directory for smoke test
    TempDir := GetTempDir + 'fpdev_smoke_' + IntToStr(GetTickCount64);
    EnsureDir(TempDir);

    HelloPas := TempDir + PathDelim + 'hello.pas';
    {$IFDEF MSWINDOWS}
    HelloExe := TempDir + PathDelim + 'hello.exe';
    {$ELSE}
    HelloExe := TempDir + PathDelim + 'hello';
    {$ENDIF}

    // Create hello.pas
    AssignFile(HelloFile, HelloPas);
    try
      Rewrite(HelloFile);
      WriteLn(HelloFile, 'program hello;');
      WriteLn(HelloFile, 'begin');
      WriteLn(HelloFile, '  WriteLn(''Hello, World!'');');
      WriteLn(HelloFile, 'end.');
      CloseFile(HelloFile);
    except
      on E: Exception do
      begin
        VerifResult.ErrorMessage := 'Failed to create hello.pas: ' + E.Message;
        Exit(False);
      end;
    end;

    // Compile hello.pas
    LResult := TProcessExecutor.Execute(AFPCExe, ['-o' + HelloExe, HelloPas], '');
    if not LResult.Success then
    begin
      VerifResult.ErrorMessage :=
        'Smoke test: Failed to compile hello.pas (exit code: ' +
        IntToStr(LResult.ExitCode) + ')';
      Exit(False);
    end;

    // Check if executable was created
    if not FileExists(HelloExe) then
    begin
      VerifResult.ErrorMessage := 'Smoke test: Compiled executable not found: ' + HelloExe;
      Exit(False);
    end;

    // Run hello.exe and check output
    Lines := TStringList.Create;
    try
      {$IFDEF MSWINDOWS}
      // On Windows, check if a .bat file exists (mock environment)
      if FileExists(ChangeFileExt(HelloExe, '.bat')) then
        LResult := TProcessExecutor.Execute(
          'cmd.exe',
          [WINDOWS_CMD_SWITCH, ChangeFileExt(HelloExe, '.bat')],
          ''
        )
      else
        LResult := TProcessExecutor.Execute(HelloExe, [], '');
      {$ELSE}
      LResult := TProcessExecutor.Execute(HelloExe, [], '');
      {$ENDIF}

      if not LResult.Success then
      begin
        VerifResult.ErrorMessage := 'Smoke test: hello program failed (exit code: ' + IntToStr(LResult.ExitCode) + ')';
        Exit(False);
      end;

      // Check output
      Lines.Text := LResult.StdOut;
      if Lines.Count > 0 then
        Output := Trim(Lines[0])
      else
        Output := '';

      if Output <> 'Hello, World!' then
      begin
        VerifResult.ErrorMessage :=
          'Smoke test: Unexpected output. Expected ''Hello, World!'', got: ''' +
          Output + '''';
        Exit(False);
      end;

      // Smoke test passed!
      VerifResult.SmokeTestPassed := True;
      Result := True;

    finally
      Lines.Free;

      // Cleanup temporary files
      try
        if FileExists(HelloExe) then DeleteFile(HelloExe);
        if FileExists(HelloPas) then DeleteFile(HelloPas);
        RemoveDir(TempDir);
      except
        // Ignore cleanup errors
      end;
    end;

  except
    on E: Exception do
    begin
      VerifResult.ErrorMessage := 'Smoke test exception: ' + E.Message;
      Exit(False);
    end;
  end;
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
