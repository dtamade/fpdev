program test_package_installcommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.types,
  fpdev.package.installcommandflow;

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

  TPackageInstallProbe = class
  public
    AvailablePackages: TPackageArray;
    InstallResult: Boolean;
    KeepArtifactsCalls: Integer;
    LastKeepArtifacts: Boolean;
    InstallCalls: Integer;
    LastInstallPackage: string;
    LastInstallVersion: string;
    function GetAvailablePackages: TPackageArray;
    procedure SetKeepArtifacts(const AValue: Boolean);
    function InstallPackage(
      const APackageName: string;
      const AVersion: string;
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

function TPackageInstallProbe.GetAvailablePackages: TPackageArray;
begin
  Result := AvailablePackages;
end;

procedure TPackageInstallProbe.SetKeepArtifacts(const AValue: Boolean);
begin
  Inc(KeepArtifactsCalls);
  LastKeepArtifacts := AValue;
end;

function TPackageInstallProbe.InstallPackage(
  const APackageName: string;
  const AVersion: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Inc(InstallCalls);
  LastInstallPackage := APackageName;
  LastInstallVersion := AVersion;
  if Outp = nil then;
  if Errp = nil then;
  Result := InstallResult;
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

procedure TestPrepareHelpReturnsUsage;
var
  Plan: TPackageInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PreparePackageInstallCommandPlanCore(
      ['--help'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage', Outp.Contains('fpdev package install'), Outp.Text);
    Check('prepare help keeps stderr empty', Trim(Errp.Text) = '', Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareRejectsUnknownOption;
var
  Plan: TPackageInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PreparePackageInstallCommandPlanCore(
      ['demo', '--unknown'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare unknown option writes usage', Errp.Contains('fpdev package install'), Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareParsesPackageVersionAndFlags;
var
  Plan: TPackageInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PreparePackageInstallCommandPlanCore(
      ['demo', '1.2.3', '--keep-build-artifacts', '--no-deps'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare green path keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare green path keeps package name', Plan.PackageName = 'demo', Plan.PackageName);
    Check('prepare green path keeps version', Plan.Version = '1.2.3', Plan.Version);
    Check('prepare green path keeps keep-artifacts', Plan.KeepBuildArtifacts, 'flag missing');
    Check('prepare green path keeps no-deps', Plan.NoDeps, 'flag missing');
    Check('prepare green path dry-run stays false', not Plan.DryRun, 'dry-run should be false');
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareRejectsUnexpectedPositionalArg;
var
  Plan: TPackageInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PreparePackageInstallCommandPlanCore(
      ['demo', '1.2.3', 'extra'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional writes usage', Errp.Contains('fpdev package install'), Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestExecuteDryRunDoesNotInstall;
var
  Plan: TPackageInstallCommandPlan;
  Probe: TPackageInstallProbe;
  Outp, Errp: TStringOutput;
  OutRef, ErrRef: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageInstallCommandPlan);
  Plan.PackageName := 'demo';
  Plan.DryRun := True;
  Plan.NoDeps := True;

  Probe := TPackageInstallProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  OutRef := Outp;
  ErrRef := Errp;
  try
    Code := ExecutePackageInstallCommandPlanCore(
      Plan,
      OutRef,
      ErrRef,
      @Probe.SetKeepArtifacts,
      nil,
      @Probe.GetAvailablePackages,
      @Probe.InstallPackage
    );
    Check('execute dry-run returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute dry-run prints header', Outp.Contains('Dry-run mode'), Outp.Text);
    Check('execute dry-run prints package', Outp.Contains('Package: demo'), Outp.Text);
    Check('execute dry-run prints deps skipped', Outp.Contains('Dependencies: skipped'), Outp.Text);
    Check('execute dry-run does not install', Probe.InstallCalls = 0, IntToStr(Probe.InstallCalls));
  finally
    ErrRef := nil;
    OutRef := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteWarnsAboutNoDepsAndInstallsGreenPath;
var
  Plan: TPackageInstallCommandPlan;
  Probe: TPackageInstallProbe;
  Outp, Errp: TStringOutput;
  OutRef, ErrRef: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageInstallCommandPlan);
  Plan.PackageName := 'demo';
  Plan.Version := '1.2.3';
  Plan.KeepBuildArtifacts := True;
  Plan.NoDeps := True;

  Probe := TPackageInstallProbe.Create;
  SetLength(Probe.AvailablePackages, 1);
  Probe.AvailablePackages[0] := MakePackage('demo', '1.2.3');
  Probe.InstallResult := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  OutRef := Outp;
  ErrRef := Errp;
  try
    Code := ExecutePackageInstallCommandPlanCore(
      Plan,
      OutRef,
      ErrRef,
      @Probe.SetKeepArtifacts,
      nil,
      @Probe.GetAvailablePackages,
      @Probe.InstallPackage
    );
    Check('execute green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute green path warns about no-deps',
      Outp.Contains('Installing with dependencies'),
      Outp.Text);
    Check('execute green path sets keep artifacts once', Probe.KeepArtifactsCalls = 1, IntToStr(Probe.KeepArtifactsCalls));
    Check('execute green path passes keep artifacts true', Probe.LastKeepArtifacts, 'keep artifacts false');
    Check('execute green path installs once', Probe.InstallCalls = 1, IntToStr(Probe.InstallCalls));
    Check('execute green path keeps package name', Probe.LastInstallPackage = 'demo', Probe.LastInstallPackage);
    Check('execute green path keeps version', Probe.LastInstallVersion = '1.2.3', Probe.LastInstallVersion);
  finally
    ErrRef := nil;
    OutRef := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteReturnsNotFoundForMissingPackage;
var
  Plan: TPackageInstallCommandPlan;
  Probe: TPackageInstallProbe;
  Outp, Errp: TStringOutput;
  OutRef, ErrRef: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageInstallCommandPlan);
  Plan.PackageName := 'missing';

  Probe := TPackageInstallProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  OutRef := Outp;
  ErrRef := Errp;
  try
    Code := ExecutePackageInstallCommandPlanCore(
      Plan,
      OutRef,
      ErrRef,
      @Probe.SetKeepArtifacts,
      nil,
      @Probe.GetAvailablePackages,
      @Probe.InstallPackage
    );
    Check('execute missing package returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('execute missing package prints index error',
      Errp.Contains(_Fmt(CMD_PKG_NOT_IN_INDEX, ['missing'])),
      Errp.Text);
    Check('execute missing package does not install', Probe.InstallCalls = 0, IntToStr(Probe.InstallCalls));
  finally
    ErrRef := nil;
    OutRef := nil;
    Probe.Free;
  end;
end;

procedure TestExecuteMapsInstallFailureToExitError;
var
  Plan: TPackageInstallCommandPlan;
  Probe: TPackageInstallProbe;
  Outp, Errp: TStringOutput;
  OutRef, ErrRef: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageInstallCommandPlan);
  Plan.PackageName := 'demo';

  Probe := TPackageInstallProbe.Create;
  SetLength(Probe.AvailablePackages, 1);
  Probe.AvailablePackages[0] := MakePackage('demo', '2.0.0');
  Probe.InstallResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  OutRef := Outp;
  ErrRef := Errp;
  try
    Code := ExecutePackageInstallCommandPlanCore(
      Plan,
      OutRef,
      ErrRef,
      @Probe.SetKeepArtifacts,
      nil,
      @Probe.GetAvailablePackages,
      @Probe.InstallPackage
    );
    Check('execute failed install returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute failed install still calls install', Probe.InstallCalls = 1, IntToStr(Probe.InstallCalls));
  finally
    ErrRef := nil;
    OutRef := nil;
    Probe.Free;
  end;
end;

begin
  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnknownOption;
  TestPrepareParsesPackageVersionAndFlags;
  TestPrepareRejectsUnexpectedPositionalArg;
  TestExecuteDryRunDoesNotInstall;
  TestExecuteWarnsAboutNoDepsAndInstallsGreenPath;
  TestExecuteReturnsNotFoundForMissingPackage;
  TestExecuteMapsInstallFailureToExitError;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  WriteLn('Total: ', PassCount + FailCount);

  if FailCount > 0 then
    Halt(1);
end.
