program test_package_searchcommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.searchcommandflow;

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

  TPackageSearchProbe = class
  public
    TextSearchResult: Boolean;
    TextSearchCalls: Integer;
    JSONSearchCalls: Integer;
    LastTextQuery: string;
    LastJSONQuery: string;
    JSONResults: TStringList;
    constructor Create;
    destructor Destroy; override;
    function SearchText(const AQuery: string; Outp: IOutput): Boolean;
    function SearchJSON(const AQuery: string): TStringList;
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

constructor TPackageSearchProbe.Create;
begin
  inherited Create;
  JSONResults := TStringList.Create;
  TextSearchResult := True;
end;

destructor TPackageSearchProbe.Destroy;
begin
  JSONResults.Free;
  inherited Destroy;
end;

function TPackageSearchProbe.SearchText(const AQuery: string; Outp: IOutput): Boolean;
begin
  Inc(TextSearchCalls);
  LastTextQuery := AQuery;
  if Outp <> nil then
    Outp.WriteLn('text:' + AQuery);
  Result := TextSearchResult;
end;

function TPackageSearchProbe.SearchJSON(const AQuery: string): TStringList;
begin
  Inc(JSONSearchCalls);
  LastJSONQuery := AQuery;
  Result := TStringList.Create;
  Result.Assign(JSONResults);
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
  Plan: TPackageSearchCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageSearchCommandPlanCore(
      ['--help'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help writes usage', OutpObj.Contains('fpdev package search'), OutpObj.Text);
    Check('prepare help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnknownOption;
var
  Plan: TPackageSearchCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageSearchCommandPlanCore(
      ['demo', '--unknown'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare unknown option returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare unknown option requests exit', ShouldExit, 'should exit');
    Check('prepare unknown option writes usage',
      ErrpObj.Contains('fpdev package search'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsMissingQuery;
var
  Plan: TPackageSearchCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageSearchCommandPlanCore(
      [],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare missing query returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare missing query requests exit', ShouldExit, 'should exit');
    Check('prepare missing query writes usage',
      ErrpObj.Contains('fpdev package search'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsBlankQuery;
var
  Plan: TPackageSearchCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageSearchCommandPlanCore(
      ['   '],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare blank query returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare blank query requests exit', ShouldExit, 'should exit');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareRejectsUnexpectedPositionalArg;
var
  Plan: TPackageSearchCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageSearchCommandPlanCore(
      ['demo', 'extra'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional requests exit', ShouldExit, 'should exit');
    Check('prepare extra positional writes usage',
      ErrpObj.Contains('fpdev package search'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareParsesQueryAndJsonFlag;
var
  Plan: TPackageSearchCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PreparePackageSearchCommandPlanCore(
      ['--json', 'demo_pkg'],
      Outp,
      Errp,
      Plan,
      ShouldExit
    );
    Check('prepare green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare green path keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare green path keeps query', Plan.Query = 'demo_pkg', Plan.Query);
    Check('prepare green path keeps json flag', Plan.JsonOutput, 'json flag missing');
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteTextSearchSuccess;
var
  Plan: TPackageSearchCommandPlan;
  Probe: TPackageSearchProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageSearchCommandPlan);
  Plan.Query := 'demo';
  Probe := TPackageSearchProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.TextSearchResult := True;
    Code := ExecutePackageSearchCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.SearchText,
      @Probe.SearchJSON
    );
    Check('execute text success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute text success calls text callback once', Probe.TextSearchCalls = 1, IntToStr(Probe.TextSearchCalls));
    Check('execute text success keeps query', Probe.LastTextQuery = 'demo', Probe.LastTextQuery);
    Check('execute text success does not call json callback', Probe.JSONSearchCalls = 0, IntToStr(Probe.JSONSearchCalls));
    Check('execute text success forwards output', OutpObj.Contains('text:demo'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteTextSearchFailureMapsToExitError;
var
  Plan: TPackageSearchCommandPlan;
  Probe: TPackageSearchProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageSearchCommandPlan);
  Plan.Query := 'demo';
  Probe := TPackageSearchProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.TextSearchResult := False;
    Code := ExecutePackageSearchCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.SearchText,
      @Probe.SearchJSON
    );
    Check('execute text failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute text failure calls text callback once', Probe.TextSearchCalls = 1, IntToStr(Probe.TextSearchCalls));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteJsonSearchWritesJSON;
var
  Plan: TPackageSearchCommandPlan;
  Probe: TPackageSearchProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
  JSONData: TJSONData;
  JSONObject: TJSONObject;
  Results: TJSONArray;
begin
  Plan := Default(TPackageSearchCommandPlan);
  Plan.Query := 'demo';
  Plan.JsonOutput := True;
  Probe := TPackageSearchProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  JSONData := nil;
  try
    Probe.JSONResults.Add('demo-one');
    Probe.JSONResults.Add('demo-two');

    Code := ExecutePackageSearchCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.SearchText,
      @Probe.SearchJSON
    );
    Check('execute json success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute json success calls json callback once', Probe.JSONSearchCalls = 1, IntToStr(Probe.JSONSearchCalls));
    Check('execute json success keeps query', Probe.LastJSONQuery = 'demo', Probe.LastJSONQuery);
    Check('execute json success does not call text callback', Probe.TextSearchCalls = 0, IntToStr(Probe.TextSearchCalls));

    try
      JSONData := GetJSON(OutpObj.Text);
      JSONObject := TJSONObject(JSONData);
      Results := JSONObject.Arrays['results'];
      Check('execute json writes query field', JSONObject.Get('query', '') = 'demo');
      Check('execute json writes count field', JSONObject.Get('count', -1) = 2);
      Check('execute json writes first result',
        (Results <> nil) and (Results.Count = 2) and (Results.Strings[0] = 'demo-one'));
    except
      on E: Exception do
        Check('execute json writes valid JSON', False, E.Message);
    end;
  finally
    if JSONData <> nil then
      JSONData.Free;
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteJsonRequiresCallback;
var
  Plan: TPackageSearchCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan := Default(TPackageSearchCommandPlan);
  Plan.Query := 'demo';
  Plan.JsonOutput := True;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := ExecutePackageSearchCommandPlanCore(
      Plan,
      Outp,
      Errp,
      nil,
      nil
    );
    Check('execute json missing callback returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

begin
  WriteLn('=== Package Search Commandflow Tests ===');

  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsUnknownOption;
  TestPrepareRejectsMissingQuery;
  TestPrepareRejectsBlankQuery;
  TestPrepareRejectsUnexpectedPositionalArg;
  TestPrepareParsesQueryAndJsonFlag;

  TestExecuteTextSearchSuccess;
  TestExecuteTextSearchFailureMapsToExitError;
  TestExecuteJsonSearchWritesJSON;
  TestExecuteJsonRequiresCallback;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
