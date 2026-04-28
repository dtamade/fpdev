program test_package_listcommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.types,
  fpdev.package.listcommandflow;

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

  TPackageListProbe = class
  public
    InstalledPackages: TPackageArray;
    AvailablePackages: TPackageArray;
    TextListResult: Boolean;
    TextListCalls: Integer;
    LastShowAll: Boolean;
    function GetInstalledPackages: TPackageArray;
    function GetAvailablePackages: TPackageArray;
    function ListPackages(const AShowAll: Boolean; Outp: IOutput): Boolean;
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

function TPackageListProbe.GetInstalledPackages: TPackageArray;
begin
  Result := InstalledPackages;
end;

function TPackageListProbe.GetAvailablePackages: TPackageArray;
begin
  Result := AvailablePackages;
end;

function TPackageListProbe.ListPackages(const AShowAll: Boolean; Outp: IOutput): Boolean;
begin
  Inc(TextListCalls);
  LastShowAll := AShowAll;
  if Outp <> nil then
    Outp.WriteLn('text:' + BoolToStr(AShowAll, True));
  Result := TextListResult;
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

function MakePackage(const AName, AVersion, ADescription: string): TPackageInfo;
begin
  Result := Default(TPackageInfo);
  Result.Name := AName;
  Result.Version := AVersion;
  Result.Description := ADescription;
  Result.Author := 'fpdev-test';
  Result.License := 'MIT';
  Result.Homepage := 'https://example.test/' + AName;
  SetLength(Result.Dependencies, 2);
  Result.Dependencies[0] := 'dep-one';
  Result.Dependencies[1] := 'dep-two';
end;

procedure TestPrepareHelpReturnsUsage;
var
  Plan: TPackageListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageListCommandPlanCore(
      ['--help'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage', OutpObj.Contains('fpdev package list'), OutpObj.Text);
    Check('prepare help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnknownOption;
var
  Plan: TPackageListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageListCommandPlanCore(
      ['--unknown'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare unknown option writes usage', ErrpObj.Contains('fpdev package list'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnexpectedPositionalArg;
var
  Plan: TPackageListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageListCommandPlanCore(
      ['unexpected'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional requests exit', ShouldExit, 'should exit');
    Check('prepare extra positional writes usage', ErrpObj.Contains('fpdev package list'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareDefaultsToInstalledTextMode;
var
  Plan: TPackageListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageListCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare defaults returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare defaults keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare defaults keeps show-all false', not Plan.ShowAll, 'show-all should be false');
    Check('prepare defaults keeps json false', not Plan.JsonOutput, 'json should be false');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareParsesAllAndJsonFlags;
var
  Plan: TPackageListCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageListCommandPlanCore(
      ['-a', '--json'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare flags returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare flags keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare flags keeps show-all true', Plan.ShowAll, 'show-all missing');
    Check('prepare flags keeps json true', Plan.JsonOutput, 'json missing');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteTextCallsListPackagesAndReturnsOk;
var
  Plan: TPackageListCommandPlan;
  Probe: TPackageListProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageListCommandPlan);
  Probe := TPackageListProbe.Create;
  Probe.TextListResult := True;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageListCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.ListPackages,
      @Probe.GetAvailablePackages,
      @Probe.GetInstalledPackages
    );
    Check('execute text success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute text success calls list once', Probe.TextListCalls = 1, IntToStr(Probe.TextListCalls));
    Check('execute text success keeps show-all false', not Probe.LastShowAll, 'show-all should be false');
    Check('execute text success forwards output', OutpObj.Contains('text:False'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteTextFailureMapsToExitError;
var
  Plan: TPackageListCommandPlan;
  Probe: TPackageListProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageListCommandPlan);
  Probe := TPackageListProbe.Create;
  Probe.TextListResult := False;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageListCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.ListPackages,
      @Probe.GetAvailablePackages,
      @Probe.GetInstalledPackages
    );
    Check('execute text failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute text failure still calls list once', Probe.TextListCalls = 1, IntToStr(Probe.TextListCalls));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteJsonUsesInstalledPackagesByDefault;
var
  Plan: TPackageListCommandPlan;
  Probe: TPackageListProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
  JSONData: TJSONData;
  JSONObject: TJSONObject;
  Packages: TJSONArray;
begin
  Plan := Default(TPackageListCommandPlan);
  Plan.JsonOutput := True;
  Probe := TPackageListProbe.Create;
  SetLength(Probe.InstalledPackages, 1);
  Probe.InstalledPackages[0] := MakePackage('installed-demo', '1.0.0', 'installed package');
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  JSONData := nil;
  try
    Code := ExecutePackageListCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.ListPackages,
      @Probe.GetAvailablePackages,
      @Probe.GetInstalledPackages
    );
    Check('execute json installed returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute json installed skips text callback', Probe.TextListCalls = 0, IntToStr(Probe.TextListCalls));

    JSONData := GetJSON(OutpObj.Text);
    JSONObject := TJSONObject(JSONData);
    Packages := JSONObject.Arrays['packages'];
    Check('execute json installed keeps show_all false', not JSONObject.Get('show_all', True), OutpObj.Text);
    Check('execute json installed keeps package count', (Packages <> nil) and (Packages.Count = 1), OutpObj.Text);
    Check('execute json installed keeps package name',
      (Packages <> nil) and (Packages.Objects[0].Get('name', '') = 'installed-demo'), OutpObj.Text);
  finally
    if JSONData <> nil then
      JSONData.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteJsonUsesAvailablePackagesForAll;
var
  Plan: TPackageListCommandPlan;
  Probe: TPackageListProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
  JSONData: TJSONData;
  JSONObject: TJSONObject;
  Packages: TJSONArray;
begin
  Plan := Default(TPackageListCommandPlan);
  Plan.ShowAll := True;
  Plan.JsonOutput := True;
  Probe := TPackageListProbe.Create;
  SetLength(Probe.AvailablePackages, 1);
  Probe.AvailablePackages[0] := MakePackage('available-demo', '2.0.0', 'available package');
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  JSONData := nil;
  try
    Code := ExecutePackageListCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.ListPackages,
      @Probe.GetAvailablePackages,
      @Probe.GetInstalledPackages
    );
    Check('execute json available returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute json available skips text callback', Probe.TextListCalls = 0, IntToStr(Probe.TextListCalls));

    JSONData := GetJSON(OutpObj.Text);
    JSONObject := TJSONObject(JSONData);
    Packages := JSONObject.Arrays['packages'];
    Check('execute json available keeps show_all true', JSONObject.Get('show_all', False), OutpObj.Text);
    Check('execute json available keeps package count', (Packages <> nil) and (Packages.Count = 1), OutpObj.Text);
    Check('execute json available keeps package name',
      (Packages <> nil) and (Packages.Objects[0].Get('name', '') = 'available-demo'), OutpObj.Text);
  finally
    if JSONData <> nil then
      JSONData.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== Package List Commandflow Tests ===');

  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnknownOption;
  TestPrepareRejectsUnexpectedPositionalArg;
  TestPrepareDefaultsToInstalledTextMode;
  TestPrepareParsesAllAndJsonFlags;

  TestExecuteTextCallsListPackagesAndReturnsOk;
  TestExecuteTextFailureMapsToExitError;
  TestExecuteJsonUsesInstalledPackagesByDefault;
  TestExecuteJsonUsesAvailablePackagesForAll;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
