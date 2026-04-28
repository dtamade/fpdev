program test_lazarus_runtimeactions;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.config.interfaces,
  fpdev.fpc.installversionflow,
  fpdev.lazarus.pathflow,
  fpdev.lazarus.runtimeactions,
  fpdev.output.intf,
  fpdev.paths,
  fpdev.utils,
  test_config_isolation,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  TestRootDir: string = '';
  ConfigManager: IConfigManager;

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

  TRuntimeHarness = class
  public
    InstalledValue: Boolean;
    ResolvedInstallPathValue: string;
    CompatibleFPCVersionValue: string;
    LaunchResult: Boolean;
    LastInstalledCheckVersion: string;
    LastResolvedInstallVersion: string;
    LastCompatibleFPCVersionRequest: string;
    LastLaunchExecutable: string;
    function IsVersionInstalled(const AVersion: string): Boolean;
    function ResolveInstallPath(const AVersion: string): string;
    function ResolveCompatibleFPCVersion(const AVersion: string): string;
    function ResolveExecutablePath(const AInstallPath: string): string;
    function LaunchExecutable(const AExecutable: string): Boolean;
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

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TRuntimeHarness.IsVersionInstalled(const AVersion: string): Boolean;
begin
  LastInstalledCheckVersion := AVersion;
  Result := InstalledValue;
end;

function TRuntimeHarness.ResolveInstallPath(const AVersion: string): string;
begin
  LastResolvedInstallVersion := AVersion;
  Result := ResolvedInstallPathValue;
end;

function TRuntimeHarness.ResolveCompatibleFPCVersion(
  const AVersion: string): string;
begin
  LastCompatibleFPCVersionRequest := AVersion;
  Result := CompatibleFPCVersionValue;
end;

function TRuntimeHarness.ResolveExecutablePath(const AInstallPath: string): string;
begin
  Result := BuildLazarusExecutablePathFromInstallPathCore(
    AInstallPath,
    {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}
  );
end;

function TRuntimeHarness.LaunchExecutable(const AExecutable: string): Boolean;
begin
  LastLaunchExecutable := AExecutable;
  Result := LaunchResult;
end;

procedure MakeExecutable(const APath: string);
begin
  {$IFDEF UNIX}
  if fpchmod(APath, &755) <> 0 then
    raise Exception.Create('Failed to mark executable: ' + APath);
  {$ENDIF}
end;

procedure WriteMockExecutable(const APath, ALabel: string);
begin
  ForceDirectories(ExtractFileDir(APath));
  with TStringList.Create do
  try
    {$IFDEF UNIX}
    Add('#!/bin/sh');
    Add('echo "' + ALabel + '"');
    {$ELSE}
    Add('@echo off');
    {$ENDIF}
    SaveToFile(APath);
  finally
    Free;
  end;
  MakeExecutable(APath);
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure InitTestEnvironment;
var
  Settings: TFPDevSettings;
begin
  TestRootDir := CreateUniqueTempDir('test_lazarus_runtimeactions');
  ConfigManager := CreateIsolatedConfigManager;
  Settings := ConfigManager.GetSettingsManager.GetSettings;
  Settings.InstallRoot := TestRootDir;
  ConfigManager.GetSettingsManager.SetSettings(Settings);
end;

procedure CleanupTestEnvironment;
begin
  ConfigManager := nil;
  CleanupTempDir(TestRootDir);
end;

procedure TestTestLazarusInstallationCoreUsesConfiguredCustomInstallPath;
var
  Harness: TRuntimeHarness;
  OutBuffer: TStringOutput;
  ErrBuffer: TStringOutput;
  Outp: IOutput;
  Errp: IOutput;
  ExecutablePath: string;
begin
  Harness := TRuntimeHarness.Create;
  OutBuffer := TStringOutput.Create;
  ErrBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Errp := ErrBuffer as IOutput;
  try
    Harness.InstalledValue := True;
    Harness.ResolvedInstallPathValue := TestRootDir + PathDelim + 'custom-lazarus-3.9';
    ExecutablePath := Harness.ResolveExecutablePath(Harness.ResolvedInstallPathValue);
    WriteMockExecutable(ExecutablePath, 'lazarus 3.9 custom');

    Check(
      'runtime helper test installation succeeds for configured custom install path',
      TestLazarusInstallationCore(
        Outp,
        Errp,
        '3.9',
        @Harness.IsVersionInstalled,
        @Harness.ResolveInstallPath,
        @Harness.ResolveExecutablePath
      ),
      'expected test installation helper to succeed'
    );
    Check(
      'runtime helper resolves configured custom install version',
      Harness.LastResolvedInstallVersion = '3.9',
      'version=' + Harness.LastResolvedInstallVersion
    );
    Check(
      'runtime helper emits passing version test message',
      OutBuffer.Contains('3.9'),
      'stdout=' + OutBuffer.Text
    );
    Check(
      'runtime helper keeps error output empty on success',
      Trim(ErrBuffer.Text) = '',
      'stderr=' + ErrBuffer.Text
    );
  finally
    Outp := nil;
    Errp := nil;
    Harness.Free;
  end;
end;

procedure TestLaunchLazarusIDECoreUsesDefaultConfiguredVersion;
var
  Harness: TRuntimeHarness;
  OutBuffer: TStringOutput;
  Outp: IOutput;
  Success: Boolean;
  ExpectedExecutable: string;
begin
  Harness := TRuntimeHarness.Create;
  OutBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  try
    Harness.InstalledValue := True;
    Harness.LaunchResult := True;
    Harness.ResolvedInstallPathValue := TestRootDir + PathDelim + 'custom-lazarus-4.1';
    ExpectedExecutable := Harness.ResolveExecutablePath(Harness.ResolvedInstallPathValue);

    Success := LaunchLazarusIDECore(
      TestRootDir,
      '',
      '4.1',
      Outp,
      @Harness.ResolveInstallPath,
      @Harness.ResolveExecutablePath,
      @Harness.IsVersionInstalled,
      @Harness.LaunchExecutable
    );

    Check(
      'runtime helper launch succeeds for default configured version',
      Success,
      'expected launch helper to succeed'
    );
    Check(
      'runtime helper launch checks current version when requested version is empty',
      Harness.LastInstalledCheckVersion = '4.1',
      'version=' + Harness.LastInstalledCheckVersion
    );
    Check(
      'runtime helper launch resolves current version install path',
      Harness.LastResolvedInstallVersion = '4.1',
      'version=' + Harness.LastResolvedInstallVersion
    );
    Check(
      'runtime helper launch executes resolved custom executable',
      Harness.LastLaunchExecutable = ExpectedExecutable,
      'executable=' + Harness.LastLaunchExecutable
    );
  finally
    Outp := nil;
    Harness.Free;
  end;
end;

procedure TestConfigureLazarusIDECoreUsesConfiguredFPCVersionAndConfigRoot;
var
  Harness: TRuntimeHarness;
  OutBuffer: TStringOutput;
  ErrBuffer: TStringOutput;
  Outp: IOutput;
  Errp: IOutput;
  SavedConfigRoot: string;
  ConfigRoot: string;
  FPCInstallDir: string;
  FPCExecutablePath: string;
  EnvironmentOptionsPath: string;
  EnvironmentOptionsText: TStringList;
begin
  Harness := TRuntimeHarness.Create;
  OutBuffer := TStringOutput.Create;
  ErrBuffer := TStringOutput.Create;
  Outp := OutBuffer as IOutput;
  Errp := ErrBuffer as IOutput;
  SavedConfigRoot := GetEnvironmentVariable('FPDEV_LAZARUS_CONFIG_ROOT');
  try
    Harness.InstalledValue := True;
    Harness.ResolvedInstallPathValue := TestRootDir + PathDelim + 'custom-lazarus-3.7-configure';
    Harness.CompatibleFPCVersionValue := '3.0.4';
    ForceDirectories(Harness.ResolvedInstallPathValue);

    ConfigRoot := TestRootDir + PathDelim + 'runtime-config-root';
    if not set_env('FPDEV_LAZARUS_CONFIG_ROOT', ConfigRoot) then
      raise Exception.Create('Failed to set FPDEV_LAZARUS_CONFIG_ROOT');

    FPCInstallDir := BuildFPCInstallDirFromInstallRoot(TestRootDir, '3.0.4');
    FPCExecutablePath := BuildFPCInstalledExecutablePathCore(FPCInstallDir);
    WriteMockExecutable(FPCExecutablePath, 'fpc 3.0.4');

    Check(
      'runtime helper configure succeeds with configured FPC version override',
      ConfigureLazarusIDECore(
        ConfigManager,
        Outp,
        Errp,
        '3.7',
        @Harness.IsVersionInstalled,
        @Harness.ResolveInstallPath,
        @Harness.ResolveCompatibleFPCVersion
      ),
      'expected configure helper to succeed'
    );
    Check(
      'runtime helper configure requests configured FPC version for target version',
      Harness.LastCompatibleFPCVersionRequest = '3.7',
      'version=' + Harness.LastCompatibleFPCVersionRequest
    );
    Check(
      'runtime helper configure uses custom config root',
      DirectoryExists(ConfigRoot + PathDelim + '.lazarus-3.7'),
      'missing config dir under custom config root'
    );
    Check(
      'runtime helper configure writes compiler path for configured FPC version',
      OutBuffer.Contains(FPCExecutablePath),
      'stdout=' + OutBuffer.Text
    );
    EnvironmentOptionsPath := ConfigRoot + PathDelim + '.lazarus-3.7' +
      PathDelim + 'environmentoptions.xml';
    Check(
      'runtime helper configure writes environment options file',
      FileExists(EnvironmentOptionsPath),
      'missing environmentoptions.xml'
    );
    if FileExists(EnvironmentOptionsPath) then
    begin
      EnvironmentOptionsText := TStringList.Create;
      try
        EnvironmentOptionsText.LoadFromFile(EnvironmentOptionsPath);
        Check(
          'runtime helper configure persists configured fpc executable path',
          Pos(FPCExecutablePath, EnvironmentOptionsText.Text) > 0,
          'environmentoptions=' + EnvironmentOptionsText.Text
        );
      finally
        EnvironmentOptionsText.Free;
      end;
    end;
  finally
    RestoreEnv('FPDEV_LAZARUS_CONFIG_ROOT', SavedConfigRoot);
    Outp := nil;
    Errp := nil;
    Harness.Free;
  end;
end;

begin
  WriteLn('=== Lazarus Runtime Actions Tests ===');

  InitTestEnvironment;
  try
    TestTestLazarusInstallationCoreUsesConfiguredCustomInstallPath;
    TestLaunchLazarusIDECoreUsesDefaultConfiguredVersion;
    TestConfigureLazarusIDECoreUsesConfiguredFPCVersionAndConfigRoot;
  finally
    CleanupTestEnvironment;
  end;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
