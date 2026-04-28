program test_package_publishcommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.types,
  fpdev.package.publishcommandflow;

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

  TPackagePublishProbe = class
  public
    InstalledPackages: TPackageArray;
    PublishResult: Boolean;
    LastExitCode: Integer;
    PublishCalls: Integer;
    LastPackageName: string;
    function GetInstalledPackages: TPackageArray;
    function PublishPackage(const APackageName: string; Outp: IOutput; Errp: IOutput): Boolean;
    function GetLastPublishExitCode: Integer;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  TempRootCounter: Integer = 0;

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

function TPackagePublishProbe.GetInstalledPackages: TPackageArray;
begin
  Result := InstalledPackages;
end;

function TPackagePublishProbe.PublishPackage(
  const APackageName: string;
  Outp: IOutput;
  Errp: IOutput
): Boolean;
begin
  Inc(PublishCalls);
  LastPackageName := APackageName;
  if Outp = nil then;
  if Errp = nil then;
  Result := PublishResult;
end;

function TPackagePublishProbe.GetLastPublishExitCode: Integer;
begin
  Result := LastExitCode;
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

function MakePackage(const AName, AInstallPath: string): TPackageInfo;
begin
  Result := Default(TPackageInfo);
  Result.Name := AName;
  Result.InstallPath := AInstallPath;
end;

function CreateTempRoot(const APrefix: string): string;
begin
  Inc(TempRootCounter);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + APrefix + '_' +
    FormatDateTime('yyyymmddhhnnsszzz', Now) + '_' + IntToStr(TempRootCounter);
  ForceDirectories(Result);
end;

procedure CleanupTempRoot(const ARoot: string);
var
  MetadataPath: string;
begin
  MetadataPath := IncludeTrailingPathDelimiter(ARoot) + 'package.json';
  if FileExists(MetadataPath) then
    DeleteFile(MetadataPath);
  RemoveDir(ARoot);
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

procedure WriteMetadataFile(const APackageRoot: string);
var
  SL: TStringList;
begin
  ForceDirectories(APackageRoot);
  SL := TStringList.Create;
  try
    SL.Text := '{' + LineEnding +
      '  "name": "demo",' + LineEnding +
      '  "version": "1.2.3"' + LineEnding +
      '}';
    SL.SaveToFile(IncludeTrailingPathDelimiter(APackageRoot) + 'package.json');
  finally
    SL.Free;
  end;
end;

procedure TestPrepareHelpReturnsUsage;
var
  Plan: TPackagePublishCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackagePublishCommandPlanCore(
      ['--help'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage',
      OutpObj.Contains('fpdev package publish'), OutpObj.Text);
    Check('prepare help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnknownOption;
var
  Plan: TPackagePublishCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackagePublishCommandPlanCore(
      ['demo', '--unknown'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare unknown option writes usage',
      ErrpObj.Contains('fpdev package publish'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsMissingPackage;
var
  Plan: TPackagePublishCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackagePublishCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare missing package returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare missing package requests exit', ShouldExit, 'should exit');
    Check('prepare missing package writes usage',
      ErrpObj.Contains('fpdev package publish'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnexpectedPositionalArg;
var
  Plan: TPackagePublishCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackagePublishCommandPlanCore(
      ['demo', 'extra'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional requests exit', ShouldExit, 'should exit');
    Check('prepare extra positional writes usage',
      ErrpObj.Contains('fpdev package publish'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareKeepsPackageName;
var
  Plan: TPackagePublishCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackagePublishCommandPlanCore(
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
  Plan: TPackagePublishCommandPlan;
  Probe: TPackagePublishProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackagePublishCommandPlan);
  Plan.PackageName := 'missing-demo';
  Probe := TPackagePublishProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackagePublishCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.PublishPackage,
      @Probe.GetLastPublishExitCode
    );
    Check('execute missing package returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('execute missing package does not call publish', Probe.PublishCalls = 0, IntToStr(Probe.PublishCalls));
    Check('execute missing package writes stderr',
      Pos('not found', LowerCase(ErrpObj.Text)) > 0, ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteRejectsMissingMetadata;
var
  Plan: TPackagePublishCommandPlan;
  Probe: TPackagePublishProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Root: string;
  Code: Integer;
begin
  Root := CreateTempRoot('fpdev_publishcommandflow_missing_meta');
  Plan := Default(TPackagePublishCommandPlan);
  Plan.PackageName := 'demo';
  Probe := TPackagePublishProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    SetLength(Probe.InstalledPackages, 1);
    Probe.InstalledPackages[0] := MakePackage('demo', Root);

    Code := ExecutePackagePublishCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.PublishPackage,
      @Probe.GetLastPublishExitCode
    );
    Check('execute missing metadata returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('execute missing metadata does not call publish', Probe.PublishCalls = 0, IntToStr(Probe.PublishCalls));
    Check('execute missing metadata writes stderr',
      Pos('metadata', LowerCase(ErrpObj.Text)) > 0, ErrpObj.Text);
  finally
    CleanupTempRoot(Root);
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteCallsPublishAndReturnsOk;
var
  Plan: TPackagePublishCommandPlan;
  Probe: TPackagePublishProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Root: string;
  Code: Integer;
begin
  Root := CreateTempRoot('fpdev_publishcommandflow_success');
  WriteMetadataFile(Root);

  Plan := Default(TPackagePublishCommandPlan);
  Plan.PackageName := 'demo';
  Probe := TPackagePublishProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    SetLength(Probe.InstalledPackages, 1);
    Probe.InstalledPackages[0] := MakePackage('demo', Root);
    Probe.PublishResult := True;
    Probe.LastExitCode := EXIT_ERROR;

    Code := ExecutePackagePublishCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.PublishPackage,
      @Probe.GetLastPublishExitCode
    );
    Check('execute success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute success calls publish once', Probe.PublishCalls = 1, IntToStr(Probe.PublishCalls));
    Check('execute success keeps package name', Probe.LastPackageName = 'demo', Probe.LastPackageName);
  finally
    CleanupTempRoot(Root);
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecutePropagatesManagerExitCode;
var
  Plan: TPackagePublishCommandPlan;
  Probe: TPackagePublishProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Root: string;
  Code: Integer;
begin
  Root := CreateTempRoot('fpdev_publishcommandflow_exit_code');
  WriteMetadataFile(Root);

  Plan := Default(TPackagePublishCommandPlan);
  Plan.PackageName := 'demo';
  Probe := TPackagePublishProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    SetLength(Probe.InstalledPackages, 1);
    Probe.InstalledPackages[0] := MakePackage('demo', Root);
    Probe.PublishResult := False;
    Probe.LastExitCode := EXIT_NOT_FOUND;

    Code := ExecutePackagePublishCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.PublishPackage,
      @Probe.GetLastPublishExitCode
    );
    Check('execute failure returns manager exit code', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('execute failure calls publish once', Probe.PublishCalls = 1, IntToStr(Probe.PublishCalls));
  finally
    CleanupTempRoot(Root);
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteMapsZeroManagerExitCodeToExitError;
var
  Plan: TPackagePublishCommandPlan;
  Probe: TPackagePublishProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Root: string;
  Code: Integer;
begin
  Root := CreateTempRoot('fpdev_publishcommandflow_zero_exit');
  WriteMetadataFile(Root);

  Plan := Default(TPackagePublishCommandPlan);
  Plan.PackageName := 'demo';
  Probe := TPackagePublishProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    SetLength(Probe.InstalledPackages, 1);
    Probe.InstalledPackages[0] := MakePackage('demo', Root);
    Probe.PublishResult := False;
    Probe.LastExitCode := EXIT_OK;

    Code := ExecutePackagePublishCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.GetInstalledPackages,
      @Probe.PublishPackage,
      @Probe.GetLastPublishExitCode
    );
    Check('execute zero manager exit maps to EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    CleanupTempRoot(Root);
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== Package Publish Commandflow Tests ===');

  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnknownOption;
  TestPrepareRejectsMissingPackage;
  TestPrepareRejectsUnexpectedPositionalArg;
  TestPrepareKeepsPackageName;

  TestExecuteRejectsPackageNotInstalled;
  TestExecuteRejectsMissingMetadata;
  TestExecuteCallsPublishAndReturnsOk;
  TestExecutePropagatesManagerExitCode;
  TestExecuteMapsZeroManagerExitCodeToExitError;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
