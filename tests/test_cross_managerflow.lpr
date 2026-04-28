program test_cross_managerflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.config.interfaces,
  fpdev.cross.query,
  fpdev.cross.managerflow,
  fpdev.i18n,
  fpdev.i18n.strings,
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

  TCrossManagerProbe = class
  public
    AvailableTargets: TCrossTargetQueryArray;
    InstalledTargets: TCrossTargetQueryArray;
    ValidateResult: Boolean;
    InstalledResult: Boolean;
    TargetInfo: TCrossTargetQueryInfo;
    InstallPath: string;
    ConfigFound: Boolean;
    CrossTarget: TCrossTarget;
    BinutilsDownloadResult: Boolean;
    LibrariesDownloadResult: Boolean;
    SystemCompilerDetected: Boolean;
    SetupEnvironmentResult: Boolean;
    SaveConfigResult: Boolean;
    RemoveConfigResult: Boolean;
    SystemBinutilsPath: string;
    PackageManagerInstructions: string;
    SavedCrossTarget: TCrossTarget;
    AvailableCalls: Integer;
    InstalledCalls: Integer;
    ValidateCalls: Integer;
    InstalledCheckCalls: Integer;
    InfoCalls: Integer;
    InstallPathCalls: Integer;
    ConfigCalls: Integer;
    BinutilsCalls: Integer;
    LibrariesCalls: Integer;
    SystemDetectCalls: Integer;
    SetupCalls: Integer;
    SaveConfigCalls: Integer;
    RemoveConfigCalls: Integer;
    InstructionsCalls: Integer;
    LastTarget: string;
    function GetAvailableTargets: TCrossTargetQueryArray;
    function GetInstalledTargets: TCrossTargetQueryArray;
    function ValidateTarget(const ATarget: string): Boolean;
    function IsTargetInstalled(const ATarget: string): Boolean;
    function GetTargetInfo(const ATarget: string): TCrossTargetQueryInfo;
    function GetTargetInstallPath(const ATarget: string): string;
    function GetCrossTargetConfig(const ATarget: string; out AInfo: TCrossTarget): Boolean;
    function DetectSystemCompiler(const ATarget: string; out ABinutilsPath: string): Boolean;
    function SaveCrossTargetConfig(const ATarget: string; const AInfo: TCrossTarget): Boolean;
    function SetupCrossEnvironment(const ATarget: string; const ATargetInfo: TCrossTargetQueryInfo): Boolean;
    function RemoveCrossTargetConfig(const ATarget: string): Boolean;
    function GetPackageManagerInstructions(const ATarget: string): string;
    function DownloadBinutils(const ATarget: string; const ATargetInfo: TCrossTargetQueryInfo;
      Outp: IOutput): Boolean;
    function DownloadLibraries(const ATarget: string; const ATargetInfo: TCrossTargetQueryInfo;
      Outp: IOutput): Boolean;
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

function CloneTargets(const ATargets: TCrossTargetQueryArray): TCrossTargetQueryArray;
var
  Index: Integer;
begin
  Result := nil;
  SetLength(Result, Length(ATargets));
  for Index := 0 to High(ATargets) do
    Result[Index] := ATargets[Index];
end;

function TCrossManagerProbe.GetAvailableTargets: TCrossTargetQueryArray;
begin
  Inc(AvailableCalls);
  Result := CloneTargets(AvailableTargets);
end;

function TCrossManagerProbe.GetInstalledTargets: TCrossTargetQueryArray;
begin
  Inc(InstalledCalls);
  Result := CloneTargets(InstalledTargets);
end;

function TCrossManagerProbe.ValidateTarget(const ATarget: string): Boolean;
begin
  Inc(ValidateCalls);
  LastTarget := ATarget;
  Result := ValidateResult;
end;

function TCrossManagerProbe.IsTargetInstalled(const ATarget: string): Boolean;
begin
  Inc(InstalledCheckCalls);
  LastTarget := ATarget;
  Result := InstalledResult;
end;

function TCrossManagerProbe.GetTargetInfo(const ATarget: string): TCrossTargetQueryInfo;
begin
  Inc(InfoCalls);
  LastTarget := ATarget;
  Result := TargetInfo;
end;

function TCrossManagerProbe.GetTargetInstallPath(const ATarget: string): string;
begin
  Inc(InstallPathCalls);
  LastTarget := ATarget;
  Result := InstallPath;
end;

function TCrossManagerProbe.GetCrossTargetConfig(const ATarget: string; out AInfo: TCrossTarget): Boolean;
begin
  Inc(ConfigCalls);
  LastTarget := ATarget;
  AInfo := CrossTarget;
  Result := ConfigFound;
end;

function TCrossManagerProbe.DetectSystemCompiler(const ATarget: string; out ABinutilsPath: string): Boolean;
begin
  Inc(SystemDetectCalls);
  LastTarget := ATarget;
  ABinutilsPath := SystemBinutilsPath;
  Result := SystemCompilerDetected;
end;

function TCrossManagerProbe.SaveCrossTargetConfig(const ATarget: string; const AInfo: TCrossTarget): Boolean;
begin
  Inc(SaveConfigCalls);
  LastTarget := ATarget;
  SavedCrossTarget := AInfo;
  Result := SaveConfigResult;
end;

function TCrossManagerProbe.SetupCrossEnvironment(const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo): Boolean;
begin
  Inc(SetupCalls);
  LastTarget := ATarget;
  if ATargetInfo.Name = '' then;
  Result := SetupEnvironmentResult;
end;

function TCrossManagerProbe.RemoveCrossTargetConfig(const ATarget: string): Boolean;
begin
  Inc(RemoveConfigCalls);
  LastTarget := ATarget;
  Result := RemoveConfigResult;
end;

function TCrossManagerProbe.GetPackageManagerInstructions(const ATarget: string): string;
begin
  Inc(InstructionsCalls);
  LastTarget := ATarget;
  Result := PackageManagerInstructions;
end;

function TCrossManagerProbe.DownloadBinutils(const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo; Outp: IOutput): Boolean;
begin
  Inc(BinutilsCalls);
  LastTarget := ATarget;
  if ATargetInfo.Name = '' then;
  if Outp = nil then;
  Result := BinutilsDownloadResult;
end;

function TCrossManagerProbe.DownloadLibraries(const ATarget: string;
  const ATargetInfo: TCrossTargetQueryInfo; Outp: IOutput): Boolean;
begin
  Inc(LibrariesCalls);
  LastTarget := ATarget;
  if ATargetInfo.Name = '' then;
  if Outp = nil then;
  Result := LibrariesDownloadResult;
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

function MakeTargetInfo(const AName, ADisplayName, ACPU, AOS, APrefix: string;
  AInstalled: Boolean): TCrossTargetQueryInfo;
begin
  Result := Default(TCrossTargetQueryInfo);
  Result.Name := AName;
  Result.DisplayName := ADisplayName;
  Result.CPU := ACPU;
  Result.OS := AOS;
  Result.BinutilsPrefix := APrefix;
  Result.Available := True;
  Result.Installed := AInstalled;
end;

procedure TouchFile(const APath: string);
begin
  with TFileStream.Create(APath, fmCreate) do
    Free;
end;

procedure EnsureDirPath(const APath: string);
begin
  if not DirectoryExists(APath) then
    ForceDirectories(APath);
end;

procedure TestExecuteCrossListTargetsCoreShowsAvailableTargets;
var
  Probe: TCrossManagerProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    SetLength(Probe.AvailableTargets, 2);
    Probe.AvailableTargets[0] := MakeTargetInfo('win64', 'Windows 64-bit', 'x86_64', 'win64',
      'x86_64-w64-mingw32-', True);
    Probe.AvailableTargets[1] := MakeTargetInfo('arm-linux', 'ARM Linux', 'arm', 'linux',
      'arm-linux-gnueabihf-', False);

    OK := ExecuteCrossListTargetsCore(True, @Probe.GetAvailableTargets, @Probe.GetInstalledTargets, OutRef);

    Check('cross list available returns true', OK, 'expected success');
    Check('cross list available uses available provider', Probe.AvailableCalls = 1,
      'available calls=' + IntToStr(Probe.AvailableCalls));
    Check('cross list available skips installed provider', Probe.InstalledCalls = 0,
      'installed calls=' + IntToStr(Probe.InstalledCalls));
    Check('cross list available writes header', OutBuf.Contains(_(MSG_CROSS_LIST_AVAILABLE)),
      OutBuf.Text);
    Check('cross list available writes total', OutBuf.Contains(_Fmt(MSG_CROSS_LIST_TOTAL, [2])),
      OutBuf.Text);
    Check('cross list available writes installed status', OutBuf.Contains(_(MSG_CROSS_STATUS_INSTALLED)),
      OutBuf.Text);
  finally
    OutRef := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossListTargetsCoreShowsInstalledEmptyState;
var
  Probe: TCrossManagerProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    SetLength(Probe.InstalledTargets, 0);

    OK := ExecuteCrossListTargetsCore(False, @Probe.GetAvailableTargets, @Probe.GetInstalledTargets, OutRef);

    Check('cross list installed empty returns true', OK, 'expected success');
    Check('cross list installed uses installed provider', Probe.InstalledCalls = 1,
      'installed calls=' + IntToStr(Probe.InstalledCalls));
    Check('cross list installed writes installed header', OutBuf.Contains(_(MSG_CROSS_LIST_INSTALLED)),
      OutBuf.Text);
    Check('cross list installed writes empty hint', OutBuf.Contains(_(MSG_CROSS_LIST_NO_INSTALLED)),
      OutBuf.Text);
    Check('cross list installed writes use-all hint', OutBuf.Contains(_(MSG_CROSS_LIST_USE_ALL)),
      OutBuf.Text);
  finally
    OutRef := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossShowTargetInfoCoreRejectsUnsupportedTarget;
var
  Probe: TCrossManagerProbe;
  ErrBuf: TStringOutput;
  ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  ErrBuf := TStringOutput.Create;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := False;

    OK := ExecuteCrossShowTargetInfoCore('mips-haiku', @Probe.ValidateTarget,
      @Probe.GetTargetInfo, @Probe.GetTargetInstallPath, nil, ErrRef);

    Check('cross show unsupported returns false', not OK, 'expected failure');
    Check('cross show unsupported writes error',
      ErrBuf.Contains(_Fmt(CMD_CROSS_TARGET_UNSUPPORTED, ['mips-haiku'])),
      ErrBuf.Text);
  finally
    ErrRef := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossShowTargetInfoCoreWritesInstallPath;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.TargetInfo := MakeTargetInfo('win64', 'Windows 64-bit', 'x86_64', 'win64',
      'x86_64-w64-mingw32-', True);
    Probe.InstallPath := '/tmp/cross/win64';

    OK := ExecuteCrossShowTargetInfoCore('win64', @Probe.ValidateTarget,
      @Probe.GetTargetInfo, @Probe.GetTargetInstallPath, OutRef, ErrRef);

    Check('cross show installed returns true', OK, 'expected success');
    Check('cross show writes display name', OutBuf.Contains(_Fmt(MSG_CROSS_SHOW_DISPLAY_NAME, ['Windows 64-bit'])),
      OutBuf.Text);
    Check('cross show writes cpu', OutBuf.Contains(_Fmt(MSG_CROSS_SHOW_CPU, ['x86_64'])),
      OutBuf.Text);
    Check('cross show writes os', OutBuf.Contains(_Fmt(MSG_CROSS_SHOW_OS, ['win64'])),
      OutBuf.Text);
    Check('cross show writes prefix', OutBuf.Contains(_Fmt(MSG_CROSS_SHOW_BINUTILS_PREFIX, ['x86_64-w64-mingw32-'])),
      OutBuf.Text);
    Check('cross show writes install path', OutBuf.Contains('Install Path: /tmp/cross/win64'),
      OutBuf.Text);
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossUpdateTargetCoreKeepsWarnings;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := True;
    Probe.BinutilsDownloadResult := False;
    Probe.LibrariesDownloadResult := False;
    Probe.TargetInfo := MakeTargetInfo('win64', 'Windows 64-bit', 'x86_64', 'win64',
      'x86_64-w64-mingw32-', True);

    OK := ExecuteCrossUpdateTargetCore('win64', @Probe.ValidateTarget, @Probe.IsTargetInstalled,
      @Probe.GetTargetInfo, @Probe.DownloadBinutils, @Probe.DownloadLibraries, OutRef, ErrRef);

    Check('cross update returns true when downloads warn', OK, 'expected warning success');
    Check('cross update calls binutils downloader', Probe.BinutilsCalls = 1,
      'binutils calls=' + IntToStr(Probe.BinutilsCalls));
    Check('cross update calls libraries downloader', Probe.LibrariesCalls = 1,
      'libraries calls=' + IntToStr(Probe.LibrariesCalls));
    Check('cross update writes binutils warning',
      OutBuf.Contains(_Fmt(MSG_CROSS_UPDATE_BINUTILS_WARN, ['win64'])),
      OutBuf.Text);
    Check('cross update writes libraries warning',
      OutBuf.Contains(_Fmt(MSG_CROSS_UPDATE_LIBS_WARN, ['win64'])),
      OutBuf.Text);
    Check('cross update writes done message',
      OutBuf.Contains(_Fmt(MSG_CROSS_UPDATE_DONE, ['win64'])),
      OutBuf.Text);
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossInstallTargetCoreRejectsUnsupportedTarget;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := False;

    OK := ExecuteCrossInstallTargetCore('mips-haiku', @Probe.ValidateTarget,
      @Probe.IsTargetInstalled, @Probe.GetTargetInfo, @Probe.GetTargetInstallPath,
      @Probe.DetectSystemCompiler, @Probe.SaveCrossTargetConfig, @Probe.DownloadBinutils,
      @Probe.DownloadLibraries, @Probe.SetupCrossEnvironment,
      @Probe.GetPackageManagerInstructions, OutRef, ErrRef);

    Check('cross install unsupported returns false', not OK, 'expected failure');
    Check('cross install unsupported writes error',
      ErrBuf.Contains(_Fmt(CMD_CROSS_TARGET_UNSUPPORTED, ['mips-haiku'])),
      ErrBuf.Text);
    Check('cross install unsupported skips target info lookup', Probe.InfoCalls = 0,
      'info calls=' + IntToStr(Probe.InfoCalls));
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossInstallTargetCoreShortCircuitsWhenAlreadyInstalled;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := True;

    OK := ExecuteCrossInstallTargetCore('win64', @Probe.ValidateTarget,
      @Probe.IsTargetInstalled, @Probe.GetTargetInfo, @Probe.GetTargetInstallPath,
      @Probe.DetectSystemCompiler, @Probe.SaveCrossTargetConfig, @Probe.DownloadBinutils,
      @Probe.DownloadLibraries, @Probe.SetupCrossEnvironment,
      @Probe.GetPackageManagerInstructions, OutRef, ErrRef);

    Check('cross install already-installed returns true', OK, 'expected success');
    Check('cross install already-installed writes note',
      OutBuf.Contains(_Fmt(MSG_CROSS_ALREADY_INSTALLED, ['win64'])),
      OutBuf.Text);
    Check('cross install already-installed skips system detection', Probe.SystemDetectCalls = 0,
      'system detect calls=' + IntToStr(Probe.SystemDetectCalls));
    Check('cross install already-installed skips downloads', Probe.BinutilsCalls = 0,
      'binutils calls=' + IntToStr(Probe.BinutilsCalls));
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossInstallTargetCoreUsesSystemCompilerWhenAvailable;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := False;
    Probe.TargetInfo := MakeTargetInfo('win64', 'Windows 64-bit', 'x86_64', 'win64',
      'x86_64-w64-mingw32-', False);
    Probe.InstallPath := '/tmp/cross/win64';
    Probe.SystemCompilerDetected := True;
    Probe.SystemBinutilsPath := '/usr/bin/x86_64-w64-mingw32';
    Probe.SaveConfigResult := True;

    OK := ExecuteCrossInstallTargetCore('win64', @Probe.ValidateTarget,
      @Probe.IsTargetInstalled, @Probe.GetTargetInfo, @Probe.GetTargetInstallPath,
      @Probe.DetectSystemCompiler, @Probe.SaveCrossTargetConfig, @Probe.DownloadBinutils,
      @Probe.DownloadLibraries, @Probe.SetupCrossEnvironment,
      @Probe.GetPackageManagerInstructions, OutRef, ErrRef);

    Check('cross install system compiler returns true', OK, 'expected success');
    Check('cross install system compiler saves config', Probe.SaveConfigCalls = 1,
      'save calls=' + IntToStr(Probe.SaveConfigCalls));
    Check('cross install system compiler saves enabled target', Probe.SavedCrossTarget.Enabled,
      'expected enabled target');
    Check('cross install system compiler saves binutils path',
      Probe.SavedCrossTarget.BinutilsPath = '/usr/bin/x86_64-w64-mingw32',
      Probe.SavedCrossTarget.BinutilsPath);
    Check('cross install system compiler clears libraries path',
      Probe.SavedCrossTarget.LibrariesPath = '',
      Probe.SavedCrossTarget.LibrariesPath);
    Check('cross install system compiler writes found message',
      OutBuf.Contains(_Fmt(MSG_CROSS_SYSTEM_FOUND, ['/usr/bin/x86_64-w64-mingw32'])),
      OutBuf.Text);
    Check('cross install system compiler writes success',
      OutBuf.Contains(_Fmt(MSG_CROSS_INSTALL_SUCCESS, ['win64'])),
      OutBuf.Text);
    Check('cross install system compiler writes using-system note',
      OutBuf.Contains(_Fmt(MSG_CROSS_USING_SYSTEM, ['/usr/bin/x86_64-w64-mingw32'])),
      OutBuf.Text);
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossInstallTargetCoreShowsManualInstructionsWhenBinutilsDownloadFails;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  TempRoot: string;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  TempRoot := CreateUniqueTempDir('fpdev-cross-install-manual');
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := False;
    Probe.TargetInfo := MakeTargetInfo('win64', 'Windows 64-bit', 'x86_64', 'win64',
      'x86_64-w64-mingw32-', False);
    Probe.InstallPath := TempRoot + PathDelim + 'toolchain';
    Probe.BinutilsDownloadResult := False;
    Probe.PackageManagerInstructions := 'sudo apt install binutils-mingw-w64';

    OK := ExecuteCrossInstallTargetCore('win64', @Probe.ValidateTarget,
      @Probe.IsTargetInstalled, @Probe.GetTargetInfo, @Probe.GetTargetInstallPath,
      @Probe.DetectSystemCompiler, @Probe.SaveCrossTargetConfig, @Probe.DownloadBinutils,
      @Probe.DownloadLibraries, @Probe.SetupCrossEnvironment,
      @Probe.GetPackageManagerInstructions, OutRef, ErrRef);

    Check('cross install manual path returns false', not OK, 'expected failure for manual follow-up');
    Check('cross install manual path creates install dir', DirectoryExists(Probe.InstallPath),
      Probe.InstallPath);
    Check('cross install manual path asks for package instructions', Probe.InstructionsCalls = 1,
      'instruction calls=' + IntToStr(Probe.InstructionsCalls));
    Check('cross install manual path writes manual instructions',
      OutBuf.Contains('sudo apt install binutils-mingw-w64'),
      OutBuf.Text);
    Check('cross install manual path writes follow-up hint',
      OutBuf.Contains(_(MSG_CROSS_AFTER_INSTALL_HINT)),
      OutBuf.Text);
    Check('cross install manual path skips setup', Probe.SetupCalls = 0,
      'setup calls=' + IntToStr(Probe.SetupCalls));
  finally
    CleanupTempDir(TempRoot);
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossInstallTargetCoreConfiguresEnvironmentAfterDownloads;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  TempRoot: string;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  TempRoot := CreateUniqueTempDir('fpdev-cross-install-setup');
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := False;
    Probe.TargetInfo := MakeTargetInfo('win64', 'Windows 64-bit', 'x86_64', 'win64',
      'x86_64-w64-mingw32-', False);
    Probe.InstallPath := TempRoot + PathDelim + 'toolchain';
    Probe.BinutilsDownloadResult := True;
    Probe.LibrariesDownloadResult := False;
    Probe.SetupEnvironmentResult := True;

    OK := ExecuteCrossInstallTargetCore('win64', @Probe.ValidateTarget,
      @Probe.IsTargetInstalled, @Probe.GetTargetInfo, @Probe.GetTargetInstallPath,
      @Probe.DetectSystemCompiler, @Probe.SaveCrossTargetConfig, @Probe.DownloadBinutils,
      @Probe.DownloadLibraries, @Probe.SetupCrossEnvironment,
      @Probe.GetPackageManagerInstructions, OutRef, ErrRef);

    Check('cross install setup path returns true', OK, 'expected success');
    Check('cross install setup path creates install dir', DirectoryExists(Probe.InstallPath),
      Probe.InstallPath);
    Check('cross install setup path downloads binutils', Probe.BinutilsCalls = 1,
      'binutils calls=' + IntToStr(Probe.BinutilsCalls));
    Check('cross install setup path attempts libraries download', Probe.LibrariesCalls = 1,
      'libraries calls=' + IntToStr(Probe.LibrariesCalls));
    Check('cross install setup path runs setup', Probe.SetupCalls = 1,
      'setup calls=' + IntToStr(Probe.SetupCalls));
    Check('cross install setup path writes libraries skip note',
      OutBuf.Contains(_(MSG_CROSS_LIBS_SKIP_NOTE)),
      OutBuf.Text);
    Check('cross install setup path writes success',
      OutBuf.Contains(_Fmt(MSG_CROSS_INSTALL_SUCCESS, ['win64'])),
      OutBuf.Text);
  finally
    CleanupTempDir(TempRoot);
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestResolveCrossCleanPathsCorePrefersConfiguredPaths;
var
  Probe: TCrossManagerProbe;
  Paths: TCrossCleanPaths;
begin
  Probe := TCrossManagerProbe.Create;
  try
    Probe.InstallPath := '/tmp/cross/win64';
    Probe.ConfigFound := True;
    Probe.CrossTarget := Default(TCrossTarget);
    Probe.CrossTarget.BinutilsPath := '/opt/cross-bin';
    Probe.CrossTarget.LibrariesPath := '/opt/cross-lib';

    Paths := ResolveCrossCleanPathsCore('win64', @Probe.GetTargetInstallPath, @Probe.GetCrossTargetConfig);

    Check('cross clean paths keep install path', Paths.InstallPath = '/tmp/cross/win64',
      Paths.InstallPath);
    Check('cross clean paths prefer configured binutils', Paths.BinutilsPath = '/opt/cross-bin',
      Paths.BinutilsPath);
    Check('cross clean paths prefer configured libraries', Paths.LibrariesPath = '/opt/cross-lib',
      Paths.LibrariesPath);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteCrossCleanTargetCoreDeletesArtifacts;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  TempRoot, BinDir, LibDir: string;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  TempRoot := CreateUniqueTempDir('fpdev-cross-managerflow-clean');
  BinDir := TempRoot + PathDelim + 'bin';
  LibDir := TempRoot + PathDelim + 'lib';
  EnsureDirPath(BinDir);
  EnsureDirPath(LibDir);
  TouchFile(TempRoot + PathDelim + 'binutils.tar.xz');
  TouchFile(TempRoot + PathDelim + 'binutils.zip');
  TouchFile(TempRoot + PathDelim + 'libraries.tar.xz');
  TouchFile(TempRoot + PathDelim + 'libraries.zip');
  TouchFile(TempRoot + PathDelim + 'cross_test.pas');
  TouchFile(TempRoot + PathDelim + 'cross_test');
  TouchFile(TempRoot + PathDelim + 'cross_test.exe');
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := True;
    Probe.InstallPath := TempRoot;

    OK := ExecuteCrossCleanTargetCore('win64', @Probe.ValidateTarget, @Probe.IsTargetInstalled,
      @Probe.GetTargetInstallPath, @Probe.GetCrossTargetConfig, OutRef, ErrRef);

    Check('cross clean returns true', OK, 'expected success');
    Check('cross clean removes bin dir', not DirectoryExists(BinDir), BinDir);
    Check('cross clean removes lib dir', not DirectoryExists(LibDir), LibDir);
    Check('cross clean removes binutils archive',
      not FileExists(TempRoot + PathDelim + 'binutils.tar.xz'),
      'binutils.tar.xz still exists');
    Check('cross clean removes libraries archive',
      not FileExists(TempRoot + PathDelim + 'libraries.zip'),
      'libraries.zip still exists');
    Check('cross clean removes test artifact',
      not FileExists(TempRoot + PathDelim + 'cross_test.exe'),
      'cross_test.exe still exists');
    Check('cross clean writes done message',
      OutBuf.Contains(_Fmt(MSG_CROSS_CLEAN_DONE, ['win64'])),
      OutBuf.Text);
    Check('cross clean writes preserved-config note',
      OutBuf.Contains(_Fmt(MSG_CROSS_CLEAN_NOTE, ['win64'])),
      OutBuf.Text);
  finally
    CleanupTempDir(TempRoot);
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossUninstallTargetCoreReturnsSuccessWhenMissing;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.InstalledResult := False;

    OK := ExecuteCrossUninstallTargetCore('win64', @Probe.IsTargetInstalled,
      @Probe.GetTargetInstallPath, @Probe.RemoveCrossTargetConfig, OutRef, ErrRef);

    Check('cross uninstall missing returns true', OK, 'expected success');
    Check('cross uninstall missing writes note',
      OutBuf.Contains(_Fmt(MSG_CROSS_TARGET_NOT_INSTALLED_MSG, ['win64'])),
      OutBuf.Text);
    Check('cross uninstall missing skips config removal', Probe.RemoveConfigCalls = 0,
      'remove config calls=' + IntToStr(Probe.RemoveConfigCalls));
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteCrossUninstallTargetCoreDeletesInstallDirAndConfig;
var
  Probe: TCrossManagerProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  TempRoot: string;
  OK: Boolean;
begin
  Probe := TCrossManagerProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  TempRoot := CreateUniqueTempDir('fpdev-cross-uninstall');
  TouchFile(TempRoot + PathDelim + 'marker.txt');
  try
    Probe.InstalledResult := True;
    Probe.InstallPath := TempRoot;
    Probe.RemoveConfigResult := True;

    OK := ExecuteCrossUninstallTargetCore('win64', @Probe.IsTargetInstalled,
      @Probe.GetTargetInstallPath, @Probe.RemoveCrossTargetConfig, OutRef, ErrRef);

    Check('cross uninstall installed returns true', OK, 'expected success');
    Check('cross uninstall installed removes directory', not DirectoryExists(TempRoot), TempRoot);
    Check('cross uninstall installed removes config', Probe.RemoveConfigCalls = 1,
      'remove config calls=' + IntToStr(Probe.RemoveConfigCalls));
    Check('cross uninstall installed writes success',
      OutBuf.Contains(_Fmt(MSG_CROSS_UNINSTALLED, ['win64'])),
      OutBuf.Text);
  finally
    CleanupTempDir(TempRoot);
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

begin
  TestExecuteCrossListTargetsCoreShowsAvailableTargets;
  TestExecuteCrossListTargetsCoreShowsInstalledEmptyState;
  TestExecuteCrossShowTargetInfoCoreRejectsUnsupportedTarget;
  TestExecuteCrossShowTargetInfoCoreWritesInstallPath;
  TestExecuteCrossUpdateTargetCoreKeepsWarnings;
  TestExecuteCrossInstallTargetCoreRejectsUnsupportedTarget;
  TestExecuteCrossInstallTargetCoreShortCircuitsWhenAlreadyInstalled;
  TestExecuteCrossInstallTargetCoreUsesSystemCompilerWhenAvailable;
  TestExecuteCrossInstallTargetCoreShowsManualInstructionsWhenBinutilsDownloadFails;
  TestExecuteCrossInstallTargetCoreConfiguresEnvironmentAfterDownloads;
  TestResolveCrossCleanPathsCorePrefersConfiguredPaths;
  TestExecuteCrossCleanTargetCoreDeletesArtifacts;
  TestExecuteCrossUninstallTargetCoreReturnsSuccessWhenMissing;
  TestExecuteCrossUninstallTargetCoreDeletesInstallDirAndConfig;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
