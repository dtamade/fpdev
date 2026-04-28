program test_fpc_installcommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.types,
  fpdev.config.interfaces,
  fpdev.fpc.installcommandflow;

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

  TInstallCommandProbe = class
  private
    FEvents: array of string;
    procedure AddEvent(const AEvent: string);
  public
    BinaryResult: Boolean;
    SourceResult: Boolean;
    CallCount: Integer;
    LastVersion: string;
    LastPrefix: string;
    LastFromSource: Boolean;
    LastOfflineMode: Boolean;
    LastNoCache: Boolean;
    function InstallVersion(
      const AVersion: string;
      const AFromSource: Boolean;
      const APrefix: string;
      const AEnsure: Boolean;
      const ANoCache: Boolean;
      const AOfflineMode: Boolean
    ): Boolean;
    function EventText: string;
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

procedure TInstallCommandProbe.AddEvent(const AEvent: string);
var
  Index: Integer;
begin
  Index := Length(FEvents);
  SetLength(FEvents, Index + 1);
  FEvents[Index] := AEvent;
end;

function TInstallCommandProbe.InstallVersion(
  const AVersion: string;
  const AFromSource: Boolean;
  const APrefix: string;
  const AEnsure: Boolean;
  const ANoCache: Boolean;
  const AOfflineMode: Boolean
): Boolean;
begin
  Inc(CallCount);
  LastVersion := AVersion;
  LastPrefix := APrefix;
  LastFromSource := AFromSource;
  LastOfflineMode := AOfflineMode;
  LastNoCache := ANoCache;
  if AEnsure then;

  if AFromSource then
  begin
    AddEvent('source');
    Result := SourceResult;
  end
  else
  begin
    AddEvent('binary');
    Result := BinaryResult;
  end;
end;

function TInstallCommandProbe.EventText: string;
var
  Index: Integer;
begin
  Result := '';
  for Index := 0 to High(FEvents) do
  begin
    if Result <> '' then
      Result := Result + '>';
    Result := Result + FEvents[Index];
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

function DefaultSettings: TFPDevSettings;
begin
  Result := Default(TFPDevSettings);
  Result.ParallelJobs := 2;
end;

function DefaultPlan(const AVersion: string): TFPCInstallCommandPlan;
begin
  Result := Default(TFPCInstallCommandPlan);
  Result.Version := AVersion;
  Result.Mode := imAuto;
end;

procedure TestPrepareHelpReturnsUsage;
var
  Settings: TFPDevSettings;
  Plan: TFPCInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  Code := PrepareFPCInstallCommandPlanCore(
    ['--help'],
    Settings,
    Outp,
    Errp,
    Plan,
    ShouldExit,
    SettingsModified
  );
  Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
  Check('prepare help requests exit', ShouldExit, 'expected terminal help');
  Check('prepare help writes usage', Outp.Contains('fpdev fpc install'), Outp.Text);
  Check('prepare help keeps stderr empty', Trim(Errp.Text) = '', Errp.Text);
  Check('prepare help keeps settings unmodified', not SettingsModified, 'settings modified');
end;

procedure TestPrepareUpdatesJobsAndPlan;
var
  Settings: TFPDevSettings;
  Plan: TFPCInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  Code := PrepareFPCInstallCommandPlanCore(
    ['3.2.2', '--jobs=8', '--offline'],
    Settings,
    Outp,
    Errp,
    Plan,
    ShouldExit,
    SettingsModified
  );
  Check('prepare jobs returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
  Check('prepare jobs continues execution', not ShouldExit, 'unexpected terminal response');
  Check('prepare jobs updates settings', Settings.ParallelJobs = 8, IntToStr(Settings.ParallelJobs));
  Check('prepare jobs marks settings modified', SettingsModified, 'expected settings change');
  Check('prepare jobs sets version', Plan.Version = '3.2.2', Plan.Version);
  Check('prepare jobs sets offline flag', Plan.OfflineMode, 'offline not set');
end;

procedure TestPrepareRejectsInvalidFromMode;
var
  Settings: TFPDevSettings;
  Plan: TFPCInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  Code := PrepareFPCInstallCommandPlanCore(
    ['3.2.2', '--from=invalid'],
    Settings,
    Outp,
    Errp,
    Plan,
    ShouldExit,
    SettingsModified
  );
  Check('prepare invalid from returns usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
  Check('prepare invalid from requests exit', ShouldExit, 'expected terminal error');
  Check('prepare invalid from writes error', Errp.Contains('invalid'), Errp.Text);
end;

procedure TestPrepareRejectsEmptyPrefix;
var
  Settings: TFPDevSettings;
  Plan: TFPCInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  Code := PrepareFPCInstallCommandPlanCore(
    ['3.2.2', '--prefix='],
    Settings,
    Outp,
    Errp,
    Plan,
    ShouldExit,
    SettingsModified
  );
  Check('prepare empty prefix returns usage error', Code = EXIT_USAGE_ERROR, IntToStr(Code));
  Check('prepare empty prefix requests exit', ShouldExit, 'expected terminal error');
  Check('prepare empty prefix writes usage', Errp.Contains('fpdev fpc install'), Errp.Text);
end;

procedure TestExecuteAutoFallsBackToSource;
var
  Plan: TFPCInstallCommandPlan;
  Probe: TInstallCommandProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan := DefaultPlan('3.2.2');
  Probe := TInstallCommandProbe.Create;
  Probe.BinaryResult := False;
  Probe.SourceResult := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  Code := ExecuteFPCInstallCommandPlanCore(
    Plan,
    Outp,
    Errp,
    False,
    @Probe.InstallVersion
  );
  Check('execute auto fallback returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
  Check('execute auto fallback calls binary then source', Probe.EventText = 'binary>source', Probe.EventText);
  Check('execute auto fallback writes fallback banner',
    Outp.Contains('Binary installation failed, falling back to source installation'),
    Outp.Text);
end;

procedure TestExecuteNetworkDisabledStopsBeforeInstall;
var
  Plan: TFPCInstallCommandPlan;
  Probe: TInstallCommandProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan := DefaultPlan('3.2.2');
  Plan.Mode := imBinary;
  Probe := TInstallCommandProbe.Create;
  Probe.BinaryResult := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  Code := ExecuteFPCInstallCommandPlanCore(
    Plan,
    Outp,
    Errp,
    True,
    @Probe.InstallVersion
  );
  Check('execute network-disabled returns EXIT_IO_ERROR', Code = EXIT_IO_ERROR, IntToStr(Code));
  Check('execute network-disabled makes no install call', Probe.CallCount = 0, IntToStr(Probe.CallCount));
  Check('execute network-disabled writes guard', Errp.Contains('FPDEV_SKIP_NETWORK_TESTS=1'), Errp.Text);
end;

procedure TestExecuteOfflineFailureUsesIOError;
var
  Plan: TFPCInstallCommandPlan;
  Probe: TInstallCommandProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan := DefaultPlan('3.2.2');
  Plan.Mode := imBinary;
  Plan.OfflineMode := True;
  Probe := TInstallCommandProbe.Create;
  Probe.BinaryResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  Code := ExecuteFPCInstallCommandPlanCore(
    Plan,
    Outp,
    Errp,
    False,
    @Probe.InstallVersion
  );
  Check('execute offline failure returns EXIT_IO_ERROR', Code = EXIT_IO_ERROR, IntToStr(Code));
  Check('execute offline failure only calls binary once', Probe.EventText = 'binary', Probe.EventText);
  Check('execute offline failure forwards offline flag', Probe.LastOfflineMode, 'offline not forwarded');
end;

procedure TestExecuteSourceModeSuccessCallsSourceOnly;
var
  Plan: TFPCInstallCommandPlan;
  Probe: TInstallCommandProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan := DefaultPlan('3.2.2');
  Plan.Mode := imSource;
  Plan.Prefix := '/opt/fpc';
  Probe := TInstallCommandProbe.Create;
  Probe.SourceResult := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  Code := ExecuteFPCInstallCommandPlanCore(
    Plan,
    Outp,
    Errp,
    False,
    @Probe.InstallVersion
  );
  Check('execute source mode returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
  Check('execute source mode only calls source once', Probe.EventText = 'source', Probe.EventText);
  Check('execute source mode forwards prefix', Probe.LastPrefix = '/opt/fpc', Probe.LastPrefix);
  Check('execute source mode marks from-source', Probe.LastFromSource, 'from-source not forwarded');
end;

begin
  TestPrepareHelpReturnsUsage;
  TestPrepareUpdatesJobsAndPlan;
  TestPrepareRejectsInvalidFromMode;
  TestPrepareRejectsEmptyPrefix;
  TestExecuteAutoFallsBackToSource;
  TestExecuteNetworkDisabledStopsBeforeInstall;
  TestExecuteOfflineFailureUsesIOError;
  TestExecuteSourceModeSuccessCallsSourceOnly;

  if FailCount > 0 then
  begin
    WriteLn(Format('%d tests failed; %d passed', [FailCount, PassCount]));
    Halt(1);
  end;

  WriteLn(Format('All %d tests passed', [PassCount]));
end.
