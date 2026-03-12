program test_lazarus_runtimeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.lazarus.commandflow;

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

  TLazarusRuntimeProbe = class
  public
    GitRepoResult: Boolean;
    GitRemoteResult: Boolean;
    GitPullResult: Boolean;
    InstallCheckResult: Boolean;
    LaunchResult: Boolean;
    CleanRaises: Boolean;
    CleanedCount: Integer;
    RepoCalls: Integer;
    RemoteCalls: Integer;
    PullCalls: Integer;
    InstallCheckCalls: Integer;
    LaunchCalls: Integer;
    CleanCalls: Integer;
    LastRepoPath: string;
    LastLaunchExecutable: string;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function IsInstalled(const AVersion: string): Boolean;
    function Launch(const AExecutable: string): Boolean;
    function Clean(const ASourceDir: string): Integer;
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

function TLazarusRuntimeProbe.IsRepository(const APath: string): Boolean;
begin
  Inc(RepoCalls);
  LastRepoPath := APath;
  Result := GitRepoResult;
end;

function TLazarusRuntimeProbe.HasRemote(const APath: string): Boolean;
begin
  Inc(RemoteCalls);
  LastRepoPath := APath;
  Result := GitRemoteResult;
end;

function TLazarusRuntimeProbe.Pull(const APath: string): Boolean;
begin
  Inc(PullCalls);
  LastRepoPath := APath;
  Result := GitPullResult;
end;

function TLazarusRuntimeProbe.IsInstalled(const AVersion: string): Boolean;
begin
  Inc(InstallCheckCalls);
  LastRepoPath := AVersion;
  Result := InstallCheckResult;
end;

function TLazarusRuntimeProbe.Launch(const AExecutable: string): Boolean;
begin
  Inc(LaunchCalls);
  LastLaunchExecutable := AExecutable;
  Result := LaunchResult;
end;

function TLazarusRuntimeProbe.Clean(const ASourceDir: string): Integer;
begin
  Inc(CleanCalls);
  LastRepoPath := ASourceDir;
  if CleanRaises then
    raise Exception.Create('clean failed');
  Result := CleanedCount;
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

procedure TestCreateLazarusSourcePlanCoreFallsBackToCurrentVersion;
var
  Plan: TLazarusSourcePlan;
begin
  Plan := CreateLazarusSourcePlanCore('/tmp/fpdev-data', '', '3.2');
  Check('source plan uses current version fallback', Plan.Version = '3.2', 'got=' + Plan.Version);
  Check('source plan path includes version suffix', Pos('lazarus-3.2', Plan.SourceDir) > 0, 'path=' + Plan.SourceDir);
end;

procedure TestExecuteLazarusUpdatePlanCoreReturnsFalseWithoutGitBackend;
var
  Plan: TLazarusSourcePlan;
  Probe: TLazarusRuntimeProbe;
begin
  Plan := CreateLazarusSourcePlanCore('/tmp/fpdev-data', '3.0', '');
  Probe := TLazarusRuntimeProbe.Create;
  try
    Probe.GitRepoResult := True;
    Probe.GitRemoteResult := True;
    Probe.GitPullResult := True;
    Check('update core returns false without git backend',
      not ExecuteLazarusUpdatePlanCore(Plan, False, @Probe.IsRepository, @Probe.HasRemote, @Probe.Pull));
    Check('update core skips repo checks when backend missing', Probe.RepoCalls = 0);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteLazarusUpdatePlanCoreTreatsNoRemoteAsSuccess;
var
  Plan: TLazarusSourcePlan;
  Probe: TLazarusRuntimeProbe;
begin
  Plan := CreateLazarusSourcePlanCore('/tmp/fpdev-data', '3.1', '');
  Probe := TLazarusRuntimeProbe.Create;
  try
    Probe.GitRepoResult := True;
    Probe.GitRemoteResult := False;
    Probe.GitPullResult := False;
    Check('update core treats local-only repo as success',
      ExecuteLazarusUpdatePlanCore(Plan, True, @Probe.IsRepository, @Probe.HasRemote, @Probe.Pull));
    Check('update core skips pull when no remote', Probe.PullCalls = 0);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteLazarusUpdatePlanCoreTreatsPullFailureAsNonFatal;
var
  Plan: TLazarusSourcePlan;
  Probe: TLazarusRuntimeProbe;
begin
  Plan := CreateLazarusSourcePlanCore('/tmp/fpdev-data', '3.3', '');
  Probe := TLazarusRuntimeProbe.Create;
  try
    Probe.GitRepoResult := True;
    Probe.GitRemoteResult := True;
    Probe.GitPullResult := False;
    Check('update core treats pull failure as non-fatal',
      ExecuteLazarusUpdatePlanCore(Plan, True, @Probe.IsRepository, @Probe.HasRemote, @Probe.Pull));
    Check('update core runs pull once', Probe.PullCalls = 1);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteLazarusCleanPlanCoreHandlesCleanerException;
var
  Plan: TLazarusSourcePlan;
  Probe: TLazarusRuntimeProbe;
  Outp: TStringOutput;
begin
  Plan := CreateLazarusSourcePlanCore('/tmp/fpdev-data', '3.4', '');
  Probe := TLazarusRuntimeProbe.Create;
  Outp := TStringOutput.Create;
  try
    Probe.CleanRaises := True;
    Check('clean core returns false on cleaner exception',
      not ExecuteLazarusCleanPlanCore(Plan, Outp, @Probe.Clean));
    Check('clean core writes error text', Outp.Contains('CleanSources error'), Outp.Text);
  finally
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestCreateLazarusLaunchPlanCoreFallsBackToCurrentVersion;
var
  Plan: TLazarusLaunchPlan;
begin
  Plan := CreateLazarusLaunchPlanCore('/tmp/fpdev-data', '', '3.5');
  Check('launch plan uses current version fallback', Plan.Version = '3.5', 'got=' + Plan.Version);
  Check('launch plan executable path contains lazarus', Pos('lazarus', Plan.ExecutablePath) > 0, 'path=' + Plan.ExecutablePath);
end;

procedure TestExecuteLazarusLaunchPlanCoreReportsMissingVersion;
var
  Plan: TLazarusLaunchPlan;
  Probe: TLazarusRuntimeProbe;
  Outp: TStringOutput;
begin
  Plan := CreateLazarusLaunchPlanCore('/tmp/fpdev-data', '', '');
  Probe := TLazarusRuntimeProbe.Create;
  Outp := TStringOutput.Create;
  try
    Check('launch core reports missing version',
      not ExecuteLazarusLaunchPlanCore(Plan, Outp, @Probe.IsInstalled, @Probe.Launch));
    Check('launch core prints no-version message',
      Outp.Contains(_(CMD_LAZARUS_RUN_NO_VERSION)),
      Outp.Text);
  finally
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestExecuteLazarusLaunchPlanCoreReportsNotInstalled;
var
  Plan: TLazarusLaunchPlan;
  Probe: TLazarusRuntimeProbe;
  Outp: TStringOutput;
begin
  Plan := CreateLazarusLaunchPlanCore('/tmp/fpdev-data', '3.6', '');
  Probe := TLazarusRuntimeProbe.Create;
  Outp := TStringOutput.Create;
  try
    Probe.InstallCheckResult := False;
    Check('launch core reports not installed',
      not ExecuteLazarusLaunchPlanCore(Plan, Outp, @Probe.IsInstalled, @Probe.Launch));
    Check('launch core prints not-installed message',
      Outp.Contains('3.6'),
      Outp.Text);
    Check('launch core skips launcher when missing install', Probe.LaunchCalls = 0);
  finally
    Outp.Free;
    Probe.Free;
  end;
end;

procedure TestExecuteLazarusLaunchPlanCoreReportsSuccess;
var
  Plan: TLazarusLaunchPlan;
  Probe: TLazarusRuntimeProbe;
  Outp: TStringOutput;
begin
  Plan := CreateLazarusLaunchPlanCore('/tmp/fpdev-data', '3.7', '');
  Probe := TLazarusRuntimeProbe.Create;
  Outp := TStringOutput.Create;
  try
    Probe.InstallCheckResult := True;
    Probe.LaunchResult := True;
    Check('launch core returns true on success',
      ExecuteLazarusLaunchPlanCore(Plan, Outp, @Probe.IsInstalled, @Probe.Launch));
    Check('launch core prints launched message',
      Outp.Contains(_Fmt(CMD_LAZARUS_RUN_LAUNCHED, ['3.7'])),
      Outp.Text);
  finally
    Outp.Free;
    Probe.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  Lazarus Runtime Flow Test Suite');
  WriteLn('========================================');
  WriteLn;

  TestCreateLazarusSourcePlanCoreFallsBackToCurrentVersion;
  TestExecuteLazarusUpdatePlanCoreReturnsFalseWithoutGitBackend;
  TestExecuteLazarusUpdatePlanCoreTreatsNoRemoteAsSuccess;
  TestExecuteLazarusUpdatePlanCoreTreatsPullFailureAsNonFatal;
  TestExecuteLazarusCleanPlanCoreHandlesCleanerException;
  TestCreateLazarusLaunchPlanCoreFallsBackToCurrentVersion;
  TestExecuteLazarusLaunchPlanCoreReportsMissingVersion;
  TestExecuteLazarusLaunchPlanCoreReportsNotInstalled;
  TestExecuteLazarusLaunchPlanCoreReportsSuccess;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
