program test_fpc_installer_environmentflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf, fpdev.constants, fpdev.config.interfaces,
  fpdev.fpc.installer.environmentflow,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

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
  end;

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

type
  TEnvironmentProbe = class
  public
    AddResult: Boolean;
    RaiseOnAdd: Boolean;
    Calls: Integer;
    LastName: string;
    LastInfo: TToolchainInfo;
    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
  end;

function TEnvironmentProbe.AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
begin
  Inc(Calls);
  LastName := AName;
  LastInfo := AInfo;
  if RaiseOnAdd then
    raise Exception.Create('add boom');
  Result := AddResult;
end;

procedure TestBuildInstalledToolchainInfo;
var
  Info: TToolchainInfo;
  InstallDate: TDateTime;
begin
  InstallDate := EncodeDate(2026, 3, 9) + EncodeTime(12, 34, 56, 0);
  Info := BuildInstalledFPCToolchainInfo('3.2.2', '/opt/fpc/3.2.2', InstallDate);

  Check('build info uses release type', Info.ToolchainType = ttRelease,
    'unexpected toolchain type');
  Check('build info copies version', Info.Version = '3.2.2',
    'version=' + Info.Version);
  Check('build info copies install path', Info.InstallPath = '/opt/fpc/3.2.2',
    'install path=' + Info.InstallPath);
  Check('build info uses official repo url', Info.SourceURL = FPC_OFFICIAL_REPO,
    'source url=' + Info.SourceURL);
  Check('build info marks installed', Info.Installed,
    'installed should be true');
  Check('build info preserves install date', Info.InstallDate = InstallDate,
    'install date mismatch');
end;

procedure TestEnvironmentRegistrationSuccess;
var
  Probe: TEnvironmentProbe;
  ErrBuf: TStringOutput;
  InstallDir: string;
begin
  Probe := TEnvironmentProbe.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_envflow_ok');
  try
    Probe.AddResult := True;

    Check('environment registration returns true',
      ExecuteFPCEnvironmentRegistrationFlow('3.2.2', InstallDir, ErrBuf,
        @Probe.AddToolchain),
      'expected success');
    Check('environment registration calls add once', Probe.Calls = 1,
      'calls=' + IntToStr(Probe.Calls));
    Check('environment registration uses fpc-<version> name', Probe.LastName = 'fpc-3.2.2',
      'name=' + Probe.LastName);
    Check('environment registration passes install path', Probe.LastInfo.InstallPath = InstallDir,
      'install path=' + Probe.LastInfo.InstallPath);
    Check('environment registration passes version', Probe.LastInfo.Version = '3.2.2',
      'version=' + Probe.LastInfo.Version);
    Check('environment registration keeps stderr quiet',
      not ErrBuf.Contains('Failed'), 'unexpected stderr output');
  finally
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

procedure TestEnvironmentRegistrationRejectsEmptyVersion;
var
  Probe: TEnvironmentProbe;
  ErrBuf: TStringOutput;
begin
  Probe := TEnvironmentProbe.Create;
  ErrBuf := TStringOutput.Create;
  try
    Check('environment registration rejects empty version',
      not ExecuteFPCEnvironmentRegistrationFlow('', '/tmp/fpc', ErrBuf,
        @Probe.AddToolchain),
      'expected failure');
    Check('environment registration skips add on empty version', Probe.Calls = 0,
      'calls=' + IntToStr(Probe.Calls));
  finally
    Probe.Free;
  end;
end;

procedure TestEnvironmentRegistrationRejectsMissingDir;
var
  Probe: TEnvironmentProbe;
  ErrBuf: TStringOutput;
begin
  Probe := TEnvironmentProbe.Create;
  ErrBuf := TStringOutput.Create;
  try
    Check('environment registration rejects missing dir',
      not ExecuteFPCEnvironmentRegistrationFlow('3.2.2', '/tmp/fpdev-missing-dir-never-exists', ErrBuf,
        @Probe.AddToolchain),
      'expected failure');
    Check('environment registration skips add on missing dir', Probe.Calls = 0,
      'calls=' + IntToStr(Probe.Calls));
  finally
    Probe.Free;
  end;
end;

procedure TestEnvironmentRegistrationAddFailure;
var
  Probe: TEnvironmentProbe;
  ErrBuf: TStringOutput;
  InstallDir: string;
begin
  Probe := TEnvironmentProbe.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_envflow_add_fail');
  try
    Probe.AddResult := False;

    Check('environment add failure returns false',
      not ExecuteFPCEnvironmentRegistrationFlow('3.2.3', InstallDir, ErrBuf,
        @Probe.AddToolchain),
      'expected failure');
    Check('environment add failure reports stderr',
      ErrBuf.Contains('Failed to add toolchain to configuration'),
      'missing add failure message');
  finally
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

procedure TestEnvironmentRegistrationExceptionPath;
var
  Probe: TEnvironmentProbe;
  ErrBuf: TStringOutput;
  InstallDir: string;
begin
  Probe := TEnvironmentProbe.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_envflow_exception');
  try
    Probe.RaiseOnAdd := True;

    Check('environment exception returns false',
      not ExecuteFPCEnvironmentRegistrationFlow('3.2.4', InstallDir, ErrBuf,
        @Probe.AddToolchain),
      'expected failure');
    Check('environment exception reports stderr',
      ErrBuf.Contains('SetupEnvironment failed - add boom'),
      'missing exception message');
  finally
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer Environment Flow Tests ===');

  TestBuildInstalledToolchainInfo;
  TestEnvironmentRegistrationSuccess;
  TestEnvironmentRegistrationRejectsEmptyVersion;
  TestEnvironmentRegistrationRejectsMissingDir;
  TestEnvironmentRegistrationAddFailure;
  TestEnvironmentRegistrationExceptionPath;

  WriteLn;
  WriteLn('Total: ', PassCount + FailCount);
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
