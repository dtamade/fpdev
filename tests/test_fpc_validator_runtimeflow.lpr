program test_fpc_validator_runtimeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.config,
  fpdev.output.intf,
  fpdev.fpc.validator,
  fpdev.fpc.installversionflow,
  fpdev.paths,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.utils,
  fpdev.utils.process,
  test_temp_paths;

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Contains(const S: string): Boolean;
    function Text: string;
  end;

var
  TempRootDir: string;
  InstallRootDir: string;
  Custom331InstallPath: string;
  TestConfigPath: string;
  ConfigManager: TFPDevConfigManager;
  Validator: TFPCValidator;
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure MakeExecutable(const APath: string);
begin
  {$IFDEF UNIX}
  if fpchmod(APath, &755) <> 0 then
    raise Exception.Create('failed to mark executable: ' + APath);
  {$ENDIF}
end;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TStringOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function BuildVersionInstallPath(const AVersion: string): string;
begin
  Result := BuildFPCInstallDirFromInstallRoot(InstallRootDir, AVersion);
end;

function BuildVersionExecutablePath(const AVersion: string): string;
begin
  {$IFDEF MSWINDOWS}
  Result := BuildVersionInstallPath(AVersion) + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  Result := BuildVersionInstallPath(AVersion) + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
end;

function BuildExecutablePathFromInstallPath(const AInstallPath: string): string;
begin
  {$IFDEF MSWINDOWS}
  Result := AInstallPath + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  Result := AInstallPath + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}
end;

procedure AddToolchainInfoAtPath(const AVersion, ASourceURL, AInstallPath: string; AInstallDate: TDateTime);
var
  Info: TToolchainInfo;
begin
  Initialize(Info);
  Info.Version := AVersion;
  Info.InstallPath := AInstallPath;
  Info.SourceURL := ASourceURL;
  Info.Installed := True;
  Info.InstallDate := AInstallDate;
  ConfigManager.AddToolchain('fpc-' + AVersion, Info);
end;

procedure AddToolchainInfo(const AVersion, ASourceURL: string; AInstallDate: TDateTime);
begin
  AddToolchainInfoAtPath(AVersion, ASourceURL, BuildVersionInstallPath(AVersion), AInstallDate);
end;

procedure BuildFakeFPCAtInstallPath(const AInstallPath, AVersion: string; AExitCode: Integer);
var
  ExePath: string;
  {$IFDEF MSWINDOWS}
  SourcePath: string;
  SourceFile: TextFile;
  CompileResult: TProcessResult;
  {$ELSE}
  ScriptLines: TStringList;
  {$ENDIF}
begin
  ExePath := BuildExecutablePathFromInstallPath(AInstallPath);
  ForceDirectories(ExtractFileDir(ExePath));

  {$IFNDEF MSWINDOWS}
  ScriptLines := TStringList.Create;
  try
    ScriptLines.Add('#!/bin/sh');
    ScriptLines.Add('echo "fake fpc ' + AVersion + '"');
    ScriptLines.Add('exit ' + IntToStr(AExitCode));
    ScriptLines.SaveToFile(ExePath);
  finally
    ScriptLines.Free;
  end;
  MakeExecutable(ExePath);
  Exit;
  {$ENDIF}

  {$IFDEF MSWINDOWS}
  SourcePath := IncludeTrailingPathDelimiter(TempRootDir) + 'fake_fpc_' + StringReplace(AVersion, '.', '_', [rfReplaceAll]) + '.lpr';
  AssignFile(SourceFile, SourcePath);
  try
    Rewrite(SourceFile);
    WriteLn(SourceFile, 'program fake_fpc;');
    WriteLn(SourceFile, '{$mode objfpc}{$H+}');
    WriteLn(SourceFile, 'begin');
    WriteLn(SourceFile, '  WriteLn(''fake fpc ' + AVersion + ''');');
    WriteLn(SourceFile, '  Halt(' + IntToStr(AExitCode) + ');');
    WriteLn(SourceFile, 'end.');
  finally
    CloseFile(SourceFile);
  end;

  CompileResult := TProcessExecutor.Execute('fpc', ['-o' + ExePath, SourcePath], TempRootDir);
  if not CompileResult.Success then
    raise Exception.Create('failed to build fake fpc for ' + AVersion + ': ' + CompileResult.StdErr + ' ' + CompileResult.ErrorMessage);
  {$ENDIF}
end;

procedure BuildFakeFPC(const AVersion: string; AExitCode: Integer);
begin
  BuildFakeFPCAtInstallPath(BuildVersionInstallPath(AVersion), AVersion, AExitCode);
end;

procedure SetupSuiteEnvironment;
var
  Settings: TFPDevSettings;
begin
  TempRootDir := CreateUniqueTempDir('fpdev-validator-runtimeflow');
  TestConfigPath := IncludeTrailingPathDelimiter(TempRootDir) + 'config.json';
  InstallRootDir := IncludeTrailingPathDelimiter(TempRootDir) + 'install-root';
  ForceDirectories(InstallRootDir);

  ConfigManager := TFPDevConfigManager.Create(TestConfigPath);
  if not ConfigManager.LoadConfig then
    ConfigManager.CreateDefaultConfig;

  Settings := ConfigManager.GetSettings;
  Settings.InstallRoot := InstallRootDir;
  ConfigManager.SetSettings(Settings);

  BuildFakeFPC('3.2.2', 0);
  BuildFakeFPC('3.2.3', 1);
  BuildFakeFPC('3.2.4', 0);
  Custom331InstallPath := IncludeTrailingPathDelimiter(TempRootDir) + 'custom-fpc-3.3.1';
  BuildFakeFPCAtInstallPath(Custom331InstallPath, '3.3.1', 0);
  AddToolchainInfo('3.2.2', 'https://example.invalid/fpc-stable.git', EncodeDate(2026, 3, 9) + EncodeTime(10, 11, 12, 0));
  AddToolchainInfo('3.2.3', 'https://example.invalid/fpc-broken.git', EncodeDate(2026, 3, 9) + EncodeTime(13, 14, 15, 0));
  AddToolchainInfo('3.2.4', 'https://example.invalid/fpc-metadata-missing.git', 0);
  AddToolchainInfoAtPath('3.3.1', 'https://example.invalid/fpc-customprefix.git', Custom331InstallPath,
    EncodeDate(2026, 3, 9) + EncodeTime(16, 17, 18, 0));

  Validator := TFPCValidator.Create(ConfigManager.AsConfigManager);
end;

procedure TeardownSuiteEnvironment;
begin
  if Assigned(Validator) then
    Validator.Free;
  if Assigned(ConfigManager) then
    ConfigManager.Free;
  CleanupTempDir(TempRootDir);
end;

procedure TestShowVersionInfoUsesPlainEnglishLabels;
var
  OutBuffer: TStringOutput;
  Outp: IOutput;
  Success: Boolean;
  ExpectedDate: string;
begin
  OutBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  ExpectedDate := '2026-03-09 10:11:12';
  Success := Validator.ShowVersionInfo('3.2.2', Outp);
  Check('validator show info succeeds for installed version', Success, 'unexpected failure');
  Check('validator show info uses plain install date label', OutBuffer.Contains('Install Date: ' + ExpectedDate), OutBuffer.Text);
  Check('validator show info uses plain source url label', OutBuffer.Contains('Source URL: https://example.invalid/fpc-stable.git'), OutBuffer.Text);
end;

procedure TestShowVersionInfoFormatsMissingInstallDateAsUnknown;
var
  OutBuffer: TStringOutput;
  Outp: IOutput;
  Success: Boolean;
begin
  OutBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Success := Validator.ShowVersionInfo('3.2.4', Outp);
  Check('validator show info succeeds when install date missing', Success, 'unexpected failure');
  Check('validator show info prints unknown install date when metadata missing',
    OutBuffer.Contains('Install Date: unknown'), OutBuffer.Text);
  Check('validator show info prints source url when install date missing',
    OutBuffer.Contains('Source URL: https://example.invalid/fpc-metadata-missing.git'), OutBuffer.Text);
end;

procedure TestShowVersionInfoReportsNotInstalledToOutput;
var
  OutBuffer: TStringOutput;
  Outp: IOutput;
  Success: Boolean;
begin
  OutBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Success := Validator.ShowVersionInfo('9.9.9', Outp);
  Check('validator show info returns true when version not installed', Success, 'unexpected failure');
  Check('validator show info reports not installed', OutBuffer.Contains(_Fmt(ERR_NOT_INSTALLED, ['FPC 9.9.9'])), OutBuffer.Text);
end;

procedure TestTestInstallationReportsMissingVersion;
var
  OutBuffer, ErrBuffer: TStringOutput;
  Outp, Errp: IOutput;
  Success: Boolean;
begin
  OutBuffer := TStringOutput.Create;
  ErrBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Errp := ErrBuffer as IOutput;
  Success := Validator.TestInstallation('9.9.9', Outp, Errp);
  Check('validator test installation fails for missing version', not Success, 'unexpected success');
  Check('validator test installation reports missing version', ErrBuffer.Contains(_Fmt(CMD_FPC_USE_NOT_FOUND, ['9.9.9'])), ErrBuffer.Text);
end;

procedure TestTestInstallationReportsHealthyInstall;
var
  OutBuffer, ErrBuffer: TStringOutput;
  Outp, Errp: IOutput;
  Success: Boolean;
begin
  OutBuffer := TStringOutput.Create;
  ErrBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Errp := ErrBuffer as IOutput;
  Success := Validator.TestInstallation('3.2.2', Outp, Errp);
  Check('validator test installation succeeds for healthy fake compiler', Success, 'unexpected failure');
  Check('validator test installation writes checking', OutBuffer.Contains(_Fmt(CMD_FPC_DOCTOR_CHECKING, ['3.2.2'])), OutBuffer.Text);
  Check('validator test installation writes ok', OutBuffer.Contains(_(CMD_FPC_DOCTOR_OK)), OutBuffer.Text);
end;

procedure TestTestInstallationUsesConfiguredCustomPrefix;
var
  OutBuffer, ErrBuffer: TStringOutput;
  Outp, Errp: IOutput;
  Success: Boolean;
begin
  OutBuffer := TStringOutput.Create;
  ErrBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Errp := ErrBuffer as IOutput;
  Success := Validator.TestInstallation('3.3.1', Outp, Errp);
  Check('validator test installation succeeds for configured custom prefix', Success,
    ErrBuffer.Text + LineEnding + OutBuffer.Text);
  Check('validator test installation writes checking for configured custom prefix',
    OutBuffer.Contains(_Fmt(CMD_FPC_DOCTOR_CHECKING, ['3.3.1'])), OutBuffer.Text);
  Check('validator test installation writes ok for configured custom prefix',
    OutBuffer.Contains(_(CMD_FPC_DOCTOR_OK)), OutBuffer.Text);
end;

procedure TestTestInstallationReportsIssues;
var
  OutBuffer, ErrBuffer: TStringOutput;
  Outp, Errp: IOutput;
  Success: Boolean;
begin
  OutBuffer := TStringOutput.Create;
  ErrBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Errp := ErrBuffer as IOutput;
  Success := Validator.TestInstallation('3.2.3', Outp, Errp);
  Check('validator test installation fails for broken fake compiler', not Success, 'unexpected success');
  Check('validator test installation writes issues', ErrBuffer.Contains(_Fmt(CMD_FPC_DOCTOR_ISSUES, [1])), ErrBuffer.Text);
end;

procedure TestTestInstallationUsesSameProcessHomeFallback;
var
  LocalConfig: TFPDevConfigManager;
  LocalValidator: TFPCValidator;
  LocalSettings: TFPDevSettings;
  LocalConfigPath: string;
  ProbeHome: string;
  ProbeWorkDir: string;
  CurrentDir: string;
  Version: string;
  InstallRoot: string;
  InstallPath: string;
  OutBuffer, ErrBuffer: TStringOutput;
  Outp, Errp: IOutput;
  Success: Boolean;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
  {$IFDEF MSWINDOWS}
  SavedUserProfile: string;
  SavedAppData: string;
  {$ELSE}
  SavedHome: string;
  {$ENDIF}
begin
  ProbeHome := CreateUniqueTempDir('fpdev-validator-home');
  ProbeWorkDir := CreateUniqueTempDir('fpdev-validator-cwd');
  LocalConfigPath := IncludeTrailingPathDelimiter(ProbeWorkDir) + 'config.json';
  LocalConfig := nil;
  LocalValidator := nil;
  Version := '4.4.4';
  CurrentDir := GetCurrentDir;
  OutBuffer := TStringOutput.Create;
  ErrBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Errp := ErrBuffer as IOutput;

  {$IFDEF MSWINDOWS}
  SavedUserProfile := get_env('USERPROFILE');
  SavedAppData := get_env('APPDATA');
  {$ELSE}
  SavedHome := get_env('HOME');
  {$ENDIF}
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  try
    SetPortableMode(False);
    unset_env('FPDEV_DATA_ROOT');
    unset_env('XDG_DATA_HOME');

    LocalConfig := TFPDevConfigManager.Create(LocalConfigPath);
    if not LocalConfig.LoadConfig then
      LocalConfig.CreateDefaultConfig;
    LocalSettings := LocalConfig.GetSettings;
    LocalSettings.InstallRoot := '';
    LocalConfig.SetSettings(LocalSettings);

    {$IFDEF MSWINDOWS}
    set_env('USERPROFILE', ProbeHome);
    set_env('APPDATA', ProbeHome);
    {$ELSE}
    set_env('HOME', ProbeHome);
    {$ENDIF}
    InstallRoot := GetDataRoot;
    InstallPath := BuildFPCInstallDirFromInstallRoot(InstallRoot, Version);
    BuildFakeFPCAtInstallPath(InstallPath, Version, 0);

    if not SetCurrentDir(ProbeWorkDir) then
      raise Exception.Create('failed to change current directory to probe work dir');

    LocalValidator := TFPCValidator.Create(LocalConfig.AsConfigManager);
    Success := LocalValidator.TestInstallation(Version, Outp, Errp);
    Check('validator test installation uses same-process home fallback', Success,
      ErrBuffer.Text + LineEnding + OutBuffer.Text);
    Check('validator test installation writes checking for same-process home fallback',
      OutBuffer.Contains(_Fmt(CMD_FPC_DOCTOR_CHECKING, [Version])), OutBuffer.Text);
    Check('validator test installation writes ok for same-process home fallback',
      OutBuffer.Contains(_(CMD_FPC_DOCTOR_OK)), OutBuffer.Text);
  finally
    if LocalValidator <> nil then
      LocalValidator.Free;
    if LocalConfig <> nil then
      LocalConfig.Free;
    SetCurrentDir(CurrentDir);
    {$IFDEF MSWINDOWS}
    RestoreEnv('USERPROFILE', SavedUserProfile);
    RestoreEnv('APPDATA', SavedAppData);
    {$ELSE}
    RestoreEnv('HOME', SavedHome);
    {$ENDIF}
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    CleanupTempDir(ProbeWorkDir);
    CleanupTempDir(ProbeHome);
  end;
end;

procedure TestTestInstallationUsesFPDEVDataRootOverride;
var
  LocalConfig: TFPDevConfigManager;
  LocalValidator: TFPCValidator;
  LocalSettings: TFPDevSettings;
  LocalConfigPath: string;
  ProbeDataRoot: string;
  ProbeWorkDir: string;
  CurrentDir: string;
  Version: string;
  InstallRoot: string;
  InstallPath: string;
  OutBuffer, ErrBuffer: TStringOutput;
  Outp, Errp: IOutput;
  Success: Boolean;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
begin
  ProbeDataRoot := CreateUniqueTempDir('fpdev-validator-data-root');
  ProbeWorkDir := CreateUniqueTempDir('fpdev-validator-data-cwd');
  LocalConfigPath := IncludeTrailingPathDelimiter(ProbeWorkDir) + 'config.json';
  LocalConfig := nil;
  LocalValidator := nil;
  Version := '5.5.5';
  CurrentDir := GetCurrentDir;
  OutBuffer := TStringOutput.Create;
  ErrBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Errp := ErrBuffer as IOutput;
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  try
    SetPortableMode(False);
    unset_env('XDG_DATA_HOME');
    set_env('FPDEV_DATA_ROOT', ProbeDataRoot);
    InstallRoot := GetDataRoot;
    InstallPath := BuildFPCInstallDirFromInstallRoot(InstallRoot, Version);
    BuildFakeFPCAtInstallPath(InstallPath, Version, 0);

    LocalConfig := TFPDevConfigManager.Create(LocalConfigPath);
    if not LocalConfig.LoadConfig then
      LocalConfig.CreateDefaultConfig;
    LocalSettings := LocalConfig.GetSettings;
    LocalSettings.InstallRoot := '';
    LocalConfig.SetSettings(LocalSettings);

    if not SetCurrentDir(ProbeWorkDir) then
      raise Exception.Create('failed to change current directory to probe work dir');

    LocalValidator := TFPCValidator.Create(LocalConfig.AsConfigManager);
    Success := LocalValidator.TestInstallation(Version, Outp, Errp);
    Check('validator test installation uses FPDEV_DATA_ROOT override', Success,
      ErrBuffer.Text + LineEnding + OutBuffer.Text);
    Check('validator test installation writes checking for FPDEV_DATA_ROOT override',
      OutBuffer.Contains(_Fmt(CMD_FPC_DOCTOR_CHECKING, [Version])), OutBuffer.Text);
    Check('validator test installation writes ok for FPDEV_DATA_ROOT override',
      OutBuffer.Contains(_(CMD_FPC_DOCTOR_OK)), OutBuffer.Text);
  finally
    if LocalValidator <> nil then
      LocalValidator.Free;
    if LocalConfig <> nil then
      LocalConfig.Free;
    SetCurrentDir(CurrentDir);
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    CleanupTempDir(ProbeWorkDir);
    CleanupTempDir(ProbeDataRoot);
  end;
end;

begin
  try
    SetupSuiteEnvironment;
    TestShowVersionInfoUsesPlainEnglishLabels;
    TestShowVersionInfoFormatsMissingInstallDateAsUnknown;
    TestShowVersionInfoReportsNotInstalledToOutput;
    TestTestInstallationReportsMissingVersion;
    TestTestInstallationReportsHealthyInstall;
    TestTestInstallationUsesConfiguredCustomPrefix;
    TestTestInstallationReportsIssues;
    TestTestInstallationUsesSameProcessHomeFallback;
    TestTestInstallationUsesFPDEVDataRootOverride;
  finally
    TeardownSuiteEnvironment;
  end;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
