program test_package_whycommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.whycommandflow;

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

procedure TestPrepareHelpReturnsUsage;
var
  Plan: TPackageWhyCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageWhyCommandPlanCore(
      ['--help'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage', OutpObj.Contains('fpdev package why'), OutpObj.Text);
    Check('prepare help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnknownOption;
var
  Plan: TPackageWhyCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageWhyCommandPlanCore(
      ['--unknown'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare unknown option writes usage', ErrpObj.Contains('fpdev package why'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsMissingPackage;
var
  Plan: TPackageWhyCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageWhyCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare missing package returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare missing package requests exit', ShouldExit, 'should exit');
    Check('prepare missing package writes error', ErrpObj.Contains('Missing argument'), ErrpObj.Text);
    Check('prepare missing package writes usage', ErrpObj.Contains('fpdev package why'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsExtraPositional;
var
  Plan: TPackageWhyCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageWhyCommandPlanCore(
      ['zlib', 'extra'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional requests exit', ShouldExit, 'should exit');
    Check('prepare extra positional writes usage', ErrpObj.Contains('fpdev package why'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareKeepsPackage;
var
  Plan: TPackageWhyCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageWhyCommandPlanCore(
      ['zlib'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare package returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare package keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare package keeps name', Plan.PackageName = 'zlib', Plan.PackageName);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteOutput;
var
  Plan: TPackageWhyCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageWhyCommandPlan);
  Plan.PackageName := 'zlib';
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageWhyCommandPlanCore(Plan, Outp, Errp);
    Check('execute returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute shows header', OutpObj.Contains('Why is "zlib" installed?'), OutpObj.Text);
    Check('execute shows path heading', OutpObj.Contains('Dependency path:'), OutpObj.Text);
    Check('execute shows tree root', OutpObj.Contains('+-- fpdev-core >= 1.0.0'), OutpObj.Text);
    Check('execute shows tree leaf', OutpObj.Contains('+-- zlib'), OutpObj.Text);
    Check('execute shows required by', OutpObj.Contains('Required by: fpdev-core'), OutpObj.Text);
    Check('execute shows constraint', OutpObj.Contains('Constraint: >= 1.0.0'), OutpObj.Text);
    Check('execute keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

begin
  WriteLn('=== Package Why Commandflow Tests ===');

  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnknownOption;
  TestPrepareRejectsMissingPackage;
  TestPrepareRejectsExtraPositional;
  TestPrepareKeepsPackage;
  TestExecuteOutput;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
