program test_lazarus_leafcommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.lazarus.leafcommandflow;

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
    function FirstLine: string;
    function LineCount: Integer;
    function Text: string;
  end;

  TLazarusLeafProbe = class
  public
    CurrentVersion: string;
    ValidVersion: Boolean;
    SetDefaultResult: Boolean;
    ShowResult: Boolean;
    ConfigureResult: Boolean;
    UninstallResult: Boolean;
    UpdateResult: Boolean;
    TestResult: Boolean;
    SetDefaultWritesToOut: string;
    SetDefaultWritesToErr: string;
    ShowWritesToOut: string;
    ConfigureWritesToOut: string;
    ConfigureWritesToErr: string;
    UninstallWritesToOut: string;
    UninstallWritesToErr: string;
    UpdateWritesToOut: string;
    UpdateWritesToErr: string;
    TestWritesToOut: string;
    TestWritesToErr: string;
    GetCurrentVersionCalls: Integer;
    SetDefaultCalls: Integer;
    ShowCalls: Integer;
    ConfigureCalls: Integer;
    UninstallCalls: Integer;
    UpdateCalls: Integer;
    TestCalls: Integer;
    LastVersion: string;
    function GetCurrentVersion: string;
    function IsValidVersion(const AVersion: string): Boolean;
    function SetDefaultVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;
    function ShowVersionInfo(const Outp: IOutput; const AVersion: string): Boolean;
    function ConfigureIDE(const Outp, Errp: IOutput; const AVersion: string): Boolean;
    function UninstallVersion(const Outp, Errp: IOutput; const AVersion: string): Boolean;
    function UpdateSources(const Outp, Errp: IOutput; const AVersion: string): Boolean;
    function TestInstallation(const Outp, Errp: IOutput; const AVersion: string): Boolean;
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

function TStringOutput.FirstLine: string;
begin
  if FBuffer.Count > 0 then
    Result := FBuffer[0]
  else
    Result := '';
end;

function TStringOutput.LineCount: Integer;
begin
  Result := FBuffer.Count;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TLazarusLeafProbe.GetCurrentVersion: string;
begin
  Inc(GetCurrentVersionCalls);
  Result := CurrentVersion;
end;

function TLazarusLeafProbe.IsValidVersion(const AVersion: string): Boolean;
begin
  LastVersion := AVersion;
  Result := ValidVersion;
end;

function TLazarusLeafProbe.SetDefaultVersion(const Outp, Errp: IOutput;
  const AVersion: string): Boolean;
begin
  Inc(SetDefaultCalls);
  LastVersion := AVersion;
  if (Outp <> nil) and (SetDefaultWritesToOut <> '') then
    Outp.WriteLn(SetDefaultWritesToOut);
  if (Errp <> nil) and (SetDefaultWritesToErr <> '') then
    Errp.WriteLn(SetDefaultWritesToErr);
  Result := SetDefaultResult;
end;

function TLazarusLeafProbe.ShowVersionInfo(const Outp: IOutput;
  const AVersion: string): Boolean;
begin
  Inc(ShowCalls);
  LastVersion := AVersion;
  if (Outp <> nil) and (ShowWritesToOut <> '') then
    Outp.WriteLn(ShowWritesToOut);
  Result := ShowResult;
end;

function TLazarusLeafProbe.ConfigureIDE(const Outp, Errp: IOutput;
  const AVersion: string): Boolean;
begin
  Inc(ConfigureCalls);
  LastVersion := AVersion;
  if (Outp <> nil) and (ConfigureWritesToOut <> '') then
    Outp.WriteLn(ConfigureWritesToOut);
  if (Errp <> nil) and (ConfigureWritesToErr <> '') then
    Errp.WriteLn(ConfigureWritesToErr);
  Result := ConfigureResult;
end;

function TLazarusLeafProbe.UninstallVersion(const Outp, Errp: IOutput;
  const AVersion: string): Boolean;
begin
  Inc(UninstallCalls);
  LastVersion := AVersion;
  if (Outp <> nil) and (UninstallWritesToOut <> '') then
    Outp.WriteLn(UninstallWritesToOut);
  if (Errp <> nil) and (UninstallWritesToErr <> '') then
    Errp.WriteLn(UninstallWritesToErr);
  Result := UninstallResult;
end;

function TLazarusLeafProbe.UpdateSources(const Outp, Errp: IOutput;
  const AVersion: string): Boolean;
begin
  Inc(UpdateCalls);
  LastVersion := AVersion;
  if (Outp <> nil) and (UpdateWritesToOut <> '') then
    Outp.WriteLn(UpdateWritesToOut);
  if (Errp <> nil) and (UpdateWritesToErr <> '') then
    Errp.WriteLn(UpdateWritesToErr);
  Result := UpdateResult;
end;

function TLazarusLeafProbe.TestInstallation(const Outp, Errp: IOutput;
  const AVersion: string): Boolean;
begin
  Inc(TestCalls);
  LastVersion := AVersion;
  if (Outp <> nil) and (TestWritesToOut <> '') then
    Outp.WriteLn(TestWritesToOut);
  if (Errp <> nil) and (TestWritesToErr <> '') then
    Errp.WriteLn(TestWritesToErr);
  Result := TestResult;
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

procedure TestPrepareCurrentHelpReturnsUsage;
var
  Plan: TLazarusCurrentCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusCurrentCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare current help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare current help requests exit', ShouldExit, 'expected exit');
    Check('prepare current help writes usage', OutpObj.Contains('fpdev lazarus current'), OutpObj.Text);
    Check('prepare current help writes json option', OutpObj.Contains('json'), OutpObj.Text);
    Check('prepare current help keeps stderr empty', Trim(ErrpObj.Text) = '', ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareCurrentRejectsUnknownOption;
var
  Plan: TLazarusCurrentCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusCurrentCommandPlanCore(['--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('prepare current unknown returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare current unknown requests exit', ShouldExit, 'expected exit');
    Check('prepare current unknown writes usage to stderr',
      ErrpObj.Contains('fpdev lazarus current'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareCurrentRejectsPositionalArg;
var
  Plan: TLazarusCurrentCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusCurrentCommandPlanCore(['extra'], Outp, Errp, Plan, ShouldExit);
    Check('prepare current positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare current positional requests exit', ShouldExit, 'expected exit');
    Check('prepare current positional writes usage to stderr',
      ErrpObj.Contains('fpdev lazarus current'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteCurrentJsonUnsetUsesNull;
var
  Plan: TLazarusCurrentCommandPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.JsonOutput := True;
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.CurrentVersion := '';
    Code := ExecuteLazarusCurrentCommandPlanCore(Plan, Outp, @Probe.GetCurrentVersion);
    Check('execute current json unset returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute current json unset calls getter once', Probe.GetCurrentVersionCalls = 1,
      IntToStr(Probe.GetCurrentVersionCalls));
    Check('execute current json unset writes null version',
      OutpObj.Contains('"version" : null'), OutpObj.Text);
    Check('execute current json unset writes has_default false',
      OutpObj.Contains('"has_default" : false'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteCurrentTextWithVersion;
var
  Plan: TLazarusCurrentCommandPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.JsonOutput := False;
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.CurrentVersion := '3.0';
    Code := ExecuteLazarusCurrentCommandPlanCore(Plan, Outp, @Probe.GetCurrentVersion);
    Check('execute current text returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute current text writes current version',
      OutpObj.Contains(_Fmt(CMD_LAZARUS_CURRENT_VERSION, ['3.0'])), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareUseRejectsMissingVersion;
var
  Plan: TLazarusVersionLeafPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusUseCommandPlanCore([], Outp, Errp, Plan, ShouldExit);
    Check('prepare use missing version returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare use missing version requests exit', ShouldExit, 'expected exit');
    Check('prepare use missing version writes argument error',
      ErrpObj.Contains('version'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUseRejectsExtraArg;
var
  Plan: TLazarusVersionLeafPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusUseCommandPlanCore(['3.0', 'extra'], Outp, Errp, Plan, ShouldExit);
    Check('prepare use extra arg returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare use extra arg requests exit', ShouldExit, 'expected exit');
    Check('prepare use extra arg writes usage', ErrpObj.Contains('fpdev lazarus use'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteUseInvokesCallback;
var
  Plan: TLazarusVersionLeafPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.Version := '3.0';
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.SetDefaultResult := True;
    Code := ExecuteLazarusUseCommandPlanCore(Plan, Outp, Errp, @Probe.SetDefaultVersion);
    Check('execute use returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute use calls callback once', Probe.SetDefaultCalls = 1, IntToStr(Probe.SetDefaultCalls));
    Check('execute use forwards version', Probe.LastVersion = '3.0', Probe.LastVersion);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareShowRejectsMissingVersion;
var
  Plan: TLazarusVersionLeafPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusShowCommandPlanCore([], Outp, Errp, Plan, ShouldExit);
    Check('prepare show missing version returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare show missing version requests exit', ShouldExit, 'expected exit');
    Check('prepare show missing version writes usage', ErrpObj.Contains('fpdev lazarus show'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteShowRejectsUnsupportedVersion;
var
  Plan: TLazarusVersionLeafPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.Version := '99.99.99';
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.ValidVersion := False;
    Code := ExecuteLazarusShowCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.IsValidVersion,
      @Probe.ShowVersionInfo
    );
    Check('execute show unsupported returns EXIT_NOT_FOUND', Code = EXIT_NOT_FOUND, IntToStr(Code));
    Check('execute show unsupported does not invoke show callback', Probe.ShowCalls = 0,
      IntToStr(Probe.ShowCalls));
    Check('execute show unsupported writes stderr',
      ErrpObj.Contains(_Fmt(CMD_LAZARUS_UNSUPPORTED_VERSION, ['99.99.99'])), ErrpObj.Text);
    Check('execute show unsupported keeps stdout empty', Trim(OutpObj.Text) = '', OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteShowInvokesCallback;
var
  Plan: TLazarusVersionLeafPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.Version := '3.0';
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.ValidVersion := True;
    Probe.ShowResult := True;
    Probe.ShowWritesToOut := 'show invoked';
    Code := ExecuteLazarusShowCommandPlanCore(
      Plan,
      Outp,
      Errp,
      @Probe.IsValidVersion,
      @Probe.ShowVersionInfo
    );
    Check('execute show returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute show calls callback once', Probe.ShowCalls = 1, IntToStr(Probe.ShowCalls));
    Check('execute show forwards version', Probe.LastVersion = '3.0', Probe.LastVersion);
    Check('execute show preserves callback output', OutpObj.Contains('show invoked'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareConfigureHelpReturnsUsage;
var
  Plan: TLazarusVersionLeafPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusConfigureCommandPlanCore(['--help'], Outp, Errp, Plan, ShouldExit);
    Check('prepare configure help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare configure help requests exit', ShouldExit, 'expected exit');
    Check('prepare configure help writes usage', OutpObj.Contains('fpdev lazarus configure'), OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteConfigureWritesStartBanner;
var
  Plan: TLazarusVersionLeafPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.Version := '3.0';
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.ConfigureResult := False;
    Probe.ConfigureWritesToErr := 'configure failed';
    Code := ExecuteLazarusConfigureCommandPlanCore(Plan, Outp, Errp, @Probe.ConfigureIDE);
    Check('execute configure failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute configure writes start banner first',
      OutpObj.FirstLine = _Fmt(CMD_LAZARUS_CONFIG_START, ['3.0']), OutpObj.Text);
    Check('execute configure keeps manager error only',
      ErrpObj.LineCount = 1, ErrpObj.Text);
    Check('execute configure preserves manager error',
      ErrpObj.Contains('configure failed'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteUninstallFailureAppendsGenericFailed;
var
  Plan: TLazarusVersionLeafPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.Version := '3.0';
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.UninstallResult := False;
    Probe.UninstallWritesToErr := 'uninstall failed';
    Code := ExecuteLazarusUninstallCommandPlanCore(Plan, Outp, Errp, @Probe.UninstallVersion);
    Check('execute uninstall failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute uninstall preserves manager error',
      ErrpObj.Contains('uninstall failed'), ErrpObj.Text);
    Check('execute uninstall appends generic failed',
      ErrpObj.Contains(_(MSG_FAILED)), ErrpObj.Text);
    Check('execute uninstall writes two stderr lines',
      ErrpObj.LineCount = 2, ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareUpdateAllowsNoArgs;
var
  Plan: TLazarusUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusUpdateCommandPlanCore([], Outp, Errp, Plan, ShouldExit);
    Check('prepare update no args returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare update no args does not request exit', not ShouldExit, 'unexpected exit');
    Check('prepare update no args keeps version empty', Plan.Version = '', Plan.Version);
    Check('prepare update no args keeps outputs empty',
      (Trim(OutpObj.Text) = '') and (Trim(ErrpObj.Text) = ''), OutpObj.Text + ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestPrepareUpdateRejectsExtraArg;
var
  Plan: TLazarusUpdateCommandPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusUpdateCommandPlanCore(['3.0', 'extra'], Outp, Errp, Plan, ShouldExit);
    Check('prepare update extra arg returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare update extra arg requests exit', ShouldExit, 'expected exit');
    Check('prepare update extra arg writes usage', ErrpObj.Contains('fpdev lazarus update'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteUpdateFailureDoesNotAppendGenericMessage;
var
  Plan: TLazarusUpdateCommandPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.Version := '3.0';
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.UpdateResult := False;
    Probe.UpdateWritesToErr := 'source missing';
    Code := ExecuteLazarusUpdateCommandPlanCore(Plan, Outp, Errp, @Probe.UpdateSources);
    Check('execute update failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute update keeps single stderr line', ErrpObj.LineCount = 1, ErrpObj.Text);
    Check('execute update preserves manager error', ErrpObj.Contains('source missing'), ErrpObj.Text);
    Check('execute update keeps stdout empty', Trim(OutpObj.Text) = '', OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestExecuteUpdateSuccessPassesEmptyVersion;
var
  Plan: TLazarusUpdateCommandPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.Version := '';
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.UpdateResult := True;
    Probe.UpdateWritesToOut := 'update invoked';
    Code := ExecuteLazarusUpdateCommandPlanCore(Plan, Outp, Errp, @Probe.UpdateSources);
    Check('execute update success returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute update forwards empty version', Probe.LastVersion = '', Probe.LastVersion);
    Check('execute update preserves manager output only', OutpObj.LineCount = 1, OutpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

procedure TestPrepareTestRejectsUnknownOption;
var
  Plan: TLazarusVersionLeafPlan;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Code := PrepareLazarusTestCommandPlanCore(['--unknown'], Outp, Errp, Plan, ShouldExit);
    Check('prepare test unknown returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare test unknown requests exit', ShouldExit, 'expected exit');
    Check('prepare test unknown writes usage', ErrpObj.Contains('fpdev lazarus test'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
  end;
end;

procedure TestExecuteTestFailureDoesNotAppendGenericMessage;
var
  Plan: TLazarusVersionLeafPlan;
  Probe: TLazarusLeafProbe;
  OutpObj, ErrpObj: TStringOutput;
  Outp, Errp: IOutput;
  Code: Integer;
begin
  Plan.Version := '3.0';
  Probe := TLazarusLeafProbe.Create;
  InitOutputs(OutpObj, ErrpObj, Outp, Errp);
  try
    Probe.TestResult := False;
    Probe.TestWritesToErr := 'test failed';
    Code := ExecuteLazarusTestCommandPlanCore(Plan, Outp, Errp, @Probe.TestInstallation);
    Check('execute test failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute test preserves manager error only', ErrpObj.LineCount = 1, ErrpObj.Text);
    Check('execute test preserves manager error text', ErrpObj.Contains('test failed'), ErrpObj.Text);
  finally
    ReleaseOutputs(Outp, Errp, OutpObj, ErrpObj);
    Probe.Free;
  end;
end;

begin
  TestPrepareCurrentHelpReturnsUsage;
  TestPrepareCurrentRejectsUnknownOption;
  TestPrepareCurrentRejectsPositionalArg;
  TestExecuteCurrentJsonUnsetUsesNull;
  TestExecuteCurrentTextWithVersion;
  TestPrepareUseRejectsMissingVersion;
  TestPrepareUseRejectsExtraArg;
  TestExecuteUseInvokesCallback;
  TestPrepareShowRejectsMissingVersion;
  TestExecuteShowRejectsUnsupportedVersion;
  TestExecuteShowInvokesCallback;
  TestPrepareConfigureHelpReturnsUsage;
  TestExecuteConfigureWritesStartBanner;
  TestExecuteUninstallFailureAppendsGenericFailed;
  TestPrepareUpdateAllowsNoArgs;
  TestPrepareUpdateRejectsExtraArg;
  TestExecuteUpdateFailureDoesNotAppendGenericMessage;
  TestExecuteUpdateSuccessPassesEmptyVersion;
  TestPrepareTestRejectsUnknownOption;
  TestExecuteTestFailureDoesNotAppendGenericMessage;

  if FailCount > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', FailCount, ' checks failed, ', PassCount, ' passed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('PASSED: ', PassCount, ' checks');
end.
