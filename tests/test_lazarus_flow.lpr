program test_lazarus_flow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  test_temp_paths,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.lazarus.config,
  fpdev.lazarus.commandflow;

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

  TLazarusInstallProbe = class
  public
    DownloadSuccess: Boolean;
    BuildSuccess: Boolean;
    SetupSuccess: Boolean;
    ConfigureSuccess: Boolean;
    DownloadCalls: Integer;
    BuildCalls: Integer;
    SetupCalls: Integer;
    ConfigureCalls: Integer;
    LastDownloadVersion: string;
    LastDownloadDir: string;
    LastBuildSourceDir: string;
    LastBuildInstallDir: string;
    LastBuildFPCVersion: string;
    LastSetupVersion: string;
    LastConfigureVersion: string;
    function Download(const AVersion, ATargetDir: string): Boolean;
    function Build(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean;
    function Setup(const AVersion: string): Boolean;
    function Configure(const Outp, Errp: IOutput; const AVersion: string): Boolean;
  end;

var
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

function TLazarusInstallProbe.Download(const AVersion, ATargetDir: string): Boolean;
begin
  Inc(DownloadCalls);
  LastDownloadVersion := AVersion;
  LastDownloadDir := ATargetDir;
  Result := DownloadSuccess;
end;

function TLazarusInstallProbe.Build(const ASourceDir, AInstallDir, AFPCVersion: string): Boolean;
begin
  Inc(BuildCalls);
  LastBuildSourceDir := ASourceDir;
  LastBuildInstallDir := AInstallDir;
  LastBuildFPCVersion := AFPCVersion;
  Result := BuildSuccess;
end;

function TLazarusInstallProbe.Setup(const AVersion: string): Boolean;
begin
  Inc(SetupCalls);
  LastSetupVersion := AVersion;
  Result := SetupSuccess;
end;

function TLazarusInstallProbe.Configure(const Outp, Errp: IOutput; const AVersion: string): Boolean;
begin
  Inc(ConfigureCalls);
  LastConfigureVersion := AVersion;
  Result := ConfigureSuccess;
  if Outp = nil then;
  if Errp = nil then;
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

procedure WriteFile(const APath, AContent: string);
var
  Stream: TFileStream;
  Bytes: RawByteString;
begin
  ForceDirectories(ExtractFileDir(APath));
  Stream := TFileStream.Create(APath, fmCreate);
  try
    Bytes := RawByteString(AContent);
    if Length(Bytes) > 0 then
      Stream.WriteBuffer(Bytes[1], Length(Bytes));
  finally
    Stream.Free;
  end;
end;

procedure TestCreateLazarusInstallPlanCoreUsesRequestedFPCVersion;
var
  Plan: TLazarusInstallPlan;
begin
  Plan := CreateLazarusInstallPlanCore('/tmp/fpdev-data', '3.2', '3.2.2', '3.2.0', True, True);
  Check('install plan uses requested fpc version',
    Plan.FPCVersion = '3.2.2',
    'got=' + Plan.FPCVersion);
  Check('install plan keeps source mode', not Plan.NeedsSourceFallbackWarning);
  Check('install plan source dir uses version suffix',
    Pos('lazarus-3.2', Plan.SourceDir) > 0,
    'source=' + Plan.SourceDir);
end;

procedure TestCreateLazarusInstallPlanCoreFallsBackToRecommendedVersion;
var
  Plan: TLazarusInstallPlan;
begin
  Plan := CreateLazarusInstallPlanCore('/tmp/fpdev-data', '3.0', '', '3.2.2', False, False);
  Check('install plan falls back to recommended fpc',
    Plan.FPCVersion = '3.2.2',
    'got=' + Plan.FPCVersion);
  Check('install plan marks binary fallback warning', Plan.NeedsSourceFallbackWarning);
  Check('install plan can disable configure', not Plan.ConfigureAfterInstall);
end;

procedure TestExecuteLazarusInstallPlanCoreReportsDownloadFailure;
var
  Plan: TLazarusInstallPlan;
  Probe: TLazarusInstallProbe;
  Errp: TStringOutput;
begin
  Plan := CreateLazarusInstallPlanCore('/tmp/fpdev-data', '3.0', '', '3.2.2', True, False);
  Probe := TLazarusInstallProbe.Create;
  Errp := TStringOutput.Create;
  try
    Probe.DownloadSuccess := False;
    Probe.BuildSuccess := True;
    Probe.SetupSuccess := True;
    Probe.ConfigureSuccess := True;

    Check('install flow download failure returns false',
      not ExecuteLazarusInstallPlanCore(Plan, nil, Errp, @Probe.Download, @Probe.Build, @Probe.Setup, @Probe.Configure));
    Check('install flow download failure logs localized error',
      Errp.Contains(_(CMD_LAZARUS_SOURCE_DOWNLOAD_FAILED)),
      Errp.Text);
    Check('install flow download failure short-circuits build', Probe.BuildCalls = 0);
  finally
    Errp.Free;
    Probe.Free;
  end;
end;

procedure TestExecuteLazarusInstallPlanCoreTreatsConfigureFailureAsWarning;
var
  Plan: TLazarusInstallPlan;
  Probe: TLazarusInstallProbe;
  Outp, Errp: TStringOutput;
begin
  Plan := CreateLazarusInstallPlanCore('/tmp/fpdev-data', '3.1', '', '3.2.2', False, True);
  Probe := TLazarusInstallProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Probe.DownloadSuccess := True;
    Probe.BuildSuccess := True;
    Probe.SetupSuccess := True;
    Probe.ConfigureSuccess := False;

    Check('install flow configure warning remains success',
      ExecuteLazarusInstallPlanCore(Plan, Outp, Errp, @Probe.Download, @Probe.Build, @Probe.Setup, @Probe.Configure));
    Check('install flow emits binary fallback warning',
      Outp.Contains('fallback to source build'),
      Outp.Text);
    Check('install flow invokes configure callback', Probe.ConfigureCalls = 1);
    Check('install flow reports manual configure hint',
      Errp.Contains('fpdev lazarus configure 3.1'),
      Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestResolveLazarusConfigDirCoreUsesExplicitRoot;
var
  ConfigDir: string;
begin
  ConfigDir := ResolveLazarusConfigDirCore('3.3', '/tmp/laz-root', '/home/demo', '/appdata/demo');
  Check('config dir uses explicit root',
    Pos('/tmp/laz-root', ConfigDir) = 1,
    'config=' + ConfigDir);
  Check('config dir suffix includes version', Pos('3.3', ConfigDir) > 0, 'config=' + ConfigDir);
end;

procedure TestCreateLazarusBuildPlanCoreWindowsUsesMingwAndExe;
var
  Plan: TLazarusBuildPlan;
  ExpectedBinDir: string;
begin
  Plan := CreateLazarusBuildPlanCore(
    '/tmp/lazarus-src',
    '/tmp/lazarus-install',
    '/tmp/settings-root',
    '3.2.2',
    8,
    'mingw32-make',
    'C:\\Windows\\System32',
    True
  );

  ExpectedBinDir := '/tmp/settings-root' + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'bin';

  Check('build plan keeps source dir', Plan.SourceDir = '/tmp/lazarus-src', 'source=' + Plan.SourceDir);
  Check('build plan keeps install dir', Plan.InstallDir = '/tmp/lazarus-install', 'install=' + Plan.InstallDir);
  Check('windows build plan uses mingw32-make', Plan.MakeCommand = 'mingw32-make', 'make=' + Plan.MakeCommand);
  Check('windows build plan appends .exe to fpc executable',
    Plan.FPCExecutable = ExpectedBinDir + PathDelim + 'fpc.exe',
    'fpc=' + Plan.FPCExecutable);
  Check('windows build plan passes FPC executable in params',
    Pos('FPC=' + ExpectedBinDir + PathDelim + 'fpc.exe', Plan.Params[3]) = 1,
    'param=' + Plan.Params[3]);
  Check('windows build plan prepends fpc bin to PATH',
    Plan.EnvVars[0] = 'PATH=' + ExpectedBinDir + PathSeparator + 'C:\\Windows\\System32',
    'env=' + Plan.EnvVars[0]);
end;

procedure TestCreateLazarusBuildPlanCoreUnixKeepsPlainFPCAndDeduplicatesStableToolPath;
var
  Plan: TLazarusBuildPlan;
  ExpectedBinDir: string;
begin
  Plan := CreateLazarusBuildPlanCore(
    '/tmp/lazarus-src',
    '/tmp/lazarus-install',
    '/tmp/settings-root',
    '3.2.2',
    4,
    'gmake',
    '/usr/bin',
    False
  );

  ExpectedBinDir := '/tmp/settings-root' + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'bin';

  Check('unix build plan uses provided make command', Plan.MakeCommand = 'gmake', 'make=' + Plan.MakeCommand);
  Check('unix build plan keeps plain fpc executable',
    Plan.FPCExecutable = ExpectedBinDir + PathDelim + 'fpc',
    'fpc=' + Plan.FPCExecutable);
  Check('unix build plan forces serial jobs for stability',
    Plan.Params[4] = '-j1',
    'jobs=' + Plan.Params[4]);
  Check('unix build plan prepends stable tool PATH without duplicate /usr/bin',
    Plan.EnvVars[0] = 'PATH=' + ExpectedBinDir + PathSeparator + '/usr/bin' + PathSeparator + '/bin',
    'env=' + Plan.EnvVars[0]);
  Check('unix build plan pins install tool',
    Plan.EnvVars[1] = 'INSTALL=/usr/bin/install',
    'install=' + Plan.EnvVars[1]);
end;

procedure TestApplyLazarusConfigurePlanCoreWritesExpectedPaths;
var
  TempDir: string;
  InstallPath: string;
  SettingsRoot: string;
  ConfigRoot: string;
  FPCBinDir: string;
  FPCExe: string;
  FPCSourceDir: string;
  Plan: TLazarusConfigurePlan;
  IDEConfig: TLazarusIDEConfig;
  Outp, Errp: TStringOutput;
begin
  TempDir := CreateUniqueTempDir('lazarus-flow-config');
  try
    InstallPath := TempDir + PathDelim + 'lazarus' + PathDelim + '3.4';
    SettingsRoot := TempDir + PathDelim + 'data';
    ConfigRoot := TempDir + PathDelim + 'config-root';
    FPCBinDir := SettingsRoot + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2' + PathDelim + 'bin';
    FPCSourceDir := SettingsRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
    ForceDirectories(InstallPath);
    ForceDirectories(FPCBinDir);
    ForceDirectories(FPCSourceDir);
    {$IFDEF MSWINDOWS}
    FPCExe := FPCBinDir + PathDelim + 'fpc.exe';
    {$ELSE}
    FPCExe := FPCBinDir + PathDelim + 'fpc';
    {$ENDIF}
    WriteFile(FPCExe, '');

    Plan := CreateLazarusConfigurePlanCore('3.4', InstallPath, SettingsRoot, '3.2.2', ConfigRoot,
      TempDir + PathDelim + 'home', TempDir + PathDelim + 'appdata');
    IDEConfig := TLazarusIDEConfig.Create(Plan.ConfigDir);
    Outp := TStringOutput.Create;
    Errp := TStringOutput.Create;
    try
      Check('configure flow apply returns true',
        ApplyLazarusConfigurePlanCore(Plan, Outp, Errp, IDEConfig),
        Errp.Text);
      Check('configure flow writes compiler path',
        IDEConfig.GetCompilerPath = Plan.FPCPath,
        'compiler=' + IDEConfig.GetCompilerPath);
      Check('configure flow writes library path',
        IDEConfig.GetLibraryPath = Plan.InstallPath,
        'library=' + IDEConfig.GetLibraryPath);
      Check('configure flow writes source path',
        IDEConfig.GetFPCSourcePath = Plan.FPCSourcePath,
        'source=' + IDEConfig.GetFPCSourcePath);
      Check('configure flow creates config dir', DirectoryExists(Plan.ConfigDir), 'config=' + Plan.ConfigDir);
      Check('configure flow prints summary header',
        Outp.Contains(_(MSG_LAZARUS_CONFIG_SUMMARY)),
        Outp.Text);
    finally
      Errp.Free;
      Outp.Free;
      IDEConfig.Free;
    end;
  finally
    CleanupTempDir(TempDir);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  Lazarus Flow Test Suite');
  WriteLn('========================================');
  WriteLn;

  TestCreateLazarusInstallPlanCoreUsesRequestedFPCVersion;
  TestCreateLazarusInstallPlanCoreFallsBackToRecommendedVersion;
  TestExecuteLazarusInstallPlanCoreReportsDownloadFailure;
  TestExecuteLazarusInstallPlanCoreTreatsConfigureFailureAsWarning;
  TestResolveLazarusConfigDirCoreUsesExplicitRoot;
  TestCreateLazarusBuildPlanCoreWindowsUsesMingwAndExe;
  TestCreateLazarusBuildPlanCoreUnixKeepsPlainFPCAndDeduplicatesStableToolPath;
  TestApplyLazarusConfigurePlanCoreWritesExpectedPaths;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
