program test_lazarus_installcommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.config.interfaces,
  fpdev.lazarus.installcommandflow;

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

  TLazarusInstallProbe = class
  public
    ResultToReturn: Boolean;
    CallCount: Integer;
    LastVersion: string;
    LastFPCVersion: string;
    LastFromSource: Boolean;
    LastConfigure: Boolean;
    function InstallVersion(
      const Outp, Errp: IOutput;
      const AVersion: string;
      const AFPCVersion: string;
      const AFromSource: Boolean;
      const AConfigure: Boolean
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

function TLazarusInstallProbe.InstallVersion(
  const Outp, Errp: IOutput;
  const AVersion: string;
  const AFPCVersion: string;
  const AFromSource: Boolean;
  const AConfigure: Boolean
): Boolean;
begin
  Inc(CallCount);
  LastVersion := AVersion;
  LastFPCVersion := AFPCVersion;
  LastFromSource := AFromSource;
  LastConfigure := AConfigure;
  if Outp = nil then;
  if Errp = nil then;
  Result := ResultToReturn;
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

procedure TestPrepareHelpReturnsUsage;
var
  Settings: TFPDevSettings;
  Plan: TLazarusInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareLazarusInstallCommandPlanCore(
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
    Check('prepare help writes usage', Outp.Contains('fpdev lazarus install'), Outp.Text);
    Check('prepare help keeps stderr empty', Trim(Errp.Text) = '', Errp.Text);
    Check('prepare help keeps settings unmodified', not SettingsModified, 'settings modified');
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareRejectsHelpWithExtraArg;
var
  Settings: TFPDevSettings;
  Plan: TLazarusInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareLazarusInstallCommandPlanCore(
      ['--help', 'extra'],
      Settings,
      Outp,
      Errp,
      Plan,
      ShouldExit,
      SettingsModified
    );
    Check('prepare help extra returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare help extra requests exit', ShouldExit, 'should exit');
    Check('prepare help extra writes usage to stderr',
      Errp.Contains('fpdev lazarus install'),
      Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareUpdatesJobsAndFlags;
var
  Settings: TFPDevSettings;
  Plan: TLazarusInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareLazarusInstallCommandPlanCore(
      ['3.2', '--from=source', '--fpc=3.2.2', '--jobs=8', '--no-configure'],
      Settings,
      Outp,
      Errp,
      Plan,
      ShouldExit,
      SettingsModified
    );
    Check('prepare green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare green path keeps executing', not ShouldExit, 'unexpected exit');
    Check('prepare green path updates jobs', Settings.ParallelJobs = 8, IntToStr(Settings.ParallelJobs));
    Check('prepare green path marks settings modified', SettingsModified, 'settings not modified');
    Check('prepare green path keeps version', Plan.Version = '3.2', Plan.Version);
    Check('prepare green path keeps requested fpc version', Plan.FPCVersion = '3.2.2', Plan.FPCVersion);
    Check('prepare green path sets source mode', Plan.FromSource, 'expected source mode');
    Check('prepare green path disables configure', not Plan.ConfigureAfterInstall, 'configure still enabled');
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareRejectsInvalidFromMode;
var
  Settings: TFPDevSettings;
  Plan: TLazarusInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareLazarusInstallCommandPlanCore(
      ['3.2', '--from=invalid'],
      Settings,
      Outp,
      Errp,
      Plan,
      ShouldExit,
      SettingsModified
    );
    Check('prepare invalid from returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare invalid from requests exit', ShouldExit, 'should exit');
    Check('prepare invalid from keeps stdout empty', Trim(Outp.Text) = '', Outp.Text);
    Check('prepare invalid from prints usage', Errp.Contains('fpdev lazarus install'), Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareRejectsEmptyFPCValue;
var
  Settings: TFPDevSettings;
  Plan: TLazarusInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareLazarusInstallCommandPlanCore(
      ['3.2', '--fpc='],
      Settings,
      Outp,
      Errp,
      Plan,
      ShouldExit,
      SettingsModified
    );
    Check('prepare empty fpc returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare empty fpc prints missing value',
      Errp.Contains('Missing --fpc value'),
      Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareRejectsUnexpectedPositionalArg;
var
  Settings: TFPDevSettings;
  Plan: TLazarusInstallCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit, SettingsModified: Boolean;
  Code: Integer;
begin
  Settings := DefaultSettings;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareLazarusInstallCommandPlanCore(
      ['3.2', 'extra'],
      Settings,
      Outp,
      Errp,
      Plan,
      ShouldExit,
      SettingsModified
    );
    Check('prepare extra positional returns EXIT_USAGE_ERROR', Code = EXIT_USAGE_ERROR, IntToStr(Code));
    Check('prepare extra positional prints usage', Errp.Contains('fpdev lazarus install'), Errp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestExecutePrintsStartBannerAndDelegates;
var
  Plan: TLazarusInstallCommandPlan;
  Probe: TLazarusInstallProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan := Default(TLazarusInstallCommandPlan);
  Plan.Version := '3.2';
  Plan.FPCVersion := '3.2.2';
  Plan.FromSource := True;
  Plan.ConfigureAfterInstall := False;

  Probe := TLazarusInstallProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Probe.ResultToReturn := True;
    Code := ExecuteLazarusInstallCommandPlanCore(Plan, Outp, Errp, @Probe.InstallVersion);
    Check('execute green path returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute green path prints start banner',
      Outp.Contains(_Fmt(CMD_LAZARUS_INSTALL_START, ['3.2'])),
      Outp.Text);
    Check('execute green path calls install once', Probe.CallCount = 1, IntToStr(Probe.CallCount));
    Check('execute green path passes fpc version', Probe.LastFPCVersion = '3.2.2', Probe.LastFPCVersion);
    Check('execute green path passes source mode', Probe.LastFromSource, 'expected source mode');
    Check('execute green path passes configure flag', not Probe.LastConfigure, 'configure should be false');
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestExecuteMapsFailureToExitError;
var
  Plan: TLazarusInstallCommandPlan;
  Probe: TLazarusInstallProbe;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan := Default(TLazarusInstallCommandPlan);
  Plan.Version := '3.3';
  Plan.ConfigureAfterInstall := True;

  Probe := TLazarusInstallProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Probe.ResultToReturn := False;
    Code := ExecuteLazarusInstallCommandPlanCore(Plan, Outp, Errp, @Probe.InstallVersion);
    Check('execute failed install returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute failed install still prints start banner',
      Outp.Contains(_Fmt(CMD_LAZARUS_INSTALL_START, ['3.3'])),
      Outp.Text);
  finally
    Errp.Free;
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestExecuteRejectsMissingCallback;
var
  Plan: TLazarusInstallCommandPlan;
  Outp, Errp: TStringOutput;
  Code: Integer;
begin
  Plan := Default(TLazarusInstallCommandPlan);
  Plan.Version := '3.4';

  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := ExecuteLazarusInstallCommandPlanCore(Plan, Outp, Errp, nil);
    Check('execute nil callback returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

begin
  TestPrepareHelpReturnsUsage;
  TestPrepareRejectsHelpWithExtraArg;
  TestPrepareUpdatesJobsAndFlags;
  TestPrepareRejectsInvalidFromMode;
  TestPrepareRejectsEmptyFPCValue;
  TestPrepareRejectsUnexpectedPositionalArg;
  TestExecutePrintsStartBannerAndDelegates;
  TestExecuteMapsFailureToExitError;
  TestExecuteRejectsMissingCallback;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  WriteLn('Total: ', PassCount + FailCount);

  if FailCount > 0 then
    Halt(1);
end.
