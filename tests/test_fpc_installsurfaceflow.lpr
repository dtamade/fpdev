program test_fpc_installsurfaceflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.fpc.installsurfaceflow;

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

  TInstallSurfaceProbe = class
  private
    FEvents: array of string;
    procedure AddEvent(const AEvent: string);
  public
    ValidateVersionResult: Boolean;
    IsVersionInstalledResult: Boolean;
    WriteMetadataResult: Boolean;
    InstallBinaryResult: Boolean;
    ValidateCalls: Integer;
    GetInstallPathCalls: Integer;
    IsVersionInstalledCalls: Integer;
    ConfigureInstallerCalls: Integer;
    InstallBinaryCalls: Integer;
    WriteMetadataCalls: Integer;
    RefreshCalls: Integer;
    LastConfiguredNoCache: Boolean;
    LastConfiguredOffline: Boolean;
    LastInstallPath: string;
    LastRefreshPath: string;
    LastRefreshVersion: string;
    function ValidateVersion(const AVersion: string): Boolean;
    function GetVersionInstallPath(const AVersion: string): string;
    function IsVersionInstalled(const AVersion: string): Boolean;
    procedure ConfigureInstaller(ANoCache, AOfflineMode: Boolean);
    function InstallBinary(const AVersion, APrefix: string): Boolean;
    function WriteMetadata(const AVersion, AInstallPath: string; AFromSource: Boolean): Boolean;
    function RefreshInstallVerificationMetadata(const AVersion, AInstallPath: string): Boolean;
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

procedure TInstallSurfaceProbe.AddEvent(const AEvent: string);
var
  Index: Integer;
begin
  Index := Length(FEvents);
  SetLength(FEvents, Index + 1);
  FEvents[Index] := AEvent;
end;

function TInstallSurfaceProbe.ValidateVersion(const AVersion: string): Boolean;
begin
  Inc(ValidateCalls);
  AddEvent('validate');
  if AVersion = '' then;
  Result := ValidateVersionResult;
end;

function TInstallSurfaceProbe.GetVersionInstallPath(const AVersion: string): string;
begin
  Inc(GetInstallPathCalls);
  AddEvent('path');
  Result := '/managed/fpc/' + AVersion;
end;

function TInstallSurfaceProbe.IsVersionInstalled(const AVersion: string): Boolean;
begin
  Inc(IsVersionInstalledCalls);
  AddEvent('installed');
  if AVersion = '' then;
  Result := IsVersionInstalledResult;
end;

procedure TInstallSurfaceProbe.ConfigureInstaller(ANoCache, AOfflineMode: Boolean);
begin
  Inc(ConfigureInstallerCalls);
  LastConfiguredNoCache := ANoCache;
  LastConfiguredOffline := AOfflineMode;
  AddEvent('configure');
end;

function TInstallSurfaceProbe.InstallBinary(const AVersion, APrefix: string): Boolean;
begin
  Inc(InstallBinaryCalls);
  AddEvent('binary');
  if AVersion = '' then;
  if APrefix = '' then;
  Result := InstallBinaryResult;
end;

function TInstallSurfaceProbe.WriteMetadata(const AVersion, AInstallPath: string;
  AFromSource: Boolean): Boolean;
begin
  Inc(WriteMetadataCalls);
  LastInstallPath := AInstallPath;
  AddEvent('metadata');
  if AVersion = '' then;
  if AFromSource then;
  Result := WriteMetadataResult;
end;

function TInstallSurfaceProbe.RefreshInstallVerificationMetadata(
  const AVersion, AInstallPath: string): Boolean;
begin
  Inc(RefreshCalls);
  LastRefreshVersion := AVersion;
  LastRefreshPath := AInstallPath;
  AddEvent('refresh');
  Result := True;
end;

function TInstallSurfaceProbe.EventText: string;
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

function MakeState(const AVersion: string): TFPCInstallSurfaceState;
begin
  Result := Default(TFPCInstallSurfaceState);
  Result.Version := AVersion;
  Result.InstallRoot := '/managed';
end;

procedure TestInvalidVersionFailsBeforeCore;
var
  Probe: TInstallSurfaceProbe;
  OutBuf, ErrBuf: TStringOutput;
  Outp, Errp: IOutput;
  State: TFPCInstallSurfaceState;
  Callbacks: TFPCInstallSurfaceCallbacks;
begin
  Probe := TInstallSurfaceProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Outp := OutBuf;
  Errp := ErrBuf;
  try
    Probe.ValidateVersionResult := False;
    State := MakeState('bad.version');

    Callbacks := Default(TFPCInstallSurfaceCallbacks);
    Callbacks.ValidateVersion := @Probe.ValidateVersion;
    Callbacks.GetVersionInstallPath := @Probe.GetVersionInstallPath;
    Callbacks.IsVersionInstalled := @Probe.IsVersionInstalled;
    Callbacks.ConfigureInstaller := @Probe.ConfigureInstaller;
    Callbacks.InstallBinary := @Probe.InstallBinary;
    Callbacks.WriteMetadata := @Probe.WriteMetadata;
    Callbacks.RefreshInstallVerificationMetadata := @Probe.RefreshInstallVerificationMetadata;

    Check(
      'invalid version fails before core',
      not ExecuteManagedFPCInstallSurfaceCore(State, Outp, Errp, Callbacks),
      'expected helper to fail fast'
    );
    Check('invalid version runs validation once', Probe.ValidateCalls = 1,
      'validate=' + IntToStr(Probe.ValidateCalls));
    Check('invalid version skips configure installer', Probe.ConfigureInstallerCalls = 0,
      'configure=' + IntToStr(Probe.ConfigureInstallerCalls));
    Check('invalid version skips binary install', Probe.InstallBinaryCalls = 0,
      'binary=' + IntToStr(Probe.InstallBinaryCalls));
    Check('invalid version prints translated error',
      ErrBuf.Contains(_Fmt(ERR_INVALID_VERSION, ['bad.version'])),
      ErrBuf.Text);
  finally
    Outp := nil;
    Errp := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestOfflineModeSkipsValidationAndRefreshesOnSuccess;
var
  Probe: TInstallSurfaceProbe;
  OutBuf, ErrBuf: TStringOutput;
  Outp, Errp: IOutput;
  State: TFPCInstallSurfaceState;
  Callbacks: TFPCInstallSurfaceCallbacks;
begin
  Probe := TInstallSurfaceProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Outp := OutBuf;
  Errp := ErrBuf;
  try
    Probe.ValidateVersionResult := False;
    Probe.InstallBinaryResult := True;
    Probe.WriteMetadataResult := True;
    State := MakeState('3.2.2');
    State.OfflineMode := True;
    State.NoCache := True;
    State.Prefix := '/custom/fpc';

    Callbacks := Default(TFPCInstallSurfaceCallbacks);
    Callbacks.ValidateVersion := @Probe.ValidateVersion;
    Callbacks.GetVersionInstallPath := @Probe.GetVersionInstallPath;
    Callbacks.IsVersionInstalled := @Probe.IsVersionInstalled;
    Callbacks.ConfigureInstaller := @Probe.ConfigureInstaller;
    Callbacks.InstallBinary := @Probe.InstallBinary;
    Callbacks.WriteMetadata := @Probe.WriteMetadata;
    Callbacks.RefreshInstallVerificationMetadata := @Probe.RefreshInstallVerificationMetadata;

    Check(
      'offline mode still allows install',
      ExecuteManagedFPCInstallSurfaceCore(State, Outp, Errp, Callbacks),
      ErrBuf.Text
    );
    Check('offline mode skips validation callback', Probe.ValidateCalls = 0,
      'validate=' + IntToStr(Probe.ValidateCalls));
    Check('offline mode configures installer once', Probe.ConfigureInstallerCalls = 1,
      'configure=' + IntToStr(Probe.ConfigureInstallerCalls));
    Check('offline mode forwards no-cache flag', Probe.LastConfiguredNoCache,
      'no-cache should be true');
    Check('offline mode forwards offline flag', Probe.LastConfiguredOffline,
      'offline should be true');
    Check('offline mode reaches binary install', Probe.InstallBinaryCalls = 1,
      'binary=' + IntToStr(Probe.InstallBinaryCalls));
    Check('offline mode refreshes metadata after success', Probe.RefreshCalls = 1,
      'refresh=' + IntToStr(Probe.RefreshCalls));
    Check('offline mode refreshes resolved prefix path', Probe.LastRefreshPath = '/custom/fpc',
      'path=' + Probe.LastRefreshPath);
  finally
    Outp := nil;
    Errp := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

procedure TestConfigureRunsBeforeCoreAndFailureSkipsRefresh;
var
  Probe: TInstallSurfaceProbe;
  OutBuf, ErrBuf: TStringOutput;
  Outp, Errp: IOutput;
  State: TFPCInstallSurfaceState;
  Callbacks: TFPCInstallSurfaceCallbacks;
begin
  Probe := TInstallSurfaceProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Outp := OutBuf;
  Errp := ErrBuf;
  try
    Probe.ValidateVersionResult := True;
    Probe.InstallBinaryResult := False;
    State := MakeState('3.2.2');

    Callbacks := Default(TFPCInstallSurfaceCallbacks);
    Callbacks.ValidateVersion := @Probe.ValidateVersion;
    Callbacks.GetVersionInstallPath := @Probe.GetVersionInstallPath;
    Callbacks.IsVersionInstalled := @Probe.IsVersionInstalled;
    Callbacks.ConfigureInstaller := @Probe.ConfigureInstaller;
    Callbacks.InstallBinary := @Probe.InstallBinary;
    Callbacks.WriteMetadata := @Probe.WriteMetadata;
    Callbacks.RefreshInstallVerificationMetadata := @Probe.RefreshInstallVerificationMetadata;

    Check(
      'failed install returns false',
      not ExecuteManagedFPCInstallSurfaceCore(State, Outp, Errp, Callbacks),
      'expected failure'
    );
    Check('configure runs before binary core work',
      Pos('configure>binary', Probe.EventText) > 0,
      Probe.EventText);
    Check('failed install does not refresh metadata', Probe.RefreshCalls = 0,
      'refresh=' + IntToStr(Probe.RefreshCalls));
  finally
    Outp := nil;
    Errp := nil;
    OutBuf := nil;
    ErrBuf := nil;
    Probe.Free;
  end;
end;

begin
  TestInvalidVersionFailsBeforeCore;
  TestOfflineModeSkipsValidationAndRefreshesOnSuccess;
  TestConfigureRunsBeforeCoreAndFailureSkipsRefresh;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
