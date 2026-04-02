program test_fpc_runtimeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.config.interfaces,
  fpdev.utils.process,
  fpdev.fpc.runtimeflow;

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

  TFPCGitProbe = class(TInterfacedObject, IFPCGitRuntime)
  public
    BackendAvailableResult: Boolean;
    RepoResult: Boolean;
    RemoteResult: Boolean;
    PullResult: Boolean;
    PullErrorText: string;
    RepoCalls: Integer;
    RemoteCalls: Integer;
    PullCalls: Integer;
    LastPath: string;
    function BackendAvailable: Boolean;
    function IsRepository(const APath: string): Boolean;
    function HasRemote(const APath: string): Boolean;
    function Pull(const APath: string): Boolean;
    function GetLastError: string;
  end;

  TFPCRuntimeProbe = class
  public
    DirectoryExistsResult: Boolean;
    CleanRaises: Boolean;
    CleanedCount: Integer;
    ValidateVersionResult: Boolean;
    InstalledResult: Boolean;
    InstallPathValue: string;
    ToolchainLookupResult: Boolean;
    ToolchainInfoValue: TToolchainInfo;
    ProcessResultValue: TProcessResult;
    ProcessRaises: Boolean;
    DirectoryCalls: Integer;
    CleanCalls: Integer;
    ValidateCalls: Integer;
    InstalledCalls: Integer;
    InstallPathCalls: Integer;
    ToolchainCalls: Integer;
    ProcessCalls: Integer;
    LastPath: string;
    LastVersion: string;
    LastExecutable: string;
    function DirectoryExistsAt(const APath: string): Boolean;
    function Clean(const ASourceDir: string): Integer;
    function ValidateVersion(const AVersion: string): Boolean;
    function IsInstalled(const AVersion: string): Boolean;
    function ResolveInstallPath(const AVersion: string): string;
    function LookupToolchain(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
    function RunInfo(const AExecutable: string): TProcessResult;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure WriteCustomVersionInfo(const AOut: IOutput; const AInfo: TToolchainInfo);
begin
  if AOut <> nil then
  begin
    AOut.WriteLn('Custom install date=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', AInfo.InstallDate));
    AOut.WriteLn('Custom source=' + AInfo.SourceURL);
  end;
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

function TFPCGitProbe.BackendAvailable: Boolean;
begin
  Result := BackendAvailableResult;
end;

function TFPCGitProbe.IsRepository(const APath: string): Boolean;
begin
  Inc(RepoCalls);
  LastPath := APath;
  Result := RepoResult;
end;

function TFPCGitProbe.HasRemote(const APath: string): Boolean;
begin
  Inc(RemoteCalls);
  LastPath := APath;
  Result := RemoteResult;
end;

function TFPCGitProbe.Pull(const APath: string): Boolean;
begin
  Inc(PullCalls);
  LastPath := APath;
  Result := PullResult;
end;

function TFPCGitProbe.GetLastError: string;
begin
  Result := PullErrorText;
end;

function TFPCRuntimeProbe.DirectoryExistsAt(const APath: string): Boolean;
begin
  Inc(DirectoryCalls);
  LastPath := APath;
  Result := DirectoryExistsResult;
end;

function TFPCRuntimeProbe.Clean(const ASourceDir: string): Integer;
begin
  Inc(CleanCalls);
  LastPath := ASourceDir;
  if CleanRaises then
    raise Exception.Create('clean failed');
  Result := CleanedCount;
end;

function TFPCRuntimeProbe.ValidateVersion(const AVersion: string): Boolean;
begin
  Inc(ValidateCalls);
  LastVersion := AVersion;
  Result := ValidateVersionResult;
end;

function TFPCRuntimeProbe.IsInstalled(const AVersion: string): Boolean;
begin
  Inc(InstalledCalls);
  LastVersion := AVersion;
  Result := InstalledResult;
end;

function TFPCRuntimeProbe.ResolveInstallPath(const AVersion: string): string;
begin
  Inc(InstallPathCalls);
  LastVersion := AVersion;
  Result := InstallPathValue;
end;

function TFPCRuntimeProbe.LookupToolchain(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
begin
  Inc(ToolchainCalls);
  LastVersion := AVersion;
  AInfo := ToolchainInfoValue;
  Result := ToolchainLookupResult;
end;

function TFPCRuntimeProbe.RunInfo(const AExecutable: string): TProcessResult;
begin
  Inc(ProcessCalls);
  LastExecutable := AExecutable;
  if ProcessRaises then
    raise Exception.Create('process failed');
  Result := ProcessResultValue;
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

procedure TestCreateFPCSourcePlanCoreUsesMainWhenVersionBlank;
var
  Plan: TFPCSourcePlan;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '');
  Check('source plan falls back to main version', Plan.Version = 'main', 'got=' + Plan.Version);
  Check('source plan path uses fpc-main', Pos('fpc-main', Plan.SourceDir) > 0, 'path=' + Plan.SourceDir);
end;

procedure TestExecuteFPCUpdatePlanCoreFailsWhenSourceMissing;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  Git: IFPCGitRuntime;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := False;
  Git := TFPCGitProbe.Create;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, Git);
    Check('update fails when source dir missing', not Success, 'unexpected success');
    Check('update missing dir error emitted', Errp.Contains(_Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [Plan.SourceDir])), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCUpdatePlanCoreFailsWithoutGitBackend;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  GitProbe: TFPCGitProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  GitProbe := TFPCGitProbe.Create;
  GitProbe.BackendAvailableResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, GitProbe);
    Check('update fails when git backend unavailable', not Success, 'unexpected success');
    Check('update backend error emitted', Errp.Contains(_(CMD_FPC_NO_GIT_BACKEND)), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCUpdatePlanCoreFailsWhenNotRepository;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  GitProbe: TFPCGitProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  GitProbe := TFPCGitProbe.Create;
  GitProbe.BackendAvailableResult := True;
  GitProbe.RepoResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, GitProbe);
    Check('update fails when source dir is not repo', not Success, 'unexpected success');
    Check('update not-repo error emitted', Errp.Contains(_Fmt(CMD_FPC_NOT_GIT_REPO, [Plan.SourceDir])), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCUpdatePlanCoreTreatsLocalOnlyRepoAsSuccess;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  GitProbe: TFPCGitProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  GitProbe := TFPCGitProbe.Create;
  GitProbe.BackendAvailableResult := True;
  GitProbe.RepoResult := True;
  GitProbe.RemoteResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, GitProbe);
    Check('update treats local-only repo as success', Success, 'unexpected failure');
    Check('update local-only message emitted', Outp.Contains(_(MSG_FPC_SOURCE_LOCAL_ONLY)), Outp.Text);
    Check('update local-only path included', Outp.Contains(Plan.SourceDir), Outp.Text);
    Check('update local-only skips pull', GitProbe.PullCalls = 0, 'pullcalls=' + IntToStr(GitProbe.PullCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCUpdatePlanCoreReportsPullSuccess;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  GitProbe: TFPCGitProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  GitProbe := TFPCGitProbe.Create;
  GitProbe.BackendAvailableResult := True;
  GitProbe.RepoResult := True;
  GitProbe.RemoteResult := True;
  GitProbe.PullResult := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, GitProbe);
    Check('update reports pull success', Success, 'unexpected failure');
    Check('update success message emitted', Outp.Contains(_(CMD_FPC_UPDATE_DONE)), Outp.Text);
    Check('update success path included', Outp.Contains(Plan.SourceDir), Outp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCUpdatePlanCoreReportsPullFailure;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  GitProbe: TFPCGitProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  GitProbe := TFPCGitProbe.Create;
  GitProbe.BackendAvailableResult := True;
  GitProbe.RepoResult := True;
  GitProbe.RemoteResult := True;
  GitProbe.PullResult := False;
  GitProbe.PullErrorText := 'merge failed';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, GitProbe);
    Check('update fails on pull failure', not Success, 'unexpected success');
    Check('update pull failure message emitted', Errp.Contains(_Fmt(CMD_FPC_GIT_PULL_FAILED, ['merge failed'])), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCUpdatePlanCoreNormalizesDirtyPullFailure;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  GitProbe: TFPCGitProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  GitProbe := TFPCGitProbe.Create;
  GitProbe.BackendAvailableResult := True;
  GitProbe.RepoResult := True;
  GitProbe.RemoteResult := True;
  GitProbe.PullResult := False;
  GitProbe.PullErrorText :=
    'error: Your local changes to the following files would be overwritten by merge:' + LineEnding +
    #9'README.txt' + LineEnding +
    'Please commit your changes or stash them before you merge.';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, GitProbe);
    Check('update dirty failure returns false', not Success, 'unexpected success');
    Check('update dirty failure normalized',
      Errp.Contains(_Fmt(CMD_FPC_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DIRTY_WORKTREE)])),
      Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCUpdatePlanCoreNormalizesDetachedHeadPullFailure;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  GitProbe: TFPCGitProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  GitProbe := TFPCGitProbe.Create;
  GitProbe.BackendAvailableResult := True;
  GitProbe.RepoResult := True;
  GitProbe.RemoteResult := True;
  GitProbe.PullResult := False;
  GitProbe.PullErrorText := 'Detached HEAD';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, GitProbe);
    Check('update detached failure returns false', not Success, 'unexpected success');
    Check('update detached failure normalized',
      Errp.Contains(_Fmt(CMD_FPC_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DETACHED_HEAD)])),
      Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCUpdatePlanCoreNormalizesDivergedPullFailure;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  GitProbe: TFPCGitProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  GitProbe := TFPCGitProbe.Create;
  GitProbe.BackendAvailableResult := True;
  GitProbe.RepoResult := True;
  GitProbe.RemoteResult := True;
  GitProbe.PullResult := False;
  GitProbe.PullErrorText := 'Non-fast-forward update requires merge/rebase';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCUpdatePlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, GitProbe);
    Check('update diverged failure returns false', not Success, 'unexpected success');
    Check('update diverged failure normalized',
      Errp.Contains(_Fmt(CMD_FPC_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DIVERGED_HISTORY)])),
      Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCCleanPlanCoreFailsWhenSourceMissing;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCCleanPlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, @Probe.Clean);
    Check('clean fails when source dir missing', not Success, 'unexpected success');
    Check('clean missing dir error emitted', Errp.Contains(_Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [Plan.SourceDir])), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCCleanPlanCoreReportsDeletedCount;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  Probe.CleanedCount := 12;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCCleanPlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, @Probe.Clean);
    Check('clean succeeds when cleaner returns count', Success, 'unexpected failure');
    Check('clean success message emitted', Outp.Contains(_(CMD_FPC_CLEAN_DONE)), Outp.Text);
    Check('clean deleted count included', Outp.Contains('12 file(s)'), Outp.Text);
    Check('clean path included', Outp.Contains(Plan.SourceDir), Outp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCCleanPlanCoreHandlesCleanerException;
var
  Plan: TFPCSourcePlan;
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Plan := CreateFPCSourcePlanCore('/tmp/fpdev-root', '3.2.2');
  Probe := TFPCRuntimeProbe.Create;
  Probe.DirectoryExistsResult := True;
  Probe.CleanRaises := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCCleanPlanCore(Plan, Outp, Errp, @Probe.DirectoryExistsAt, @Probe.Clean);
    Check('clean fails when cleaner raises exception', not Success, 'unexpected success');
    Check('clean exception message emitted', Errp.Contains('CleanSources failed - clean failed'), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCShowVersionInfoCoreRejectsInvalidVersion;
var
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Probe := TFPCRuntimeProbe.Create;
  Probe.ValidateVersionResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCShowVersionInfoCore('9.9.9', Outp, Errp,
      @Probe.ValidateVersion, @Probe.IsInstalled, @Probe.ResolveInstallPath, @Probe.LookupToolchain);
    Check('show info rejects invalid version', not Success, 'unexpected success');
    Check('show info invalid version error emitted', Errp.Contains(_Fmt(CMD_FPC_UNSUPPORTED_VERSION, ['9.9.9'])), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCShowVersionInfoCoreReportsInstalledToolchainInfo;
var
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
  ExpectedDate: string;
begin
  Probe := TFPCRuntimeProbe.Create;
  Probe.ValidateVersionResult := True;
  Probe.InstalledResult := True;
  Probe.InstallPathValue := '/tmp/fpc/3.2.2';
  Probe.ToolchainLookupResult := True;
  Probe.ToolchainInfoValue.InstallDate := EncodeDate(2026, 3, 9) + EncodeTime(10, 11, 12, 0);
  Probe.ToolchainInfoValue.SourceURL := 'https://example.invalid/fpc.git';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  ExpectedDate := FormatDateTime('yyyy-mm-dd hh:nn:ss', Probe.ToolchainInfoValue.InstallDate);
  try
    Success := ExecuteFPCShowVersionInfoCore('3.2.2', Outp, Errp,
      @Probe.ValidateVersion, @Probe.IsInstalled, @Probe.ResolveInstallPath, @Probe.LookupToolchain);
    Check('show info succeeds for installed version', Success, 'unexpected failure');
    Check('show info prints install date', Outp.Contains(_Fmt(MSG_FPC_INSTALL_DATE, [ExpectedDate])), Outp.Text);
    Check('show info prints source url', Outp.Contains(_Fmt(MSG_FPC_SOURCE_URL, [Probe.ToolchainInfoValue.SourceURL])), Outp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCShowVersionInfoCoreFormatsMissingInstallDateAsUnknown;
var
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Probe := TFPCRuntimeProbe.Create;
  Probe.ValidateVersionResult := True;
  Probe.InstalledResult := True;
  Probe.InstallPathValue := '/tmp/fpc/3.2.2';
  Probe.ToolchainLookupResult := True;
  Probe.ToolchainInfoValue.InstallDate := 0;
  Probe.ToolchainInfoValue.SourceURL := 'https://example.invalid/fpc.git';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCShowVersionInfoCore('3.2.2', Outp, Errp,
      @Probe.ValidateVersion, @Probe.IsInstalled, @Probe.ResolveInstallPath, @Probe.LookupToolchain);
    Check('show info succeeds when install date missing', Success, 'unexpected failure');
    Check('show info prints unknown install date when metadata missing',
      Outp.Contains(_Fmt(MSG_FPC_INSTALL_DATE, ['unknown'])), Outp.Text);
    Check('show info prints source url when install date missing',
      Outp.Contains(_Fmt(MSG_FPC_SOURCE_URL, [Probe.ToolchainInfoValue.SourceURL])), Outp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCShowVersionInfoCoreSupportsCustomWriterWithoutValidation;
var
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
  ExpectedDate: string;
begin
  Probe := TFPCRuntimeProbe.Create;
  Probe.InstalledResult := True;
  Probe.InstallPathValue := '/tmp/fpc/3.2.2';
  Probe.ToolchainLookupResult := True;
  Probe.ToolchainInfoValue.InstallDate := EncodeDate(2026, 3, 9) + EncodeTime(12, 13, 14, 0);
  Probe.ToolchainInfoValue.SourceURL := 'https://example.invalid/custom.git';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  ExpectedDate := FormatDateTime('yyyy-mm-dd hh:nn:ss', Probe.ToolchainInfoValue.InstallDate);
  try
    Success := ExecuteFPCShowVersionInfoCore('3.2.2', Outp, Errp,
      nil, @Probe.IsInstalled, @Probe.ResolveInstallPath, @Probe.LookupToolchain, @WriteCustomVersionInfo);
    Check('show info supports custom writer without validation', Success, 'unexpected failure');
    Check('show info custom install date emitted', Outp.Contains('Custom install date=' + ExpectedDate), Outp.Text);
    Check('show info custom source emitted', Outp.Contains('Custom source=' + Probe.ToolchainInfoValue.SourceURL), Outp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCShowVersionInfoCoreReportsNotInstalled;
var
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Probe := TFPCRuntimeProbe.Create;
  Probe.ValidateVersionResult := True;
  Probe.InstalledResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCShowVersionInfoCore('3.2.2', Outp, Errp,
      @Probe.ValidateVersion, @Probe.IsInstalled, @Probe.ResolveInstallPath, @Probe.LookupToolchain);
    Check('show info returns true for valid but not installed version', Success, 'unexpected failure');
    Check('show info not installed message emitted', Errp.Contains(_Fmt(ERR_NOT_INSTALLED, ['FPC 3.2.2'])), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCTestInstallationCoreFailsWhenNotInstalled;
var
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Probe := TFPCRuntimeProbe.Create;
  Probe.InstalledResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCTestInstallationCore('3.2.2', Outp, Errp,
      @Probe.IsInstalled, @Probe.ResolveInstallPath, @Probe.RunInfo);
    Check('test installation fails when version is not installed', not Success, 'unexpected success');
    Check('test installation not found message emitted', Errp.Contains(_Fmt(CMD_FPC_USE_NOT_FOUND, ['3.2.2'])), Errp.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCTestInstallationCoreReportsHealthyInstall;
var
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Probe := TFPCRuntimeProbe.Create;
  Probe.InstalledResult := True;
  Probe.InstallPathValue := '/tmp/fpc/3.2.2';
  Probe.ProcessResultValue.Success := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCTestInstallationCore('3.2.2', Outp, Errp,
      @Probe.IsInstalled, @Probe.ResolveInstallPath, @Probe.RunInfo);
    Check('test installation succeeds when command succeeds', Success, 'unexpected failure');
    Check('test installation prints checking message', Outp.Contains(_Fmt(CMD_FPC_DOCTOR_CHECKING, ['3.2.2'])), Outp.Text);
    Check('test installation prints ok message', Outp.Contains(_(CMD_FPC_DOCTOR_OK)), Outp.Text);
    Check('test installation executable uses bin directory', Pos(PathDelim + 'bin' + PathDelim + 'fpc', Probe.LastExecutable) > 0, Probe.LastExecutable);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteFPCTestInstallationCoreReportsIssues;
var
  Probe: TFPCRuntimeProbe;
  Outp, Errp: TStringOutput;
  Success: Boolean;
begin
  Probe := TFPCRuntimeProbe.Create;
  Probe.InstalledResult := True;
  Probe.InstallPathValue := '/tmp/fpc/3.2.2';
  Probe.ProcessResultValue.Success := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    Success := ExecuteFPCTestInstallationCore('3.2.2', Outp, Errp,
      @Probe.IsInstalled, @Probe.ResolveInstallPath, @Probe.RunInfo);
    Check('test installation returns false when command fails', not Success, 'unexpected success');
    Check('test installation prints issues message', Errp.Contains(_Fmt(CMD_FPC_DOCTOR_ISSUES, [1])), Errp.Text);
  finally
    Probe.Free;
  end;
end;

begin
  TestCreateFPCSourcePlanCoreUsesMainWhenVersionBlank;
  TestExecuteFPCUpdatePlanCoreFailsWhenSourceMissing;
  TestExecuteFPCUpdatePlanCoreFailsWithoutGitBackend;
  TestExecuteFPCUpdatePlanCoreFailsWhenNotRepository;
  TestExecuteFPCUpdatePlanCoreTreatsLocalOnlyRepoAsSuccess;
  TestExecuteFPCUpdatePlanCoreReportsPullSuccess;
  TestExecuteFPCUpdatePlanCoreReportsPullFailure;
  TestExecuteFPCUpdatePlanCoreNormalizesDirtyPullFailure;
  TestExecuteFPCUpdatePlanCoreNormalizesDetachedHeadPullFailure;
  TestExecuteFPCUpdatePlanCoreNormalizesDivergedPullFailure;
  TestExecuteFPCCleanPlanCoreFailsWhenSourceMissing;
  TestExecuteFPCCleanPlanCoreReportsDeletedCount;
  TestExecuteFPCCleanPlanCoreHandlesCleanerException;
  TestExecuteFPCShowVersionInfoCoreRejectsInvalidVersion;
  TestExecuteFPCShowVersionInfoCoreReportsInstalledToolchainInfo;
  TestExecuteFPCShowVersionInfoCoreFormatsMissingInstallDateAsUnknown;
  TestExecuteFPCShowVersionInfoCoreSupportsCustomWriterWithoutValidation;
  TestExecuteFPCShowVersionInfoCoreReportsNotInstalled;
  TestExecuteFPCTestInstallationCoreFailsWhenNotInstalled;
  TestExecuteFPCTestInstallationCoreReportsHealthyInstall;
  TestExecuteFPCTestInstallationCoreReportsIssues;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
