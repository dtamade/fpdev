program test_package_manager_installupdateflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.package.types,
  fpdev.toolchain.fetcher,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.package.fetch,
  fpdev.package.lifecycle;

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

  TManagerFlowProbe = class
  public
    ValidateResult: Boolean;
    InstalledResult: Boolean;
    BuildPlanResult: Boolean;
    ResolveDepsResult: Boolean;
    DownloadResult: Boolean;
    InstallArchiveResult: Boolean;
    UninstallResult: Boolean;
    InstallResult: Boolean;
    BuildPlanCalls: Integer;
    ResolveDepsCalls: Integer;
    DownloadCalls: Integer;
    InstallArchiveCalls: Integer;
    UninstallCalls: Integer;
    InstallCalls: Integer;
    LastResolveDepPackage: string;
    LastDownloadZipPath: string;
    LastInstallArchivePackage: string;
    LastInstallArchiveVersion: string;
    LastInstallArchiveSandboxDir: string;
    LastInstallArchiveKeepArtifacts: Boolean;
    LastInstallVersion: string;
    LastInstallPackage: string;
    LastInstalledQuery: string;
    NextDownloadPlan: TPackageDownloadPlan;
    CleanupWarningPath: string;
    DownloadErr: string;
    InstallArchiveErr: string;
    InstalledInfo: TPackageInfo;
    AvailablePackages: TPackageArray;
    function Validate(const APackageName: string): Boolean;
    function IsInstalled(const APackageName: string): Boolean;
    function GetAvailablePackages: TPackageArray;
    function BuildPlan(const APackageName, AVersion, ACacheDir: string;
      const AAvailablePackages: TPackageArray; out APlan: TPackageDownloadPlan): Boolean;
    function ResolveDependencies(const APackageInfo: TPackageInfo; Outp, Errp: IOutput): Boolean;
    function DownloadCached(const AURLs: TStringArray; const ADestFile: string;
      const AOptions: TFetchOptions; out AErr: string): Boolean;
    function InstallArchive(const APackageName, AVersion, AZipPath, ASandboxDir: string;
      AKeepArtifacts: Boolean; out ACleanupWarningPath: string; out AErr: string): Boolean;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
    function Uninstall(const APackageName: string; Outp, Errp: IOutput): Boolean;
    function Install(const APackageName, AVersion: string; Outp, Errp: IOutput): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = ''); forward;

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

function TManagerFlowProbe.Validate(const APackageName: string): Boolean;
begin
  LastInstalledQuery := APackageName;
  Result := ValidateResult;
end;

function TManagerFlowProbe.IsInstalled(const APackageName: string): Boolean;
begin
  LastInstalledQuery := APackageName;
  Result := InstalledResult;
end;

function TManagerFlowProbe.GetAvailablePackages: TPackageArray;
var
  I: Integer;
begin
  Initialize(Result);
  SetLength(Result, Length(AvailablePackages));
  for I := 0 to High(AvailablePackages) do
    Result[I] := AvailablePackages[I];
end;

function TManagerFlowProbe.BuildPlan(const APackageName, AVersion, ACacheDir: string;
  const AAvailablePackages: TPackageArray; out APlan: TPackageDownloadPlan): Boolean;
var
  I: Integer;
begin
  Inc(BuildPlanCalls);
  if APackageName = '' then;
  if AVersion = '' then;
  if ACacheDir = '' then;
  if Length(AAvailablePackages) < 0 then;
  APlan.PackageInfo := NextDownloadPlan.PackageInfo;
  APlan.ZipPath := NextDownloadPlan.ZipPath;
  SetLength(APlan.URLs, Length(NextDownloadPlan.URLs));
  for I := 0 to High(NextDownloadPlan.URLs) do
    APlan.URLs[I] := NextDownloadPlan.URLs[I];
  APlan.FetchOptions := NextDownloadPlan.FetchOptions;
  Result := BuildPlanResult;
end;

function TManagerFlowProbe.ResolveDependencies(const APackageInfo: TPackageInfo; Outp, Errp: IOutput): Boolean;
begin
  Inc(ResolveDepsCalls);
  LastResolveDepPackage := APackageInfo.Name;
  if Outp = nil then;
  if Errp = nil then;
  Result := ResolveDepsResult;
end;

function TManagerFlowProbe.DownloadCached(const AURLs: TStringArray; const ADestFile: string;
  const AOptions: TFetchOptions; out AErr: string): Boolean;
begin
  Inc(DownloadCalls);
  if Length(AURLs) < 0 then;
  if AOptions.TimeoutMS < 0 then;
  LastDownloadZipPath := ADestFile;
  AErr := DownloadErr;
  Result := DownloadResult;
end;

function TManagerFlowProbe.InstallArchive(const APackageName, AVersion, AZipPath, ASandboxDir: string;
  AKeepArtifacts: Boolean; out ACleanupWarningPath: string; out AErr: string): Boolean;
begin
  Inc(InstallArchiveCalls);
  LastInstallArchivePackage := APackageName;
  LastInstallArchiveVersion := AVersion;
  LastInstallArchiveSandboxDir := ASandboxDir;
  LastInstallArchiveKeepArtifacts := AKeepArtifacts;
  if AZipPath = '' then;
  ACleanupWarningPath := CleanupWarningPath;
  AErr := InstallArchiveErr;
  Result := InstallArchiveResult;
end;

function TManagerFlowProbe.GetPackageInfo(const APackageName: string): TPackageInfo;
begin
  if APackageName = '' then;
  Result := InstalledInfo;
end;

function TManagerFlowProbe.Uninstall(const APackageName: string; Outp, Errp: IOutput): Boolean;
begin
  Inc(UninstallCalls);
  if APackageName = '' then;
  if Outp = nil then;
  if Errp = nil then;
  Result := UninstallResult;
end;

function TManagerFlowProbe.Install(const APackageName, AVersion: string; Outp, Errp: IOutput): Boolean;
begin
  Inc(InstallCalls);
  LastInstallPackage := APackageName;
  LastInstallVersion := AVersion;
  if APackageName = '' then;
  if Outp = nil then;
  if Errp = nil then;
  Result := InstallResult;
end;

procedure TestExecutePackageDependencyInstallCoreInstallsResolvedDependencies;
var
  Probe: TManagerFlowProbe;
  PackageInfo: TPackageInfo;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TManagerFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    PackageInfo.Name := 'alpha';
    SetLength(PackageInfo.Dependencies, 1);
    PackageInfo.Dependencies[0] := 'zlib >=1.0.0';
    SetLength(Probe.AvailablePackages, 1);
    Probe.AvailablePackages[0].Name := 'zlib';
    Probe.AvailablePackages[0].Version := '1.2.0';
    Probe.InstallResult := True;

    Check('dependency install core succeeds for resolvable dependency',
      ExecutePackageDependencyInstallCore(
        PackageInfo,
        Probe.AvailablePackages,
        @Probe.Install,
        OutRef,
        ErrRef
      ));
    Check('dependency install core invokes install once', Probe.InstallCalls = 1,
      'install calls=' + IntToStr(Probe.InstallCalls));
    Check('dependency install core installs resolved package', Probe.LastInstallPackage = 'zlib',
      'package=' + Probe.LastInstallPackage);
    Check('dependency install core installs resolved version', Probe.LastInstallVersion = '1.2.0',
      'version=' + Probe.LastInstallVersion);
    Check('dependency install core prints batch header',
      OutBuf.Contains(_(MSG_PKG_DEP_INSTALLING_ALL)), OutBuf.Text);
    Check('dependency install core prints per-package message',
      OutBuf.Contains(_Fmt(MSG_PKG_DEP_INSTALLING_ONE, ['zlib'])), OutBuf.Text);
  finally
    ErrRef := nil; OutRef := nil; ErrBuf := nil; OutBuf := nil; Probe.Free;
  end;
end;

procedure TestExecutePackageDependencyInstallCoreReportsInstallFailure;
var
  Probe: TManagerFlowProbe;
  PackageInfo: TPackageInfo;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TManagerFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    PackageInfo.Name := 'alpha';
    SetLength(PackageInfo.Dependencies, 1);
    PackageInfo.Dependencies[0] := 'zlib >=1.0.0';
    SetLength(Probe.AvailablePackages, 1);
    Probe.AvailablePackages[0].Name := 'zlib';
    Probe.AvailablePackages[0].Version := '1.2.0';
    Probe.InstallResult := False;

    Check('dependency install core returns false when install fails',
      not ExecutePackageDependencyInstallCore(
        PackageInfo,
        Probe.AvailablePackages,
        @Probe.Install,
        OutRef,
        ErrRef
      ));
    Check('dependency install core reports failed dependency',
      ErrBuf.Contains(_Fmt(MSG_PKG_DEP_INSTALL_FAILED, ['zlib'])), ErrBuf.Text);
  finally
    ErrRef := nil; OutRef := nil; ErrBuf := nil; OutBuf := nil; Probe.Free;
  end;
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

procedure TestExecutePackageManagerInstallCoreSkipsInstalledPackage;
var
  Probe: TManagerFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TManagerFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := True;
    Check('install manager returns true for installed package',
      ExecutePackageManagerInstallCore('alpha', '', '/tmp/cache', '/tmp/sandbox', False,
        @Probe.Validate, @Probe.IsInstalled, @Probe.GetAvailablePackages, @Probe.BuildPlan,
        @Probe.ResolveDependencies, @Probe.DownloadCached, @Probe.InstallArchive, OutRef, ErrRef));
    Check('install manager skips plan build for installed package', Probe.BuildPlanCalls = 0,
      'build plan calls=' + IntToStr(Probe.BuildPlanCalls));
  finally
    ErrRef := nil; OutRef := nil; ErrBuf := nil; OutBuf := nil; Probe.Free;
  end;
end;

procedure TestExecutePackageManagerInstallCoreResolvesDepsAndWarnsOnCleanup;
var
  Probe: TManagerFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TManagerFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := False;
    Probe.BuildPlanResult := True;
    Probe.ResolveDepsResult := True;
    Probe.DownloadResult := True;
    Probe.InstallArchiveResult := True;
    Probe.CleanupWarningPath := '/tmp/fpdev-cleanup-warning';
    Probe.NextDownloadPlan.PackageInfo.Name := 'alpha';
    Probe.NextDownloadPlan.PackageInfo.Version := '1.2.0';
    SetLength(Probe.NextDownloadPlan.PackageInfo.Dependencies, 1);
    Probe.NextDownloadPlan.PackageInfo.Dependencies[0] := 'beta >=1.0.0';
    Probe.NextDownloadPlan.ZipPath := '/tmp/cache/packages/alpha-1.2.0.zip';
    SetLength(Probe.NextDownloadPlan.URLs, 1);
    Probe.NextDownloadPlan.URLs[0] := 'https://example.com/alpha.zip';

    Check('install manager succeeds when all phases pass',
      ExecutePackageManagerInstallCore('alpha', '', '/tmp/cache', '/tmp/sandbox', True,
        @Probe.Validate, @Probe.IsInstalled, @Probe.GetAvailablePackages, @Probe.BuildPlan,
        @Probe.ResolveDependencies, @Probe.DownloadCached, @Probe.InstallArchive, OutRef, ErrRef));
    Check('install manager resolves dependencies once', Probe.ResolveDepsCalls = 1,
      'resolve calls=' + IntToStr(Probe.ResolveDepsCalls));
    Check('install manager downloads once', Probe.DownloadCalls = 1,
      'download calls=' + IntToStr(Probe.DownloadCalls));
    Check('install manager installs archive once', Probe.InstallArchiveCalls = 1,
      'archive calls=' + IntToStr(Probe.InstallArchiveCalls));
    Check('install manager forwards latest version', Probe.LastInstallArchiveVersion = '1.2.0',
      'version=' + Probe.LastInstallArchiveVersion);
    Check('install manager forwards keep artifacts', Probe.LastInstallArchiveKeepArtifacts,
      'expected keep artifacts true');
    Check('install manager prints dependency resolution', OutBuf.Contains(_(MSG_PKG_DEP_RESOLVING)), OutBuf.Text);
    Check('install manager prints cleanup warning', ErrBuf.Contains(_Fmt(MSG_PKG_CLEAN_TMP_FAILED, ['/tmp/fpdev-cleanup-warning'])), ErrBuf.Text);
  finally
    ErrRef := nil; OutRef := nil; ErrBuf := nil; OutBuf := nil; Probe.Free;
  end;
end;

procedure TestExecutePackageManagerInstallCoreStopsWhenDepsFail;
var
  Probe: TManagerFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TManagerFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := False;
    Probe.BuildPlanResult := True;
    Probe.ResolveDepsResult := False;
    Probe.NextDownloadPlan.PackageInfo.Name := 'alpha';
    SetLength(Probe.NextDownloadPlan.PackageInfo.Dependencies, 1);
    Probe.NextDownloadPlan.PackageInfo.Dependencies[0] := 'beta';

    Check('install manager returns false on dependency failure',
      not ExecutePackageManagerInstallCore('alpha', '', '/tmp/cache', '/tmp/sandbox', False,
        @Probe.Validate, @Probe.IsInstalled, @Probe.GetAvailablePackages, @Probe.BuildPlan,
        @Probe.ResolveDependencies, @Probe.DownloadCached, @Probe.InstallArchive, OutRef, ErrRef));
    Check('install manager stops before download on dependency failure', Probe.DownloadCalls = 0,
      'download calls=' + IntToStr(Probe.DownloadCalls));
  finally
    ErrRef := nil; OutRef := nil; ErrBuf := nil; OutBuf := nil; Probe.Free;
  end;
end;

procedure TestExecutePackageManagerUpdateCoreRejectsInvalidPackage;
var
  Probe: TManagerFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TManagerFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := False;
    Check('update manager rejects invalid package',
      not ExecutePackageManagerUpdateCore('bad name', @Probe.Validate, @Probe.IsInstalled,
        @Probe.GetPackageInfo, @Probe.GetAvailablePackages, @Probe.Uninstall, @Probe.Install, OutRef, ErrRef));
    Check('update manager prints invalid-name error',
      ErrBuf.Contains(_Fmt(CMD_PKG_INVALID_NAME, ['bad name'])), ErrBuf.Text);
  finally
    ErrRef := nil; OutRef := nil; ErrBuf := nil; OutBuf := nil; Probe.Free;
  end;
end;

procedure TestExecutePackageManagerUpdateCoreReportsMissingInstall;
var
  Probe: TManagerFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TManagerFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := False;
    Check('update manager rejects missing install',
      not ExecutePackageManagerUpdateCore('alpha', @Probe.Validate, @Probe.IsInstalled,
        @Probe.GetPackageInfo, @Probe.GetAvailablePackages, @Probe.Uninstall, @Probe.Install, OutRef, ErrRef));
    Check('update manager prints install hint',
      ErrBuf.Contains(_Fmt(MSG_PKG_INSTALL_HINT, ['alpha'])), ErrBuf.Text);
  finally
    ErrRef := nil; OutRef := nil; ErrBuf := nil; OutBuf := nil; Probe.Free;
  end;
end;

procedure TestExecutePackageManagerUpdateCoreUsesUnknownInstalledVersionFallback;
var
  Probe: TManagerFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TManagerFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.ValidateResult := True;
    Probe.InstalledResult := True;
    Probe.UninstallResult := True;
    Probe.InstallResult := True;
    Probe.InstalledInfo.Name := 'alpha';
    Probe.InstalledInfo.Version := '';
    SetLength(Probe.AvailablePackages, 1);
    Probe.AvailablePackages[0].Name := 'alpha';
    Probe.AvailablePackages[0].Version := '2.0.0';

    Check('update manager succeeds with unknown installed version fallback',
      ExecutePackageManagerUpdateCore('alpha', @Probe.Validate, @Probe.IsInstalled,
        @Probe.GetPackageInfo, @Probe.GetAvailablePackages, @Probe.Uninstall, @Probe.Install, OutRef, ErrRef));
    Check('update manager prints unknown installed version',
      OutBuf.Contains(_Fmt(MSG_PKG_INSTALLED_VERSION, ['0.0.0'])), OutBuf.Text);
    Check('update manager installs latest version', Probe.LastInstallVersion = '2.0.0',
      'version=' + Probe.LastInstallVersion);
  finally
    ErrRef := nil; OutRef := nil; ErrBuf := nil; OutBuf := nil; Probe.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  Package Manager Install/Update Flow');
  WriteLn('========================================');
  WriteLn;

  TestExecutePackageManagerInstallCoreSkipsInstalledPackage;
  TestExecutePackageManagerInstallCoreResolvesDepsAndWarnsOnCleanup;
  TestExecutePackageManagerInstallCoreStopsWhenDepsFail;
  TestExecutePackageDependencyInstallCoreInstallsResolvedDependencies;
  TestExecutePackageDependencyInstallCoreReportsInstallFailure;
  TestExecutePackageManagerUpdateCoreRejectsInvalidPackage;
  TestExecutePackageManagerUpdateCoreReportsMissingInstall;
  TestExecutePackageManagerUpdateCoreUsesUnknownInstalledVersionFallback;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
