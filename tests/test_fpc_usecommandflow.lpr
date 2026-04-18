program test_fpc_usecommandflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.command.intf,
  fpdev.config.interfaces,
  fpdev.logger.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.fpc.types,
  fpdev.config.project,
  fpdev.fpc.usecommandflow,
  test_temp_paths;

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

  TTestContext = class(TInterfacedObject, IContext)
  private
    FOut: IOutput;
    FErr: IOutput;
  public
    constructor Create(const AOut, AErr: IOutput);
    function Out: IOutput;
    function Err: IOutput;
    function Config: IConfigManager;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

  TFPCUseProbe = class
  public
    InstallResult: Boolean;
    ActivationResult: TActivationResult;
    InstallCalls: Integer;
    ActivateCalls: Integer;
    LastInstallVersion: string;
    LastInstallFromSource: Boolean;
    LastInstallEnsure: Boolean;
    LastActivateVersion: string;
    function InstallVersion(
      const AVersion: string;
      const AFromSource: Boolean;
      const APrefix: string;
      const AEnsure: Boolean;
      const ANoCache: Boolean;
      const AOfflineMode: Boolean
    ): Boolean;
    function ActivateVersion(const AVersion: string): TActivationResult;
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

constructor TTestContext.Create(const AOut, AErr: IOutput);
begin
  inherited Create;
  FOut := AOut;
  FErr := AErr;
end;

function TTestContext.Out: IOutput;
begin
  Result := FOut;
end;

function TTestContext.Err: IOutput;
begin
  Result := FErr;
end;

function TTestContext.Config: IConfigManager;
begin
  Result := nil;
end;

function TTestContext.Logger: ILogger;
begin
  Result := nil;
end;

procedure TTestContext.SaveIfModified;
begin
end;

function TFPCUseProbe.InstallVersion(
  const AVersion: string;
  const AFromSource: Boolean;
  const APrefix: string;
  const AEnsure: Boolean;
  const ANoCache: Boolean;
  const AOfflineMode: Boolean
): Boolean;
begin
  Inc(InstallCalls);
  LastInstallVersion := AVersion;
  LastInstallFromSource := AFromSource;
  LastInstallEnsure := AEnsure;
  if APrefix = '' then;
  if ANoCache then;
  if AOfflineMode then;
  Result := InstallResult;
end;

function TFPCUseProbe.ActivateVersion(const AVersion: string): TActivationResult;
begin
  Inc(ActivateCalls);
  LastActivateVersion := AVersion;
  Result := ActivationResult;
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

procedure WriteTextFile(const APath, AContent: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

procedure TestPrepareHelpReturnsUsage;
var
  Plan: TFPCUseCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Code := PrepareFPCUseCommandPlanCore(['--help'], '', Outp, Errp, Plan, ShouldExit);
    Check('prepare help returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare help requests exit', ShouldExit, 'should exit');
    Check('prepare help shows ensure option', Outp.Contains('ensure'), Outp.Text);
    Check('prepare help shows version aliases', Outp.Contains('stable'), Outp.Text);
  finally
    Errp.Free;
    Outp.Free;
  end;
end;

procedure TestPrepareNoArgsUsesProjectConfigAlias;
var
  TempDir: string;
  SavedDir: string;
  Plan: TFPCUseCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  TempDir := CreateUniqueTempDir('fpdev_use_plan');
  SavedDir := GetCurrentDir;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    WriteTextFile(TempDir + PathDelim + '.fpdevrc', 'stable' + LineEnding);
    SetCurrentDir(TempDir);
    Code := PrepareFPCUseCommandPlanCore([], '', Outp, Errp, Plan, ShouldExit);
    Check('prepare no-args returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare no-args keeps running', not ShouldExit, 'unexpected exit');
    Check('prepare no-args resolves stable alias', Plan.Version = GetDefaultFPCVersion, Plan.Version);
    Check('prepare no-args marks source announcement', Plan.AnnounceSource, 'announcement missing');
    Check('prepare no-args records project config source', Plan.SourceLabel = 'project config', Plan.SourceLabel);
  finally
    SetCurrentDir(SavedDir);
    Errp.Free;
    Outp.Free;
    CleanupTempDir(TempDir);
  end;
end;

procedure TestPrepareExplicitAliasAndEnsureFlag;
var
  TempDir: string;
  SavedDir: string;
  Resolver: TProjectConfigResolver;
  Plan: TFPCUseCommandPlan;
  Outp, Errp: TStringOutput;
  ShouldExit: Boolean;
  Code: Integer;
begin
  TempDir := CreateUniqueTempDir('fpdev_use_alias');
  SavedDir := GetCurrentDir;
  Resolver := TProjectConfigResolver.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    SetCurrentDir(TempDir);
    Code := PrepareFPCUseCommandPlanCore(['lts', '--ensure'], '', Outp, Errp, Plan, ShouldExit);
    Check('prepare explicit alias returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('prepare explicit alias resolves lts', Plan.Version = Resolver.ResolveVersionAlias('lts'), Plan.Version);
    Check('prepare explicit alias keeps ensure flag', Plan.Ensure, 'ensure missing');
    Check('prepare explicit alias suppresses source announcement', not Plan.AnnounceSource, 'unexpected announcement');
  finally
    SetCurrentDir(SavedDir);
    Errp.Free;
    Outp.Free;
    Resolver.Free;
    CleanupTempDir(TempDir);
  end;
end;

procedure TestExecuteMissingInstallShowsHint;
var
  Plan: TFPCUseCommandPlan;
  Probe: TFPCUseProbe;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Code: Integer;
begin
  Plan := Default(TFPCUseCommandPlan);
  Plan.Version := '9.9.9';

  Probe := TFPCUseProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  try
    Code := ExecuteFPCUseCommandPlanCore(Plan, Ctx, False, @Probe.InstallVersion, @Probe.ActivateVersion);
    Check('execute missing install returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute missing install does not call installer', Probe.InstallCalls = 0, IntToStr(Probe.InstallCalls));
    Check('execute missing install does not activate', Probe.ActivateCalls = 0, IntToStr(Probe.ActivateCalls));
    Check('execute missing install prints install hint',
      ErrBuf.Contains('fpdev fpc install 9.9.9'),
      ErrBuf.Text);
    Check('execute missing install prints ensure hint',
      ErrBuf.Contains('--ensure'),
      ErrBuf.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteAutoInstallThenActivateSuccess;
var
  Plan: TFPCUseCommandPlan;
  Probe: TFPCUseProbe;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Code: Integer;
begin
  Plan := Default(TFPCUseCommandPlan);
  Plan.Version := '3.2.2';
  Plan.AutoInstall := True;
  Plan.AnnounceSource := True;
  Plan.SourceLabel := 'project config';

  Probe := TFPCUseProbe.Create;
  Probe.InstallResult := True;
  Probe.ActivationResult.Success := True;
  Probe.ActivationResult.ActivationScript := '/tmp/activate.sh';
  Probe.ActivationResult.ShellCommand := 'source /tmp/activate.sh';
  Probe.ActivationResult.VSCodeSettings := '/tmp/settings.json';

  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  try
    Code := ExecuteFPCUseCommandPlanCore(Plan, Ctx, False, @Probe.InstallVersion, @Probe.ActivateVersion);
    Check('execute autoinstall returns EXIT_OK', Code = EXIT_OK, IntToStr(Code));
    Check('execute autoinstall announces config source',
      OutBuf.Contains('Using version from project config: 3.2.2'),
      OutBuf.Text);
    Check('execute autoinstall calls installer once', Probe.InstallCalls = 1, IntToStr(Probe.InstallCalls));
    Check('execute autoinstall forces source install', Probe.LastInstallFromSource, 'expected source install');
    Check('execute autoinstall passes ensure', Probe.LastInstallEnsure, 'expected ensure');
    Check('execute autoinstall calls activate once', Probe.ActivateCalls = 1, IntToStr(Probe.ActivateCalls));
    Check('execute autoinstall prints activated message',
      OutBuf.Contains(_Fmt(CMD_FPC_USE_ACTIVATED, ['3.2.2'])),
      OutBuf.Text);
    Check('execute autoinstall prints script path',
      OutBuf.Contains('/tmp/activate.sh'),
      OutBuf.Text);
    Check('execute autoinstall prints vscode settings path',
      OutBuf.Contains('/tmp/settings.json'),
      OutBuf.Text);
    Check('execute autoinstall keeps stderr quiet', Trim(ErrBuf.Text) = '', ErrBuf.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteActivationFailureReturnsError;
var
  Plan: TFPCUseCommandPlan;
  Probe: TFPCUseProbe;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Code: Integer;
begin
  Plan := Default(TFPCUseCommandPlan);
  Plan.Version := '3.2.2';

  Probe := TFPCUseProbe.Create;
  Probe.ActivationResult.Success := False;
  Probe.ActivationResult.ErrorMessage := 'activation failed';
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  try
    Code := ExecuteFPCUseCommandPlanCore(Plan, Ctx, True, @Probe.InstallVersion, @Probe.ActivateVersion);
    Check('execute activation failure returns EXIT_ERROR', Code = EXIT_ERROR, IntToStr(Code));
    Check('execute activation failure does not install', Probe.InstallCalls = 0, IntToStr(Probe.InstallCalls));
    Check('execute activation failure calls activate once', Probe.ActivateCalls = 1, IntToStr(Probe.ActivateCalls));
    Check('execute activation failure prints error',
      ErrBuf.Contains('activation failed'),
      ErrBuf.Text);
  finally
    Probe.Free;
  end;
end;

begin
  TestPrepareHelpReturnsUsage;
  TestPrepareNoArgsUsesProjectConfigAlias;
  TestPrepareExplicitAliasAndEnsureFlag;
  TestExecuteMissingInstallShowsHint;
  TestExecuteAutoInstallThenActivateSuccess;
  TestExecuteActivationFailureReturnsError;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  WriteLn('Total: ', PassCount + FailCount);

  if FailCount > 0 then
    Halt(1);
end.
