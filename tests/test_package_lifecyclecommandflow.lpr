program test_package_lifecyclecommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.types,
  fpdev.package.lifecyclecommandflow;

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

  TPackageLifecycleProbe = class
  public
    InstalledPackages: TPackageArray;
    AvailablePackages: TPackageArray;
    UpdateResult: Boolean;
    UninstallResult: Boolean;
    InstallLocalResult: Boolean;
    UpdateCalls: Integer;
    UninstallCalls: Integer;
    InstallLocalCalls: Integer;
    LastTarget: string;
    function GetInstalledPackages: TPackageArray;
    function GetAvailablePackages: TPackageArray;
    function UpdatePackage(
      const APackageName: string;
      Outp: IOutput;
      Errp: IOutput
    ): Boolean;
    function UninstallPackage(
      const APackageName: string;
      Outp: IOutput;
      Errp: IOutput
    ): Boolean;
    function InstallFromLocal(
      const APackagePath: string;
      Outp: IOutput;
      Errp: IOutput
    ): Boolean;
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

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor;
  const AStyle: TConsoleStyle);
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

function TPackageLifecycleProbe.GetInstalledPackages: TPackageArray;
begin
  Result := InstalledPackages;
end;

function TPackageLifecycleProbe.GetAvailablePackages: TPackageArray;
begin
  Result := AvailablePackages;
end;

function TPackageLifecycleProbe.UpdatePackage(
  const APackageName: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Inc(UpdateCalls);
  LastTarget := APackageName;
  if Outp = nil then;
  if Errp = nil then;
  Result := UpdateResult;
end;

function TPackageLifecycleProbe.UninstallPackage(
  const APackageName: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Inc(UninstallCalls);
  LastTarget := APackageName;
  if Outp = nil then;
  if Errp = nil then;
  Result := UninstallResult;
end;

function TPackageLifecycleProbe.InstallFromLocal(
  const APackagePath: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Inc(InstallLocalCalls);
  LastTarget := APackagePath;
  if Outp = nil then;
  if Errp = nil then;
  Result := InstallLocalResult;
end;

procedure InitOutputs(
  out AOutObj, AErrObj: TStringOutput;
  out AOut, AErr: IOutput
);
begin
  AOutObj := TStringOutput.Create;
  AErrObj := TStringOutput.Create;
  AOut := AOutObj;
  AErr := AErrObj;
end;

procedure ReleaseOutputs(
  var AOut, AErr: IOutput;
  var AOutObj, AErrObj: TStringOutput
);
begin
  AErr := nil;
  AOut := nil;
  AErrObj := nil;
  AOutObj := nil;
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

function MakePackage(const AName, AVersion: string): TPackageInfo;
begin
  Result := Default(TPackageInfo);
  Result.Name := AName;
  Result.Version := AVersion;
end;

function CreateTempDirPath(const APrefix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    APrefix + '_' + IntToStr(DateTimeToFileDate(Now)) + '_' + IntToStr(Random(1000000));
  ForceDirectories(Result);
end;

procedure TestPrepareUpdateHelpReturnsUsage;
var
  Plan: TPackageUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageUpdateCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('update prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('update prepare help requests exit', ShouldExit, 'should exit');
    Check('update prepare help writes usage', OutpObj.Contains('fpdev package update'), OutpObj.Text);
    Check('update prepare help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUpdateRejectsUnknownOption;
var
  Plan: TPackageUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageUpdateCommandPlanCore(['demo', '--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('update prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('update prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('update prepare unknown option writes usage', ErrpObj.Contains('fpdev package update'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUpdateParsesPackage;
var
  Plan: TPackageUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageUpdateCommandPlanCore(['demo'], Outp, Errp, Plan, ShouldExit);
    Check('update prepare green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('update prepare green path keeps running', not ShouldExit, 'unexpected exit');
    Check('update prepare green path keeps package name', Plan.PackageName = 'demo', Plan.PackageName);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteUpdateRejectsNotInstalled;
var
  Plan: TPackageUpdateCommandPlan;
  Probe: TPackageLifecycleProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.PackageName := 'demo';
  Probe := TPackageLifecycleProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageUpdateCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.GetAvailablePackages,
      @Probe.UpdatePackage
    );
    Check('update execute missing install returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('update execute missing install writes install hint', ErrpObj.Contains('install demo'), ErrpObj.Text);
    Check('update execute missing install does not call update', Probe.UpdateCalls = 0, IntToStr(Probe.UpdateCalls));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteUpdateRejectsMissingIndexEntry;
var
  Plan: TPackageUpdateCommandPlan;
  Probe: TPackageLifecycleProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.PackageName := 'demo';
  Probe := TPackageLifecycleProbe.Create;
  Probe.InstalledPackages := [MakePackage('demo', '1.0.0')];
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageUpdateCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.GetAvailablePackages,
      @Probe.UpdatePackage
    );
    Check('update execute missing index returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('update execute missing index writes repo hint', ErrpObj.Contains('repo update'), ErrpObj.Text);
    Check('update execute missing index does not call update', Probe.UpdateCalls = 0, IntToStr(Probe.UpdateCalls));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteUpdateMapsSuccessAndFailure;
var
  Plan: TPackageUpdateCommandPlan;
  Probe: TPackageLifecycleProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.PackageName := 'demo';
  Probe := TPackageLifecycleProbe.Create;
  Probe.InstalledPackages := [MakePackage('demo', '1.0.0')];
  Probe.AvailablePackages := [MakePackage('demo', '1.1.0')];
  Probe.UpdateResult := True;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageUpdateCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.GetAvailablePackages,
      @Probe.UpdatePackage
    );
    Check('update execute success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('update execute success calls update once', Probe.UpdateCalls = 1, IntToStr(Probe.UpdateCalls));
    Check('update execute success keeps target', Probe.LastTarget = 'demo', Probe.LastTarget);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;

  Probe.UpdateResult := False;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageUpdateCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.GetAvailablePackages,
      @Probe.UpdatePackage
    );
    Check('update execute failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareUninstallHelpReturnsUsage;
var
  Plan: TPackageUninstallCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageUninstallCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('uninstall prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('uninstall prepare help requests exit', ShouldExit, 'should exit');
    Check('uninstall prepare help writes usage', OutpObj.Contains('fpdev package uninstall'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUninstallRejectsExtraArg;
var
  Plan: TPackageUninstallCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageUninstallCommandPlanCore(['demo', 'extra'], Outp, Errp, Plan, ShouldExit);
    Check('uninstall prepare extra arg returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('uninstall prepare extra arg requests exit', ShouldExit, 'should exit');
    Check('uninstall prepare extra arg writes usage', ErrpObj.Contains('fpdev package uninstall'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUninstallParsesPackage;
var
  Plan: TPackageUninstallCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageUninstallCommandPlanCore(['demo'], Outp, Errp, Plan, ShouldExit);
    Check('uninstall prepare green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('uninstall prepare green path keeps running', not ShouldExit, 'unexpected exit');
    Check('uninstall prepare green path keeps package name', Plan.PackageName = 'demo', Plan.PackageName);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteUninstallRejectsNotInstalled;
var
  Plan: TPackageUninstallCommandPlan;
  Probe: TPackageLifecycleProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.PackageName := 'demo';
  Probe := TPackageLifecycleProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageUninstallCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.UninstallPackage
    );
    Check('uninstall execute missing install returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('uninstall execute missing install writes error', ErrpObj.Contains('not installed'), ErrpObj.Text);
    Check('uninstall execute missing install does not call uninstall', Probe.UninstallCalls = 0, IntToStr(Probe.UninstallCalls));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteUninstallMapsSuccessAndFailure;
var
  Plan: TPackageUninstallCommandPlan;
  Probe: TPackageLifecycleProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.PackageName := 'demo';
  Probe := TPackageLifecycleProbe.Create;
  Probe.InstalledPackages := [MakePackage('demo', '1.0.0')];
  Probe.UninstallResult := True;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageUninstallCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.UninstallPackage
    );
    Check('uninstall execute success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('uninstall execute success calls uninstall once', Probe.UninstallCalls = 1, IntToStr(Probe.UninstallCalls));
    Check('uninstall execute success keeps target', Probe.LastTarget = 'demo', Probe.LastTarget);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;

  Probe.UninstallResult := False;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageUninstallCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.UninstallPackage
    );
    Check('uninstall execute failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareInstallLocalHelpReturnsUsage;
var
  Plan: TPackageInstallLocalCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInstallLocalCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('install-local prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('install-local prepare help requests exit', ShouldExit, 'should exit');
    Check('install-local prepare help writes usage', OutpObj.Contains('fpdev package install-local'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareInstallLocalRejectsUnknownOption;
var
  Plan: TPackageInstallLocalCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInstallLocalCommandPlanCore(['/tmp/demo', '--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('install-local prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('install-local prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('install-local prepare unknown option writes usage', ErrpObj.Contains('fpdev package install-local'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareInstallLocalParsesTrimmedPath;
var
  Plan: TPackageInstallLocalCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInstallLocalCommandPlanCore(['  /tmp/demo  '], Outp, Errp, Plan, ShouldExit);
    Check('install-local prepare green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('install-local prepare green path keeps running', not ShouldExit, 'unexpected exit');
    Check('install-local prepare green path trims path', Plan.PackagePath = '/tmp/demo', Plan.PackagePath);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteInstallLocalRejectsMissingDirectory;
var
  Plan: TPackageInstallLocalCommandPlan;
  Probe: TPackageLifecycleProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.PackagePath := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'fpdev_missing_local_package';
  Probe := TPackageLifecycleProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageInstallLocalCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.InstallFromLocal
    );
    Check('install-local execute missing dir returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('install-local execute missing dir writes error', ErrpObj.Contains('Package path not found'), ErrpObj.Text);
    Check('install-local execute missing dir does not call install', Probe.InstallLocalCalls = 0, IntToStr(Probe.InstallLocalCalls));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteInstallLocalMapsSuccessAndFailure;
var
  Plan: TPackageInstallLocalCommandPlan;
  Probe: TPackageLifecycleProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  TempDir: string;
  Code: Integer;
begin
  TempDir := CreateTempDirPath('fpdev_package_lifecycle_local');
  Plan.PackagePath := TempDir;
  Probe := TPackageLifecycleProbe.Create;
  Probe.InstallLocalResult := True;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageInstallLocalCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.InstallFromLocal
    );
    Check('install-local execute success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('install-local execute success calls install once', Probe.InstallLocalCalls = 1, IntToStr(Probe.InstallLocalCalls));
    Check('install-local execute success keeps path', Probe.LastTarget = TempDir, Probe.LastTarget);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;

  Probe.InstallLocalResult := False;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageInstallLocalCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.InstallFromLocal
    );
    Check('install-local execute failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
    RemoveDir(TempDir);
  end;
end;

begin
  Randomize;

  TestPrepareUpdateHelpReturnsUsage;
  TestPrepareUpdateRejectsUnknownOption;
  TestPrepareUpdateParsesPackage;
  TestExecuteUpdateRejectsNotInstalled;
  TestExecuteUpdateRejectsMissingIndexEntry;
  TestExecuteUpdateMapsSuccessAndFailure;

  TestPrepareUninstallHelpReturnsUsage;
  TestPrepareUninstallRejectsExtraArg;
  TestPrepareUninstallParsesPackage;
  TestExecuteUninstallRejectsNotInstalled;
  TestExecuteUninstallMapsSuccessAndFailure;

  TestPrepareInstallLocalHelpReturnsUsage;
  TestPrepareInstallLocalRejectsUnknownOption;
  TestPrepareInstallLocalParsesTrimmedPath;
  TestExecuteInstallLocalRejectsMissingDirectory;
  TestExecuteInstallLocalMapsSuccessAndFailure;

  if FailCount > 0 then
  begin
    WriteLn;
    WriteLn(FailCount, ' tests failed, ', PassCount, ' passed');
    Halt(1);
  end;

  WriteLn;
  WriteLn(PassCount, ' passed / 0 failed');
end.
