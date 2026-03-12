program test_fpc_validator_runtimeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config,
  fpdev.output.intf,
  fpdev.fpc.validator,
  fpdev.paths,
  fpdev.i18n,
  fpdev.i18n.strings,
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
  TestConfigPath: string;
  ConfigManager: TFPDevConfigManager;
  Validator: TFPCValidator;
  PassCount: Integer = 0;
  FailCount: Integer = 0;

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

procedure AddToolchainInfo(const AVersion, ASourceURL: string; AInstallDate: TDateTime);
var
  Info: TToolchainInfo;
begin
  Initialize(Info);
  Info.Version := AVersion;
  Info.InstallPath := BuildVersionInstallPath(AVersion);
  Info.SourceURL := ASourceURL;
  Info.Installed := True;
  Info.InstallDate := AInstallDate;
  ConfigManager.AddToolchain('fpc-' + AVersion, Info);
end;

procedure BuildFakeFPC(const AVersion: string; AExitCode: Integer);
var
  SourcePath: string;
  SourceFile: TextFile;
  ExePath: string;
  CompileResult: TProcessResult;
begin
  ExePath := BuildVersionExecutablePath(AVersion);
  ForceDirectories(ExtractFileDir(ExePath));

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
  AddToolchainInfo('3.2.2', 'https://example.invalid/fpc-stable.git', EncodeDate(2026, 3, 9) + EncodeTime(10, 11, 12, 0));
  AddToolchainInfo('3.2.3', 'https://example.invalid/fpc-broken.git', EncodeDate(2026, 3, 9) + EncodeTime(13, 14, 15, 0));

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

begin
  try
    SetupSuiteEnvironment;
    TestShowVersionInfoUsesPlainEnglishLabels;
    TestShowVersionInfoReportsNotInstalledToOutput;
    TestTestInstallationReportsMissingVersion;
    TestTestInstallationReportsHealthyInstall;
    TestTestInstallationReportsIssues;
  finally
    TeardownSuiteEnvironment;
  end;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
