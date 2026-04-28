program test_package_infocommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.types,
  fpdev.package.infocommandflow;

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

  TPackageInfoProbe = class
  public
    InstalledPackages: TPackageArray;
    ShowInfoResult: Boolean;
    ShowInfoCalls: Integer;
    LastPackageName: string;
    function GetInstalledPackages: TPackageArray;
    function ShowPackageInfo(const APackageName: string; Outp: IOutput): Boolean;
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

function TPackageInfoProbe.GetInstalledPackages: TPackageArray;
begin
  Result := InstalledPackages;
end;

function TPackageInfoProbe.ShowPackageInfo(const APackageName: string; Outp: IOutput): Boolean;
begin
  Inc(ShowInfoCalls);
  LastPackageName := APackageName;
  if Outp <> nil then
    Outp.WriteLn('info:' + APackageName);
  Result := ShowInfoResult;
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

function MakePackage(const AName: string): TPackageInfo;
begin
  Result := Default(TPackageInfo);
  Result.Name := AName;
end;

procedure TestPrepareHelpReturnsUsage;
var
  Plan: TPackageInfoCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInfoCommandPlanCore(
      ['--help'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage', OutpObj.Contains('fpdev package info'), OutpObj.Text);
    Check('prepare help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnknownOption;
var
  Plan: TPackageInfoCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInfoCommandPlanCore(
      ['demo', '--unknown'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare unknown option writes usage',
      ErrpObj.Contains('fpdev package info'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsMissingPackage;
var
  Plan: TPackageInfoCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInfoCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare missing package returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare missing package requests exit', ShouldExit, 'should exit');
    Check('prepare missing package writes usage',
      ErrpObj.Contains('fpdev package info'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsBlankPackage;
var
  Plan: TPackageInfoCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInfoCommandPlanCore(
      ['   '],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare blank package returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare blank package requests exit', ShouldExit, 'should exit');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnexpectedPositionalArg;
var
  Plan: TPackageInfoCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInfoCommandPlanCore(
      ['demo', 'extra'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional requests exit', ShouldExit, 'should exit');
    Check('prepare extra positional writes usage',
      ErrpObj.Contains('fpdev package info'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareKeepsPackageName;
var
  Plan: TPackageInfoCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageInfoCommandPlanCore(
      ['demo_pkg'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare green path keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare green path keeps package name', Plan.PackageName = 'demo_pkg', Plan.PackageName);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteRejectsPackageNotInstalled;
var
  Plan: TPackageInfoCommandPlan;
  Probe: TPackageInfoProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageInfoCommandPlan);
  Plan.PackageName := 'missing-demo';
  Probe := TPackageInfoProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageInfoCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.ShowPackageInfo
    );
    Check('execute missing package returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('execute missing package does not call show info', Probe.ShowInfoCalls = 0, IntToStr(Probe.ShowInfoCalls));
    Check('execute missing package writes stderr',
      Pos('not found', LowerCase(ErrpObj.Text)) > 0, ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteCallsShowInfoAndReturnsOk;
var
  Plan: TPackageInfoCommandPlan;
  Probe: TPackageInfoProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageInfoCommandPlan);
  Plan.PackageName := 'demo';
  Probe := TPackageInfoProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    SetLength(Probe.InstalledPackages, 1);
    Probe.InstalledPackages[0] := MakePackage('demo');
    Probe.ShowInfoResult := True;

    Code := ExecutePackageInfoCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.ShowPackageInfo
    );
    Check('execute success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute success calls show info once', Probe.ShowInfoCalls = 1, IntToStr(Probe.ShowInfoCalls));
    Check('execute success keeps package name', Probe.LastPackageName = 'demo', Probe.LastPackageName);
    Check('execute success forwards output', OutpObj.Contains('info:demo'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteFailureMapsToExitError;
var
  Plan: TPackageInfoCommandPlan;
  Probe: TPackageInfoProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageInfoCommandPlan);
  Plan.PackageName := 'demo';
  Probe := TPackageInfoProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    SetLength(Probe.InstalledPackages, 1);
    Probe.InstalledPackages[0] := MakePackage('demo');
    Probe.ShowInfoResult := False;

    Code := ExecutePackageInfoCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.ShowPackageInfo
    );
    Check('execute failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute failure calls show info once', Probe.ShowInfoCalls = 1, IntToStr(Probe.ShowInfoCalls));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== Package Info Commandflow Tests ===');

  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnknownOption;
  TestPrepareRejectsMissingPackage;
  TestPrepareRejectsBlankPackage;
  TestPrepareRejectsUnexpectedPositionalArg;
  TestPrepareKeepsPackageName;

  TestExecuteRejectsPackageNotInstalled;
  TestExecuteCallsShowInfoAndReturnsOk;
  TestExecuteFailureMapsToExitError;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
